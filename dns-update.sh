#!/bin/bash

### Google Domains provides an API to update a DNS "Syntheitc record". This script
### updates a record with the script-runner's public IP, as resolved using a DNS
### lookup.
###
### Google Dynamic DNS: https://support.google.com/domains/answer/6147083
### Synthetic Records: https://support.google.com/domains/answer/6069273

declare -a WWW_DEFAULT_COM=("www.default.com" "usernametoken" "passwordtoken")

USERNAME="null"
PASSWORD="null"
HOSTNAME="null"

OLDIP="::1"
NEWIP=""
IPTYPE="default"
MANIP="null"
SERVRESPONSE=""
declare -a IPLIST=()
declare -a tempdate=()
tempstring=""
LASTCHANGE=""
CYCLECOUNT=0
CHANGEOPT="null"
LOOP_INTERVAL="null"
LOOP_INTERVAL_DEFAULT=60
RUN_LOOP=1
DISPAY_HELP=0

function display_help() {
	echo "-------"	
	echo "[dns-update.sh]"
	echo "Updates defined Google Domains dynamic DNS record to current IPv4 or IPv6 address, or sets DNS server to localhost."
	echo "[SYNTAX]:"
	echo "bash <path>/dns-update.sh <options>"
	echo "-u        <USERNAME>"
	echo "-p        <PASSWORD>"
	echo "-s        <HOSTNAME/SERVER NAME>"
	echo "--ip      <pre-defined IP address>"
	echo "--server  <STORED SERVER ADDRESS>"
	echo "--single  -Single DNS update"
	echo "--local   -Set server address to 127.0.0.1"
	echo "--loop    -Check current IP and change server IP on change."
	echo "--loop-interval"
	echo "          -<Loop interval time> (Seconds)"
	echo "--li      -Shorthand command for loop-interval"
	echo "--v4      -Specifically retrieve INet facing IPv4 address."
	echo "--v6      -Specifically retrieve INet facing IPv6 address."
	echo ""
	echo "[EXAMPLES]:"
	echo ""
	echo "bash dns-update.sh -u user -p passw -s my.domain.com --loop-interval 30 --loop"
	echo ""
	echo "bash dns-update.sh --server my.domain.com --single"
	echo ""
	echo "bash dns-update.sh --server my.domain.com --v4 --li 30 --loop"
	echo ""
	echo "bash dns-update.sh -u user -p passw -s my.domain.com --ip 127.0.0.1 --single"
	echo "-------"
}

function generate_date_string() {
    #convert $date object to single string, seperate 
	LASTCHANGE=$(date)
	tempdate+=($LASTCHANGE)
	arraylen=${#tempdate[@]}
	tempstring=""
	z=0
	for y in ${tempdate[@]}
	do
		newstring="$tempstring $y"
		tempstring="$newstring"
		if [ $z -lt $((arraylen - 1)) ]
		then
			newstring="$tempstring-"
			tempstring="$newstring"
			z=$((z+1))
		fi
	done
}

function display_ip_changes() {
	echo "[Previous IP] / (Time Of Change):"
	i=0
	for item in ${IPLIST[@]}
	do
		if [[ $i == 0 ]]
		then
			echo "[$item]"
			i=1
		else
			echo "  --($item)"
			i=0
		fi
	done
}

function store_ip_change() {
	IPLIST+=($OLDIP)
	IPLIST+=($(echo $tempstring | tr -d ' '))
    #Reset tempdate after generate_date_string function
	tempdate=()
}

function get_current_ip() {
	#NEWIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
	#This will be used if IPv4 or IPv6 is not specified.
	#This can return either v4 or v6 values
	[[ "$IPTYPE" == "default" ]] && NEWIP=$(curl -s "https://domains.google.com/checkip")
	[[ "$IPTYPE" == "4" ]] && get_current_ip_v4
	[[ "$IPTYPE" == "6" ]] && get_current_ip_v6
}

function get_current_ip_v4() {
		NEWIP=$(wget -O - v4.ident.me 2>/dev/null)	
}

function get_current_ip_v6() {
		NEWIP=$(wget -O - v6.ident.me 2>/dev/null) 	
}

function update_google_dns() {
	[[ "$MANIP" != "null" ]] && NEWIP="$MANIP"
	URL="https://${USERNAME}:${PASSWORD}@domains.google.com/nic/update?hostname=${HOSTNAME}&myip=${NEWIP}"
	SERVRESPONSE=$(curl -s $URL)
}

display_state_change_header() {
	clear
	echo "-------"
	echo "{$HOSTNAME}"
}

display_no_state_change() {
	echo "Current IP:"
	echo "-[$NEWIP]"
	echo "Current cycle:"
	echo "-($(date))"
}

display_state_change() {
	echo "IP address changed FROM:"
	echo "-[$OLDIP]"
	echo "TO:"
	echo "-[$NEWIP]"
    echo "($LASTCHANGE)"
    echo "Domain response:"
	echo $SERVRESPONSE
}

display_footer() {
	echo "Uptime: [$CYCLECOUNT] cycles."
	echo "Loop Interval [$LOOP_INTERVAL]."
	echo "-------"
	display_ip_changes
	echo "-------"
	echo "Press ( 'q' ) to exit anytime."
	echo "-------"
}

function loop_dns_update() {
	while [ $RUN_LOOP == 1 ]
    do
        get_current_ip
        display_state_change_header
	    if [ "$OLDIP" != "$NEWIP" ]
	    then
		    generate_date_string
            store_ip_change
            update_google_dns
            display_state_change
            OLDIP=$NEWIP
	    else
            display_no_state_change
	    fi	
	    CYCLECOUNT=$((CYCLECOUNT+1))
        display_footer
	#Looking for graceful exit solution.
		#read -n 1 key
		#if [[ $key = q ]] || [[ $key = Q ]]
		#then
		#	break
		#fi
		if [[ $RUN_LOOP == 0 ]]
		then
			break
		fi
	    sleep $LOOP_INTERVAL
    done
}

function dns_update() {
    [[ "$MANIP" == "null" ]] && get_current_ip
    update_google_dns
    echo $SERVRESPONSE
}

function set_dns_local() {
	NEWIP="127.0.0.1"
	echo "Setting $HOSTNAME to $NEWIP"
	echo "Server will be offline/localhost access only."
	update_google_dns
	echo $SERVRESPONSE
} 

arg_counter=0
temp_arg_array=($@)
for arg in "$@"
do
	[[ "$arg" == "--loop" ]] && CHANGEOPT="loop"
	[[ "$arg" == "--local" ]] && CHANGEOPT="local"
	[[ "$arg" == "--single" ]] && CHANGEOPT="single"
	[[ "$arg" == "--help" ]] && DISPLAY_HELP=1

	if [[ "$arg" == "--server" ]]
	then
		value_pos=$((arg_counter + 1))
		option_value="${temp_arg_array[$value_pos]}"
		if [[ "$option_value" == "www.default.com" ]]
		then
			HOSTNAME="${WWW_DEFAULT_COM[0]}"
			USERNAME="${WWW_DEFAULT_COM[1]}"
			PASSWORD="${WWW_DEFAULT_COM[2]}"
		fi
	fi
	
	if [[ "$arg" == "-u" ]]
	then
		value_pos=$((arg_counter + 1))
		USERNAME="${temp_arg_array[$value_pos]}"
	fi

	if [[ "$arg" == "-p" ]]
	then
		value_pos=$((arg_counter + 1))
		PASSWORD="${temp_arg_array[$value_pos]}"
	fi
	
	if [[ "$arg" == "-s" ]]
	then
		value_pos=$((arg_counter + 1))
		HOSTNAME="${temp_arg_array[$value_pos]}"
	fi

	if [[ "$arg" == "--li" ]] || [[ "$arg" == "--loop-interval" ]]
	then
		value_pos=$((arg_counter + 1))
		LOOP_INTERVAL="${temp_arg_array[$value_pos]}"
	fi

	if [[ "$arg" == "--v4" ]]
	then
		IPTYPE="4"
	fi

	if [[ "$arg" == "--v6" ]]
	then
		IPTYPE="6"
	fi

	if [[ "$arg" == "--ip" ]]
	then
		value_pos=$((arg_counter + 1))
		MANIP="${temp_arg_array[$value_pos]}"
	fi	
	arg_counter=$((arg_counter + 1))
done

if [[ "$USERNAME" != "null" ]] && [[ "$PASSWORD" != "null" ]] && [[ "$HOSTNAME" != "null" ]]
then
	[[ "$LOOP_INTERVAL" == "null" ]] && LOOP_INTERVAL=$LOOP_INTERVAL_DEFAULT
	if [[ "$CHANGEOPT" == "loop" ]]
	then
		loop_dns_update &
		loop_pid=$!
		disown
		read -n 1 key
		if [[ $key = q ]] || [[ $key = Q ]]
		then
			RUN_LOOP=0
			kill $loop_pid
		fi
	fi	
	[[ "$CHANGEOPT" == "local" ]] && set_dns_local
	[[ "$CHANGEOPT" == "single" ]] && dns_update
	if [[ "$CHANGEOPT" == "null" ]]
	then
		echo "No DNS change option given."
		echo "Performing single DNS update:"
		dns_update
	fi
elif [[ $DISPLAY_HELP == 1 ]]
then
	display_help
else
	echo "Insufficient parameters. (use ' --help ' for parameter options)"
fi
