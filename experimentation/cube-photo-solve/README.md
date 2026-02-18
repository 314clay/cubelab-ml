# Rubik's Cube Last Layer Analyzer

Analyze a static photo of a Rubik's Cube and identify the OLL/PLL case with solution algorithm.

## Overview

This tool uses computer vision (OpenCV) and brute-force state matching to identify the Last Layer configuration of a Rubik's Cube from a single photo. It assumes the First Two Layers (F2L) are already solved.

**Input:** A single photo showing the **Top**, **Front**, and **Right** faces of the cube
**Output:** JSON file with the detected OLL/PLL case name and solution algorithm

## Features

- **Computer Vision:** OpenCV-based sticker detection using the Qbr methodology
- **Dynamic Color Classification:** K-Means clustering (no hardcoded RGB thresholds)
- **Brute-Force State Matching:** Generates ~3,900+ valid Last Layer states for comparison
- **Comprehensive Algorithm Database:** All 57 OLL cases and 21 PLL cases
- **Lighting-Robust:** Adapts to varying lighting conditions

## Installation

### Prerequisites

- Python 3.8+
- pip

### Install Dependencies

```bash
cd cube-photo-solve
pip install -r requirements.txt
```

This will install:
- `opencv-python` - Computer vision
- `numpy` - Numerical operations
- `scikit-learn` - K-Means clustering
- `kociemba` - Cube algorithms (reference only)

## Usage

### Basic Usage

```bash
python cube_analyzer.py cube_view.jpg
```

This will:
1. Detect and classify the 15 visible stickers
2. Match against the lookup table of valid LL states
3. Output results to `cube_result.json`

### Advanced Options

```bash
# Specify output file
python cube_analyzer.py cube_view.jpg --output my_result.json

# Save debug image with annotated stickers
python cube_analyzer.py cube_view.jpg --debug

# Adjust sticker detection sensitivity
python cube_analyzer.py cube_view.jpg --min-area 800 --max-area 60000
```

### Command-Line Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `image` | Path to cube image (required) | - |
| `--output`, `-o` | Output JSON file path | `cube_result.json` |
| `--debug` | Save annotated image showing detected stickers | `False` |
| `--min-area` | Minimum contour area for sticker detection | `1000` |
| `--max-area` | Maximum contour area for sticker detection | `50000` |

## Output Format

### Successful Match

```json
{
  "success": true,
  "case_name": "OLL 27 + T-Perm",
  "oll_case": "OLL 27",
  "pll_case": "T-Perm",
  "oll_algorithm": "R U R' U R U2 R'",
  "pll_algorithm": "R U R' U' R' F R2 U' R' U' R U R' F'",
  "rotation": "",
  "detected_colors": {
    "top": ["W", "W", "W", "W", "W", "W", "W", "W", "W"],
    "front_row": ["R", "R", "R"],
    "right_row": ["B", "B", "B"]
  },
  "confidence": 1.0,
  "input_image": "/path/to/cube_view.jpg"
}
```

### No Match Found

```json
{
  "success": false,
  "error": "No exact match found in lookup table",
  "detected_colors": {
    "top": ["W", "W", "Y", "W", "W", "W", "W", "W", "W"],
    "front_row": ["R", "R", "R"],
    "right_row": ["B", "B", "B"]
  },
  "closest_matches": [
    {
      "case_name": "OLL 27 + T-Perm",
      "oll_case": "OLL 27",
      "pll_case": "T-Perm",
      "difference": 2
    }
  ],
  "input_image": "/path/to/cube_view.jpg"
}
```

## How It Works

### 1. Computer Vision (CubeVision)

**Pipeline:**
1. **Preprocessing:** Grayscale conversion + Gaussian blur
2. **Edge Detection:** Canny edges + dilation to merge sticker gaps
3. **Contour Detection:** Find and filter square contours
   - 4 corners (using `approxPolyDP`)
   - Convex check
   - Area and aspect ratio filtering
4. **Perspective Warp:** Flatten top face to orthographic view
5. **Color Extraction:** Sample HSV values from sticker centers
6. **K-Means Clustering:** Group into 6 colors dynamically

**Output:** 15 face colors: Top (9) + Front top row (3) + Right top row (3)

### 2. State Resolution (StateResolver)

**Brute-Force Lookup Strategy:**
1. Generate all valid Last Layer states:
   - Start with solved cube
   - Apply every OLL algorithm (57 cases)
   - Apply every PLL algorithm (21 cases) to each OLL result
   - Include 4 rotations (y, y2, y', none)
   - Store ~3,900+ unique states
2. Match detected stickers against lookup table
3. Return exact match or closest alternatives

### 3. Cube State Representation

- **Custom Cube class** with 6 faces × 9 stickers each
- **Move functions** for R, L, U, D, F, B (+ modifiers ', 2)
- **Wide moves** (r, f) and **rotations** (x, y, z)
- **Algorithm parser** to apply sequences of moves

## Photography Tips

For best results:
1. **Solve F2L first** - Only the Last Layer should be unsolved
2. **Position the cube** - Show Top, Front, and Right faces clearly
3. **Good lighting** - Avoid harsh shadows or reflections
4. **Stable camera** - Reduce blur
5. **Fill the frame** - Cube should occupy most of the image
6. **Standard color scheme** - White top, Yellow bottom (standard orientation)

## Troubleshooting

### "Could not detect enough stickers"

**Causes:**
- Poor lighting
- Blurry image
- Cube too small in frame
- Non-standard cube colors

**Solutions:**
- Adjust `--min-area` and `--max-area` parameters
- Retake photo with better lighting
- Move camera closer to cube
- Use `--debug` to see what's being detected

### "No exact match found"

**Causes:**
- F2L not fully solved (invalid cube state)
- Color detection errors
- Non-standard cube state

**Solutions:**
- Verify F2L is solved
- Check detected colors in debug output
- Review closest matches to identify detection errors
- Retake photo with clearer sticker visibility

### Color Detection Issues

If colors are misclassified:
- Ensure good, even lighting
- Avoid strong colored lighting (e.g., sunset)
- Check that cube has standard colors
- Use `--debug` to visualize detected colors

## Project Structure

```
cube-photo-solve/
├── cube_analyzer.py       # Main CLI script
├── cube_vision.py         # CubeVision class (OpenCV pipeline)
├── state_resolver.py      # StateResolver class (lookup table)
├── algorithms.py          # OLL/PLL algorithm database
├── requirements.txt       # Python dependencies
├── README.md              # This file
└── tests/                 # Test files (future)
    ├── test_vision.py
    ├── test_resolver.py
    └── sample_images/
```

## Algorithm Database

- **57 OLL Cases:** All orientation patterns for the last layer
- **21 PLL Cases:** All permutation patterns for the last layer
- **Standard Algorithms:** Using common speedcubing notation

### Notation

- **R, L, U, D, F, B** - Face turns (clockwise)
- **'** - Counterclockwise (e.g., R')
- **2** - 180° turn (e.g., R2)
- **r, f** - Wide turns (two layers)
- **x, y, z** - Cube rotations
- **M** - Middle layer

## Limitations

1. **F2L Must Be Solved:** The system assumes the First Two Layers are complete
2. **Visible Faces Only:** Requires clear view of Top, Front, and Right faces
3. **Standard Color Scheme:** Best results with standard cube colors
4. **Lighting Sensitivity:** Extreme lighting may affect color detection
5. **No Edge Cases:** Cannot handle invalid cube states or unsolvable configurations

## Future Enhancements

- [ ] Support for different camera angles
- [ ] Real-time video processing
- [ ] Web interface for mobile uploads
- [ ] Support for solving from any state (not just Last Layer)
- [ ] Multi-language algorithm notation
- [ ] Visual solution animations

## License

MIT License - Feel free to use and modify

## Credits

- **Qbr Project:** Inspiration for OpenCV pipeline
- **Speedcubing Community:** Algorithm database and notation standards
- **kociemba Library:** Cube solving reference

## Contact

For issues, questions, or contributions, please open an issue on GitHub.
