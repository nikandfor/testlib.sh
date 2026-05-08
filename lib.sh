
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "This script must be sourced, not executed!"
	exit 1
fi

function echo2 {
	echo >&2 "$@"
}

function color2 {
	{

	test -t 2 && echo -en '\e['"$1"'m' || true
	cat
	test -t 2 && echo -en '\e[0m' || true

	} >&2
}

function bold {
	color2 1
}

function red {
	color2 31
}

function boldred {
	color2 '31;1'
}

function cyan {
	color2 36
}

function boldcyan {
	color2 '36;1'
}


function comment {
	echo2
	echo "# $@" | cyan
}

function comment_more {
	echo "# $@" | cyan
}

function header {
	echo2
	echo2
	echo "# $@" | boldcyan
	echo2 ===================
}

_status=0

function failed {
	test "$_status" -ne 0
}

function fail {
	_status=1

	return 1
}

function FAIL {
	_status=1

	echo "${1:-FAILED}" | boldred

	return 1
}

function stillok {
	test "$_status" -eq 0
}

function assertok {
	stillok && return

	if test -n "$1"; then
		echo "$1" | boldred
	fi

	exit $_status
}

traps=()

function defer {
	traps+=("$@")
}

function exit_code {
	for cmd in "${traps[@]}"; do
		run "$cmd"
	done

	{
		echo
		stillok &&
			echo ALL IS OK ||
			echo TEST FAILED | boldred
	} >&2

	exit $_status
}

trap exit_code EXIT

function printcmd {
	local index
	local s=("${@}")

	for index in "${!s[@]}"; do
		v="${s[index]}"

		if [[ "${s[index]}" =~ [[:space:]\&\"\'\$\`] ]]; then
			if [[ ! "$v" =~ [\"] ]]; then
				s[index]=\""$v"\"
			elif [[ ! "$v" =~ [\'] ]]; then
				s[index]=\'"$v"\'
			else
				s[index]=\"$(printf '%q' "$v")\"
			fi
		fi
	done

	echo "${s[@]}"
}

function jqorfail {
	jq -c . .out || { cat .out; FAIL $1; }
}

function safejq {
	jq -c . .out || cat .out
}

function res {
	cat .out
}

function ifcond {
	res | jq -e "$1" >/dev/null
}

# prints command and runs in
function run {
	printcmd "$@" | bold

	"$@"
}

# makes an api call
function runcurl {
	run curl -s "$@" >.out || FAIL "FAILED WITH CODE $?"
}

# checks the result and fails the test
function check_and_fail {
	if ifcond "$1"; then
		jqorfail | red
		fail
	else
		jqorfail
	fi
}

# makes api call and checks the result
function apicall {
	runcurl "$@" &&
	check_and_fail 'objects | has("error")'
}

# makes api call and checks the result expecting an error
function apicallerr {
	runcurl "$@" &&
	check_and_fail 'objects | has("error") | not'
}

# makes api call, do not fail on error
function apicallshould {
	local code

	runcurl "$@" && {
		code=$?
		safejq
		return $code
	}
}

function flatlist {
	jq -c 'if type == "array" then .[] else . end'
}

# checks the condition and prints condition if it failed
function check {
	ifcond "$1" || FAIL "FAILED: $1"
}

function waitfor {
	seconds="${seconds:-15}"
	local i

	until "$@"; do
		test "$((i++))" -ge "$seconds" && return 1

		sleep 1s
	done
}
