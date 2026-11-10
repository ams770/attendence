#!/usr/bin/env python3
"""
verify_recognition.py - SFace Preprocessing, Embedding & Verification Tool

Computes SFace face embeddings and evaluates cosine similarity separation
between genuine (same-person) and impostor (different-person) image pairs.

Usage:
  1. Dependencies:
     pip install onnxruntime opencv-python numpy

  2. Dataset Evaluation Mode:
     Compare pairs across person subdirectories (each subfolder represents one person):
       python3 tools/verify_recognition.py --dataset path/to/faces/

     Expected structure:
       faces/
         person_a/
           crop1.bmp
           crop2.jpg
         person_b/
           crop1.bmp
           crop2.jpg

  3. Pair Comparison Mode:
     Compare two individual 112x112 face crops directly:
       python3 tools/verify_recognition.py --compare image1.bmp image2.bmp

Options:
  --dataset PATH       Path to root directory containing person subfolders
  --compare IMG1 IMG2  Compare two individual face crop images
  --model PATH         Path to SFace ONNX model (default: assets/ai/face_recognition_sface_2021dec.onnx)
  --threshold FLOAT    Cosine similarity threshold (default: 0.363)
  --margin FLOAT       Minimum separation margin between top matches (default: 0.10)
"""

import argparse
import itertools
import os
import sys
from typing import Dict, List, Tuple

try:
    import cv2
    import numpy as np
    import onnxruntime as ort
except ImportError as e:
    print(f"Error importing required dependencies: {e}")
    print("Please install required packages using:")
    print("  pip install onnxruntime opencv-python numpy")
    sys.exit(1)

# Standard ArcFace canonical 112x112 5-point template (x, y)
ARCFACE_DST = np.array(
    [
        [38.2946, 51.6963],  # left eye
        [73.5318, 51.5014],  # right eye
        [56.0252, 71.7366],  # nose
        [41.5493, 92.3655],  # left mouth corner
        [70.7299, 92.2041],  # right mouth corner
    ],
    dtype=np.float32,
)


def l2_normalize(vector: np.ndarray) -> np.ndarray:
    """Computes unit vector using Euclidean norm."""
    norm = np.linalg.norm(vector)
    if norm == 0.0 or np.isnan(norm):
        return np.zeros_like(vector)
    return vector / norm


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Calculates cosine similarity between two 1D vectors."""
    dot = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return float(dot / (norm_a * norm_b))


class SFaceModel:
    """Wrapper around SFace ONNX Runtime session."""

    def __init__(self, model_path: str):
        if not os.path.isfile(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")

        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 2
        opts.intra_op_num_threads = 2
        self.session = ort.InferenceSession(
            model_path,
            sess_options=opts,
            providers=["CPUExecutionProvider"],
        )

        self.input_name = self.session.get_inputs()[0].name
        self.input_shape = self.session.get_inputs()[0].shape
        self.output_name = self.session.get_outputs()[0].name
        self.output_shape = self.session.get_outputs()[0].shape

        # SFace expects [1, 3, 112, 112]
        self.target_h = self.input_shape[2] if len(self.input_shape) >= 4 else 112
        self.target_w = self.input_shape[3] if len(self.input_shape) >= 4 else 112

    def preprocess(self, img_bgr: np.ndarray) -> np.ndarray:
        """
        Preprocesses image for SFace according to specification:
        - Resize to input dimensions (112x112)
        - Convert BGR to RGB
        - Channel order: [1, 3, H, W] planar float32
        - Raw [0.0, 255.0] unscaled byte values (scale=1.0, mean=0, std=1)
        """
        if img_bgr.shape[0] != self.target_h or img_bgr.shape[1] != self.target_w:
            img_bgr = cv2.resize(
                img_bgr,
                (self.target_w, self.target_h),
                interpolation=cv2.INTER_LINEAR,
            )

        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
        tensor = np.transpose(img_rgb, (2, 0, 1))
        tensor = np.expand_dims(tensor, axis=0)
        return tensor

    def compute_embedding(self, img_bgr: np.ndarray) -> np.ndarray:
        """Computes 128-d L2-normalized embedding for an aligned image."""
        tensor = self.preprocess(img_bgr)
        outputs = self.session.run(
            [self.output_name],
            {self.input_name: tensor},
        )
        raw_embedding = outputs[0].flatten().astype(np.float64)
        return l2_normalize(raw_embedding)


def run_pair_comparison(
    model: SFaceModel,
    path1: str,
    path2: str,
    threshold: float,
    margin: float,
) -> None:
    """Compares two individual images."""
    img1 = cv2.imread(path1)
    img2 = cv2.imread(path2)
    if img1 is None:
        print(f"Error: Unable to read image: {path1}")
        return
    if img2 is None:
        print(f"Error: Unable to read image: {path2}")
        return

    emb1 = model.compute_embedding(img1)
    emb2 = model.compute_embedding(img2)
    similarity = cosine_similarity(emb1, emb2)

    verdict = "MATCH" if similarity >= threshold else "NO MATCH"
    print("\n--- SFace Pair Comparison Result ---")
    print(f"Image 1:    {path1}")
    print(f"Image 2:    {path2}")
    print(f"Cosine:     {similarity:.4f}")
    print(f"Threshold:  {threshold:.4f}")
    print(f"Verdict:    {verdict}")


def run_dataset_evaluation(
    model: SFaceModel,
    dataset_dir: str,
    threshold: float,
    margin: float,
) -> None:
    """Evaluates genuine and impostor distribution across person folders."""
    if not os.path.isdir(dataset_dir):
        print(f"Error: Dataset directory not found: {dataset_dir}")
        return

    person_dirs = [
        d for d in os.listdir(dataset_dir)
        if os.path.isdir(os.path.join(dataset_dir, d))
    ]

    if len(person_dirs) < 2:
        print("Warning: Need at least 2 person subdirectories for impostor evaluation.")

    person_embeddings: Dict[str, List[np.ndarray]] = {}
    valid_exts = {".bmp", ".png", ".jpg", ".jpeg"}

    print(f"Loading dataset from: {dataset_dir}")
    total_images = 0
    for p in sorted(person_dirs):
        p_path = os.path.join(dataset_dir, p)
        files = [
            os.path.join(p_path, f) for f in os.listdir(p_path)
            if os.path.splitext(f.lower())[1] in valid_exts
        ]
        embs = []
        for f in files:
            img = cv2.imread(f)
            if img is not None:
                embs.append(model.compute_embedding(img))
                total_images += 1
        if embs:
            person_embeddings[p] = embs

    print(f"Loaded {total_images} images across {len(person_embeddings)} persons.")

    # 1. Genuine pairs (same person)
    genuine_scores: List[float] = []
    for p, embs in person_embeddings.items():
        if len(embs) >= 2:
            for e1, e2 in itertools.combinations(embs, 2):
                genuine_scores.append(cosine_similarity(e1, e2))

    # 2. Impostor pairs (different persons)
    impostor_scores: List[float] = []
    persons = list(person_embeddings.keys())
    for i in range(len(persons)):
        for j in range(i + 1, len(persons)):
            p1, p2 = persons[i], persons[j]
            for e1 in person_embeddings[p1]:
                for e2 in person_embeddings[p2]:
                    impostor_scores.append(cosine_similarity(e1, e2))

    print("\n================ SFace Evaluation Metrics ================")
    if genuine_scores:
        gen_arr = np.array(genuine_scores)
        print(f"Genuine Pairs:     {len(genuine_scores)}")
        print(f"  Mean Similarity: {gen_arr.mean():.4f} +/- {gen_arr.std():.4f}")
        print(f"  Min / Max:       {gen_arr.min():.4f} / {gen_arr.max():.4f}")
    else:
        print("Genuine Pairs:     None (requires >= 2 images per person)")

    if impostor_scores:
        imp_arr = np.array(impostor_scores)
        print(f"Impostor Pairs:    {len(impostor_scores)}")
        print(f"  Mean Similarity: {imp_arr.mean():.4f} +/- {imp_arr.std():.4f}")
        print(f"  Min / Max:       {imp_arr.min():.4f} / {imp_arr.max():.4f}")
    else:
        print("Impostor Pairs:    None")

    # Evaluation table across standard thresholds
    test_thresholds = [0.25, 0.30, 0.35, 0.363, 0.40, 0.45, 0.50]
    print("\nThreshold Performance Sweep:")
    print("---------------------------------------------------------")
    print(" Threshold | Genuine Acc (%) | Impostor Rej (%) | FAR (%) ")
    print("---------------------------------------------------------")
    for th in test_thresholds:
        gen_acc = (
            (sum(s >= th for s in genuine_scores) / len(genuine_scores) * 100.0)
            if genuine_scores else 0.0
        )
        imp_rej = (
            (sum(s < th for s in impostor_scores) / len(impostor_scores) * 100.0)
            if impostor_scores else 0.0
        )
        far = 100.0 - imp_rej if impostor_scores else 0.0
        print(f"   {th:0.3f}   |     {gen_acc:6.2f}      |     {imp_rej:6.2f}       |  {far:5.2f} ")
    print("---------------------------------------------------------")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify SFace face recognition preprocessing and cosine similarity.",
    )
    parser.add_argument(
        "--dataset",
        type=str,
        help="Path to dataset directory with person subfolders.",
    )
    parser.add_argument(
        "--compare",
        nargs=2,
        metavar=("IMG1", "IMG2"),
        help="Compare two individual image crops.",
    )
    parser.add_argument(
        "--model",
        type=str,
        default="assets/ai/face_recognition_sface_2021dec.onnx",
        help="Path to SFace ONNX model.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.363,
        help="Cosine similarity threshold (default: 0.363).",
    )
    parser.add_argument(
        "--margin",
        type=float,
        default=0.10,
        help="Recognition separation margin (default: 0.10).",
    )

    args = parser.parse_args()

    try:
        model = SFaceModel(args.model)
        print(f"Loaded SFace model from: {args.model}")
        print(f"Input: {model.input_name} {model.input_shape}")
        print(f"Output: {model.output_name} {model.output_shape}")
    except Exception as e:
        print(f"Failed to load SFace model: {e}")
        sys.exit(1)

    if args.compare:
        run_pair_comparison(
            model,
            args.compare[0],
            args.compare[1],
            args.threshold,
            args.margin,
        )
    elif args.dataset:
        run_dataset_evaluation(
            model,
            args.dataset,
            args.threshold,
            args.margin,
        )
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

