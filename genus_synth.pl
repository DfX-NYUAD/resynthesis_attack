#!/usr/bin/perl

use strict;
use POSIX();
use Cwd qw(); 
use warnings;
#use diagnostics;
#use Math::Matrix;
use Storable qw(dclone);
use Time::HiRes qw(time);
use Term::ANSIColor qw(:constants);

my $min_target_slack = 0;
my $cadence_run_limit = 10;

my $arg_ok = 1;
my $arg_cnt = 0;

my $is_dux = 0;
my $is_auto = 0;
my $bs_delay = 0;
my $ld_delay = 0;
my $gen_bench = 0;
my $glb_key_dc = 0;
my $user_delay = 10;
my $module_name = "";
my $glb_per_mt = 0.1;
my $glb_gen_eff = "high";
my $glb_map_eff = "high";
my $glb_opt_eff = "high";
my $glb_delay_cons = 80000;

# JK
my $dbg = 0;

while (1){
  if (defined $ARGV[$arg_cnt]){
    if ($ARGV[$arg_cnt] eq "-h" or $ARGV[$arg_cnt] eq "-help"){
      $arg_ok = 0;
      last;
    }
    else{
      if (index($ARGV[$arg_cnt], "-mod=") != -1){
        $module_name = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5);
      }
      elsif (index($ARGV[$arg_cnt], "-gen=") != -1){
        $glb_gen_eff = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5);
        if ($glb_gen_eff ne "low" and $glb_gen_eff ne "medium" and $glb_gen_eff ne "high"){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-map=") != -1){
        $glb_map_eff = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5);
        if ($glb_map_eff ne "low" and $glb_map_eff ne "medium" and $glb_map_eff ne "high"){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-opt=") != -1){
        $glb_opt_eff = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5);
        if ($glb_opt_eff ne "low" and $glb_opt_eff ne "medium" and $glb_opt_eff ne "high" and $glb_opt_eff ne "extreme"){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-crl=") != -1){
        $cadence_run_limit = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5) + 0.0;
        if ($cadence_run_limit < 1){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-pmt=") != -1){
        $glb_per_mt = substr($ARGV[$arg_cnt], 5, length($ARGV[$arg_cnt])-5) + 0.0;
        if ($glb_per_mt <= 0){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-kdc") != -1){
        $glb_key_dc = 1;
      }
      elsif (index($ARGV[$arg_cnt], "-bench") != -1){
        $gen_bench = 1;
      }
      elsif (index($ARGV[$arg_cnt], "-dc=") != -1){
        $glb_delay_cons = substr($ARGV[$arg_cnt], 4, length($ARGV[$arg_cnt])-4) + 0.0;
        if ($glb_delay_cons <= 0){
          $arg_ok = 0;
        }
      }
      elsif (index($ARGV[$arg_cnt], "-bsd") != -1){
        $bs_delay = 1;
      }
      elsif (index($ARGV[$arg_cnt], "-ldd") != -1){
        $ld_delay = 1;
      }
      elsif (index($ARGV[$arg_cnt], "-auto") != -1){
        $is_auto = 1;
      }
      elsif (index($ARGV[$arg_cnt], "-dux") != -1){
        $is_dux = 1;
      }
      else{
        $arg_ok = 0;
        last;
      }
    }
  }
  else{
    if (!$arg_cnt){
      $arg_ok = 0;
    }
    last;
  }

  $arg_cnt++;
}

if ($arg_ok){
  if ($module_name ne ""){
    if ($is_auto){
      auto_part();
    }
    else{
      main_part(0, 0, 0, 0, $glb_gen_eff, $glb_map_eff, $glb_opt_eff, $glb_delay_cons, $glb_per_mt, $glb_key_dc);
    }
  }
  else{
    help_part();
  }
}
else{
  help_part();
}

sub help_part{
  print "######################################################################################################################################################### \n";
  print "# Usage:       perl genus_synth.pl -mod=<str> -gen=<str> -map=<str> -opt=<str> -dc=<int> -pmt=<int> -kdc -bsd -ldd -crl=<int> -auto -bench -dux         # \n"; 
  print "# -mod:        Name of the module of the top design                                                                                                     # \n";
  print "# -gen:        Cadence Genus effort on syn_generic command, by default it is high                                                                       # \n";
  print "# -map:        Cadence Genus effort on syn_map command, by default it is high                                                                           # \n";
  print "# -opt:        Cadence Genus effort on syn_opt command, by default it is high                                                                           # \n";
  print "# -dc:         Delay constraint in picoseconds by default it is 80000                                                                                   # \n";
  print "# -pmt:        Maximum transition value in percentage of the delay constraint by default it is 10%                                                      # \n";
  print "# -kdc:        Sets the given delay constraint between key inputs and outputs to an extreme value of 1ps by default it does not                         # \n";
  print "# -bsd:        Different delay constraints are found in a binary search manner and used to find different designs by default it does not                # \n";
  print "# -ldd:        Different delay constraints are found in a linear degradation manner and used to find different designs by default it does not           # \n";
  print "# -crl:        Cadence Genus run limit while determinig the delay constraint using bsd and ldd methods, by default it is 10                             # \n";
  print "# -auto:       Runs the script for all possible cases by default it does not                                                                            # \n";
  print "# -bench:      Converts the resynthsized Verilog file to a bench file by default it does not                                                            # \n";
  print "# -dux:        Does not use XOR/XNOR gates by default it does                                                                                           # \n";
  print "# -h:          Prints this screen                                                                                                                       # \n";
  print "# Description: Automatically generates the synthesis script and runs the Cadence Genus synthesis tool                                                   # \n";
  print "#              In auto option, design results are reported in a summary file                                                                            # \n";
  print "#              In ldd method, the delay constraint is decreased by the value of critical path delay in first synthesis divided by the Cadence run limit # \n";
  print "######################################################################################################################################################### \n";
}

sub skip_spaces_forward{
  my ($the_string, $the_offset) = @_;
  my $the_length = length($the_string);

  while (index($the_string, " ", $the_offset) eq $the_offset) {
    $the_offset++;
    if ($the_offset > $the_length) {
      last;
    }
  }

  return $the_offset;
}

sub skip_spaces_backward{
  my ($the_string, $the_offset) = @_;

  while (index($the_string, " ", $the_offset) eq $the_offset) {
    $the_offset--;
    if ($the_offset < 0) {
      last;
    }
  }

  return $the_offset;
}

sub extract_time_data{

  my $time_slack = 0;
  my $data_path = 0;

  my $time_report = $module_name . "_time.report";

  if (open (my $fid_timing, '<:encoding(UTF-8)', $time_report)){
    while (my $the_line = <$fid_timing>){
      chomp ($the_line);
      my $lline = length($the_line);

      my $dp_index = index($the_line, "Data Path:");
      my $sl_index = index($the_line, "Slack:");

      if ($dp_index != -1){
        $dp_index = skip_spaces_forward($the_line, $dp_index+11);
        $data_path = substr($the_line, $dp_index, length($the_line)-$dp_index) + 0.0;
      }
      if ($sl_index != -1){
        $sl_index = skip_spaces_forward($the_line, $sl_index+7);
        $time_slack = substr($the_line, $sl_index, length($the_line)-$sl_index) + 0.0;
      }

      if ($time_slack and $dp_index){
        last;
      }
    }

    close ($fid_timing);
  }
  else{
    print "[ERROR] Could not open the $time_report file! \n";
  }

  return ($time_slack, $data_path);
}

sub generate_synth_tcl{
  my ($cir_index, $gen_eff, $map_eff, $opt_eff, $delay_cons, $trans_val, $key_dc) = @_;

  my $mapped_file = "";
  my $dontuse_str = "\n";

  if ($is_dux){
    $dontuse_str = <<END_OF_MESSAGE;  
# JK NOTE revised for NG45
set_dont_use XNOR2_X* 
set_dont_use XOR2_X* 
END_OF_MESSAGE
  }

  my $synth_name = $module_name . "_gen_" . $gen_eff . "_map_" . $map_eff . "_opt_" . $opt_eff;
  if ($is_auto){
    $mapped_file = $module_name . "_" . $cir_index . "_mapped.v";
  }
  else{
    $mapped_file = $synth_name . "_dp" .$delay_cons . "_mt" . $trans_val . "_mapped.v";
  }

  my $dc_str = "\n";
  if ($key_dc){
    $dc_str = "set_max_delay 1 -from [get_ports keyinput*] -to [all_output] \n";
  }
  
  my $tcl_file = $module_name . ".tcl";

  open (my $fid_tcl, '>', $tcl_file);
  my $the_message = <<END_OF_MESSAGE;  
### Initial Settings ###

set TOP_DESIGN $module_name
set VERILOG_FILES {$module_name.v}

# Setting analytical optimization to extreme
# From the datapath manual: Set the attribute value before elaboration to achieve better results
set_db dp_analytical_opt extreme
# Set datapath optimization focus on area
set_db dp_area_mode true

# Setting the number of CPUs
set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"

### Using the libraries ###

# To set the library search path and library file
set_db init_lib_search_path /home/jk176/old_home/work/Nangate/
set_db library NangateOpenCellLibrary_typical.lib

# To set the script search path
#set_db script_search_path path

# To set the HDL files search path
#set_db init_hdl_search_path path

### Loading Files ###

#read_hdl -language v2001 \$VERILOG_FILES
# JK NOTE the verilog netlist generated by 'abc' contains "design" as module name, which is a protected keyword for v2001. We could also use 'sed' or so to revise the module name
# if that quick fix below does not work out...
read_hdl -language v1995 \$VERILOG_FILES

### Elaborating the Design ###

elaborate \$TOP_DESIGN
check_design -unresolved

### Applying Constraints ###

set_time_unit -picoseconds
create_clock -domain clk_domain -name "clk_name" -period $delay_cons 
set_input_delay -clock clk_name 20 [all_inputs]
set_output_delay -clock clk_name 20 [all_outputs]
set_clock_uncertainty 14 clk_name
set_clock_latency 100 clk_name
set_max_transition $trans_val
$dc_str
### Defining Optimization Settings ###

# Ungroup all the instances manually
ungroup -all -flatten

# Set the power analysis effort high
set_db lp_power_analysis_effort high 

# To automatically enable partitioning
set_db auto_partition true

# For control logic optimization
set_db control_logic_optimization advanced

# To keeo the feedback loops in fron of flip-flops
set_db hdl_ff_keep_feedback true

# Boundary optimizations
set_db delete_unloaded_seqs true 
set_db boundary_optimize_invert_hpins true
set_db boundary_optimize_constant_hpins true
set_db boundary_optimize_feedthrough_hpins true 
set_db boundary_optimize_equal_opposite_hpins true 

# DP (datapath) commands
set_db dp_csa basic
# Setting dp_rewriting to advanced increases the area
set_db dp_rewriting basic
set_db dp_sharing advanced 
set_db dp_speculation none

# Use multibits in the library
set_db use_multibit_cells true
set_db use_multibit_combo_cells true
set_db use_multibit_seq_and_tristate_cells true
# Merge commands on multibits, merge commands generally works with instances
set_db / .multibit_adaptive_costing true
set_db / .force_merge_combos_into_multibit_cells true
set_db / .force_merge_seqs_into_multibit_cells true
set_db / .merge_combinational_hier_instance true

# Parallelization of the area optimization to reduce the run-time

set_db distributed_area_opt_cleanup true

#puts "The value for db_rewriting is [get_db dp_rewriting]"

### Reducing Runtime Using SuperThreading ###

set_db auto_super_thread true

### Do not use these logic gates
# JK NOTE revised for NG45
# JK NOTE here we're supposed to disable any multi-output gates
set_dont_use FA_X1
set_dont_use HA_X1
$dontuse_str
### Performing Synthesis ###

# syn_generic (for generic synthesis)
set_db syn_generic_effort $gen_eff
syn_generic

# syn_map (for technology mapping)
set_db syn_map_effort $map_eff
syn_map

# syn_opt (for place and route) 
set_db syn_opt_effort $opt_eff
syn_opt

### Write the Netlist in Verilog ###
write_hdl > $mapped_file;

### Generating Reports ###
report_area > \${TOP_DESIGN}_area.report
report_timing > \${TOP_DESIGN}_time.report
report_gates > \${TOP_DESIGN}_gate.report
report_power > \${TOP_DESIGN}_power.report

puts \"The RUNTIME is [get_db real_runtime]\"
puts \"The MEMORY USAGE is [get_db memory_usage]\"

END_OF_MESSAGE

  printf $fid_tcl "$the_message";

  close ($fid_tcl);

  return ($tcl_file, $mapped_file);
}

sub extract_report_data{
  my ($the_file, $the_parameter) = @_;

  my $first_data = -1;
  my $second_data = -1;

  my $init_index;
  my $last_index;

  if (open (my $the_fid, '<:encoding(UTF-8)', $the_file)){
    while (my $the_line = <$the_fid>){
      chomp ($the_line);
      #print "the_line: $the_line \n";
      #sleep (1);
      my $lline = length($the_line);

      if ($the_parameter eq "area"){
# JK NOTE revised for Genus 21.16 and NG45
#        $last_index = index($the_line, "ZeroWireload");
        $last_index = index($the_line, "5K_hvratio_1_1");
        if ($last_index != -1){
          $last_index = skip_spaces_backward($the_line, $last_index-1);
          $init_index = $last_index;
          while (substr($the_line, $init_index, 1) ne " "){
            $init_index--;

            if ($init_index < 0){
              last;
            }
          }

          $first_data = substr($the_line, $init_index+1, $last_index-$init_index);
# JK
	  if ($dbg == 1) {
		  print "the_line: '$the_line' --  the_data: '$first_data' \n";
		  sleep (1);
	  }

          close ($the_fid);
          return ($first_data, $second_data);
        }
      }
      elsif ($the_parameter eq "time"){
        $init_index = index($the_line, "Data Path:");
        if ($init_index != -1){
          $init_index = skip_spaces_forward($the_line,$init_index+11);
          $last_index = $init_index;
          while (substr($the_line, $last_index, 1) ne " "){
            $last_index++;

            if ($last_index > $lline){
              last;
            }
          }

          $first_data = substr($the_line, $init_index, $last_index-$init_index);
# JK
	  if ($dbg == 1) {
		  print "the_line: '$the_line' --  the_data: '$first_data' \n";
		  sleep (1);
	  }
        }
        
        $init_index = index($the_line, "Slack:");
        if ($init_index != -1){
          $init_index = skip_spaces_forward($the_line,$init_index+7);
          $last_index = $init_index;
          while (substr($the_line, $last_index, 1) ne " "){
            $last_index++;

            if ($last_index > $lline){
              last;
            }
          }

          $second_data = substr($the_line, $init_index, $last_index-$init_index);
# JK
	  if ($dbg == 1) {
		  print "the_line: '$the_line' --  the_data: '$second_data' \n";
		  sleep (1);
	  }

          close ($the_fid);
          return ($first_data, $second_data);
        }
      }
      elsif ($the_parameter eq "power"){

# JK NOTE revised for Genus 21.16
#
        $init_index = index($the_line, "Subtotal");
        if ($init_index != -1){
          $init_index = skip_spaces_forward($the_line, $init_index+8);

# JK NOTE lines look like this, with total power toward the end
#     Subtotal     9.42762e-06  2.72428e-06  3.74087e-06  1.58928e-05 100.00% 
# So, skip from beginning of first number to last number
          $init_index = skip_spaces_forward($the_line, $init_index+39);

          $last_index = $init_index;
          while (substr($the_line, $last_index, 1) ne " "){
            $last_index++;

            if ($last_index >= length($the_line)){
              last;
            }
          }

          $first_data = substr($the_line, $init_index, $last_index-$init_index);
# JK
	  if ($dbg == 1) {
		  print "the_line: '$the_line' --  the_data: '$first_data' \n";
		  sleep (1);
	  }

          close ($the_fid);
          return ($first_data, $second_data);
        }
      }
      elsif ($the_parameter eq "gate"){
        $init_index = index($the_line, "total");
        if ($init_index != -1){
          $init_index = skip_spaces_forward($the_line, $init_index+5);
          $last_index = $init_index;
          while (substr($the_line, $last_index, 1) ne " "){
            $last_index++;

            if ($last_index >= length($the_line)){
              last;
            }
          }

          $first_data = substr($the_line, $init_index, $last_index-$init_index);
# JK
	  if ($dbg == 1) {
		  print "the_line: '$the_line' --  the_data: '$first_data' \n";
		  sleep (1);
	  }

          close ($the_fid);
          return ($first_data, $second_data);
        }
      }
    }
  }
  else{
    print "[ERROR] Could not open the $the_file file! \n";
  }

  print "[ERROR] Could not extract the $the_parameter data! \n";

  return ($first_data, $second_data);
}

sub generate_synth_report{

  my $the_file;
  my $nan_data;
  my $gate_data;
  my $area_data;
  my $time_data;
  my $slack_data;
  my $power_data;
  my $the_parameter;

  $the_parameter = "gate";
  $the_file = $module_name . "_" . $the_parameter . ".report";
  ($gate_data, $nan_data) = extract_report_data($the_file, $the_parameter);

  $the_parameter = "area";
  $the_file = $module_name . "_" . $the_parameter . ".report";
  ($area_data, $nan_data) = extract_report_data($the_file, $the_parameter);

  $the_parameter = "time";
  $the_file = $module_name . "_" . $the_parameter . ".report";
  ($time_data, $slack_data) = extract_report_data($the_file, $the_parameter);

  $the_parameter = "power";
  $the_file = $module_name . "_" . $the_parameter . ".report";
  ($power_data, $nan_data) = extract_report_data($the_file, $the_parameter);

  my @data_arr = ($gate_data, $area_data, $time_data, $slack_data, $power_data);

  return (\@data_arr);
}

sub is_inside_diff{
  my ($data_arr_ref, $diff_cnt, $diff_mat_ref) = @_;

  for (my $i=0; $i<$diff_cnt; $i++){
    my $is_same = 1;
    for (my $j=0; $j<(scalar @{$data_arr_ref}); $j++){
      if ($data_arr_ref->[$j] != $diff_mat_ref->[$i][$j]){
        $is_same = 0;
        last;
      }
    }

    if ($is_same){
      return (1);
    }
  }

  return (-1);
}

sub check_normal_exit{

  my $file_run = "last_run.log";

  if (open (my $fid_run, '<:encoding(UTF-8)', $file_run)){
    while (my $the_line = <$fid_run>){
      chomp ($the_line);

      if (index($the_line, "Abnormal exit.") != -1){
        return (0);
      }
    }
  }

  return (1);
}

sub main_part{ 
  my ($total_cir_cnt, $diff_cnt, $diff_mat_ref, $fid_out, $gen_eff, $map_eff, $opt_eff, $delay_cons, $per_mt, $key_dc) = @_;

  my $tcl_file = "";
  my $mapped_file = "";

  my $the_cmd = "";
  my $data_arr_ref;
  my $gate_data = 0;
  my $area_data = 0;
  my $time_data = 0;
  my $slack_data = 0;
  my $power_data = 0;

  my $trans_val = int($delay_cons * $per_mt);
# NOTE JK According to Levent, this was needed to avoid crashes w/ Genus 19 and their 65nm lib
  if ($trans_val < 13){
    $trans_val = 13;
  }
  print "[INFO] Running with gen.eff $gen_eff map.eff $map_eff opt.eff $opt_eff delay.cons $delay_cons max.tran $trans_val kdc $key_dc ... \n";
  ($tcl_file, $mapped_file) = generate_synth_tcl($diff_cnt, $gen_eff, $map_eff, $opt_eff, $delay_cons, $trans_val, $key_dc);

  while (1){
# NOTE JK '-wait' useful for batch processing when all licenses will be utilized
    $the_cmd = "genus -wait 360 -batch -files " . $tcl_file . " > last_run.log";
    system ($the_cmd);

    if (check_normal_exit()){
      $total_cir_cnt++;

      if ($is_auto){
        ($data_arr_ref) = generate_synth_report();
        if (is_inside_diff($data_arr_ref, $diff_cnt, $diff_mat_ref) == -1){
          #print "gate_data: $gate_data area_data: $area_data time_data: $time_data slack_data: $slack_data power_data: $power_data \n";
# NOTE JK revised for Genus 21.16, NG45, ISCAS/ITC benchmarks
          printf $fid_out "%d\t%s\t%s\t%s\t%d\t%.2f\t%d\t%d\t%.3f\t%d\t%d\t%.10f\n", $diff_cnt, $gen_eff, $map_eff, $opt_eff, $delay_cons, $per_mt, $key_dc, $data_arr_ref->[0], $data_arr_ref->[1], $data_arr_ref->[2], $data_arr_ref->[3], $data_arr_ref->[4];
          $diff_mat_ref->[$diff_cnt][0] = $data_arr_ref->[0];
          $diff_mat_ref->[$diff_cnt][1] = $data_arr_ref->[1];
          $diff_mat_ref->[$diff_cnt][2] = $data_arr_ref->[2];
          $diff_mat_ref->[$diff_cnt][3] = $data_arr_ref->[3];
          $diff_mat_ref->[$diff_cnt][4] = $data_arr_ref->[4];
          $diff_cnt++;

          #Generate the bench file
          if ($gen_bench){
            $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
            system($the_cmd);
          }
        }
        else{
          #Remove the mapped file because the same one has already been explored
          $the_cmd = "rm " . $mapped_file;
          system ($the_cmd);
        }
      }
      else{
        #Generate the bench file
        if ($gen_bench){
          $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
          system($the_cmd);
        }
      }

      last;
    }
    else{
      sleep (1);
    }
  }

  if ($bs_delay){
    my $cadence_run = 0;
    my $ub_dp = $delay_cons;
    my $lb_dp = 0;

    my $new_dp_cob;
    my $old_dp_con = $ub_dp;
    my $min_dp = 9**9**9;

    while (1){
      $cadence_run++;

      my ($time_slack, $data_path) = extract_time_data();
      #print "time_slack: $time_slack data_path: $data_path \n";

      if ($time_slack < 0){
        $lb_dp = $old_dp_con+1;
      }
      else{
        $ub_dp = $data_path;

        if ($ub_dp < $min_dp){
          $min_dp = $ub_dp;
        }
      }

      if ($cadence_run == $cadence_run_limit){
        last;
      }

      if ($ub_dp > $lb_dp){
        my $new_dp_con = $lb_dp + POSIX::ceil(($ub_dp-$lb_dp)/2);
        $trans_val = int($new_dp_con*$per_mt);
# NOTE JK According to Levent, this was needed to avoid crashes w/ Genus 19 and their 65nm lib
        if ($trans_val < 13){
          $trans_val = 13;
        }
        #Run the design tool
        print "[INFO] Running with gen.eff $gen_eff map.eff $map_eff opt.eff $opt_eff delay.cons $new_dp_con max.tran $trans_val ... \n";
        ($tcl_file, $mapped_file) = generate_synth_tcl($diff_cnt, $gen_eff, $map_eff, $opt_eff, $new_dp_con, $trans_val, $key_dc);

        while (1){
# NOTE JK '-wait' useful for batch processing when all licenses will be utilized
          $the_cmd = "genus -wait 360 -batch -files " . $tcl_file . " > last_run.log";
          system ($the_cmd);

          if (check_normal_exit()){
            $total_cir_cnt++;

            if ($is_auto){
              ($data_arr_ref) = generate_synth_report();
              if (is_inside_diff($data_arr_ref, $diff_cnt, $diff_mat_ref) == -1){
                #print "gate_data: $gate_data area_data: $area_data time_data: $time_data slack_data: $slack_data power_data: $power_data \n";
# NOTE JK revised for Genus 21.16, NG45, ISCAS/ITC benchmarks
# NOTE JK replaced generic $delay_const w/ current $new_dp_con value
          printf $fid_out "%d\t%s\t%s\t%s\t%d\t%.2f\t%d\t%d\t%.3f\t%d\t%d\t%.10f\n", $diff_cnt, $gen_eff, $map_eff, $opt_eff, $new_dp_con, $per_mt, $key_dc, $data_arr_ref->[0], $data_arr_ref->[1], $data_arr_ref->[2], $data_arr_ref->[3], $data_arr_ref->[4];
                $diff_mat_ref->[$diff_cnt][0] = $data_arr_ref->[0];
                $diff_mat_ref->[$diff_cnt][1] = $data_arr_ref->[1];
                $diff_mat_ref->[$diff_cnt][2] = $data_arr_ref->[2];
                $diff_mat_ref->[$diff_cnt][3] = $data_arr_ref->[3];
                $diff_mat_ref->[$diff_cnt][4] = $data_arr_ref->[4];
                $diff_cnt++;
                
                #Generate the bench file
                if ($gen_bench){
                  $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
                  system($the_cmd);
                }
              }
              else{
                #Remove the mapped file because the same one has already been explored
                $the_cmd = "rm " . $mapped_file;
                system ($the_cmd);
              }
            }
            else{
              #Generate the bench file
              if ($gen_bench){
                $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
                system($the_cmd);
              }
            }

            $old_dp_con = $new_dp_con;
            last;
          }
          else{
            sleep (1);
          }
        }
      }
      else{
        last;
      }

      #print "[INFO] ub_dp: $ub_dp lb_dp: $lb_dp \n";
    }

    #print "[INFO] Total Cadence Synthesis Run: $cadence_run \n";
    #print "[INFO] Minimum Data Path: $min_dp \n";
  }
  elsif ($ld_delay){
    my $cadence_run = 1;
    
    my ($time_slack, $data_path) = extract_time_data();
    #print "time_slack: $time_slack data_path: $data_path \n";

    my $delay_dec = int($data_path/$cadence_run_limit);
    #print "delay_dec: $delay_dec \n";

    while ($cadence_run < $cadence_run_limit){
      $cadence_run++;
      
      $data_path -=$delay_dec;
      #print "the_dc: $data_path \n";
      $trans_val = int($data_path*$per_mt);
# NOTE JK According to Levent, this was needed to avoid crashes w/ Genus 19 and their 65nm lib
      if ($trans_val < 13){
        $trans_val = 13;
      }
      #Run the design tool
      print "[INFO] Running with gen.eff $gen_eff map.eff $map_eff opt.eff $opt_eff delay.cons $data_path max.tran $trans_val ... \n";
      ($tcl_file, $mapped_file) = generate_synth_tcl($diff_cnt, $gen_eff, $map_eff, $opt_eff, $data_path, $trans_val, $key_dc);

      while (1){
# NOTE JK '-wait' useful for batch processing when all licenses will be utilized
        $the_cmd = "genus -wait 360 -batch -files " . $tcl_file . " > last_run.log";
        system ($the_cmd);

        if (check_normal_exit()){
          $total_cir_cnt++;

          if ($is_auto){
            ($data_arr_ref) = generate_synth_report();
            if (is_inside_diff($data_arr_ref, $diff_cnt, $diff_mat_ref) == -1){
              #print "gate_data: $gate_data area_data: $area_data time_data: $time_data slack_data: $slack_data power_data: $power_data \n";
# NOTE JK revised for Genus 21.16, NG45, ISCAS/ITC benchmarks
# NOTE JK replaced generic $delay_const w/ current $data_path value
          printf $fid_out "%d\t%s\t%s\t%s\t%d\t%.2f\t%d\t%d\t%.3f\t%d\t%d\t%.10f\n", $diff_cnt, $gen_eff, $map_eff, $opt_eff, $data_path, $per_mt, $key_dc, $data_arr_ref->[0], $data_arr_ref->[1], $data_arr_ref->[2], $data_arr_ref->[3], $data_arr_ref->[4];
              $diff_mat_ref->[$diff_cnt][0] = $data_arr_ref->[0];
              $diff_mat_ref->[$diff_cnt][1] = $data_arr_ref->[1];
              $diff_mat_ref->[$diff_cnt][2] = $data_arr_ref->[2];
              $diff_mat_ref->[$diff_cnt][3] = $data_arr_ref->[3];
              $diff_mat_ref->[$diff_cnt][4] = $data_arr_ref->[4];
              $diff_cnt++;
              
              #Generate the bench file
              if ($gen_bench){
                $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
                system($the_cmd);
              }
            }
            else{
              #Remove the mapped file because the same one has already been explored
              $the_cmd = "rm " . $mapped_file;
              system ($the_cmd);
            }
          }
          else{
            #Generate the bench file
            if ($gen_bench){
              $the_cmd = "perl ver2bench.pl -l=mcnc_tsmc65.genlib -v=" . $mapped_file;
              system($the_cmd);
            }
          }

          last;
        }
        else{
          sleep (1);
        }
      }
    }
  }

  return ($total_cir_cnt, $diff_cnt, $diff_mat_ref);
}

sub auto_part{
  my $fid_out;
  my $diff_cnt = 0;
  my @diff_mat = ();
  my $total_cir_cnt = 0;
  my $initial_time = time();
  my $diff_mat_ref = \@diff_mat;
  my @key_dc_list = (0, 1);
  my @per_mt_list = (0.05, 0.1, 0.15);
  my @gen_eff_list = ("low", "medium", "high");
  my @map_eff_list = ("low", "medium", "high");
  my @opt_eff_list = ("low", "medium", "high", "extreme");
  #my @key_dc_list = (0, 1);
  #my @per_mt_list = (0.05);
  #my @gen_eff_list = ("high");
  #my @map_eff_list = ("high");
  #my @opt_eff_list = ("high");

  my $file_out = $module_name . "_data.summary";
  open ($fid_out, '>', $file_out);
  printf $fid_out "INDEX\tGEN\tMAP\tOPT\tDC\tPMT\tKDC\tGATE\tAREA\tTIME\tSLACK\tPOWER\n";

  for (my $kdc_index=0; $kdc_index<@key_dc_list; $kdc_index++){
    for (my $mt_index=0; $mt_index<@per_mt_list; $mt_index++){
      for (my $gen_index=0; $gen_index<@gen_eff_list; $gen_index++){
        for (my $map_index=0; $map_index<@map_eff_list; $map_index++){
          for (my $opt_index=0; $opt_index<@opt_eff_list; $opt_index++){
            #print "per_trans_val: $per_mt_list[$mt_index] gen_eff: $gen_eff_list[$gen_index] map_eff: $map_eff_list[$map_index] opt_eff: $opt_eff_list[$opt_index] kdc: $key_dc_list[$kdc_index]\n";
            
            ($total_cir_cnt, $diff_cnt, $diff_mat_ref) = main_part($total_cir_cnt, $diff_cnt, $diff_mat_ref, $fid_out, $gen_eff_list[$gen_index], $map_eff_list[$map_index], $opt_eff_list[$opt_index], $glb_delay_cons, $per_mt_list[$mt_index], $key_dc_list[$kdc_index]);
            print "[INFO] Number of designs generated: $total_cir_cnt Number of unique designs found: $diff_cnt \n";
          }
        }
      }
    }
  }

  my $last_time = int(time() - $initial_time);

  print "\n";
  print "*** Summary of Results *** \n";
  print "[INFO] Number of generated circuits: $total_cir_cnt \n";
  print "[INFO] Number of different circuits: $diff_cnt \n";
  printf "[INFO] Total CPU time: %ds \n", $last_time;

  printf $fid_out "\n";
  printf $fid_out "*** Summary of Results *** \n";
  printf $fid_out "[INFO] Number of generated circuits: %d \n", $total_cir_cnt;
  printf $fid_out "[INFO] Number of different circuits: %d \n", $diff_cnt;
  printf $fid_out "[INFO] Total CPU time: %ds \n", $last_time;
  
  close ($fid_out);
}
