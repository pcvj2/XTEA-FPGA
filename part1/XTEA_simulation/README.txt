README.txt - XTEEA Duplex Encryption/Decryption System (QuestaSim)
Author - F130812

Overview
This simulation demonstrates the duplex operation of XTEA cipher in VHDL. The testbench xtea_tb.vhd verifies the encryption and decryption of 128-bit blocks.


Directory Structure
├── xtea_enc.vhd           # Encryption core
├── xtea_dec.vhd           # Decryption core
├── xtea_top_duplex.vhd    # Top-level module combining enc/dec
├── xtea_tb.vhd            # Testbench module
├── run_xtea_tb.tcl        # TCL script to compile and simulate
├── README.txt             # This file

Run Simulation Instructions
To compile and simulate the QuestaSim design:
1.	Ensure you are in the directory containing this README.txt file.
2.	Run this command "vsim -do run_xtea_tb.tcl"

This will: 
•	Create and map the work library
•	Compile source files
•	Launch the testbench simulation
•	Add key signals to the wave viewer
•	Run for 3800ns.
