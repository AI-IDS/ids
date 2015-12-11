#!/bin/bash
# DBN train data creator
# invert columns to rows to match the SMILE input train dataset format

declare -a array=( )                      # we build a 1-D-array

read -a line < "$1"                       # read the headline

COLS=${#line[@]}                          # save number of columns

COUNTROWS=0
while read -r line; do
    COUNTROWS=$(( $COUNTROWS + 1 ))
done < "$1"
read -a line < "$1" 

for (( COUNTER = 0; COUNTER < COLS; COUNTER++ )); do
	
	for (( rows = 0; rows < COUNTROWS; rows++ )); do
	
		tmp=$(($COUNTROWS-1))
		if [ $rows -eq $tmp ]
		then
			printf "%s%s%s" ${line[$COUNTER]} "_" $rows
		else
			
			if [ $rows -eq 0 ]
			then
				printf "%s%s%s " ${line[$COUNTER]}
			else
				printf "%s%s%s " ${line[$COUNTER]} "_" $rows
			fi
		fi
	done
	
done

printf "\n" 

index=0
cnt=0

while read -a line ; do
    
    if [ $cnt -ne 0 ] 
    then
    	for (( COUNTER=0; COUNTER<${#line[@]}; COUNTER++ )); do
    		array[$index]=${line[$COUNTER]}
    		((index++))
    	done
    else
    	cnt=$(( $cnt + 1 ))
    fi
    
done < "$1"

for (( ROW = 0; ROW < COLS; ROW++ )); do
  for (( COUNTER = ROW; COUNTER < ${#array[@]}; COUNTER += COLS )); do
  	
  	tmp=$((${#array[@]}-1))
  	if [ $COUNTER -eq  $tmp ]
  	then 
    	printf "%s" ${array[$COUNTER]}
    else
    	printf "%s " ${array[$COUNTER]}
    fi
  done
done