README.txt - XTEA Duplex Encryption/Decryption with Router and IP generation System (QuestaSim)
Author - F130812

Overview
This simulation demonstrates the duplex operation of XTEA cipher in VHDL. The testbench xtea_tb.vhd verifies the encryption and decryption of 128-bit blocks.


Directory Structure
xteapart2/
├── cs_tb.vhd              # Top-level testbench
├── cs_top.vhd             # Main integration module
├── xtea_enc.vhd           # XTEA encryption core
├── xtea_dec.vhd           # XTEA decryption core
├── xtea_top_duplex.vhd    # Wrapper connecting ENC and DEC modules
├── mini_router.vhd        # Round-robin/prioritised router
├── ip_enc_gen.sv          # Input generator for plaintext/key
├── ip_dec_gen.sv          # Input generator for ciphertext
├── wave.do                # Optional: waveform script (generated or saved)
└── README.md              # This file

Run Simulation Instructions
To compile and simulate the QuestaSim design:
1.	Ensure you are in the directory containing this README.txt file.
2.	Run this command "vsim -do run_cs_tb.tcl"

This will: 
•	Create and map the work library
•	Compile source files
•	Launch the testbench simulation
•	Add key signals to the wave viewer
•	Run for 2000ns.
