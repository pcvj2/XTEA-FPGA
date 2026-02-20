# --------------------------------------------
# Quartus TCL Script for Mixed HDL Project Compilation
# --------------------------------------------

load_package flow

# ----------------------------
# Read project name from file
# ----------------------------
set nameFile "src/designName"
set fid [open $nameFile r]
set topModule [string trim [read $fid]]
close $fid

# ----------------------------
# Initialize Quartus project
# ----------------------------
project_new $topModule -overwrite

# ----------------------------
# Target device: DE1-SoC (Cyclone V)
# ----------------------------
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEMA5F31C6
set_global_assignment -name TOP_LEVEL_ENTITY $topModule

# ----------------------------
# Add HDL files
# ----------------------------

# Add SystemVerilog files from src/
foreach svFile [glob -nocomplain src/*.sv] {
    set_global_assignment -name SYSTEMVERILOG_FILE $svFile
    puts "Added SV: $svFile"
}

# Add VHDL files from src/
foreach vhdlFile [glob -nocomplain src/*.vhd] {
    set_global_assignment -name VHDL_FILE $vhdlFile
    puts "Added VHDL: $vhdlFile"
}

# ----------------------------
# Assign constraints (SDC)
# ----------------------------
set_global_assignment -name SDC_FILE "src/${topModule}.sdc"

# ----------------------------
# Load I/O Pin Assignments
# ----------------------------
if {[file exists "src/pin_assignments.tcl"]} {
    source "src/pin_assignments.tcl"
    puts "Pin assignments loaded."
} else {
    puts "Warning: No pin assignment file found."
}

# ----------------------------
# Compile design (synthesis + fit + timing)
# ----------------------------
puts "Starting Quartus build process..."
execute_flow -compile

# ----------------------------
# Move generated files
# ----------------------------
set outputExtensions {sof done jdi pin qpf qsf qws sld}
if {![file exists outputs]} {
    file mkdir outputs
}

foreach ext $outputExtensions {
    set f "${topModule}.${ext}"
    if {[file exists $f]} {
        file rename -force $f outputs/$f
        puts "Moved: $f outputs/"
    }
}

# ----------------------------
# Organize reports
# ----------------------------
if {![file exists reports]} {
    file mkdir reports
}

foreach rptFile [glob *.rpt *.summary] {
    file rename -force $rptFile reports/$rptFile
    puts "Moved: $rptFile  reports/"
}

# ----------------------------
# Program the FPGA
# ----------------------------
set sofPath "outputs/${topModule}.sof"
if {[file exists $sofPath]} {
    puts "Programming FPGA with $sofPath..."
    exec quartus_pgm -c "DE-SoC" -m jtag -o "p;$sofPath@2"
    puts "Programming complete."
} else {
    puts "Error: $sofPath not found. Skipping programming."
}

