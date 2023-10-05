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
declare -A bits_total
#
declare -A resyn_bits_corr_1
declare -A resyn_bits_incorr_1
declare -A resyn_bits_unres_1
declare -A resyn_bits_corr_2
declare -A resyn_bits_incorr_2
declare -A resyn_bits_unres_2
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
declare -A baseline_bits_corr_1
declare -A baseline_bits_incorr_1
declare -A baseline_bits_unres_1
declare -A baseline_bits_corr_2
declare -A baseline_bits_incorr_2
declare -A baseline_bits_unres_2
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
	run=${path##*/}
	run_=${run%.work}
	path_=${path%/*}
	path_id=$path_"/"$run_

	## resyn results
	#
	log_resyn=$path_/$run/$run_".log"

#	# dbg
#	echo $path_id
#	echo $run
#	echo $run_
#	echo $log_resyn
#	exit


	# NOTE total bits is same for resyn and baseline runs; extract just here
	bits_total[$path_id]=$(grep -A3 "SCOPE results: print inferences stats and keys" $log_resyn 2> /dev/null | tail -n1 | awk '{print $(NF-1)}')

	resyn_bits_corr_1[$path_id]=$(grep "# Correctly inferred key bits, Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_bits_incorr_1[$path_id]=$(grep "# Incorrectly resolved key bits, Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_bits_unres_1[$path_id]=$(grep "# Unresolved key bits, Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_AC_1[$path_id]=$(grep "Accuracy (AC), Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_PC_1[$path_id]=$(grep "Precision (PC), Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_KPA_1[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 1" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_bits_corr_2[$path_id]=$(grep "# Correctly inferred key bits, Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_bits_incorr_2[$path_id]=$(grep "# Incorrectly resolved key bits, Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_bits_unres_2[$path_id]=$(grep "# Unresolved key bits, Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_AC_2[$path_id]=$(grep "Accuracy (AC), Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_PC_2[$path_id]=$(grep "Precision (PC), Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_KPA_2[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 2" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_COPE_min[$path_id]=$(grep "Min COPE" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_COPE_max[$path_id]=$(grep "Max COPE" $log_resyn 2> /dev/null | awk '{print $NF}')
	resyn_COPE_avg[$path_id]=$(grep "Avg COPE" $log_resyn 2> /dev/null | awk '{print $NF}')

	## sanity checks on KPA
	#
	if [[ ${resyn_KPA_1[$path_id]} == "=" ]]; then
		resyn_KPA_1[$path_id]="undefined"
	fi
	if [[ ${resyn_KPA_2[$path_id]} == "=" ]]; then
		resyn_KPA_2[$path_id]="undefined"
	fi

	## sanity check on run being present at all and being done or not
	#
	if ! [[ -e $log_resyn ]]; then
		bits_total[$path_id]="---"
		resyn_bits_corr_1[$path_id]="---"
		resyn_bits_incorr_1[$path_id]="---"
		resyn_bits_unres_1[$path_id]="---"
		resyn_AC_1[$path_id]="---"
		resyn_PC_1[$path_id]="---"
		resyn_KPA_1[$path_id]="---"
		resyn_bits_corr_2[$path_id]="---"
		resyn_bits_incorr_2[$path_id]="---"
		resyn_bits_unres_2[$path_id]="---"
		resyn_AC_2[$path_id]="---"
		resyn_PC_2[$path_id]="---"
		resyn_KPA_2[$path_id]="---"
		resyn_COPE_min[$path_id]="---"
		resyn_COPE_max[$path_id]="---"
		resyn_COPE_avg[$path_id]="---"

	elif [[ ${resyn_AC_1[$path_id]} == "" ]]; then
		bits_total[$path_id]="..."
		resyn_bits_corr_1[$path_id]="..."
		resyn_bits_incorr_1[$path_id]="..."
		resyn_bits_unres_1[$path_id]="..."
		resyn_AC_1[$path_id]="..."
		resyn_PC_1[$path_id]="..."
		resyn_KPA_1[$path_id]="..."
		resyn_bits_corr_2[$path_id]="..."
		resyn_bits_incorr_2[$path_id]="..."
		resyn_bits_unres_2[$path_id]="..."
		resyn_AC_2[$path_id]="..."
		resyn_PC_2[$path_id]="..."
		resyn_KPA_2[$path_id]="..."
		resyn_COPE_min[$path_id]="..."
		resyn_COPE_max[$path_id]="..."
		resyn_COPE_avg[$path_id]="..."
	fi

	## baseline results
	#
	log_baseline=$path_/$run/$run_".log.forOriginalBench"

	baseline_bits_corr_1[$path_id]=$(grep "# Correctly inferred key bits, Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_bits_incorr_1[$path_id]=$(grep "# Incorrectly resolved key bits, Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_bits_unres_1[$path_id]=$(grep "# Unresolved key bits, Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_AC_1[$path_id]=$(grep "Accuracy (AC), Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_PC_1[$path_id]=$(grep "Precision (PC), Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_KPA_1[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 1" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_bits_corr_2[$path_id]=$(grep "# Correctly inferred key bits, Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_bits_incorr_2[$path_id]=$(grep "# Incorrectly resolved key bits, Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_bits_unres_2[$path_id]=$(grep "# Unresolved key bits, Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_AC_2[$path_id]=$(grep "Accuracy (AC), Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_PC_2[$path_id]=$(grep "Precision (PC), Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	baseline_KPA_2[$path_id]=$(grep "Key Prediction Accuracy (KPA), Variant 2" $log_baseline 2> /dev/null | awk '{print $NF}')
	# NOTE grep for 'COPE = ' explicitly to avoid confusion/mismatch w/ other COPE lines
	baseline_COPE[$path_id]=$(grep "COPE = " $log_baseline 2> /dev/null | awk '{print $NF}')

	## sanity checks on KPA
	#
	if [[ ${baseline_KPA_1[$path_id]} == "=" ]]; then
		baseline_KPA_1[$path_id]="undefined"
	fi
	if [[ ${baseline_KPA_2[$path_id]} == "=" ]]; then
		baseline_KPA_2[$path_id]="undefined"
	fi

	if ! [[ -e $log_baseline ]]; then
		baseline_bits_corr_1[$path_id]="---"
		baseline_bits_incorr_1[$path_id]="---"
		baseline_bits_unres_1[$path_id]="---"
		baseline_AC_1[$path_id]="---"
		baseline_PC_1[$path_id]="---"
		baseline_KPA_1[$path_id]="---"
		baseline_bits_corr_2[$path_id]="---"
		baseline_bits_incorr_2[$path_id]="---"
		baseline_bits_unres_2[$path_id]="---"
		baseline_AC_2[$path_id]="---"
		baseline_PC_2[$path_id]="---"
		baseline_KPA_2[$path_id]="---"
		baseline_COPE[$path_id]="---"

	elif [[ ${baseline_AC_1[$path_id]} == "" ]]; then
		baseline_bits_corr_1[$path_id]="..."
		baseline_bits_incorr_1[$path_id]="..."
		baseline_bits_unres_1[$path_id]="..."
		baseline_AC_1[$path_id]="..."
		baseline_PC_1[$path_id]="..."
		baseline_KPA_1[$path_id]="..."
		baseline_bits_corr_2[$path_id]="..."
		baseline_bits_incorr_2[$path_id]="..."
		baseline_bits_unres_2[$path_id]="..."
		baseline_AC_2[$path_id]="..."
		baseline_PC_2[$path_id]="..."
		baseline_KPA_2[$path_id]="..."
		baseline_COPE[$path_id]="..."
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
out+=" BL_Bits_1"
out+=" BL_AC_1"
out+=" BL_PC_1"
out+=" BL_KPA_1"
out+=" BL_Bits_2"
out+=" BL_AC_2"
out+=" BL_PC_2"
out+=" BL_KPA_2"
out+=" BL_COPE"
out+=" RS_Bits_1"
out+=" RS_AC_1"
out+=" RS_PC_1"
out+=" RS_KPA_1"
out+=" RS_Bits_2"
out+=" RS_AC_2"
out+=" RS_PC_2"
out+=" RS_KPA_2"
out+=" RS_COPE_min"
out+=" RS_COPE_max"
out+=" RS_COPE_avg"
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'

# following rows: data for all paths
for path in $(ls $path_in -d 2> /dev/null); do

	run=${path##*/}
	run_=${run%.work}
	path_=${path%/*}
	path_id=$path_"/"$run_

	out+="$path_id"

	out+=" ${baseline_bits_corr_1[$path_id]}"
	out+="/${baseline_bits_incorr_1[$path_id]}"
	out+="/${baseline_bits_unres_1[$path_id]}"
	out+="/${bits_total[$path_id]}"

	out+=" ${baseline_AC_1[$path_id]}"

	out+=" ${baseline_PC_1[$path_id]}"

	out+=" ${baseline_KPA_1[$path_id]}"

	out+=" ${baseline_bits_corr_2[$path_id]}"
	out+="/${baseline_bits_incorr_2[$path_id]}"
	out+="/${baseline_bits_unres_2[$path_id]}"
	out+="/${bits_total[$path_id]}"

	out+=" ${baseline_AC_2[$path_id]}"

	out+=" ${baseline_PC_2[$path_id]}"

	out+=" ${baseline_KPA_2[$path_id]}"

	out+=" ${baseline_COPE[$path_id]}"

	out+=" ${resyn_bits_corr_1[$path_id]}"
	out+="/${resyn_bits_incorr_1[$path_id]}"
	out+="/${resyn_bits_unres_1[$path_id]}"
	out+="/${bits_total[$path_id]}"

	out+=" ${resyn_AC_1[$path_id]}"

	out+=" ${resyn_PC_1[$path_id]}"

	out+=" ${resyn_KPA_1[$path_id]}"

	out+=" ${resyn_bits_corr_2[$path_id]}"
	out+="/${resyn_bits_incorr_2[$path_id]}"
	out+="/${resyn_bits_unres_2[$path_id]}"
	out+="/${bits_total[$path_id]}"

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
echo "$out" | column -t -s " " -o " | "
echo ""

echo "Legend:"
echo "======="
echo " BL_*: baseline run on original bench"
echo " RS_*: runs on all the resynthesized bench files"
echo " *_1/2: refers to key variant 1/2 of the SCOPE attack"
echo " *_Bits_*: bit-level stats for related SCOPE run; format:  #correct / #incorrect / #undecided / #total"
echo " *_AC_*: accuracy = #correct / #total"
echo " *_PC_*: precision = (#correct + #undecided) / #total"
echo " *_KPA_*: key prediction accuracy = #correct / (#total - #undecided)"
echo " *_COPE*: COPE metric as reported by SCOPE"
echo " '...': related run(s) still ongoing"
echo " '---': related run(s) not started yet"
echo ""
