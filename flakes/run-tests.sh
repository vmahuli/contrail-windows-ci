#!/bin/bash

# Run tests for patterns in patterns.txt

# Tests whether grepping all the *.in.txt testcases in this
# directory matches output of corresponding *.out.txt.

set -e
set -u
# Not doing `set -o pipefail` to allow empty grep output.

DIR=$(dirname $BASH_SOURCE)

cd "$DIR"/tests

for test_input in *.in.txt
do
    test_output=$(basename "$test_input" .in.txt).out.txt
    ../grep.sh "$test_input" | diff - "$test_output"
    >&2 echo "$test_input" PASS
done
