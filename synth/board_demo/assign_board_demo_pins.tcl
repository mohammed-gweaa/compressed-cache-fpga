# ==============================================================================
# Script:      assign_board_demo_pins.tcl
# Target:      Terasic DE2i-150 FPGA Board (Cyclone IV GX EP4CGX150DF31C7)
# Module:      l2_bdi_cache_board_demo
# Author:      Mohammed Gweaa
# Description:
#   Full physical pin constraints and I/O standards for deploying the
#   BDI Compressed L2 Cache Hardware Live Demo with In-System Signal Probes (ISSP).
# ==============================================================================

post_message -type info "Configuring physical pin assignments for Terasic DE2i-150..."

# 50 MHz Master Clock
set_location_assignment PIN_AJ16 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

# Active-Low Pushbuttons (KEY[3:0])
set_location_assignment PIN_AA26 -to KEY[0]
set_location_assignment PIN_AE25 -to KEY[1]
set_location_assignment PIN_AF30 -to KEY[2]
set_location_assignment PIN_AE26 -to KEY[3]
set_instance_assignment -name IO_STANDARD "2.5 V" -to KEY[*]

# Slide Switches (SW[17:0]) - Exact Table 3-2 from DE2i-150 User Manual
set_location_assignment PIN_V28  -to SW[0]
set_location_assignment PIN_U30  -to SW[1]
set_location_assignment PIN_V21  -to SW[2]
set_location_assignment PIN_C2   -to SW[3]
set_location_assignment PIN_AB30 -to SW[4]
set_location_assignment PIN_U21  -to SW[5]
set_location_assignment PIN_T28  -to SW[6]
set_location_assignment PIN_R30  -to SW[7]
set_location_assignment PIN_P30  -to SW[8]
set_location_assignment PIN_R29  -to SW[9]
set_location_assignment PIN_R26  -to SW[10]
set_location_assignment PIN_N26  -to SW[11]
set_location_assignment PIN_M26  -to SW[12]
set_location_assignment PIN_N25  -to SW[13]
set_location_assignment PIN_J26  -to SW[14]
set_location_assignment PIN_K25  -to SW[15]
set_location_assignment PIN_C30  -to SW[16]
set_location_assignment PIN_H25  -to SW[17]
set_instance_assignment -name IO_STANDARD "2.5 V" -to SW[*]

# 7-Segment Display HEX0
set_location_assignment PIN_E15 -to HEX0[0]
set_location_assignment PIN_E12 -to HEX0[1]
set_location_assignment PIN_G11 -to HEX0[2]
set_location_assignment PIN_F11 -to HEX0[3]
set_location_assignment PIN_F16 -to HEX0[4]
set_location_assignment PIN_D16 -to HEX0[5]
set_location_assignment PIN_F14 -to HEX0[6]

# 7-Segment Display HEX1
set_location_assignment PIN_G14 -to HEX1[0]
set_location_assignment PIN_B13 -to HEX1[1]
set_location_assignment PIN_G13 -to HEX1[2]
set_location_assignment PIN_F12 -to HEX1[3]
set_location_assignment PIN_G12 -to HEX1[4]
set_location_assignment PIN_J9  -to HEX1[5]
set_location_assignment PIN_G10 -to HEX1[6]

# 7-Segment Display HEX2
set_location_assignment PIN_G8  -to HEX2[0]
set_location_assignment PIN_G7  -to HEX2[1]
set_location_assignment PIN_F7  -to HEX2[2]
set_location_assignment PIN_AG30 -to HEX2[3]
set_location_assignment PIN_F6  -to HEX2[4]
set_location_assignment PIN_F4  -to HEX2[5]
set_location_assignment PIN_F10 -to HEX2[6]

# 7-Segment Display HEX3
set_location_assignment PIN_D10 -to HEX3[0]
set_location_assignment PIN_D7  -to HEX3[1]
set_location_assignment PIN_E6  -to HEX3[2]
set_location_assignment PIN_E4  -to HEX3[3]
set_location_assignment PIN_E3  -to HEX3[4]
set_location_assignment PIN_D5  -to HEX3[5]
set_location_assignment PIN_D4  -to HEX3[6]

# 7-Segment Display HEX4
set_location_assignment PIN_A14 -to HEX4[0]
set_location_assignment PIN_A13 -to HEX4[1]
set_location_assignment PIN_C7  -to HEX4[2]
set_location_assignment PIN_C6  -to HEX4[3]
set_location_assignment PIN_C5  -to HEX4[4]
set_location_assignment PIN_C4  -to HEX4[5]
set_location_assignment PIN_C3  -to HEX4[6]

# 7-Segment Display HEX5
set_location_assignment PIN_D3  -to HEX5[0]
set_location_assignment PIN_A10 -to HEX5[1]
set_location_assignment PIN_A9  -to HEX5[2]
set_location_assignment PIN_A7  -to HEX5[3]
set_location_assignment PIN_A6  -to HEX5[4]
set_location_assignment PIN_A11 -to HEX5[5]
set_location_assignment PIN_B6  -to HEX5[6]

# 7-Segment Display HEX6
set_location_assignment PIN_B9  -to HEX6[0]
set_location_assignment PIN_B10 -to HEX6[1]
set_location_assignment PIN_C8  -to HEX6[2]
set_location_assignment PIN_C9  -to HEX6[3]
set_location_assignment PIN_D8  -to HEX6[4]
set_location_assignment PIN_D9  -to HEX6[5]
set_location_assignment PIN_E9  -to HEX6[6]

# 7-Segment Display HEX7
set_location_assignment PIN_E10 -to HEX7[0]
set_location_assignment PIN_F8  -to HEX7[1]
set_location_assignment PIN_F9  -to HEX7[2]
set_location_assignment PIN_C10 -to HEX7[3]
set_location_assignment PIN_C11 -to HEX7[4]
set_location_assignment PIN_C12 -to HEX7[5]
set_location_assignment PIN_D12 -to HEX7[6]

set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX0[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX1[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX2[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX3[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX4[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX5[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX6[*]
set_instance_assignment -name IO_STANDARD "2.5 V" -to HEX7[*]

# Green LEDs (LEDG[8:0])
set_location_assignment PIN_AA25 -to LEDG[0]
set_location_assignment PIN_AB25 -to LEDG[1]
set_location_assignment PIN_F27  -to LEDG[2]
set_location_assignment PIN_F26  -to LEDG[3]
set_location_assignment PIN_W26  -to LEDG[4]
set_location_assignment PIN_Y22  -to LEDG[5]
set_location_assignment PIN_Y25  -to LEDG[6]
set_location_assignment PIN_AA22 -to LEDG[7]
set_location_assignment PIN_J25  -to LEDG[8]
set_instance_assignment -name IO_STANDARD "2.5 V" -to LEDG[*]

# Red LEDs (LEDR[17:0])
set_location_assignment PIN_T23 -to LEDR[0]
set_location_assignment PIN_T24 -to LEDR[1]
set_location_assignment PIN_V27 -to LEDR[2]
set_location_assignment PIN_W25 -to LEDR[3]
set_location_assignment PIN_T21 -to LEDR[4]
set_location_assignment PIN_T26 -to LEDR[5]
set_location_assignment PIN_R25 -to LEDR[6]
set_location_assignment PIN_T27 -to LEDR[7]
set_location_assignment PIN_P25 -to LEDR[8]
set_location_assignment PIN_R24 -to LEDR[9]
set_location_assignment PIN_P21 -to LEDR[10]
set_location_assignment PIN_N24 -to LEDR[11]
set_location_assignment PIN_N21 -to LEDR[12]
set_location_assignment PIN_M25 -to LEDR[13]
set_location_assignment PIN_K24 -to LEDR[14]
set_location_assignment PIN_L25 -to LEDR[15]
set_location_assignment PIN_M21 -to LEDR[16]
set_location_assignment PIN_M22 -to LEDR[17]
set_instance_assignment -name IO_STANDARD "2.5 V" -to LEDR[*]

# Set Drive Strength and Slew Rate for Stable Visual Displays
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX0[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX1[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX2[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX3[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX4[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX5[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX6[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to HEX7[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to LEDG[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to LEDR[*]

set_instance_assignment -name SLEW_RATE 1 -to HEX0[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX1[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX2[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX3[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX4[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX5[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX6[*]
set_instance_assignment -name SLEW_RATE 1 -to HEX7[*]
set_instance_assignment -name SLEW_RATE 1 -to LEDG[*]
set_instance_assignment -name SLEW_RATE 1 -to LEDR[*]

post_message -type info "All DE2i-150 physical pin constraints and standards successfully assigned!"
