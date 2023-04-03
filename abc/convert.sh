#!/bin/bash

## settings
#####

# NOTE points to path where this script resides; https://stackoverflow.com/a/246128
pwd_="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## NOTE/TODO these parameters are to be revised to match the setup at your end
# local (link to) abc binary
abc=$pwd_/abc
# lib file
lib=/home/jk176/old_home/work/Nangate/NangateOpenCellLibrary_typical.lib

## NOTE fixed parameters; not be revised unless you know what you're doing
#
b2v_tcl=$pwd_/convert_b2v.tcl
v2b_tcl=$pwd_/convert_v2b.tcl
#
# NOTE only strings/names, not full paths
bench_in=design_in.bench
bench_out=design_out.bench
verilog_in=design_in.v
verilog_out=design_out.v
lib_in=library.lib

## check all parameters
#####
if [ $# -lt 2 ]; then
	echo "Parameters required:"
	echo "1) Full path for input file to convert -- note that output file will be pushed to the same parent path/folder."
	echo "2) Conversion option: b2v (bench to verilog), or v2b (verilog to bench)."
	exit 1
fi
#
file_in=$1
if ! [[ -e $file_in ]]; then
	echo "1) Input file does not exist; check the provided path: \"$file_in\"."
	exit 1
elif [[ $file_in != *"/"* ]]; then
	echo "1) Input file is lacking path; check the provided path: \"$file_in\"."
	exit 1
fi
#
mode=$2
if ! [[ $mode == "b2v" || $mode == "v2b" ]]; then
	echo "2) Unknown conversion option: \"$mode\" -- select either \"b2v\" or \"v2b\"."
	exit 1
fi
#
## NOTE also sanity check on other parameters
if ! [[ -e $abc ]]; then
	echo "abc binary does not exist; check the provided path: \"$abc\"."
fi
if ! [[ -e $lib ]]; then
	echo "library files does not exist; check the provided path: \"$lib\"."
fi

## derive runtime parameters
#####
# NOTE file name w/o path, w/ suffix
file_in_wo_path=${file_in##*/}
# NOTE file name w/o path, w/o suffix
file_in_name=${file_in_wo_path%.*}
# NOTE path name
file_in_path=${file_in%/*}
# other derived files; output files
log_file=$file_in_path/$file_in_name'.'$mode'.log'

## dbg
#echo $file_in_wo_path
#echo $file_in_name
#echo $file_in_path
#echo $log_file
#exit

## main code, based on mode
#####
if [[ $mode == "b2v" ]]; then

	ln -sf $lib $lib_in
	ln -sf $file_in $bench_in

	$abc -f $b2v_tcl | tee $log_file

	file_out=$file_in_path/$file_in_name'.b2v.v'
	mv $verilog_out $file_out

	unlink $lib_in
	unlink $bench_in

# by construction, (i.e., check above) must be v2b
else

	ln -sf $lib $lib_in
	ln -sf $file_in $verilog_in

	$abc -f $v2b_tcl | tee $log_file

	file_out=$file_in_path/$file_in_name'.v2b.bench'
	mv $bench_out $file_out

	unlink $lib_in
	unlink $verilog_in
fi
