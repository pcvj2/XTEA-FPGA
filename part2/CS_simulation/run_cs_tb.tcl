# Set up library
vlib work
vmap work work

# Compile VHDL files
vcom -2002 cs_tb.vhd
vcom -2002 cs_top.vhd
vcom -2002 mini_router.vhd
vcom -2002 xtea_enc.vhd
vcom -2002 xtea_dec.vhd
vcom -2002 xtea_top_duplex.vhd

# Compile Verilog files
vlog ip_enc_gen.sv
vlog ip_dec_gen.sv

# Start simulation
vsim -voptargs=+acc work.cs_tb

# Navigate to the testbench scope
add wave -divider "Top-Level Signals"
add wave -hex /cs_tb/clk_tb
add wave -hex /cs_tb/reset_tb

# Navigate into the unit under test
add wave -divider "Key Loading"
add wave -hex /cs_tb/uut/full_key
add wave -hex /cs_tb/uut/key_valid
add wave -hex /cs_tb/uut/key_index
add wave -hex /cs_tb/uut/key_sent

add wave -divider "Encryption Input"
add wave -hex /cs_tb/uut/data_word_in
add wave -hex /cs_tb/uut/data_valid
add wave -hex /cs_tb/uut/feeding_data

add wave -divider "Encryption Output"
add wave -hex /cs_tb/uut/ciphertext_word_out
add wave -hex /cs_tb/uut/ciphertext_ready
add wave -hex /cs_tb/uut/cipher_buffer
add wave -hex /cs_tb/uut/cipher_index

add wave -divider "Decryption Feeding"
add wave -hex /cs_tb/uut/feeding_ciphertext
add wave -hex /cs_tb/uut/ciphertext_word_in
add wave -hex /cs_tb/uut/ciphertext_valid
add wave -hex /cs_tb/uut/decrypt_index

add wave -divider "Decryption Output"
add wave -hex /cs_tb/uut/data_word_out
add wave -hex /cs_tb/uut/data_ready
add wave -hex /cs_tb/uut/decrypted_block

add wave -divider "Router and Input Gen"
add wave -hex /cs_tb/uut/router_data_out
add wave -hex /cs_tb/uut/router_valid
add wave -hex /cs_tb/uut/data1
add wave -hex /cs_tb/uut/req1
add wave -hex /cs_tb/uut/grant1
add wave -hex /cs_tb/uut/data2
add wave -hex /cs_tb/uut/req2
add wave -hex /cs_tb/uut/grant2

add wave -divider "ip_enc_gen Debug"
add wave -hex /cs_tb/uut/ip_gen_enc/active
add wave -hex /cs_tb/uut/ip_gen_enc/count
add wave -hex /cs_tb/uut/ip_gen_enc/plaintext

add wave -divider "xtea_enc FSM Debug"
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/state
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/round_counter
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v0
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v1
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v2
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/v3
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/cipher_buf
add wave /cs_tb/uut/xtea_inst/ENC_UNIT/valid_flag

add wave -divider "xtea_dec FSM Debug"
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/state
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/round_counter
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v0
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v1
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v2
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/v3
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/input_buf
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/output_buf
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/sum
add wave /cs_tb/uut/xtea_inst/DEC_UNIT/valid_flag

# Optional: run and fit
run 2000ns
wave zoom full
