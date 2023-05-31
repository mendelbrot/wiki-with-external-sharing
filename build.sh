#!/bin/bash

# this script is for building the docs.
# the input is the path to the folder containing 
# book.toml and SUMMARY.md.
#   bash build.sh int
#   bash build.sh ext

# copy the appropriate files - overwrite existing
cp ./$1/SUMMARY.md ./src/SUMMARY.md
cp ./$1/book.toml ./book.toml 

# build to the output specified in book.toml with mdbook
mdbook build