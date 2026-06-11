
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "This script must be sourced, not executed!"
	exit 1
fi

bold="1"
red="31"
boldred="31;1"
cyan="36"
boldcyan="36;1"

echo2() {
	echo >&2 "$@"
}

color() {
	if [[ $1 -ge 0 && ($1 -eq 0 || -t $1) ]]; then
		echo -en "\e[${2}m"
		cat
		echo -en "\e[0m"
	else
		cat
	fi
}

comment() {
	{
	echo
	echo "# $*" | color 2 $cyan
	} >&2
}

comment_more() {
	{
	echo "# $*" | color 2 $cyan
	} >&2
}

header() {
	{
	echo
	echo
	echo "# $*" | color 2 $boldcyan
	echo ===================
	} >&2
}

_status=0

failed() {
	test "$_status" -ne 0
}

fail() {
	_status=1

	return 1
}

FAIL() {
	_status=1

	echo "${1:-FAILED}" | color 2 $boldred >&2

	return 1
}

stillok() {
	test "$_status" -eq 0
}

assertok() {
	stillok && return

	if test -n "$1"; then
		echo "$1" | color 2 $boldred >&2
	fi

	exit $_status
}

traps=()
trapn=()

defer() {
	traps+=("$@")
	trapn+=($#)
}

exit_code() {
	local i n end=${#traps[@]}

	for ((i=${#trapn[@]}-1; i>=0; i--)); do
		n=${trapn[i]}
		run "${traps[@]:end-n:n}"
		end=$((end-n))
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

quotecmd() {
	local index
	local s=("${@}")

	for index in "${!s[@]}"; do
		v="${s[index]}"

		if [[ -z "$v" ]]; then
			s[index]='""'
		elif [[ "$v" =~ [[:space:]\&\"\'\$\`] ]]; then
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

printcmd() {
	quotecmd "$@"
	echo
}

res() {
	cat .out
}

jsonres() {
	jq -c . .out || cat .out
}

rescode() {
	cat .code
}

resheader() {
	cat .header
}

resheaderjson() {
	cat .header.json
}

resisempty() {
	test "$(res | wc -c)" -eq 0
}

jsonresformat() {
	if [[ -v format ]]; then
		jsonres | "${format[@]}"
	else
		jsonres
	fi
}

ifcond() {
	jq -e "$@" .out >/dev/null
}

ifcode() {
	jq -e "$@" .code >/dev/null
}

ifge400() {
	ifcode '. >= 400'
}
if4xx() {
	ifcode '. >= 400 and . < 500'
}
if5xx() {
	ifcode '. >= 500'
}

checkres() {
	if ifcond "$@"; then
		jsonresformat
	else
		jsonresformat | color 1 $red
		fail
	fi
}

checkcode0() {
	if ! ifcode "$@"; then
		FAIL "status code: $(rescode)"
	fi
}

checkboth() {
	local code0 code1 code2
	code0=0

	[[ -v precheck ]] && { "${precheck[@]}"; code0=$?; }

	checkcode0 "$1"
	code1=$?

	checkres "$2"
	code2=$?

	[[ $code0 -eq 0 && $code1 -eq 0 && $code2 -eq 0 ]]
}

checkbothnc() {
	local code0 code1 code2
	code0=0

	[[ -v precheck ]] && { "${precheck[@]}"; code0=$?; }

	checkcode0 "$1"
	code1=$?

	resisempty || { res | color 1 $red; fail; }
	code2=$?

	[[ $code0 -eq 0 && $code1 -eq 0 && $code2 -eq 0 ]]
}

# prints command and runs in
run() {
	printcmd "$@" | color 2 $bold >&2

	"$@"
}

# makes an api call
runcurl() {
	printcmd curl -s "$@" | color 2 $bold >&2

	curl -s "$@" >.out -w '%output{.code}%{response_code}\n%output{.header.json}%{header_json}\n' -D .header "${curlflags[@]}" || FAIL "FAILED WITH CODE $?"
}

# makes api call and checks the result
apicall() {
	runcurl "$@" &&
	checkboth '. >= 200 and . < 300' \
		'(type == "object" and has("error")) | not'
}

apicallnc() {
	runcurl "$@" &&
	checkbothnc '. >= 200 and . < 300'
}

# makes api call and checks the result expecting an error
apicallerr() {
	runcurl "$@" &&
	checkboth '. >= 400' \
		'.'
}

apicallerrnc() {
	runcurl "$@" &&
	checkbothnc '. >= 400'
}

# makes api call, do not fail on error
apicallshould() {
	local code

	runcurl "$@" &&
	checkboth . .
}

# checks the condition and prints condition if it failed
check() {
	if ! ifcond "$@"; then
		while [[ $1 == -* ]]; do shift; done
		FAIL "CHECK FAILED: $*"
	fi
}

checkcode() {
	if ! ifcode "$@"; then
		while [[ $1 == -* ]]; do shift; done
		FAIL "CHECK FAILED (http code): $* [$(rescode)]"
	fi
}

checknobody() {
	if resheaderjson | jq -e '[(.["content-length"][]? | tonumber | . > 0), has("transfer-encoding")] | any' >/dev/null; then
		echo "CHECK FAILED: body found" | color 2 $boldred
		resheader | color 2 $red >&2
		fail
	fi
}

waitfor() {
	seconds="${seconds:-15}"
	local i

	until "$@"; do
		test "$((i++))" -ge "$seconds" && return 1

		sleep 1s
	done
}

flatlist() {
	jq -c 'if type == "array" then .[] else . end'
}
