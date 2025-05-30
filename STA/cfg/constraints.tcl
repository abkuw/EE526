# constraints.tcl
#
# This file is where design timing constraints are defined for Genus and Innovus.
# Many constraints can be written directly into the Hammer config files. However, 
# you may manually define constraints here as well.
#

create_clock -name clk -period 10 [get_ports clk_i]
# set_clock_uncertainty 0.03413 [get_clocks clk]

# Always set the input/output delay as half periods for clock setup checks
# set_input_delay  1.705 -max -clock [get_clocks clk] [all_inputs]
# set_output_delay 1.705 -max -clock [get_clocks clk] [all_outputs]

# Always set the input/output delay as 0 for clock hold checks
set_input_delay  0.0 -min -clock [get_clocks clk] [all_inputs]
set_output_delay 0.0 -min -clock [get_clocks clk] [all_outputs]

