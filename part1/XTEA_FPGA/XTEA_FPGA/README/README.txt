README.txt - XTEA Duplex Encryption/Decryption System (QuestaSim)
Author - F130812

Overview
This project automoates the entire flow of compiling and deploying the xtea_top_duplex VHDL design to the Altera DE1-SoC FPGA board using Intel Quartus Prime.

Directory Structure
xteapart1/
├── scripts/
│   └── run.tcl              # Tcl script to automate build + optional power analysis
├── src/
│   ├── designName           # Contains project name, e.g., "xtea_top_duplex"
│   ├── xtea_top_duplex.vhd  # Top-level module for duplex encryption
│   ├── xtea_enc.vhd         # XTEA encryption VHDL core
│   ├── xtea_dec.vhd         # XTEA decryption VHDL core
│   ├── xteapart1.sdc        # Timing constraints (e.g., 50 MHz clock)
│   └── pin_assignments.tcl  # DE1-SoC pin mapping (e.g., clk, rst, LEDs)
├── outputs/                 # SOF, JDI, PWR files after compilation
├── reports/                 # Generated Quartus reports (map, fit, sta, etc.)
└── README.md                # This file

Project creation
•	Source file inclusion
•	Pin and timing constraint assignment
•	Full compilation and synthesis
•	SOF file generation and programming via JTAG

Run Instructions
Set working directory:
cd ~/xteapart1

Run .tcl script
quartus_sh -t scripts/run.tcl

The script performs:
•	Project creation (xtea_top_duplex)
•	Adds VHDL files from src/
•	Loads pin + timing constraints
•	Runs synthesis, fitting, and power analysis
•	Programs the board if connected
•	Moves .sof and .pwr into outputs/
