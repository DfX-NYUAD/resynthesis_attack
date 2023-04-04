#!/bin/bash

## settings
#####

# NOTE points to path where this script resides; https://stackoverflow.com/a/246128
pwd_="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## NOTE/TODO these parameters are to be revised to match the setup at your end
source $pwd_/../settings.sh

## NOTE fixed parameters; not be revised unless you know what you're doing
#
b2v_tcl=$pwd_/convert_b2v.tcl
v2b_tcl=$pwd_/convert_v2b.tcl

## procedures
#####

semaphore_enter() {
	local mode=$1

	semaphore=$mode'.semaphore'

	while true; do

		if [[ -e $semaphore ]]; then

			sleep 1s
		else
			# check again after a little while; needed to mitigate race conditions where >1 processes just tried to enter the semaphore at the same time
			# pick random value from 0.0 to 0.9 etc to 4.9, to hopefully avoid checking again at the very same time for >1 processes
			sleep $(shuf -i 0-4 -n 1).$(shuf -i 0-9 -n 1)s

			if ! [[ -e $semaphore ]]; then

				# write/lock semaphore
				date > $semaphore

				return
			fi
		fi
	done
}

semaphore_exit() {
	local file=$1
	local log=$2

	semaphore=$mode'.semaphore'

	# delete/release semaphore
	# NOTE stderr occurs in case the semaphore was already deleted, meaning it was entered multiple times
	rm $semaphore 2>> $log
}

## check all parameters
#####
if [ $# -lt 3 ]; then
	echo "Parameters required:"
	echo "1) Full path for input file to convert -- note that output file will be pushed to the same parent path/folder."
	echo "2) Conversion option: 'b2v' (bench to verilog), or 'v2b' (verilog to bench)."
	echo "3) Semaphore handling options: 'y' or 'n'. Use 'y' if you do parallel processing within the same work folder."
	exit 1
fi
#
file_in=$1
if ! [[ -e $file_in ]]; then
	echo "Input file does not exist; check the provided path: \"$file_in\"."
	exit 1
elif [[ $file_in != *"/"* ]]; then
	echo "Input file is lacking path; check the provided path: \"$file_in\"."
	exit 1
fi
#
mode=$2
if ! [[ $mode == "b2v" || $mode == "v2b" ]]; then
	echo "Unknown conversion option: \"$mode\" -- select either \"b2v\" or \"v2b\"."
	exit 1
fi
#
use_semaphore=$3
if ! [[ $use_semaphore == "y" || $use_semaphore == "n" ]]; then
	echo "Unknown semaphore handling option: \"$use_semaphore\" -- select either \"y\" or \"n\"."
	exit 1
fi

## derive runtime parameters
#####
# NOTE file name w/o path, w/ suffix
file_in_wo_path=${file_in##*/}
# NOTE file name w/o path, w/o suffix
file_in_name=${file_in_wo_path%.*}
# NOTE path name
file_in_path=${file_in%/*}

# other files; output files in current work dir
log_file=$file_in_name'.'$mode'.log'

## dbg
#echo $file_in_wo_path
#echo $file_in_name
#echo $file_in_path
#echo $log_file
#exit

## main code
#####

## main code, depending on mode
if [[ $mode == "b2v" ]]; then

	if [[ $use_semaphore == "y" ]]; then
		semaphore_enter b2v
	fi

	ln -sf $lib $lib_in
	ln -sf $file_in $bench_in

	$abc -f $b2v_tcl | tee $log_file

	file_out=$file_in_name'.b2v.v'
	mv $verilog_out $file_out

	unlink $lib_in
	unlink $bench_in

	if [[ $use_semaphore == "y" ]]; then
		semaphore_exit b2v $log_file
	fi

# by construction, (i.e., check above) must be v2b
else
	if [[ $use_semaphore == "y" ]]; then
		semaphore_enter v2b
	fi

	ln -sf $lib $lib_in
	ln -sf $file_in $verilog_in

	$abc -f $v2b_tcl | tee $log_file

	file_out=$file_in_name'.v2b.bench'
	mv $bench_out $file_out

	unlink $lib_in
	unlink $verilog_in

	if [[ $use_semaphore == "y" ]]; then
		semaphore_exit v2b $log_file
	fi
fi
