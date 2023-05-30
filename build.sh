#!/bin/bash

# this script is for building the docs.
# the input is the path to the book.toml and SUMMARY.md:
# bash build.sh int
# bash build.sh ext

# copy the appropriate files to build the docs

cp ./"${BASH_SOURCE[0]}"/SUMMARY.md ./src/SUMMARY.md
cp ./"${BASH_SOURCE[0]}"/book.toml ./book.toml

# build

echo(mdbook build)

# cleanup: delete the files that were copied

rm ./src/SUMMARY.md
rm ./book.toml