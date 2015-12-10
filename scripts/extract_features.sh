#!/bin/bash
# KDD99-like feature generator for UNB ISCX dataset
# http://www.unb.ca/research/iscx/dataset/iscx-dataset.html

# Usage printer
function usage {
  echo "Automatization tool for extraction of KDD99-like features from"
  echo "UNB ISCX dataset Performs the following tasks:"
  echo "  -Extract features from .pcap files (kdd99extractor tool)"
  echo "  -Assign labels based on UNB XML files (labeler tool)"
  echo "  -Plot graphs with statistics (graph_plotter script)"
  echo
  echo "Usage: $0 ["
  echo "Example:"
  echo '  $0 "TestbedWed" ".xml" "labels_16.xml"'
}

# Min number of args
if [ $# -eq 0 ] ; then
  echo "Missing parameter!"
  echo
  usage
  exit 1
fi

# Help
if ([ "$1" == "-h" ]) || ([ "$1" == "--help" ]) ; then
  usage
  exit
fi

# Prefix & optional suffix
prefix=$1
if [ $# -ge 2 ]; then
  suffix=$2
else
  suffix=".xml"
fi

# Find files with given prefix & suffix
OLDIFS=$IFS
IFS=$'\n'
pattern="$prefix"*"-"*"$suffix"     # Dash required between prefix & postfix
infiles=($(ls $pattern 2> /dev/null))
count=${#infiles[@]}
echo "Input files:"
printf '  %s\n' "${infiles[@]}"
echo "$count files found"

# Less than 2 files found
if [ $count -le 1 ] ; then
  echo
  echo "One or no file with prefix '$1' found"
  echo "Nothing to do"
  IFS=$OIFS
  exit
fi

# Number of files not first nor last
middle_files=$(($count - 2))
echo "$middle_files middle files"

# Output filename
if [ $# -ge 3 ]; then
  outfile=$3
else
  # Derive output filename from source filenames
  outfile=$(sed -r 's/^(.*)-[0-9]+(.*)$/\1\2/g' <<< "${infiles[0]}")
fi
echo "Output file: $outfile" 
echo 

# Check whether the prefixes of files befor dash are same
echo -n "Checking prefixes before dash... "
first_prefix=$(sed -r 's/^(.+)-.[^-]*/\1/g' <<< "${infiles[0]}")
max=$(($count - 1))
for i in $(seq 1 $max); do
  cur=$(sed -r 's/^(.+)-.[^-]*/\1/g' <<< "${infiles[$i]}") 
  if [ "$first_prefix" != "$cur" ]; then
    echo "Failed"
    echo "File '$cur' has different prefix"
    echo
    echo "Merging cancelled"
    IFS=$OIFS
    exit 1
  fi
done
echo "OK"

echo -n "Processing... "

# Merge - multiple commands to pipe
{
  # First file
  head -n -1 "${infiles[0]}" 
  # To replace xsd only on second line pipe following after comand above
  # Fck the .xsd for now
  # | sed -r '2s/=\"Testbed([[:alpha:]]{3})Jun([0-9]+)-([0-9]+)Flows\" /=\"Testbed\1Jun\2Flows.xsd\" /g'
  #echo "0: ${infiles[0]}"
  
  # Middle files
  if [ $middle_files -gt 0 ]; then
    for i in $(seq 1 $middle_files); do
      #echo "mid $i: ${infiles[$i]}"
      tail -n +3 "${infiles[$i]}" | head -n -1
    done
  fi
  
  # Last file
  tail -n +3 "${infiles[$count - 1]}"
  #echo "last: $count ${infiles[$count - 1]}"
  
} | sed -r 's/^<(\/?)Testbed([[:alpha:]]{3})Jun([0-9]+)-([0-9]+)Flows>$/<\1Testbed\2Jun\3Flows>/g' \
  > $outfile
  
IFS=$OIFS
echo "Done."
