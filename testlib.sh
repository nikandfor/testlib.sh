
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "This script must be sourced, not executed!"
	exit 1
fi

bold="1"
red="31"
boldred="31;1"
cyan="36"
boldcyan="36;1"

function echo2 {
	echo >&2 "$@"
}

function color {
	if [[ $1 -ge 0 && ($1 -eq 0 || -t $1) ]]; then
		echo -en "\e[${2}m"
		cat
		echo -en "\e[0m"
	else
		cat
	fi
}

function comment {
	{
	echo
	echo "# $@" | color 2 $cyan
	} >&2
}

function comment_more {
	{
	echo "# $@" | color 2 $cyan
	} >&2
}

function header {
	{
	echo
	echo
	echo "# $@" | color 2 $boldcyan
	echo ===================
	} >&2
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

	echo "${1:-FAILED}" | color 2 $boldred >&2

	return 1
}

function stillok {
	test "$_status" -eq 0
}

function assertok {
	stillok && return

	if test -n "$1"; then
		echo "$1" | color 2 $boldred >&2
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
		echo TEST FAILED | color 2 $boldred
	} >&2

	exit $_status
}

trap exit_code EXIT

function quotecmd {
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

	echo -n "${s[@]}"
}

function printcmd {
	quotecmd "$@"
	echo
}

function res {
	cat .out
}

function jsonres {
	jq -c . .out || cat .out
}

function code {
	cat .code
}

function resheader {
	cat .header
}

function resisempty {
	test "$(res | wc -c)" -eq 0
}

function jsonresformat {
	if [[ -v format ]]; then
		jsonres | $format
	else
		jsonres
	fi
}

function ifcond {
	jq -e "$@" .out >/dev/null
}

function ifcode {
	jq -e "$@" .code >/dev/null
}

function ifge400 {
	ifcode '. >= 400'
}
function if4xx {
	ifcode '. >= 400 and . < 500'
}
function if5xx {
	ifcode '. >= 500'
}

function checkres {
	if ifcond "$@"; then
		jsonresformat
	else
		jsonresformat | color 1 $red
		fail
	fi
}

function checkboth {
	local code0 code1 code2
	code0=0

	[[ -v precheck ]] && { "${precheck[@]}"; code0=$?; }

	ifcode "$1"
	code1=$?

	checkres "$2"
	code2=$?

	[[ $code0 -eq 0 && $code1 -eq 0 && $code2 -eq 0 ]]
}

# prints command and runs in
function run {
	printcmd "$@" | color 2 $bold >&2

	"$@"
}

# makes an api call
function runcurl {
	printcmd curl -s "$@" | color 2 $bold >&2

	curl -s "$@" >.out -w '%output{.code}%{response_code}\n' -D .header ${curlflags[@]} || FAIL "FAILED WITH CODE $?"
}

# makes api call and checks the result
function apicall {
	runcurl "$@" &&
	checkboth '. >= 200 and . < 300' \
		'(type == "object" and has("error")) | not'
}

function apicallnc {
	runcurl "$@" &&
	ifcode '. >= 200 and . < 300' &&
	resisempty
}

# makes api call and checks the result expecting an error
function apicallerr {
	runcurl "$@" &&
	checkboth '. >= 400' \
		'.'
}

function apicallerrnc {
	runcurl "$@" &&
	ifcode '. >= 400' &&
	resisempty
}

# makes api call, do not fail on error
function apicallshould {
	local code

	runcurl "$@" &&
	checkboth . .
}

# checks the condition and prints condition if it failed
function check {
	if ! ifcond "$@"; then
		while [[ $1 == -* ]]; do shift; done
		FAIL "FAILED: $@"
	fi
}

function checkcode {
	if ! ifcode "$@"; then
		while [[ $1 == -* ]]; do shift; done
		FAIL "FAILED code: $@"
	fi
}

function waitfor {
	seconds="${seconds:-15}"
	local i

	until "$@"; do
		test "$((i++))" -ge "$seconds" && return 1

		sleep 1s
	done
}

function flatlist {
	jq -c 'if type == "array" then .[] else . end'
}
