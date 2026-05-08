#!/usr/bin/env bash

source $(dirname "$0")/lib.sh

test "$#" -gt 0 &&
        comment "Runing tests" ||
        comment "No tests to run, pass scripts as arguments"

for script in "$@"; do
        echo2
        echo2 RUNNUNG $script

        ./$script || { FAIL "FAILED $script"; break; }
done
