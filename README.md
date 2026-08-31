# Drdo_centroid
# FPGA-Based Image Centroid Finder

A fully synthesizable RTL pipeline that locates the **centroid (center of mass)** of a dark object in a 256×256 grayscale image, implemented in Verilog and targeting the Xilinx Nexys A7 (Artix-7) FPGA.

a) Result

The red crosshair marks the hardware-detected centroid at **(col=109, row=162)** on the cameraman image — landing accurately on the cameraman's body.

![Centroid Result](centroid_result.png)

| | Value |
| Hardware output | Cx = 109, Cy = 162 |
| MATLAB reference | Cx = 110.5, Cy = 163.8 |
| Difference | ±1 pixel — due to integer truncation in hardware division 

b) What It Does

Given a 256×256 grayscale image stored in on-chip memory, the hardware:
1. Scans all 65,536 pixels in a **single pass**
2. Classifies each pixel as **foreground** (dark) if intensity < threshold (119)
3. Accumulates `sum_x` (column positions), `sum_y` (row positions), `count`
4. Divides to compute centroid: `Cx = sum_x / count`, `Cy = sum_y / count`

c) Architecture


        ┌──────────────────────────────────────────────┐
        │               centroid_top.v                 │
        │                                              │
        │  single_port_ram  ──►  7-state FSM           │
        │  (256×256 image)       │                     │
        │                        ├── S_IDLE            │
        │                        ├── S_PRELOAD         │
        │                        ├── S_SCAN ◄── 65536  │
        │                        │   sum_x += col      │
        │                        │   sum_y += row      │
        │                        │   count += 1        │
        │                        ├── S_FINALIZE        │
        │                        ├── S_DIV_X ◄── 25   │
        │                        ├── S_DIV_Y ◄── 25   │
        │                        └── S_DONE            │
        │                                              │
        │  restoring_divider25  (shift-subtract)       │
        └──────────────────────────────────────────────┘


d) Modules

i) centroid_top.v - Top-level FSM-single pass accumulation + division control 
ii) restoring_divider25.v - 25-bit hardware integer divider, shift-subtract, 25-cycle latency
iii) single_port_ram.v - 65536 × 8-bit, synchronous write / asynchronous read 



f) Key Design Decisions

1. Fixed threshold calibrated offline
Threshold (119) = global mean intensity of the image, computed once in MATLAB.
This removes all histogram/variance/Otsu hardware — significantly simpler RTL.

2. Single-pass accumulation
Each pixel is read exactly once. No second pass needed — centroid is computed
on-the-fly as pixels stream out of RAM.

3. Hardware restoring divider — no division operator
FPGAs have no native integer divider. The module implements shift-subtract:
- 25-bit dividend (max: 65536 × 255 = 16,711,680)
- 18-bit divisor (max count: 65536)
- 25 clock cycles latency per division
- Zero DSP blocks — pure LUT-based arithmetic

4. Asynchronous RAM read
Pixel data is available in the same cycle as the address — no extra pipeline stage.

g) Synthesis Results (Xilinx Artix-7, Nexys A7)

| Resource | Used | Available | Utilization |

| Slice LUTs | 217 | 20,800 | 1.04% |
| Flip-Flops | 252 | 9,600 | 0.61% |
| Block RAM | 0 | 50 | 0.00% |
| DSP Blocks | 0 | 90 | 0.00% |

- Zero DSPs — all arithmetic in LUT fabric (no multipliers needed)
- Zero BRAMs — image RAM synthesized as distributed LUT RAM
- Total utilization under "1.1%"

h) Performance
| Metric | Value |

| Clock | 100 MHz |
| Cycles per frame | 65,592 |
| Time per frame | **0.66 ms** |

i) Simulation Output


==========================================
Cycles taken     : 65592
Object Found     : 1
Centroid X (col) : 109
Centroid Y (row) : 162
==========================================
Expected: Object=1, Cx~110, Cy~163
(cameraman.tif 256x256, threshold=119)

 j) Files
├── centroid_top.v            # Top-level module (synthesizable)
├── restoring_divider25.v     # Hardware divider (synthesizable)
├── single_port_ram.v         # Image RAM (synthesizable)
├── image_processing_tb.v     # Testbench (simulation only)
├── image.hex                 # Test image in hex format (256×256)
├── generate_image_hex.m      # MATLAB script to generate image.hex
├── centroid_result.png       # Centroid visualized on cameraman image
└── README.md

k) Tools

- Vivado 2025.2 — synthesis and simulation
- MATLAB — image preprocessing, threshold calibration, result verification
- Board — Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
