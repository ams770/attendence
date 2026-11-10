#!/usr/bin/env python3
"""
verify_passive.py - MiniFASNet Preprocessing, Calibration & Precropped Evaluation Tool

Usage:
  1. Dependencies:
     pip install onnxruntime opencv-python numpy

  2. Precropped Evaluation Mode (Recommended for captured device crops):
     Evaluate exact 80x80 BMP crops captured on device via /dev/passive:
       python3 tools/verify_passive.py --precropped path/to/eval_crops/

     Directory structure expected:
       eval_crops/
         live_face/
           att1_1_v2.bmp
           att1_1_v1se.bmp
         video_on_phone_fullframe/
           ...
         video_on_phone_bezel_visible/
           ...
         photo_on_phone/
           ...
         printed_photo/
           ...

     This mode tests all 5 preprocessing variants and both class index interpretations (1 and 0),
     printing mean, std, min, max, sample raw logits (to detect saturation), and a separation table
     against live_face with optimal thresholds.

  3. Full Frame Dataset Evaluation Mode:
     python3 tools/verify_passive.py --dataset path/to/dataset

Options:
  --precropped PATH    Path to eval_crops folder containing scenario subdirectories with BMPs
  --dataset PATH       Path to dataset directory containing real/ and spoof/ folders
  --v1 PATH            Path to MiniFASNetV1SE.onnx (default: assets/ai/MiniFASNetV1SE.onnx)
  --v2 PATH            Path to MiniFASNetV2.onnx (default: assets/ai/MiniFASNetV2.onnx)
  --threshold FLOAT    Classification probability threshold for real class (default: 0.85)
  --csv PATH           Optional path to save per-image evaluation results as CSV
"""

import argparse
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


def softmax(x: np.ndarray) -> np.ndarray:
    """Computes softmax probabilities along the last axis."""
    e_x = np.exp(x - np.max(x, axis=-1, keepdims=True))
    return e_x / np.sum(e_x, axis=-1, keepdims=True)


def get_scaled_crop_box(
    src_w: int,
    src_h: int,
    bbox: Tuple[int, int, int, int],
    scale: float,
) -> Tuple[int, int, int, int]:
    """
    Computes scaled bounding box with scale reduction and boundary shifting.
    Matches Silent-Face-Anti-Spoofing reference implementation.
    """
    x, y, box_w, box_h = bbox
    max_scale = min((src_h - 1) / max(box_h, 1), (src_w - 1) / max(box_w, 1))
    eff_scale = min(scale, max_scale)

    new_w = box_w * eff_scale
    new_h = box_h * eff_scale
    center_x = x + box_w / 2.0
    center_y = y + box_h / 2.0

    left = center_x - new_w / 2.0
    top = center_y - new_h / 2.0
    right = center_x + new_w / 2.0
    bottom = center_y + new_h / 2.0

    if left < 0:
        right -= left
        left = 0
    if top < 0:
        bottom -= top
        top = 0
    if right > src_w - 1:
        left -= (right - (src_w - 1))
        right = src_w - 1
    if bottom > src_h - 1:
        top -= (bottom - (src_h - 1))
        bottom = src_h - 1

    return int(round(left)), int(round(top)), int(round(right)), int(round(bottom))


def crop_image(img: np.ndarray, scale: float, out_w: int = 80, out_h: int = 80) -> np.ndarray:
    """
    Crops image around face. If image is already a face crop, centers and scales.
    Otherwise uses center bounding box (approx 50% width and height).
    """
    h, w = img.shape[:2]
    box_w = int(w * 0.5)
    box_h = int(h * 0.5)
    x = int((w - box_w) / 2)
    y = int((h - box_h) / 2)
    bbox = (x, y, box_w, box_h)

    x1, y1, x2, y2 = get_scaled_crop_box(w, h, bbox, scale)
    x1 = max(0, min(x1, w - 1))
    y1 = max(0, min(y1, h - 1))
    x2 = max(x1 + 1, min(x2 + 1, w))
    y2 = max(y1 + 1, min(y2 + 1, h))

    cropped = img[y1:y2, x1:x2]
    return cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LINEAR)


# Definition of 5 preprocessing variants
PREPROCESS_VARIANTS = {
    "bgr_raw_255": {
        "desc": "BGR raw [0, 255]",
        "rgb": False,
        "scale": 1.0,
        "mean": [0.0, 0.0, 0.0],
        "std": [1.0, 1.0, 1.0],
    },
    "bgr_0_1": {
        "desc": "BGR normalized [0, 1]",
        "rgb": False,
        "scale": 1.0 / 255.0,
        "mean": [0.0, 0.0, 0.0],
        "std": [1.0, 1.0, 1.0],
    },
    "rgb_raw_255": {
        "desc": "RGB raw [0, 255]",
        "rgb": True,
        "scale": 1.0,
        "mean": [0.0, 0.0, 0.0],
        "std": [1.0, 1.0, 1.0],
    },
    "rgb_0_1": {
        "desc": "RGB normalized [0, 1]",
        "rgb": True,
        "scale": 1.0 / 255.0,
        "mean": [0.0, 0.0, 0.0],
        "std": [1.0, 1.0, 1.0],
    },
    "rgb_imagenet": {
        "desc": "RGB ImageNet mean/std",
        "rgb": True,
        "scale": 1.0 / 255.0,
        "mean": [0.485, 0.456, 0.406],
        "std": [0.229, 0.224, 0.225],
    },
}


def preprocess_tensor(img_80: np.ndarray, config: dict) -> np.ndarray:
    """Preprocesses an 80x80 BGR image into an NCHW float32 tensor."""
    if config["rgb"]:
        img = cv2.cvtColor(img_80, cv2.COLOR_BGR2RGB)
    else:
        img = img_80.copy()

    tensor = img.astype(np.float32) * config["scale"]
    mean = np.array(config["mean"], dtype=np.float32)
    std = np.array(config["std"], dtype=np.float32)
    tensor = (tensor - mean) / std

    # HWC to CHW: (80, 80, 3) -> (3, 80, 80)
    tensor = np.transpose(tensor, (2, 0, 1))
    # Add batch dimension: (1, 3, 80, 80)
    tensor = np.expand_dims(tensor, axis=0)
    return tensor.astype(np.float32)


def find_best_threshold(live_scores: List[float], spoof_scores: List[float]) -> Tuple[float, float]:
    """Finds the decision threshold [0.00, 1.00] maximizing binary classification accuracy."""
    if not live_scores or not spoof_scores:
        return 0.50, 0.0

    best_thresh = 0.50
    best_acc = -1.0
    total = len(live_scores) + len(spoof_scores)

    for step in range(101):
        t = step / 100.0
        tp = sum(1 for s in live_scores if s >= t)
        tn = sum(1 for s in spoof_scores if s < t)
        acc = (tp + tn) / total * 100.0
        if acc > best_acc:
            best_acc = acc
            best_thresh = t

    return best_thresh, best_acc


def evaluate_precropped(
    precropped_dir: str,
    v1_path: str,
    v2_path: str,
    csv_path: str = None,
):
    """
    Evaluates precropped 80x80 BMPs captured directly from device.
    Skips detection/cropping and assesses all 5 preprocessing variants
    and both real-class index interpretations (1 and 0).
    """
    if not os.path.isdir(precropped_dir):
        print(f"Error: Precropped directory not found: {precropped_dir}")
        sys.exit(1)

    print(f"Loading ONNX models...")
    print(f"  MiniFASNetV1SE: {v1_path}")
    print(f"  MiniFASNetV2:   {v2_path}")

    sess_v1 = ort.InferenceSession(v1_path)
    sess_v2 = ort.InferenceSession(v2_path)
    input_v1 = sess_v1.get_inputs()[0].name
    input_v2 = sess_v2.get_inputs()[0].name

    # Discover scenario directories and files
    # Structure: eval_crops/<label>/*_v2.bmp and /*_v1se.bmp
    scenario_files: Dict[str, Dict[str, List[str]]] = {}

    subdirs = [d for d in os.listdir(precropped_dir) if os.path.isdir(os.path.join(precropped_dir, d))]
    if subdirs:
        for d in sorted(subdirs):
            subpath = os.path.join(precropped_dir, d)
            v2_files = [
                os.path.join(subpath, f)
                for f in os.listdir(subpath)
                if f.lower().endswith("_v2.bmp")
            ]
            v1se_files = [
                os.path.join(subpath, f)
                for f in os.listdir(subpath)
                if f.lower().endswith("_v1se.bmp")
            ]
            if v2_files or v1se_files:
                scenario_files[d] = {"v2": sorted(v2_files), "v1se": sorted(v1se_files)}
    else:
        # User may have pointed directly inside a single scenario folder
        v2_files = [
            os.path.join(precropped_dir, f)
            for f in os.listdir(precropped_dir)
            if f.lower().endswith("_v2.bmp")
        ]
        v1se_files = [
            os.path.join(precropped_dir, f)
            for f in os.listdir(precropped_dir)
            if f.lower().endswith("_v1se.bmp")
        ]
        label = os.path.basename(os.path.abspath(precropped_dir))
        scenario_files[label] = {"v2": sorted(v2_files), "v1se": sorted(v1se_files)}

    print(f"\nDiscovered Scenarios and Crop Counts:")
    for label, files in scenario_files.items():
        print(f"  - {label}: {len(files['v2'])} V2 crops, {len(files['v1se'])} V1SE crops")

    models = {
        "MiniFASNetV2": (sess_v2, input_v2, "v2"),
        "MiniFASNetV1SE": (sess_v1, input_v1, "v1se"),
    }

    csv_rows = []

    for model_name, (sess, input_name, model_key) in models.items():
        print(f"\n================================================================================")
        print(f"MODEL: {model_name}")
        print(f"================================================================================")

        for var_name, var_cfg in PREPROCESS_VARIANTS.items():
            print(f"\n--------------------------------------------------------------------------------")
            print(f"Variant: {var_name} [{var_cfg['desc']}]")
            print(f"--------------------------------------------------------------------------------")

            # Store computed metrics: label -> {'raw_logits': [], 'probs_c1': [], 'probs_c0': []}
            data_by_label: Dict[str, Dict[str, List]] = {}

            for label, files_dict in scenario_files.items():
                file_list = files_dict[model_key]
                logits_list = []
                c1_list = []
                c0_list = []

                for path in file_list:
                    img = cv2.imread(path)
                    if img is None:
                        continue
                    tensor = preprocess_tensor(img, var_cfg)
                    out = sess.run(None, {input_name: tensor})[0][0]
                    probs = softmax(out)

                    logits_list.append(out.tolist())
                    c1_list.append(float(probs[1]))
                    c0_list.append(float(probs[0]))

                    if csv_path:
                        csv_rows.append({
                            "model": model_name,
                            "variant": var_name,
                            "scenario": label,
                            "file": os.path.basename(path),
                            "logit_0": float(out[0]),
                            "logit_1": float(out[1]),
                            "logit_2": float(out[2]),
                            "prob_c0": float(probs[0]),
                            "prob_c1": float(probs[1]),
                            "prob_c2": float(probs[2]),
                        })

                data_by_label[label] = {
                    "logits": logits_list,
                    "c1": c1_list,
                    "c0": c0_list,
                }

            # 1. Print Per-Label Statistics for Real Class = Index 1 (Original)
            print("Interpretation A: Real Class = Index 1 (Silent-Face Original)")
            print(f"{'Scenario Label':<30} {'Count':<6} {'Mean':<8} {'Std':<8} {'Min':<8} {'Max':<8}")
            for label, d in data_by_label.items():
                scores = d["c1"]
                if scores:
                    mean_val = np.mean(scores)
                    std_val = np.std(scores)
                    min_val = np.min(scores)
                    max_val = np.max(scores)
                    print(f"{label:<30} {len(scores):<6} {mean_val:<8.4f} {std_val:<8.4f} {min_val:<8.4f} {max_val:<8.4f}")
                else:
                    print(f"{label:<30} 0      --       --       --       --")

            # 2. Print Per-Label Statistics for Real Class = Index 0 (Alternative)
            print("\nInterpretation B: Real Class = Index 0 (Alternative Hypothesis)")
            print(f"{'Scenario Label':<30} {'Count':<6} {'Mean':<8} {'Std':<8} {'Min':<8} {'Max':<8}")
            for label, d in data_by_label.items():
                scores = d["c0"]
                if scores:
                    mean_val = np.mean(scores)
                    std_val = np.std(scores)
                    min_val = np.min(scores)
                    max_val = np.max(scores)
                    print(f"{label:<30} {len(scores):<6} {mean_val:<8.4f} {std_val:<8.4f} {min_val:<8.4f} {max_val:<8.4f}")
                else:
                    print(f"{label:<30} 0      --       --       --       --")

            # 3. Print Sample Raw Logits to make saturation apparent
            print("\nSample Raw Logits (first 3 frames per scenario):")
            for label, d in data_by_label.items():
                sample_logits = d["logits"][:3]
                if sample_logits:
                    formatted = "; ".join([f"[{l[0]:.2f}, {l[1]:.2f}, {l[2]:.2f}]" for l in sample_logits])
                    print(f"  {label:<28}: {formatted}")

            # 4. Separation Table between live_face and each spoof label
            live_key = "live_face" if "live_face" in data_by_label else (
                "real" if "real" in data_by_label else None
            )

            if live_key and data_by_label[live_key]["c1"]:
                live_scores_c1 = data_by_label[live_key]["c1"]
                live_scores_c0 = data_by_label[live_key]["c0"]
                mean_live_c1 = np.mean(live_scores_c1)
                mean_live_c0 = np.mean(live_scores_c0)

                print(f"\nSeparation Table vs '{live_key}' (Class 1 Interpretation):")
                print(f"{'Spoof Scenario':<32} {'Delta':<10} {'Best Thresh':<12} {'Accuracy'}")
                for label, d in data_by_label.items():
                    if label == live_key:
                        continue
                    spoof_scores = d["c1"]
                    if spoof_scores:
                        delta = mean_live_c1 - np.mean(spoof_scores)
                        b_thresh, b_acc = find_best_threshold(live_scores_c1, spoof_scores)
                        print(f"{label:<32} {delta:<+10.4f} {b_thresh:<12.2f} {b_acc:.1f}%")

                print(f"\nSeparation Table vs '{live_key}' (Class 0 Interpretation):")
                print(f"{'Spoof Scenario':<32} {'Delta':<10} {'Best Thresh':<12} {'Accuracy'}")
                for label, d in data_by_label.items():
                    if label == live_key:
                        continue
                    spoof_scores = d["c0"]
                    if spoof_scores:
                        delta = mean_live_c0 - np.mean(spoof_scores)
                        b_thresh, b_acc = find_best_threshold(live_scores_c0, spoof_scores)
                        print(f"{label:<32} {delta:<+10.4f} {b_thresh:<12.2f} {b_acc:.1f}%")
            else:
                print(f"\nNote: No 'live_face' scenario found among discovered folders. Separation table omitted.")

    if csv_path and csv_rows:
        import csv
        with open(csv_path, "w", newline="") as f:
            fieldnames = [
                "model",
                "variant",
                "scenario",
                "file",
                "logit_0",
                "logit_1",
                "logit_2",
                "prob_c0",
                "prob_c1",
                "prob_c2",
            ]
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(csv_rows)
        print(f"\nSaved precropped evaluation details to CSV: {csv_path}")


def evaluate_dataset(
    dataset_dir: str,
    v1_path: str,
    v2_path: str,
    threshold: float = 0.85,
    csv_path: str = None,
):
    real_dir = os.path.join(dataset_dir, "real")
    spoof_dir = os.path.join(dataset_dir, "spoof")

    if not os.path.isdir(real_dir) or not os.path.isdir(spoof_dir):
        print(f"Error: Dataset directory must contain 'real' and 'spoof' subdirectories: {dataset_dir}")
        sys.exit(1)

    print(f"Loading ONNX models...")
    print(f"  MiniFASNetV1SE: {v1_path}")
    print(f"  MiniFASNetV2:   {v2_path}")

    sess_v1 = ort.InferenceSession(v1_path)
    sess_v2 = ort.InferenceSession(v2_path)
    input_name_v1 = sess_v1.get_inputs()[0].name
    input_name_v2 = sess_v2.get_inputs()[0].name

    valid_exts = {".jpg", ".jpeg", ".png", ".bmp"}
    real_files = [os.path.join(real_dir, f) for f in os.listdir(real_dir) if os.path.splitext(f)[1].lower() in valid_exts]
    spoof_files = [os.path.join(spoof_dir, f) for f in os.listdir(spoof_dir) if os.path.splitext(f)[1].lower() in valid_exts]

    print(f"Found {len(real_files)} real images and {len(spoof_files)} spoof images.")
    if len(real_files) == 0 or len(spoof_files) == 0:
        print("Warning: Insufficient images found for meaningful comparison.")

    models = {
        "MiniFASNetV2": (sess_v2, input_name_v2, 2.7),
        "MiniFASNetV1SE": (sess_v1, input_name_v1, 4.0),
    }

    results = []

    for model_name, (sess, input_name, crop_scale) in models.items():
        print(f"\n=======================================================")
        print(f"Evaluating {model_name} (Crop scale: {crop_scale})")
        print(f"=======================================================")

        for var_name, var_cfg in PREPROCESS_VARIANTS.items():
            real_scores_per_class = {0: [], 1: [], 2: []}
            spoof_scores_per_class = {0: [], 1: [], 2: []}

            # Evaluate real images
            for path in real_files:
                img = cv2.imread(path)
                if img is None:
                    continue
                crop = crop_image(img, crop_scale)
                tensor = preprocess_tensor(crop, var_cfg)
                out = sess.run(None, {input_name: tensor})[0][0]
                probs = softmax(out)
                for c in range(3):
                    real_scores_per_class[c].append(float(probs[c]))
                results.append({
                    "model": model_name,
                    "variant": var_name,
                    "image": os.path.basename(path),
                    "label": "real",
                    "prob_c0": float(probs[0]),
                    "prob_c1": float(probs[1]),
                    "prob_c2": float(probs[2]),
                })

            # Evaluate spoof images
            for path in spoof_files:
                img = cv2.imread(path)
                if img is None:
                    continue
                crop = crop_image(img, crop_scale)
                tensor = preprocess_tensor(crop, var_cfg)
                out = sess.run(None, {input_name: tensor})[0][0]
                probs = softmax(out)
                for c in range(3):
                    spoof_scores_per_class[c].append(float(probs[c]))
                results.append({
                    "model": model_name,
                    "variant": var_name,
                    "image": os.path.basename(path),
                    "label": "spoof",
                    "prob_c0": float(probs[0]),
                    "prob_c1": float(probs[1]),
                    "prob_c2": float(probs[2]),
                })

            print(f"\nVariant: {var_name} ({var_cfg['desc']})")
            print(f"  Class 1 as Real (Original Assumption):")
            mean_real = np.mean(real_scores_per_class[1]) if real_scores_per_class[1] else 0.0
            mean_spoof = np.mean(spoof_scores_per_class[1]) if spoof_scores_per_class[1] else 0.0
            delta = mean_real - mean_spoof
            tp = sum(1 for s in real_scores_per_class[1] if s >= threshold)
            tn = sum(1 for s in spoof_scores_per_class[1] if s < threshold)
            total = len(real_files) + len(spoof_files)
            acc = (tp + tn) / max(total, 1) * 100.0

            print(f"    Mean Real Score:  {mean_real:.4f}")
            print(f"    Mean Spoof Score: {mean_spoof:.4f}")
            print(f"    Separation Delta: {delta:+.4f}")
            print(f"    Accuracy @ {threshold}: {acc:.1f}% ({tp}/{len(real_files)} real passed, {tn}/{len(spoof_files)} spoof blocked)")

            delta_c0 = np.mean(real_scores_per_class[0]) - np.mean(spoof_scores_per_class[0])
            delta_c2 = np.mean(real_scores_per_class[2]) - np.mean(spoof_scores_per_class[2])
            print(f"    Alternative Class Deltas: Class 0: {delta_c0:+.4f}, Class 2: {delta_c2:+.4f}")

    if csv_path and results:
        import csv
        with open(csv_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["model", "variant", "image", "label", "prob_c0", "prob_c1", "prob_c2"])
            writer.writeheader()
            writer.writerows(results)
        print(f"\nSaved detailed evaluation CSV to: {csv_path}")


def main():
    parser = argparse.ArgumentParser(description="MiniFASNet Preprocessing, Calibration & Precropped Verification Tool")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--precropped", type=str, help="Path to eval_crops folder containing scenario subdirectories with BMPs")
    group.add_argument("--dataset", type=str, help="Path to full-frame directory containing real/ and spoof/ folders")

    parser.add_argument("--v1", type=str, default="assets/ai/MiniFASNetV1SE.onnx", help="Path to MiniFASNetV1SE.onnx")
    parser.add_argument("--v2", type=str, default="assets/ai/MiniFASNetV2.onnx", help="Path to MiniFASNetV2.onnx")
    parser.add_argument("--threshold", type=float, default=0.85, help="Classification probability threshold (default: 0.85)")
    parser.add_argument("--csv", type=str, default=None, help="Optional CSV output file path")

    args = parser.parse_args()

    if args.precropped:
        evaluate_precropped(args.precropped, args.v1, args.v2, args.csv)
    elif args.dataset:
        evaluate_dataset(args.dataset, args.v1, args.v2, args.threshold, args.csv)


if __name__ == "__main__":
    main()
