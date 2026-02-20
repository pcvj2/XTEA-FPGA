# Create and map work library
vlib work
vmap work work

# Compile all VHDL files
vcom -2002 xtea_enc.vhd
vcom -2002 xtea_dec.vhd
vcom -2002 xtea_top_duplex.vhd
vcom -2002 xtea_tb.vhd

# Launch simulation
vsim -voptargs=+acc work.xtea_tb

# Add waveforms
add wave -divider "Clock & Reset"
add wave -hex /xtea_tb/clk
add wave -hex /xtea_tb/reset_n

add wave -divider "Input & Key Signals"
add wave -hex /xtea_tb/plaintext_in_data
add wave -hex /xtea_tb/plaintext_in_flag
add wave -hex /xtea_tb/ciphertext_in_data
add wave -hex /xtea_tb/ciphertext_in_flag
add wave -hex /xtea_tb/key_in_data
add wave -hex /xtea_tb/key_in_flag
add wave -hex /xtea_tb/key_ready_flag

add wave -divider "Output Flags & Data"
add wave -hex /xtea_tb/ciphertext_out_data
add wave -hex /xtea_tb/ciphertext_out_flag
add wave -hex /xtea_tb/plaintext_out_data
add wave -hex /xtea_tb/plaintext_out_flag

add wave -divider "Internals & Final Output"
add wave -hex /xtea_tb/input_data
add wave -hex /xtea_tb/xtea_keys
add wave -hex /xtea_tb/encrypted_data
add wave -hex /xtea_tb/decrypted_data

# Run and view
run 3800ns
wave zoom full
