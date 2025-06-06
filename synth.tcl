# this script generates the following useful files: ("*" is the module name)
# *.vg       - the synthesized structural verilog module netlist
# *_svsim.sv - a simulation wrapper file if your module has parameters or SystemVerilog syntax
# *.ddc      - the internal dc_shell design representation
#              can be reused for later synthesis with 'read_ddc'
# *.chk      - the check file of warnings and errors in the design
#              many warnings are safely ignorable, don't stress about them
# *.rep      - area, timing, constraint, resource, and netlist reports
#              mainly used for checking slack: run 'grep slack *.rep' to view slack

# and these files that you can just ignore: (these are created automatically :/)
# command.log  - a list of *every* command run, but without their output
#                includes all setup commands so can be a good reference, but hides this file far below
# *.mr         - meant for use with VHDL, can ignore since we use SystemVerilog
# default.svf  - used for formal verification of the compiled functionality
# *.pvl        - generated by the analyze command, loaded by dc_shell to avoid recompiling
#                if your design doesn't seem to be updating, delete this file
# *.syn        - generated by the analyze command, you can ignore these

########################################
# ---- load environment variables ---- #
########################################

# this script requires the following environment variables:
# CLOCK_PERIOD - the clock period                                  (a float)
# SOURCES      - a list of verilog source files (no header files)  (a space-separated string)
# MODULE       - the name of the top level module from the sources (a string)

# this script supports hierarchical synthesis through these *optional* environment variables:
# CHILD_MODULES - modules that will be included as-is and not recompile (a space-separated string)
# DDC_FILES     - the ddc sources that contain these child modules      (a space-separated string)

# also this optional environment variable:
# DC_SHELL_MULTICORE - how many CPU cores to use when compiling (an integer)

# an additional environment variable for synthesizing modules with parameters:
# PARAMS - an optional list of paramters for the top level module
#          in the form: Param1=val,Param2=val,Param3=val
#          i.e. the module: "module CAM #(parameter SIZE)" might have PARAMS: "SIZE=8"
#          these change both the module name and the name of the output files
#          MODULE becomes: MODULE_Param1val_Param2_val_Param3val
#          (this script does not support passing parameters to non-top level modules)
#          (it also does not support unnamed parameters or any other parameter format)

# required variables
# these are either set by a Makefile export or on the command line
# ex: CLOCK_PERIOD=30.0 SOURCES="my_mod.sv one.sv two.sv" MODULE=my_mod dc_shell-t -f flat_synth.tcl
try {
    set clock_period [getenv CLOCK_PERIOD]
    set sources [getenv SOURCES]
    set design_name [getenv MODULE]
} on error {msg} {
    puts "ERROR: failed to load a required environment variable"
    puts "Message: $msg"
    exit 1
}

# hierarchical synthesis variables (optional)
# (this try block fails silently if either variable is missing)
try {
  set child_modules [getenv CHILD_MODULES]
  set ddc_files [getenv DDC_FILES]
} on error {} {}

# how many CPU cores to use when compiling
# (this try block fails silently if the variable is missing)
try { set_host_options -max_cores [getenv DC_SHELL_MULTICORE] } on error {} {}

# set the module parameters for elaboration
# (this try block fails silently if the variable is missing)
try {
  set module_parameters [getenv PARAMS]
  puts "using parameters: $module_parameters"
  # if we elaborate successfully, we'll add the parameter suffix to the design name
  # convert equals and spaces to blank and convert commas to underscores
  set param_suffix [string map {"=" "" " " "" "," "_"} ${module_parameters}]
} on error {} {}

##########################################
# ---- link library and search path ---- #
##########################################

# these variables are needed by analyze and elaborate and by the 'link' command further down

set target_library lec25dscc25_TT.db

# link_library is a variable for resolving standard cell references in designs
# the standard cell library we use is in the lec25dscc25_TT.db file
# the * will have dc_shell search its own library first, then the target
set link_library "* $target_library"

# the search path is where dc_shell will search for files to read and load
# lec25dscc25_TT.db is located in the last location
set search_path [list "./" "../" "/afs/umich.edu/class/eecs470/lib/synopsys/"]

###########################################
# ---- setup miscellaneous variables ---- #
###########################################

# this script assumes your clock and reset variables will be named "clock" and "reset" everywhere
# note: these are just local variables
set clock_name clock
set reset_name reset

# this makes it so you don't need to add
# // synopsys sync_set_reset "reset"
# before every always_ff block
# I'm not updating every source file because of this though
set hdlin_ff_always_sync_set_reset "true"

# Set some flags 
suppress_message "VER-130" ;# warns on delays in non-blocking assignment
set suppress_errors "UID-401 OPT-1206 OPT-1207 OPT-12"

#############################################
# ---- read and elaborate source files ---- #
#############################################

# read files now so that we can fail quickly if analysis or elaboration have errors

# read ddc files directly, and give their modules the "dont_touch" parameter
# only if those modules were set above
if { [info exists child_modules] && $child_modules ne "" &&
     [info exists ddc_files    ] && $ddc_files     ne "" } {
  read_file -format ddc [list $ddc_files]
  set_dont_touch $child_modules
}

# try to elaborate and set the current design, but quit early if there are errors
# the combination of analyze and elaborate does the same thing as read_file
# analyze doesn't accept header files but does allow expanding parameters
if { ![analyze -format sverilog $sources] } {exit 1}

# elaborate, potentially with parameters
if { [info exists module_parameters] && $module_parameters ne ""} {
  if { ![elaborate $design_name -param "$module_parameters"] } {exit 1}
  set design_name ${design_name}_${param_suffix}
} else {
  if { ![elaborate $design_name] } {exit 1}
}

if { [current_design $design_name] == [list] } {exit 1}

#########################################
# ---- compilation setup functions ---- #
#########################################

# I'm defining functions here to break out and *name* the separate things we do for setup

proc eecs_470_set_compilation_flags {} {
  set_app_var compile_top_all_paths "true"
  set_app_var auto_wire_load_selection "false"
  set_app_var compile_seqmap_synchronous_extraction "true" ;# seems to be unused?
}

proc eecs_470_set_wire_load {design_name} {
  set WIRE_LOAD tsmcwire
  set LOGICLIB lec25dscc25_TT

  set_wire_load_model -name $WIRE_LOAD -lib $LOGICLIB $design_name
  set_wire_load_mode top
  set_fix_multiple_port_nets -outputs -buffer_constants
}

proc eecs_470_generate_clock {clock_name clock_period} {
  set CLK_UNCERTAINTY 0.1 ;# the latency/transition time of the clock

  create_clock -period $clock_period -name $clock_name [find port $clock_name]
  set_clock_uncertainty $CLK_UNCERTAINTY $clock_name
  set_fix_hold $clock_name
}

proc eecs_470_setup_paths {clock_name} {
  set DRIVING_CELL dffacs1 ;# the driving cell from the link_library

  # TODO: can we just remove these lines?
  group_path -from [all_inputs] -name input_grp
  group_path -to [all_outputs] -name output_grp

  set_driving_cell  -lib_cell $DRIVING_CELL [all_inputs]
  remove_driving_cell [find port $clock_name]
}

proc eecs_470_set_design_constraints {reset_name clock_name clock_period} {
  set AVG_FANOUT_LOAD 10
  set AVG_LOAD 0.1
  set AVG_INPUT_DELAY 0.1   ;# ns
  set AVG_OUTPUT_DELAY 0.1  ;# ns
  set CRIT_RANGE 1.0        ;# ns
  set MAX_FANOUT 32
  set MAX_TRANSITION 1.0    ;# percent

  # these are some unused values that I've commented out, but am leaving for reference
  # set HIGH_LOAD 1.0
  # set MID_FANOUT 8
  # set LOW_FANOUT 1
  # set HIGH_DRIVE 0
  # set FAST_TRANSITION 0.1

  # set some constraints
  set_fanout_load $AVG_FANOUT_LOAD [all_outputs]
  set_load $AVG_LOAD [all_outputs]
  set_input_delay $AVG_INPUT_DELAY -clock $clock_name [all_inputs]
  set_output_delay $AVG_OUTPUT_DELAY -clock $clock_name [all_outputs]

  # remove constraints for only the clock and reset
  # I'm not actually sure if we need these after the others or not
  remove_input_delay -clock $clock_name [find port $clock_name]
  set_dont_touch $reset_name
  set_resistance 0 $reset_name
  set_drive 0 $reset_name

  # these define specific limitations on the design and optimizer
  set_critical_range $CRIT_RANGE [current_design]
  set_max_delay $clock_period [all_outputs]
  # these are currently unused for some reason, leaving commented
  # set_max_fanout $MAX_FANOUT [current_design]
  # set_max_transition $MAX_TRANSITION [current_design]
}

####################################
# ---- synthesize the design! ---- #
####################################

eecs_470_set_compilation_flags

# link our current design against the link_library
# exit if there was an error
if { ![link] } {exit 1}

eecs_470_set_wire_load $design_name
eecs_470_generate_clock $clock_name $clock_period
eecs_470_setup_paths $clock_name
eecs_470_set_design_constraints $reset_name $clock_name $clock_period

# separate the subdesign instances to improve synthesis (excluding set_dont_touch designs)
# do this before writing the check file
uniquify
ungroup -all -flatten

# write the check file before compiling
set chk_file ./${design_name}.chk
redirect $chk_file { check_design }

# where the magic happens
# map_effort can be changed to high if you're ok with time increasing for better performance
# or you can change from compile to compile_ultra for best performance, but likely increased time
compile -map_effort medium
# compile_ultra

################################
# ---- write output files ---- #
################################

# note the .chk file is written just before the compile command above
set netlist_file ./${design_name}.vg       ;# our .vg file! it's generated here!
set ddc_file     ./${design_name}.ddc      ;# the internal dc_shell design representation (binary data)
set svsim_file   ./${design_name}_svsim.sv ;# a simulation instantiation wrapper
set rep_file     ./${design_name}.rep      ;# area, timing, constraint, resource, and netlist reports

# write the design into both sv and ddc formats, also the svsim wrapper
write_file -hierarchy -format verilog -output $netlist_file $design_name
write_file -hierarchy -format ddc     -output $ddc_file     $design_name
write_file            -format svsim   -output $svsim_file   $design_name

# the various reports (design, area, timing, constraints, resources)
redirect         $rep_file { report_design -nosplit }
redirect -append $rep_file { report_area }
redirect -append $rep_file { report_timing -max_paths 2 -input_pins -nets -transition_time -nosplit }
redirect -append $rep_file { report_constraint -max_delay -verbose -nosplit }
redirect -append $rep_file { report_resources -hier }

# also report a reference of the used modules from the final netlist
remove_design -all
read_file -format verilog $netlist_file
current_design $design_name
redirect -append $rep_file { report_reference -nosplit }

exit 0 ;# success! (maybe)