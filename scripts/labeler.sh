#!/bin/bash
# UNB ISCX dataset feature labeler  (wrapper for Java app)
# Labeler assigner for KDD-like featureset
# Loads unlabeled KDD-like connection features from CSV & assigns labels from 
# XML file based on these colums:
#   - src_ip
#   - src_port
#   - dst_ip
#   - dst_port
#   - protocol_type
#
# UNB ISCX dataset: http://www.unb.ca/research/iscx/dataset/iscx-dataset.html
# KDD features: http://kdd.ics.uci.edu/databases/kddcup99/kddcup99.html

# Change to root of repository 
cd ..

IFS=
java_hint_dirs=(
  "c:/ProgramData/Oracle/*/javapath"
  "c:/Program Files/Java/*/bin"
  "c:/Program Files (x86)/Java/*/bin"
  "c:/UiB"
)


# Usage printer
function usage {
  echo "Labeler"
  echo
  echo "Usage: $0 [-t OFFSET] LABELS_XML UNLABELED_CSV OUTPUT_LABELED_CSV"
  echo "Example:"
  echo '  $0 -t -18000 labels.xml features.csv results.csv'
}

# Find command to execute program using which, if not found
# try to lookup executable in hint folders
#
# Usage: find_program program hint_dir1 hint_dir2 ...
function find_program {
  if which "$1" &>/dev/null; then
    echo "$1"
    return 0
  fi
  
  # Try to find in hint_dirs
  found=0
  for hint in "${@:2}"; do
    hint="${hint}/$1.exe"
    
    while IFS=  read -r -d $'\0' path; do
        if [[ -x "$path" ]]; then
          echo "$path"
          return 0
          break
        fi
    done < <(find ${hint} -print0  2> /dev/null)
  done
  
  return 1
}

# Help
if ([ "$1" == "-h" ]) || ([ "$1" == "--help" ]) ; then
  usage
  exit
fi

# TODO: Min number of args
if [ $# -lt 3 ] ; then
  echo "Missing parameters!" >&2 
  usage >&2 
  exit 1
fi

# Find java
if ! java=$(find_program java ${java_hint_dirs[@]}); then 
  echo "Could not locate java! Try to set hint folders in script." >&2 
  exit 2
fi


# If .java file updated recompile
if [ "labeler/Labeler.java" -nt "labeler/Labeler.class" ] || [ "labeler/Labeler.java" -nt "labeler/Labeler\$MyErrorHandler.class" ]; then
  echo "Recompiling..."
  if javac=$(find_program javac ${java_hint_dirs[@]}); then 
    $javac "labeler/Labeler.java"
  else
  echo "Could not locate javac! Try to set hint folders in script." >&2 
  exit 3
  fi
fi

# Run labeler
$java labeler.Labeler "$@"
