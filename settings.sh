
# NOTE points to path where this script resides; https://stackoverflow.com/a/246128
pwd__="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## NOTE/TODO these parameters are to be revised to match the setup at your end

# local link to abc binary
# https://github.com/berkeley-abc/abc.git
abc=/data/projects/abc/abc

# local link to SCOPE folder
# https://github.com/alaql89/SCOPE
scope_dir=/data/projects/SCOPE

# local link to convert.sh
convert=$pwd__/abc/convert.sh

# local link to genus_synth.pl and options/parameters
synth=$pwd__/genus_synth.pl
synth_settings="-ldd -crl=5 -auto -dux"

# lib file
lib=/home/jk176/old_home/work/Nangate/NangateOpenCellLibrary_typical.lib

# NOTE only strings/names, not full paths; this is on purpose
bench_in=design_in.bench
verilog_out=design_in.b2v.v
verilog_in=design_in.v
bench_out=design_in.v2b.bench
lib_in=library.lib

# NOTE scale/resolution for floating point computation
scale_fp=4

## sanity checks
#
if ! [[ -e $abc ]]; then
	echo "'abc' binary does not exist; check the provided path: \"$abc\"."
	exit 1
fi
#
if ! [[ -d $scope_dir ]]; then
	echo "'SCOPE' directory does not exist; check the provided path: \"$scope_dir\"."
	exit 1
fi
#
if ! [[ -e $lib ]]; then
	echo "Library files does not exist; check the provided path: \"$lib\"."
	exit 1
fi
