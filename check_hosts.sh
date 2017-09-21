#!/bin/bash
## Author: branislav@atomia.com
#
# Prerequisites: populated /etc/hosts file with required hostnames
#

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 LocalDomain"
	exit 1
else
	LOCAL_DOMAIN="$1"
fi

# print header
printf '%-20s %-20s %-15s %-15s\n' "--------------------" "--------------------" "---------------" "---------------"
printf '%-20s %-20s %-15s %-15s\n' "HOSTNAME" "IP" "Ping" "SSH"
printf '%-20s %-20s %-15s %-15s\n' "--------------------" "--------------------" "---------------" "---------------"

# go through hosts file and check availability
for record in $( grep "${LOCAL_DOMAIN}" /etc/hosts | awk '{print $ 1}'); do

	HOSTNAME=$( grep "${record}" /etc/hosts | awk '{print $ 2}')
	EXIST=''
	REACHABLE=''

	if ping -c 1 ${record} &>/dev/null; then
		EXIST="✓"
	else
		EXIST="✗"
	fi

	if netcat -z ${record} 22 2>/dev/null; then
		REACHABLE="✓"
	else
		REACHABLE="✗"
	fi

	printf '%-20s %-20s %-17s %-15s\n' $HOSTNAME $record $EXIST $REACHABLE
done
printf '%-20s %-20s %-15s %-15s\n' "--------------------" "--------------------" "---------------" "---------------"
exit 0