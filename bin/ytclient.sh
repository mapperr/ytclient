#! /bin/bash


cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/ytclient.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "file di configurazione [$FILE_CONFIG] non trovato"
	exit 1
fi

source "$FILE_CONFIG"


# ---------------------------------------------------------
# setup
# ---------------------------------------------------------



# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

helpmsg()
{
	SCRIPT_NAME=`basename $0`
	echo ""
	echo "commands:"
	echo ""
	echo "- login <username> <password>"
	echo "	"
	echo ""
	echo "- issue get [-m <max_issues_to_return>] [query]"
	echo "	print a list of issues"
	echo ""
	echo "- issue field <issue_id> <field_name> [newValue]"
	echo "	print the value of the field <field_name> of the issue <issue_id>, or set the field with [newValue]"
	echo ""
	echo "- issue exec <issue_id> <command>"
	echo "	execute the given command on the given issue"
	echo ""
}

ytc_login()
{
	test -z "$2" && return 2
	
	if echo "$BIN_HTTP" | grep "^curl" > /dev/null
	then
		if $BIN_HTTP -d "login=$1&password=$2" "$URL_REST_BASE/user/login" | grep "<login>ok</login>" > /dev/null
		then
			echo "logged in"
			return 0
		else
			echo "login failed"
			return 3
		fi
	else
		return 1
	fi
}

ytc_issue_get()
{
	while getopts ":m:" opt
	do
		case $opt in
		m)
			max="max=$OPTARG&"
			shift 2
		;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
		;;
		esac
	done
	filters="$@"
	if [ ! -z "$filters" ]
	then
		filters_urlencoded=$(echo $filters | sed -f conf/sed_urlescape.txt)
		filters_querystring="filter=$filters_urlencoded"
	fi
	querystring=`echo "$max$filters_querystring" | sed 's/&$//g'`
	$BIN_HTTP "$URL_REST_BASE/issue?$querystring"  |  sed 's/<\([A-Za-z0-9]\)/\n<\1/g' | sed 's/^<issue /\n<issue /g' | sed 's#</field></issue>#</field>\n</issue>#g'
}

ytc_issue_execute()
{
	test -z "$2" && return 1
	
	issueid="$1"
	shift
	command="$@"
	
	command_urlencoded=$(echo $command | sed -f conf/sed_urlescape.txt)
	$BIN_HTTP -d "command=$command" "$URL_REST_BASE/issue/$issueid/execute"
	return $?
}


ytc_issue_manage_field()
{
	test -z "$2" && return 1
	
	issueid="$1"
	fieldName="$2"
	newValue="$3"
	
	if [ -z "$newValue" ]
	then
		ytc_issue_get "$issueid" | grep -A1 $fieldName | grep value | \
			sed -e 's#</field>##g' -e 's#</value>##g' -e 's#<value.*>##g'
		return $?
	else
		newValue_urlencoded=$(echo $newValue | sed -f conf/sed_urlescape.txt)
		$BIN_HTTP -d "command=$fieldName+$newValue_urlencoded" "$URL_REST_BASE/issue/$issueid/execute"
		return $?
	fi
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "login" ]
then
	shift
	ytc_login $@
	exit $?
fi

if [ "$1" = "issue" ]
then
	shift
	
	if [ "$1" = "get" ]
	then
		shift
		ytc_issue_get $@
		exit $?
	fi
	
	if [ "$1" = "field" ]
	then
		shift
		ytc_issue_manage_field $@
		exit $?
	fi
	
	if [ "$1" = "exec" ]
	then
		shift
		ytc_issue_execute $@
		exit $?
	fi
fi


helpmsg
exit 0