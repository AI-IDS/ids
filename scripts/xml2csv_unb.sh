#!/bin/bash
# UNB ISCX dataset XML to CSV convertor
# http://www.unb.ca/research/iscx/dataset/iscx-dataset.html

# Usage printer
function usage {
  echo "UNB ISCX dataset XML label file shrinker"
  echo "  Converts XML file with labels to csv"
  echo "  Input must be prepared using shrink_unb_xmls.sh"
  echo
  echo "Usage: $0 XML_PREFIX [XML_SUFFIX] [OUTPUT_XML_PREFIX] [OUTPUT_XML_SUFFIX]"
  echo "Example:"
  echo '  $0 "labels_" ".xml" "csv_labels_" ".csv"'
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

# Input prefix refix & optional suffix
inprefix=$1
if [ $# -ge 2 ]; then
  insuffix=$2
else
  insuffix=".xml"
fi

# Optional output prefix & suffix
if [ $# -ge 3 ]; then
  outprefix=$3
else
  outprefix=$inprefix
fi
if [ $# -ge 4 ]; then
  outsuffix=$4
else
  outsuffix="_xml.csv"
fi
echo 

# Find files with given prefix & suffix
OLDIFS=$IFS
IFS=$'\n'
pattern="$inprefix"*"$insuffix"     # Dash required between prefix & postfix
infiles=($(ls $pattern 2> /dev/null))
count=${#infiles[@]}
echo "$count files found"



# Conversion
echo "Converting..."
for in in ${infiles[@]}; do
  # Output filename
  out=$(sed -r "s|^$inprefix(.*)$insuffix$|$outprefix\1$outsuffix|g" <<< "$in")
  echo "  $in --> $out"
  
  # Construct header
  grep -m 1 -B100 "^</" "$in" | head -n -1 | tail -n +4 \
    | sed -r 's|^.+</([^>]+)>$|,\1|g' | tr -d '\n' | cut -c2- > "$out"

  # The long ugly magic
  tail -n +4 "$in" | head -n -2 |                 # Start with 4th line, remove last 2 lines
    tr -d ',@' |                                  # Delete reserved chars ',' and '@'
    sed -r 's|^(<[^>]*>)(.*)(</[^>]*>)$|,\2|g' |  # Remove tags around values, add comma before
    sed 's/^<.*$/@/g' |                           # Replace leftover "grouping" tags with '@'
    tr -d '\n' | cut -c2- |                       # Concatenate lines, get rid of first extra comma
    sed 's/@@,/\n/g' >> "$out"                    # Break lines
done

IFS=$OIFS
echo "Done."
