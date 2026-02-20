# Load the Quartus flow package so that flow commands are available
load_package flow

#-------------------------------
# Read the design name from the file in the src directory
#-------------------------------
set designNameFile "src/designName"
set fileId [open $designNameFile "r"]
set designName [read $fileId]
close $fileId
set designName [string trim $designName]  ;# Remove any trailing whitespace/newlines

#-------------------------------
# Create (or overwrite) the project using the design name
#-------------------------------
project_new $designName -overwrite

# Set target device for the DE1-SoC (Cyclone V device)
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEMA5F31C6

# Set the top-level entity using the design name
set_global_assignment -name TOP_LEVEL_ENTITY $designName

#-------------------------------
# Add SystemVerilog source files from src/
#-------------------------------
set fileListSV [glob -nocomplain src/*.sv]
foreach file $fileListSV {
    set_global_assignment -name SYSTEMVERILOG_FILE $file
    puts "Added SystemVerilog file: $file"
}

#-------------------------------
# Add VHDL source files from src/
#-------------------------------
set fileListVHD [glob -nocomplain src/*.vhd]
foreach file $fileListVHD {
    set_global_assignment -name VHDL_FILE $file
    puts "Added VHDL file: $file"
}

#-------------------------------
# Add the SDC file (manually created or exported from TimeQuest)
#-------------------------------
set_global_assignment -name SDC_FILE "src/${designName}.sdc"

#-------------------------------
# Source the pin assignment file
#-------------------------------
source "src/pin_assignments.tcl"

#-------------------------------
# Compile the project (generate .sof)
#-------------------------------
execute_flow -compile

#-------------------------------
# Move compilation outputs
#-------------------------------
set extensions {sof done jdi pin qpf qsf qws sld}
puts "Looking for output files for design: $designName"

if {![file isdirectory "outputs"]} {
    file mkdir "outputs"
    puts "Created outputs directory"
}

foreach ext $extensions {
    set src_file "${designName}.${ext}"
    set dst_file "outputs/${designName}.${ext}"
    puts "Checking for file: $src_file"
    if {[file exists $src_file]} {
        file rename -force $src_file $dst_file
        puts "Moved $src_file to $dst_file"
    } else {
        puts "File $src_file not found."
    }
}

#-------------------------------
# Move report files
#-------------------------------
if {![file isdirectory "reports"]} {
    file mkdir "reports"
    puts "Created reports directory."
}

foreach file [glob *.summary] {
    file rename -force $file "reports/$file"
    puts "Moved $file to reports/"
}

foreach file [glob *.rpt] {
    file rename -force $file "reports/$file"
    puts "Moved $file to reports/"
}

#-------------------------------
# Program FPGA
#-------------------------------
exec quartus_pgm -c "DE-SoC" -m jtag -o "p;outputs/${designName}.sof@1"

