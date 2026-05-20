# Superpixel DMD-Camera Toolkit

This repository contains MATLAB utilities and control scripts to define superpixel patterns, embed them into regions of interest (ROIs), and interact with a Digital Micromirror Device (DMD). Functions are named according to the following convention:

---

## 📛 Function Naming Conventions

- `util_*` — General-purpose utility functions.  
  They perform numerical or image-processing tasks and can run independently of DMD or camera hardware.

- `dmd_*` — Functions that interact with the DMD hardware, e.g., for initialization, image transfer, or control.

- `cam_*` — Functions related to camera interaction or acquisition (none included yet in this set, but follow this pattern for future additions).

---

## 📦 Included Functions

### ### ✅ `util_*` — Standalone Tools

| Function | Purpose |
|---------|---------|
| [`util_superpx_calculator`](util_superpx_calculator.m) | Computes superpixel layout given either the number of superpixels or their side dimensions. Returns superpixel size, count along each axis, and adjusted ROI size. |
| [`util_bin_to_superpx`](util_bin_to_superpx.m) | Converts a binary array (+1/-1) into a tiled 2D binary image of checkered superpixels. |
| [`util_embed_ROI_in_DMD`](util_embed_ROI_in_DMD.m) | Embeds a binary image into a larger DMD-sized frame, placing it within a specified rectangular ROI. |
| [`util_roi_definition`](util_roi_definition.m) | Computes the top-left and bottom-right corner coordinates of a centered or shifted ROI inside the DMD frame. |

---

### 🖥️ `dmd_*` — DMD Hardware Control

| Function | Purpose |
|---------|---------|
| [`dmd_start`](dmd_start.m) | Initializes communication with the DMD hardware, sets up the library path, loads the DLL, and returns the device handle and DMD dimensions. |

---

## ⚙️ Typical Workflow

1. **Define the ROI** (centered or shifted):
   ```matlab
   [x1, y1, x2, y2] = util_roi_definition(W_DMD, H_DMD, W_ROI, H_ROI, x_shift, y_shift);
