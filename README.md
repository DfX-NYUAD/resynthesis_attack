Notes by Johann for this fork:

- This fork provides all wrapper functionalities that were missing initial in the original code: conversion from verilog to bench and vice versa, calls to the SCOPE attack, batch processing of multiple runs, parsing of results, etc.
- Revise settings.sh for $abc, $scope\_dir, and $lib -- you very likely want to keep the other settings as is
- Revise also genus\_synth.pl for the library path
- This fork is tailored for the Nangate 45nm library
- To use the wrapper for parallel processing, you may run something like this over a large set of bench files
```
for file in */*/*.bench; do ../../scripts/wrapper.sh $file & done
```
- To keep track of the progress for parallel processing, you may run something like this
```
watch "tail -q -n1 */*/*.work/*.summary | grep -v 'Total CPU' | column -t" 
```
- If needed, to stop/pause and continue all the parallel processing jobs, you may run something like this
```
for job in $(jobs -p); do kill -STOP $job; done
for job in $(jobs -p); do kill -CONT $job; done
```
- If needed, to kill all the parallel processing jobs, you may run something like this
```
for job in $(jobs -p); do kill $job; done
for job in $(ps aux | grep /data/projects/resynth_attack/scripts/genus_synth.pl | grep -v grep | awk '{print $2}'); do kill $job; done
```
- Once done, to parse all results into a table, you may run something like this
```
../../scripts/helper_parse_logs.sh \*/\*/\*.work
```

# resynthesis tool

Scripts and other material related to the resynthesis-based attack strategy against logic locking.

A resynthesis-based strategy that utilizes the strength of a commercial electronic design automation (EDA) tool to reveal the vulnerabilities of a locked circuit. To do so, in a pre-attack step, a locked netlist is resynthesized using different synthesis parameters in a systematic way, leading to a large number of functionally equivalent but structurally different locked circuits.

The script must be configured to point to a standard cell library. Check line #266 of genus_synth.pl:
 ```
# set_db init_lib_search_path <lib_path>
# set_db library <lib>
 ```
 
 #######################################################################################
  ```
  Usage:   perl genus_synth.pl -mod=<str> -gen=<str> -map=<str> -opt=<str> -dc=<int> -pmt=<int> -kdc -bsd -ldd -crl=<int> -auto -bench -dux
  -mod:    Name of the module of the top design
  -gen:    Cadence Genus effort on syn_generic command, by default it is high
  -map:    Cadence Genus effort on syn_map command, by default it is high
  -opt:    Cadence Genus effort on syn_opt command, by default it is high
  -dc:     Delay constraint in picoseconds by default it is 80000
  -pmt:    Maximum transition value in percentage of the delay constraint by default it is 10%
  -kdc:    Sets the given delay constraint between key inputs and outputs to an extreme value of 1ps by default it does not
  -bsd:    Different delay constraints are found in a binary search manner and used to find different designs by default it does not
  -ldd:    Different delay constraints are found in a linear degradation manner and used to find different designs by default it does not
  -crl:    Cadence Genus run limit while determinig the delay constraint using bsd and ldd methods, by default it is 10
  -auto:   Runs the script for all possible cases by default it does not
  -bench:  Converts the resynthsized Verilog file to a bench file by default it does not
  -dux:    Does not use XOR/XNOR gates by default it does
  -h:      Prints this screen
  
  Description: Automatically generates the synthesis script and runs the Cadence Genus synthesis tool
    In auto option, design results are reported in a summary file
    In ldd method, the delay constraint is decreased by the value of critical path delay in first synthesis divided by the Cadence run limit
  ```
#######################################################################################
 ```
# Default command in the paper: perl genus_synth.pl -mod=<str> -ldd -crl=5 -auto -bench -dux
```

Use the following format of your choice to cite this paper:

1- Bibtex

@INPROCEEDINGS{9806291,
  author={Almeida, Felipe and Aksoy, Levent and Nguyen, Quang Linh and Dupuis, Sophie and Flottes, Marie Lise and Pagliarini, Samuel},
  booktitle={2023 24th International Symposium on Quality Electronic Design (ISQED)}, 
  title={Resynthesis-based Attacks Against Logic Locking}, 
  year={2023},
  volume={},
  number={},
  pages={},
  doi={}}

2- IEEE

F. Almeida, L. Aksoy, Q-L. Nguyen, S. Dupuis, M-L. Flottes, S. Pagliarini, "Resynthesis-based Attacks Against Logic Locking," 2023 24th International Symposium on Quality Electronic Design (ISQED), 2023.

3- Preprint

The preprint of the paper is available on the following link: https://arxiv.org/abs/2301.04400
