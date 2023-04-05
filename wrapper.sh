#!/bin/bash

## settings
#####

# NOTE points to path where this script resides; https://stackoverflow.com/a/246128
pwd_="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## NOTE/TODO these parameters are to be revised to match the setup at your end
source $pwd_/settings.sh

## check all parameters
#####
if [ $# -lt 1 ]; then
	echo 'Parameters required:'
	echo '1) Full path for locked bench file. Note that this helper will auto-generate and use a corresponding work dir in the same path, e.g., locked.bench -> locked.work'
	exit
fi
#
file_in=$1
if ! [[ -e $file_in ]]; then
	echo "Input file does not exist; check the provided path: \"$file_in\"."
	exit 1
elif [[ $file_in != *"/"* ]]; then
	echo "Input file is lacking path; check the provided path: \"$file_in\"."
	exit 1
elif [[ $file_in != *".bench" ]]; then
	echo "Input file seems to not be a bench file; check the provided path: \"$file_in\"."
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
#
# other derived files; output files
work_dir=$file_in_path/$file_in_name'.work'
log_file=$file_in_name'.log'

## dbg
#echo $file_in_wo_path
#echo $file_in_name
#echo $file_in_path
#echo $log_file
#exit

## main code
#####

# 0) further init steps, along w/ sanity checks
##

correct_key_string_bench=$(ack "#key=" $file_in)
if [[ $correct_key_string_bench == "" ]]; then
	echo "Input file does not contain a line with the correct key, following the syntax '#key=[...]'; check the provided path: \"$file_in\"."
	exit 1
fi
# extract actual key bits
# NOTE keep 'correct_key_string_bench' separate as well, since we need to put this line back to converted bench files
correct_key_string=${correct_key_string_bench#\#key=}

# 1) generate and enter work dir
##

mkdir -p $work_dir
cd $work_dir

work_dir_full_path=$(pwd)

echo "$file_in > " | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > Init and entering work dir: \"$work_dir\"" | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# 2) backup data of previous runs, if any
##
# NOTE ignore backup folders, and also trigger backup only for >1 files (as the log file is already 1 file)
if [[ $(ls | grep -v 'backup_' | wc -l) -gt 1 ]]; then

	backup_dir=backup_$(date +%s)

	mkdir $backup_dir

	for file in *; do
		if [[ $file != "backup_"* ]]; then
			mv $file $backup_dir/
		fi
	done

	echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
	echo "$file_in > Backup prior run data to: \"$work_dir/$backup_dir\"" | tee -a $log_file
	echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
	echo "$file_in > " | tee -a $log_file
fi

# 3) convert bench to verilog
##
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > Converting input bench file \"$file_in_wo_path\" to verilog" | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# NOTE by construction, the input file is in the parent folder
$convert ../$file_in_wo_path b2v n

# 4) run resynth script
##
echo "$file_in > " | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > Running resynth script; this will take some long time ..." | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# link from converted verilog to expected input file
ln -sf $file_in_name'.b2v.v' $verilog_in

# actual call to resynth script
# NOTE 'design_in' is the generic module name for all files; as generated by 'abc'
perl $synth -mod=design_in $synth_settings | tee -a $log_file

echo "$file_in > " | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > Done running resynth script" | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# 5) prepare SCOPE
##
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > Preparing SCOPE: convert all resynth verilog files to bench, etc ..." | tee -a $log_file
echo "$file_in > ---------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# convert resynth verilog to bench
for file in design_*_mapped.v; do
	$convert ./$file v2b n
done

# carry over correct key from original bench file
for file in design_*_mapped.v2b.bench; do
	sed -i "1i$correct_key_string_bench" $file
done

# init local copy of SCOPE; required to enable parallel processing within different work dirs
#
mkdir SCOPE
#
mkdir SCOPE/abc_compiler
ln -sf $abc SCOPE/abc_compiler/
#
cp -ra $scope_dir/src SCOPE/
#
mkdir SCOPE/attacked_files
mkdir SCOPE/extracted_keys
mkdir SCOPE/feature_reports
mkdir SCOPE/obfus_tests

# link files into SCOPE work dir; must reside in there
for file in design_*_mapped.v2b.bench; do
	ln -sf ../../$file SCOPE/attacked_files/
done

# 6) run SCOPE on all bench files
##
echo "$file_in > " | tee -a $log_file
echo "$file_in > -------------------------------------------------------" | tee -a $log_file
echo "$file_in > Running SCOPE attack; this may take some long time ..." | tee -a $log_file
echo "$file_in > -------------------------------------------------------" | tee -a $log_file
echo "$file_in > " | tee -a $log_file

# return silently back, out of work dir; just to put "previous pwd" back onto the "stack"
cd - > /dev/null
# jump to SCOPE dir; required for running SCOPE
cd $work_dir_full_path/SCOPE

# actual call to scope
./src/scope | tee -a ../$log_file

# 7) parse SCOPE results
##

## NOTE associative arrays not really needed, but are more straightforward to handle in bash
# key: index of key bit, starting from 1; value: count of times this key bit got resolved/inferred to be '0'
declare -A key_bits_counts_0
# key: index of key bit, starting from 1; value: count of times this key bit got resolved/inferred to be '1'
declare -A key_bits_counts_1
# key: index of key bit, starting from 1; value: count of times this key bit did not got resolved/inferred, meaning it's labelled as 'X'
declare -A key_bits_counts_X
# key: index of key bit, starting from 1; value: final inference
declare -A key_bits_inference_variant_1
declare -A key_bits_inference_variant_2

# init arrays
# NOTE no need to init key_bits_inference_variant_* arrays
for ((i=1; i<=${#correct_key_string}; i++)); do

	key_bits_counts_0[$i]=0
	key_bits_counts_1[$i]=0
	key_bits_counts_X[$i]=0
done

echo "$file_in > " | tee -a ../$log_file
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > SCOPE results: extract all key bit inferences ..." | tee -a ../$log_file
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file

# extract results files: key_variant_1.txt
#
# NOTE there also exists key_variant_2.txt which is the inverse for each and every inferred; this is because SCOPE works by clustering keybits into two groups but cannot tell which
# group is bit 0 and which bit 1 -- this variant 2 can be covered for the final inference, not needed during parsing
for file in attacked_files/design_*_mapped.v2b.bench; do

	file_=$file
	file_=${file_##*/}
	file_=${file_%.*}
	key_file=extracted_keys/$file_/key_variant_1.txt

	echo "$file_in > Parsing for \"$key_file\" ..."

	for ((i=1; i<=${#correct_key_string}; i++)); do

		# NOTE mute stderr as the file might not exist in case SCOPE errors out
		bit_inferred=$(head -c $i $key_file 2> /dev/null | tail -c 1)

		case $bit_inferred in
			0)
				((key_bits_counts_0[$i] = ${key_bits_counts_0[$i]} + 1))
			;;
			1)
				((key_bits_counts_1[$i] = ${key_bits_counts_1[$i]} + 1))
			;;
			*)
				((key_bits_counts_X[$i] = ${key_bits_counts_X[$i]} + 1))
			;;
		esac
	done
done

# 8) derive final inference for both SCOPE key variants
##

for ((i=1; i<=${#correct_key_string}; i++)); do

	# simple majority vote, but only among the inferences for 0 and 1, not considering all X inferences
	if [[ ${key_bits_counts_0[$i]} -gt ${key_bits_counts_1[$i]} ]]; then

		key_bits_inference_variant_1[$i]=0
		key_bits_inference_variant_2[$i]=1

	elif [[ ${key_bits_counts_1[$i]} -gt ${key_bits_counts_0[$i]} ]]; then

		key_bits_inference_variant_1[$i]=1
		key_bits_inference_variant_2[$i]=0
	else
		key_bits_inference_variant_1[$i]="X"
		key_bits_inference_variant_2[$i]="X"
	fi
done

# 9) compute SCOPE metrics

key_bits_variant_1__correct=0;
key_bits_variant_1__X=0;
key_bits_variant_2__correct=0;
key_bits_variant_2__X=0;

for ((i=1; i<=${#correct_key_string}; i++)); do

	bit_correct=$(echo $correct_key_string | head -c $i | tail -c 1)

	if [[ ${key_bits_inference_variant_1[$i]} == "X" ]]; then
		((key_bits_variant_1__X = key_bits_variant_1__X + 1))

	elif [[ ${key_bits_inference_variant_1[$i]} == $bit_correct ]]; then
		((key_bits_variant_1__correct = key_bits_variant_1__correct + 1))
	fi

	if [[ ${key_bits_inference_variant_2[$i]} == "X" ]]; then
		((key_bits_variant_2__X = key_bits_variant_2__X + 1))

	elif [[ ${key_bits_inference_variant_2[$i]} == $bit_correct ]]; then
		((key_bits_variant_2__correct = key_bits_variant_2__correct + 1))
	fi
done

accuracy_variant_1=$(bc -l <<< "scale=$scale_fp; ($key_bits_variant_1__correct / ${#correct_key_string})")
accuracy_variant_2=$(bc -l <<< "scale=$scale_fp; ($key_bits_variant_2__correct / ${#correct_key_string})")
precision_variant_1=$(bc -l <<< "scale=$scale_fp; (($key_bits_variant_1__correct + $key_bits_variant_1__X) / ${#correct_key_string})")
precision_variant_2=$(bc -l <<< "scale=$scale_fp; (($key_bits_variant_2__correct + $key_bits_variant_2__X) / ${#correct_key_string})")
key_prediction_accuracy_variant_1=$(bc -l <<< "scale=$scale_fp; ($key_bits_variant_1__correct / (${#correct_key_string} - $key_bits_variant_1__X))")
key_prediction_accuracy_variant_2=$(bc -l <<< "scale=$scale_fp; ($key_bits_variant_2__correct / (${#correct_key_string} - $key_bits_variant_2__X))")

## dbg
#echo "$file_in >  ($key_bits_variant_1__correct / ${#correct_key_string})"
#echo "$file_in >  ($key_bits_variant_2__correct / ${#correct_key_string})"
#echo "$file_in >  (($key_bits_variant_1__correct + $key_bits_variant_1__X) / ${#correct_key_string})"
#echo "$file_in >  (($key_bits_variant_2__correct + $key_bits_variant_2__X) / ${#correct_key_string})"
#echo "$file_in >  ($key_bits_variant_1__correct / (${#correct_key_string} - $key_bits_variant_1__X))"
#echo "$file_in >  ($key_bits_variant_2__correct / (${#correct_key_string} - $key_bits_variant_2__X))"

# also parse COPE metrics from the current log file

cope_min=1
cope_max=0
cope_count=0
cope_avg=0

for cope_curr in $(grep "COPE metric:" ../$log_file | awk '{print $(NF-1)}'); do

	((cope_count = cope_count + 1))

	cope_avg=$(bc -l <<< "scale=$scale_fp; ($cope_avg + $cope_curr)")

	# floating point comparison using bc
	if (( $(echo "$cope_curr < $cope_min" | bc -l) )); then
		cope_min=$cope_curr
	fi

	# floating point comparison using bc
	if (( $(echo "$cope_curr > $cope_max" | bc -l) )); then
		cope_max=$cope_curr
	fi
done
cope_avg=$(bc -l <<< "scale=$scale_fp; ($cope_avg / $cope_count)")

# 9) print results
##

echo "$file_in > " | tee -a ../$log_file
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > SCOPE results: print inferences stats and keys" | tee -a ../$log_file
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file

# NOTE to print as table using 'column -t', we have to gather all data/rows first via string concatenation
out=""

# 1st row: header
out+="$file_in > Inference / Key bit	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="$i	"
done
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'
#
out+="$file_in > --------------------------	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="---	"
done
out+=$'\n'

# following rows: data
out+="$file_in > X	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="${key_bits_counts_X[$i]}	"
done
out+=$'\n'
#
out+="$file_in > 0	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="${key_bits_counts_0[$i]}	"
done
out+=$'\n'
#
out+="$file_in > 1	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="${key_bits_counts_1[$i]}	"
done
out+=$'\n'
#
out+="$file_in > --------------------------	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="---	"
done
out+=$'\n'
#
out+="$file_in > Final Inference, Variant 1	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="${key_bits_inference_variant_1[$i]}	"
done
out+=$'\n'
#
out+="$file_in > Final Inference, Variant 2	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="${key_bits_inference_variant_2[$i]}	"
done
out+=$'\n'
#
out+="$file_in > --------------------------	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="---	"
done
out+=$'\n'
#
out+="$file_in > Correct Key	"
for ((i=1; i<=${#correct_key_string}; i++)); do
	out+="$(echo $correct_key_string | head -c $i | tail -c 1)	"
done
out+=$'\n'

# print inference stats as full table
# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
echo "$out" | column -t -s "	" -o " | " | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file

# print other metrics
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > SCOPE results: final metrics" | tee -a ../$log_file
echo "$file_in > -------------------------------------------------------" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file

echo "$file_in >  Accuracy (AC), Variant 1 = $accuracy_variant_1" | tee -a ../$log_file
echo "$file_in >  Precision (PC), Variant 1 = $precision_variant_1" | tee -a ../$log_file
echo "$file_in >  Key Prediction Accuracy (KPA), Variant 1 = $key_prediction_accuracy_variant_1" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file
echo "$file_in >  Accuracy (AC), Variant 2 = $accuracy_variant_2" | tee -a ../$log_file
echo "$file_in >  Precision (PC), Variant 2 = $precision_variant_2" | tee -a ../$log_file
echo "$file_in >  Key Prediction Accuracy (KPA), Variant 2 = $key_prediction_accuracy_variant_2" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file
echo "$file_in >  Min COPE = $cope_min" | tee -a ../$log_file
echo "$file_in >  Max COPE = $cope_max" | tee -a ../$log_file
echo "$file_in >  Avg COPE = $cope_avg" | tee -a ../$log_file
echo "$file_in > " | tee -a ../$log_file

# return silently back, out of SCOPE dir
cd - > /dev/null
