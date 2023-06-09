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
	echo '1) Full path for locked verilog file.'
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
elif [[ $file_in != *".v" ]]; then
	echo "Input file seems to not be a verilog file; check the provided path: \"$file_in\"."
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

## dbg
#echo $file_in_wo_path
#echo $file_in_name
#echo $file_in_path
#exit

## main code
#####

# 1) extract key from verilog
##

correct_key_string_verilog=$(ack "Secret key is" $file_in)
if [[ $correct_key_string_verilog == "" ]]; then
	echo "Input file does not contain a line with the correct key, following the syntax 'Secret key is\'[...]\''; check the provided path: \"$file_in\"."
	exit 1
fi
# extract actual key bits
correct_key_string=${correct_key_string_verilog#*\'}
correct_key_string=${correct_key_string%\'*}
correct_key_string=$(echo $correct_key_string | tr -d '[:blank:]')


# 2) convert verilog to bench
##

# NOTE use semaphore here as we're not operating in an actual work dir yet
$convert $file_in v2b y

# 3) embed correct key into bench
##
correct_key_string_bench="#key=$correct_key_string"
sed -i "1i$correct_key_string_bench" $file_in_name".v2b.bench"

# 4) put all KEYINPUT nets/ports into lower-case
##
sed -i "s/KEYINPUT/keyinput/g" $file_in_name".v2b.bench"

# 5) arrange files into original input files folder
##
mv $file_in_name".v2b.bench" $file_in_name".bench"
mv $file_in_name"."* $file_in_path/
