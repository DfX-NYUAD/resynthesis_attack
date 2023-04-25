#!/bin/bash

## functions
#####

# https://unix.stackexchange.com/a/415450
progress_bar() {
	local w=1 p=$1;  shift
	# create a string of spaces, then change them to dots
	printf -v dots "%*s" "$(( $p * $w ))" ""; dots=${dots// /.}
	# print those dots on a fixed-width space plus the percentage etc. 
	printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*" #>&2 ## use to write to stderr
}

## check all parameters
#####
if [ $# -lt 1 ]; then
	echo 'Parameters required:'
	echo '1) Path for work directory/directories, e.g, RLL/config1/bench_\*/\*.work NOTE: you must escape any * wildcard.'
	exit 1
fi
#
path_in=$1
#
for path in $(ls $path_in -d 2> /dev/null); do

# NOTE not required, as we already iterate here over list of existing directories
#	if ! [[ -d $path ]]; then
#		echo "Work directory \"$path\" does not exist; check the provided path \"$path_in\"."
#		exit 1
#	fi

	if [[ $path != *".work" ]]; then
		echo "Work directory \"$path\" does not seem to be an actual work dir; \".work\" is missing in the path; check the provided path \"$path_in\"."
		exit 1
	fi
done

## main code
#####

## 0) arrays declaration
#
## key: path id, that is path w/o last part on '*.work'; value: metric related to array name
#
declare -A resyn_AC_1
declare -A resyn_AC_2
declare -A resyn_PC_1
declare -A resyn_PC_2
declare -A resyn_KPA_1
declare -A resyn_KPA_2
declare -A resyn_COPE_min
declare -A resyn_COPE_max
declare -A resyn_COPE_avg
#
declare -A baseline_AC_1
declare -A baseline_AC_2
declare -A baseline_PC_1
declare -A baseline_PC_2
declare -A baseline_KPA_1
declare -A baseline_KPA_2
declare -A baseline_COPE

## 1) parsing
#

echo "Parsing ..."

p=0
progress_bar 0
p_total=$(ls $path_in -d 2> /dev/null | wc -l)

for path in $(ls $path_in -d 2> /dev/null); do

	## init
	#
	path_id=$(echo ${path%/*} | sed -e 's/_16/_016/' -e 's/_32/_032/' -e 's/_64/_064/')
	path_id_=${path%/*}
	run=${path##*/}
	run_=${run%.work}

#	# dbg
#	echo $path_id
#	echo $path_id_
#	echo $run
#	echo $run_

	## resyn results
	#
	log_resyn=$path_id_/$run/$run_".log"

	resyn_AC_1[$path_id]=$(grep "Accuracy (AC), Variant 1" $log_resyn | awk '{print $NF}')
	resyn_PC_1[$path_id]=$(grep "Precision (PC), Variant 1" $log_resyn | awk '{print $NF}')
	resyn_KPA_1[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 1" $log_resyn | awk '{print $NF}')
	resyn_AC_2[$path_id]=$(grep "Accuracy (AC), Variant 2" $log_resyn | awk '{print $NF}')
	resyn_PC_2[$path_id]=$(grep "Precision (PC), Variant 2" $log_resyn | awk '{print $NF}')
	resyn_KPA_2[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 2" $log_resyn | awk '{print $NF}')
	resyn_COPE_min[$path_id]=$(grep "Min COPE" $log_resyn | awk '{print $NF}')
	resyn_COPE_max[$path_id]=$(grep "Max COPE" $log_resyn | awk '{print $NF}')
	resyn_COPE_avg[$path_id]=$(grep "Avg COPE" $log_resyn | awk '{print $NF}')

	# sanity checks on KPA
	if [[ ${resyn_KPA_1[$path_id]} == "=" ]]; then
		resyn_KPA_1[$path_id]="undefined"
	fi
	if [[ ${resyn_KPA_2[$path_id]} == "=" ]]; then
		resyn_KPA_2[$path_id]="undefined"
	fi

	## baseline results
	#
	log_baseline=$path_id_/$run/$run_".log.forOriginalBench"

	baseline_AC_1[$path_id]=$(grep "Accuracy (AC), Variant 1" $log_baseline | awk '{print $NF}')
	baseline_PC_1[$path_id]=$(grep "Precision (PC), Variant 1" $log_baseline | awk '{print $NF}')
	baseline_KPA_1[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 1" $log_baseline | awk '{print $NF}')
	baseline_AC_2[$path_id]=$(grep "Accuracy (AC), Variant 2" $log_baseline | awk '{print $NF}')
	baseline_PC_2[$path_id]=$(grep "Precision (PC), Variant 2" $log_baseline | awk '{print $NF}')
	baseline_KPA_2[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 2" $log_baseline | awk '{print $NF}')
	# NOTE grep for 'COPE = ' explicitly to avoid confusion/mismatch w/ other COPE lines
	baseline_COPE[$path_id]=$(grep "COPE = " $log_baseline | awk '{print $NF}')

	# sanity checks on KPA
	if [[ ${baseline_KPA_1[$path_id]} == "=" ]]; then
		baseline_KPA_1[$path_id]="undefined"
	fi
	if [[ ${baseline_KPA_2[$path_id]} == "=" ]]; then
		baseline_KPA_2[$path_id]="undefined"
	fi

	## progress bar
	#
	((p = p + 1))
	progress_bar $(( 100 * p/p_total ))
done
# NOTE final newline to finish progress bar
echo ""

echo "Parsing done"

## 2a) printing; prepare/build up table
#

#echo "Building up table ..."

# NOTE to print as table using 'column -t', we have to gather all data/rows first via string concatenation
out=""

# 1st row: header
out+="Design"
out+=" Baseline_AC_1"
out+=" Baseline_PC_1"
out+=" Baseline_KPA_1"
out+=" Baseline_AC_2"
out+=" Baseline_PC_2"
out+=" Baseline_KPA_2"
out+=" Baseline_COPE"
out+=" Resyn_AC_1"
out+=" Resyn_PC_1"
out+=" Resyn_KPA_1"
out+=" Resyn_AC_2"
out+=" Resyn_PC_2"
out+=" Resyn_KPA_2"
out+=" Resyn_COPE_min"
out+=" Resyn_COPE_max"
out+=" Resyn_COPE_avg"
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'

# following rows: data for all paths
for path in $(ls $path_in -d 2> /dev/null); do

	path_id=$(echo ${path%/*} | sed -e 's/_16/_016/' -e 's/_32/_032/' -e 's/_64/_064/')

	out+="$path_id"

	out+=" ${baseline_AC_1[$path_id]}"
	out+=" ${baseline_PC_1[$path_id]}"
	out+=" ${baseline_KPA_1[$path_id]}"
	out+=" ${baseline_AC_2[$path_id]}"
	out+=" ${baseline_PC_2[$path_id]}"
	out+=" ${baseline_KPA_2[$path_id]}"
	out+=" ${baseline_COPE[$path_id]}"
	out+=" ${resyn_AC_1[$path_id]}"
	out+=" ${resyn_PC_1[$path_id]}"
	out+=" ${resyn_KPA_1[$path_id]}"
	out+=" ${resyn_AC_2[$path_id]}"
	out+=" ${resyn_PC_2[$path_id]}"
	out+=" ${resyn_KPA_2[$path_id]}"
	out+=" ${resyn_COPE_min[$path_id]}"
	out+=" ${resyn_COPE_max[$path_id]}"
	out+=" ${resyn_COPE_avg[$path_id]}"

	out+=$'\n'
done

#echo "Building up table done"

## 2b) printing; actual printing of
#
# print as full table
# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
echo ""
echo ""
echo "$out" | column -t -s " " -o " | "
