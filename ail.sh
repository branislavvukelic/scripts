#!/bin/bash
## Author: branislav@atomia.com
#
# Prerequisites: Replicated mongodb setup
#

if [ -z "$1" ] ; then
        echo "usage: $0 --backup|--restore"
        echo "example:"
        echo -e "$0 --backup \t# will backup mongodb database "
        echo -e "$0 --restore \t# will restore database from the last backup"
        echo -e "\t\t\t# (if we provide an argument in form yyyy-mm-dd_hh it will restore backup from that moment)"
        echo -e "\t\t\t# (eg. $0 --restore 2017-05-17_22    will restore backup from 2017-05-17 at 22h)"
        exit 1
fi

DIR=`date +%Y-%m-%d_%H` # keep it in this format to avoid folder mess
# Default values for variables
# ===============
DEST=/db_backup      # location where we want to store backups
DB_HOST=127.0.0.1    # db host we use to pull backups, if we use script on dedicated backup host we put ip of some machine in the cluster
DUMP_TIME=
USER=admin           # user with backup and restore privileges
PASS=admin           # password for that user
# ===============
MONGOSTATUS=`mktemp`

function backup {
echo "----- BACKUP MONGODB from $DB_HOST -----"

# we create backup dir
mkdir $DEST/$DIR

# backup mongodb with oplog
mongodump --oplog -h $DB_HOST -u $USER -p $PASS -o $DEST/$DIR
}

function restore {
RESTOREDIR=""
# if we provide an argument it will restore that backup, else it will use the last one
if [ -z "$1" ] ; then
    RESTOREDIR=`ls -td $DEST/*/ | head -1`
else
    RESTOREDIR=$DEST/$1
fi

# we parse primary node address from mongostatus
DB_PRIMARY=`jq '.members[] | select(.stateStr == "PRIMARY") | .name' $MONGOSTATUS | sed 's/"//g' | cut -d \: -f1`

echo "----- RESTORE MONGODB from $RESTOREDIR backup to $DB_PRIMARY -----"

# check if restore location exists and restore mongodb with oplog
if [[ ! -e $RESTOREDIR ]]; then
    echo "Location you want to restore from doesn't exist, please provide valid backup files location and try again."
else
    mongorestore --oplogReplay --drop -h $DB_PRIMARY -u $USER -p $PASS $RESTOREDIR
fi
}

function status {
echo "----- CURRENT MONGODB STATUS -----"
# get mongo status
jq '.members[] | .stateStr + ": " + .name ' $MONGOSTATUS
}

while [ "$1" != "" ]; do
    case $1 in
        -a | --action )         
		ACTION=$2
		shift 1
		;;
        -u | --username )
		USER=$2
        shift 1
		;;
        -p | --password )
		PASS=$2
        shift 1
		;;
        -h | --host )
		DB_HOST=$2
        shift 1
		;;
        -t | --time )
		DUMP_TIME=$2
        shift 1
		;;
        -d | --destination )
		DEST=$2
        shift 1
		;;
    esac
shift
done

# get current mongodb status
mongo --host $DB_HOST -u $USER -p $PASS --authenticationDatabase admin --quiet --eval "JSON.stringify(rs.status())" > $MONGOSTATUS

# install jq package if it doesn't exist
if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
    read -p "jq is required to run this script. Do you want to install it now? " yn
    case $yn in
        [Yy]* ) apt-get install -y jq;;
        [Nn]* ) exit;;
    esac
fi

if [[ $ACTION == "backup" ]] ; then
    backup
elif [[ $ACTION == "restore" ]] ; then
    restore $DUMP_TIME
elif [[ $ACTION == "status" ]] ; then
    status
else
	echo "You have provided wrong ACTION!!!"
	echo "ACTION: " $ACTION
fi

rm -f "$MONGOSTATUS"