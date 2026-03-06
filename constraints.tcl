# -------------------------------------------------------------------------
# LexiSplit RTL Synthesis Script
# -------------------------------------------------------------------------

# Set target technology library (replace with your specific .db file)
set target_library "tcbn28hpcplus.db" 
set link_library "* $target_library"

# 1. Read SystemVerilog Source Files
analyze -format sverilog {
    expert_eval_unit.sv 
    adder_tree_32.sv 
    lexi_split_phase1.sv
    lexi_split_phase2.sv
    lexi_split_top.sv
}
elaborate lexi_split_top


# 2. Clock Constraints (1.0 ns period = 1 GHz)
create_clock -name clk -period 1.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_clock_transition 0.05 [get_clocks clk]

# 3. Input/Output Delay Constraints
# Assume inputs arrive 0.2ns after the clock edge from upstream logic
set data_inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_input_delay 0.2 -clock clk $data_inputs

# Async reset should not be part of synchronous setup/hold timing.
set_false_path -from [get_ports rst_n]

# Assume downstream logic requires the output 0.2ns before the next clock edge
set_output_delay 0.2 -clock clk [all_outputs]

# 4. Environment Constraints
# Define standard load capacitance (e.g., driving 4 standard inverters)
set_load 0.01 [all_outputs]
# Set maximum fanout to prevent massive, slow buffers
set_max_fanout 20 [current_design]

# 5. Compile Strategy
# Map to standard cells and optimize for timing and area
compile_ultra

# 6. Generate Reports for the Paper
file mkdir reports
report_timing > reports/timing_report.rpt
report_area   > reports/area_report.rpt
report_power  > reports/power_report.rpt

# 7. Export Gate-Level Netlist
file mkdir gate_level
write -format verilog -hierarchy -output gate_level/lexi_split_top_syn.v
