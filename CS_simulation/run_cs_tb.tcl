# Set up library
vlib work
vmap work work
# Compile SystemVerilog files
vlog ip_enc_gen.sv
vlog ip_dec_gen.sv
# Compile VHDL files (2008 standard)
vcom -2008 mini_router.vhd
vcom -2008 xtea_enc.vhd
vcom -2008 xtea_dec.vhd
vcom -2008 xtea_top_duplex.vhd
vcom -2008 cs_top.vhd
vcom -2008 cs_tb.vhd
# Start simulation
vsim -voptargs=+acc work.cs_tb
# Top-level signals
add wave -divider "Top-Level Signals"
add wave -hex /cs_tb/clk_tb
add wave -hex /cs_tb/reset_tb
# Router and generators
add wave -divider "Router and Input Generators"
add wave -hex /cs_tb/uut/data1
add wave -hex /cs_tb/uut/req1
add wave -hex /cs_tb/uut/grant1
add wave -hex /cs_tb/uut/data2
add wave -hex /cs_tb/uut/req2
add wave -hex /cs_tb/uut/grant2
add wave -hex /cs_tb/uut/router_data_out
add wave -hex /cs_tb/uut/router_valid
# Key loading
add wave -divider "Key Loading"
add wave -hex /cs_tb/uut/full_key
add wave -hex /cs_tb/uut/key_valid
# Plaintext input
add wave -divider "Plaintext Input"
add wave -hex /cs_tb/uut/plain_word
add wave -hex /cs_tb/uut/plain_valid
add wave -hex /cs_tb/uut/block_ready
# Encryption
add wave -divider "Encryption"
add wave -hex /cs_tb/uut/ciphertext_word_out
add wave -hex /cs_tb/uut/ciphertext_ready
add wave -hex /cs_tb/uut/cipher_buffer
add wave -hex /cs_tb/uut/cipher_full
# Decryption
add wave -divider "Decryption"
add wave -hex /cs_tb/uut/ciph_word
add wave -hex /cs_tb/uut/ciph_valid
add wave -hex /cs_tb/uut/dec_word_out
add wave -hex /cs_tb/uut/dec_ready
add wave -hex /cs_tb/uut/dec_buffer
# XTEA enc FSM
add wave -divider "XTEA Enc FSM"
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/state
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/round_counter
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v0
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v1
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v2
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v3
# XTEA dec FSM
add wave -divider "XTEA Dec FSM"
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/state
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/round_counter
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v0
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v1
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v2
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v3
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/sum
# Run
run 2000ns
wave zoom full
