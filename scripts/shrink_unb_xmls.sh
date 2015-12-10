#!/bin/bash
# UNB ISCX dataset XML label file shrinker
# http://www.unb.ca/research/iscx/dataset/iscx-dataset.html

# Usage printer
function usage {
  echo "UNB ISCX dataset XML label file shrinker"
  echo "  Shrinks all files with given prefix (and optionaly suffix)"
  echo "  by removing following XML tags:"
  echo "    <appName>"
  echo "    <totalSourceBytes>"
  echo "    <totalDestinationBytes>"
  echo "    <totalDestinationPackets>"
  echo "    <totalSourcePackets>"
  echo "    <sourcePayloadAsBase64>"
  echo "    <sourcePayloadAsUTF>"
  echo "    <destinationPayloadAsBase64>"
  echo "    <destinationPayloadAsUTF>"
  echo "    <direction>"
  echo "    <sourceTCPFlagsDescription>"
  echo "    <destinationTCPFlagsDescription>"
  echo "    <startTime>"
  echo
  echo "Usage: $0 XML_PREFIX [XML_SUFFIX] [OUTPUT_XML_PREFIX] [OUTPUT_XML_SUFFIX]"
  echo "Example:"
  echo '  $0 "labels_" ".xml" "labels_16_light.xml"'
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
  outsuffix="_light.xml"
fi
echo 

# Find files with given prefix & suffix
OLDIFS=$IFS
IFS=$'\n'
pattern="$inprefix"*"$insuffix"     # Dash required between prefix & postfix
infiles=($(ls $pattern 2> /dev/null))
count=${#infiles[@]}
echo "$count files found"

# Do the magic
echo "Shrinking..."
for in in ${infiles[@]}; do
  # Output filename
  out=$(sed -r "s|^$inprefix(.*)$insuffix$|$outprefix\1$outsuffix|g" <<< "$in")
  
  echo "  $in --> $out"
  grep -Ev 'appName|total|sensor|Payload|direct|TCP|<startTime>' "$in" > "$out"
done

IFS=$OIFS
echo "Done."