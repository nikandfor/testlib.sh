#!/usr/bin/env bash

outputdir="${1:-.}"
outputdir=${outputdir%/}

lib=$(dirname "$0")/testlib.sh
baseurl=https://codeberg.org/nikandfor/testlib.sh/raw/branch/main

test -f "$lib" && source "$lib"

if ! declare -f run > /dev/null; then
    run() { "$@"; }
fi

function dl {
	run curl -s "$baseurl/$1" -o "$outputdir/$1"
}

function dlcx {
	dl "$1" && run chmod +x "$outputdir/$1"
}

dl   testlib.sh
dlcx run_all.sh
dlcx update_testlib.sh
