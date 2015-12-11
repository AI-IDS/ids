#!/bin/bash

if [ $# -eq 0 ] ; then
  ./kdd99extractor.exe -e | Rscript ANN_predictor.R
else
  Rscript ../R/ANN_predictor.R < $1
fi