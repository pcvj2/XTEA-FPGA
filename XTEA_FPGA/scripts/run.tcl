# ------------------------------------------------------
# Quartus TCL Automation Script
# Runs full compilation and optional FPGA programming
# ------------------------------------------------------

# Load Quartus compile-time tools
load_package flow

# ----------------------------
# Load project name from file
# ----------------------------
set projectPath "src/designName"
set fileID [open $projectPath "r"]
set projName [string trim [read $fileID]]
close $fileID

# ----------------------------
# Initialize the Quartus project
# ----------------------------
project_new $projName -overwrite

# ----------------------------
# Assign target FPGA configuration
# ----------------------------
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEMA5F31C6
set_global_assignment -name TOP_LEVEL_ENTITY xtea_top_duplex

# ----------------------------
# Add VHDL source files
# ----------------------------
foreach file {
    src/xtea_top_duplex.vhd
    src/xtea_enc.vhd
    src/xtea_dec.vhd
} {
    set_global_assignment -name VHDL_FILE $file
}

# ----------------------------
# Add constraints
# ----------------------------
set_global_assignment -name SDC_FILE src/xteapart1.sdc

# ----------------------------
# Load pin assignments (optional)
# ----------------------------
if {[file exists "src/pin_assignments.tcl"]} {
    source src/pin_assignments.tcl
}

# ----------------------------
# Execute full Quartus compilation
# ----------------------------
execute_flow -compile

# ----------------------------
# Program the device using JTAG
# ----------------------------
puts "==> Attempting to program device..."
set sofPath "outputs/${projName}.sof"
if {[file exists $sofPath]} {
    exec quartus_pgm -c "DE-SoC" -m jtag -o "p;$sofPath@2"
    puts "==> Programming completed."
} else {
    puts "!! ERROR: SOF file not found at $sofPath"
}

# -------------------------------
# Run Power Analysis after compilation
# -------------------------------
exec quartus_pow $projName --read_settings_files=on --write_settings_files=off

# Move the generated .pwr file to the outputs directory
set pwr_file "${projName}.pwr"
if {[file exists $pwr_file]} {
    file rename -force $pwr_file "outputs/$pwr_file"
    puts "Moved $pwr_file to outputs/$pwr_file"
} else {
    puts "Power analysis report $pwr_file not found."
}
