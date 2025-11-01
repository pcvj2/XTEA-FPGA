README.txt - XTEA Duplex Encryption/Decryption with Router and IP Generation System (QuestaSim)
Author - F130812

Overview
This project automates the entire flow of compiling and deploying the cs_top VHDL design to the Altera DE1-SoC FPGA board using Intel Quartus Prime.

Directory Structure
xteapart2/
├── src/                    # All HDL and constraint files
│   ├── cs_top.vhd          # Top-level module
│   ├── cs_tb.vhd           # Testbench (for simulation only)
│   ├── xtea_enc.vhd        # Encryption core
│   ├── xtea_dec.vhd        # Decryption core
│   ├── xtea_top_duplex.vhd # Wrapper for encryption/decryption
│   ├── mini_router.vhd     # Round-robin router
│   ├── ip_enc_gen.sv       # Input generator for plaintext
│   ├── ip_dec_gen.sv       # Input generator for ciphertext
│   ├── cs_top.sdc          # Clock/Timing constraints
│   ├── pin_assignments.tcl # LED pin mappings for DE1-SoC
│   └── designName          # Text file with project name (e.g., `xtea_top_duplex`)
├── outputs/                # .sof bitstream and reports (generated)
├── reports/                # STA, Fit, Map summaries (generated)
├── scripts/                # run.tcl build + flash + power script
├── README/                 # Folder containing this documentation
├── cs_top.qpf              # Quartus Project File
└── run.tcl                 # Tcl automation script (called via quartus_sh)

Project creation
•	Source file inclusion
•	Pin and timing constraint assignment
•	Full compilation and synthesis
•	SOF file generation and programming via JTAG

Run Instructions
Set working directory:
cd ~/xteapart2

Run .tcl script
quartus_sh -t scripts/run.tcl

The script performs:
•	Project creation (xtea_top_duplex)
•	Adds VHDL files from src/
•	Loads pin + timing constraints
•	Runs synthesis, fitting, and power analysis
•	Programs the board if connected
