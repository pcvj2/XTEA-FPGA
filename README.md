## FPGA-Based XTEA Cryptographic Accelerator

**Language:** VHDL/SystemVerilog  
**Tools:** Intel Quartus Prime, ModelSim, TCL Scripting  
**Target Platform:** Altera DE1-SoC (Cyclone V)

---

## 🧠 Overview
This project implements a **duplex hardware accelerator** for the eXtended Tiny Encryption Algorithm (XTEA), supporting both encryption and decryption on FPGA hardware.  
It was developed as part of the *Electronic System Design with FPGAs (WSC354)* module under Dr. Luciano Ost.

The design was validated through simulation and hardware synthesis using Quartus Prime, achieving real-time throughput with minimal logic utilization.

---

## ⚙️ Architecture
The project consists of several synthesizable modules:

- `xtea_enc.vhd` – Encryption core  
- `xtea_dec.vhd` – Decryption core  
- `subkey_calc.vhd` – Parallel subkey generator  
- `xtea_top_duplex.vhd` – Top-level integrating encryption/decryption cores  
- `xtea_tb.vhd` – Self-checking testbench  
- `mini_router.vhd` – Priority-based router for message flow control  

---

## 🧩 Features
- **64-bit block encryption** using 128-bit keys  
- **Pipelined architecture** for high throughput  
- **Independent subkey calculation** (one clock cycle before use)  
- **Round-Robin arbitration router** for multiplexed I/O  
- Full simulation with ModelSim waveform validation  

---

## 📊 Results
| Metric | Value |
|--------|--------|
| Frequency (Fmax) | **70.37 MHz** |
| Logic utilization | **920 ALMs (3%)** |
| Power (Core Dynamic) | **9.44 mW** |
| Latency | **66 clock cycles per block** |
