# System Limitations and Operational Boundaries

This document details known operational boundaries, adversarial vulnerability constraints, and threat modeling assumptions for the on-device attendance verification system.

---

## 1. Passive Anti-Spoofing (MiniFASNet) Limitations

### Modern Smartphone Screen Attacks
- **Passive MiniFASNet alone must not be treated as reliable protection against replayed high-definition video or photos displayed on a modern phone or tablet screen.**
- Modern mobile displays feature ultra-high pixel density (e.g. OLED / Retina displays > 450 PPI), high dynamic range, and anti-reflective glass. Under ambient illumination, passive 2D Fourier texture patterns, moiré artifacts, and specular reflectance cues on which 80x80 CNN models rely are significantly attenuated or entirely undetectable.

### Screen Filling Frame vs. Bezel Visible
- **Screen Filling the Frame**: When an attacker displays a face on a phone screen held close enough that the device bezel and borders are excluded from the camera field of view, the model receives only the face texture rendered through the display. In this scenario, passive MiniFASNet frequently assigns high live probabilities (scores above 0.95), producing false acceptances.
- **Bezel Visible**: When the smartphone bezel, chassis edges, or holding fingers are visible in the camera frame, environmental cues and edge reflections provide contextual indicators. However, because MiniFASNet crops tightly around the detected face bounding box, exterior bezel context is discarded by the 2.7x and 4.0x cropper if the crop boundary falls entirely within the replaying screen.

### Defense-in-Depth Architecture
- Passive liveness is designed as **Tier 1 of a multi-layer defense**, not an autonomous gate.
- To prevent replay and print attacks in production, passive liveness is coupled with:
  1. **Interactive Challenges (Step 05)**: Active head pose challenges, eye blink sequences, and random micro-motion prompts that cannot be satisfied by static photos or pre-recorded video loops.
  2. **Active Flash Challenge (Step 06)**: Dynamic screen illumination flash pulses measuring physical photometric skin reflectance and specular response across randomized RGB wavelengths.
  3. **Continuous Passive Monitoring**: Real-time rolling floor checks (`PassiveMonitor`) ensuring that a spoof device swapped during an active challenge triggers an immediate violation.

---

## 2. Sensor and Environmental Constraints

### Lighting Conditions
- Extreme backlight (e.g. subject standing directly in front of a bright window or sunlight) produces silhouetting that degrades landmark detection accuracy.
- Severe low-light (< 15 lux) introduces sensor gain noise that impairs both feature alignment and passive texture analysis.

### Occlusions and Angles
- The face detector requires visible eyes, nose, and mouth. Sunglasses, opaque surgical masks, or heavy partial occlusions prevent landmark extraction and fail the quality gate (`QualityIssue.landmarksMissing`).
- Head yaw and pitch exceeding 15 degrees fail the orientation gate (`QualityIssue.poseOutOfRange`) to prevent perspective foreshortening distortion during recognition.

---

## 3. Active Challenges, Temporal Signals & Flash Challenge Limitations

### Active Interactive Challenges
- **Real-Time Video Puppetry & Generative Avatars**: Interactive random prompts (blink, head turn, smile) mitigate static photos and pre-recorded video replays. However, state-of-the-art generative video puppetry or real-time 3D facial reenactment models driven by a live operator could theoretically follow prompts. Multi-factor passive texture analysis and depth cues remain critical.
- **Cheating by Pre-turned Head**: An attacker holding a printed photo already turned sideways could attempt to skip the turn phase. The state machine enforces starting from a neutral baseline (`awaitingCenter` within 10 degrees of baseline yaw) before registering turn progress.

### Temporal Motion Signals (TemporalAnalyzer)
- **Facial Micro-Motion**:
  - Live human subjects holding their breath and attempting to remain perfectly motionless in dim light can exhibit very low natural coordinate variance, approaching the frozen boundary.
  - Conversely, an attacker holding a printed photo or phone with natural hand tremor introduces physical jitter that can mimic physiological micro-movement. Micro-motion is therefore evaluated as a baseline gate (detecting completely frozen photos or paused screens), not standalone proof of life.
- **Video Loop Detection**:
  - Detects repeating periodic trajectories within 4 to 16 frame lags (approx. 0.3s to 1.5s).
  - Attackers using long, non-repeating video recordings or video loops longer than the sliding window buffer (25 frames) will not be flagged by the loop detection metric alone.
- **3D Planar Rigidity Test**:
  - Relies on fitting a 2D affine transformation between 5 facial landmarks across neutral and turned poses.
  - In a real 3D face, out-of-plane nasal protrusion produces depth parallax under yaw rotation that inflates affine residual error, whereas a flat 2D photograph rotates rigidly with near-zero residual.
  - *Limitation 1 (Wide-Angle Perspective)*: Close-up front-camera selfie lenses (< 25mm equivalent) introduce perspective foreshortening that can distort 2D planar projections even on flat surfaces.
  - *Limitation 2 (Small Head Turns)*: When head yaw rotation is under 15 degrees, 3D parallax displacement of the nose is negligible and cannot be reliably distinguished from 2D planar motion. The test is strictly skipped if yaw does not reach the required threshold.
  - *Limitation 3 (3D Curved Masks)*: A rigid 3D curved mask or bent printed cardboard possesses real geometric depth and may exhibit residual parallax similar to a live human face.

### Screen-Color-Flash Reflection Challenge (FlashChallenge)
- **Ambient Illumination Dependence**:
  - In direct sunlight or bright outdoor environments (> 220 brightness ceiling), ambient lux completely overpowers the phone display's maximum luminance, preventing measurable skin reflection shifts. The system skips evaluation and records `ambientTooBright`.
  - In total darkness (< 30 brightness floor), camera sensor noise and aggressive auto-gain amplification degrade chrominance delta SNR. The system skips evaluation and records `ambientTooDark`.
- **Specular Bounce off Glass**:
  - When a smartphone replay attack is positioned in close proximity to the authenticating device, specular screen reflection off the attacking phone's front glass can bounce colored light back into the camera.
  - While skin diffuse reflectance differs from glass specular reflection in chrominance saturation, flash challenge is treated as weighted supporting evidence, never an autonomous gate.
- **Hardware Configurable**:
  - Flash challenge can be enabled or disabled in Settings and defaults to active only on High Tier devices to preserve battery and throughput on resource-constrained hardware.


