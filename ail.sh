#!/bin/bash
## Author: branislav@atomia.com
##

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
# change variables according to your needs
# ===============
DEST=/db_backup
DB_HOST=127.0.0.1
USER=atomia
PASS=atomia
# ===============
DB_PRIMARY=""

mongostatus=`mktemp`
# get current mongodb status
mongo -h $DB_HOST -u $USER -p $PASS --quiet --eval "JSON.stringify(rs.status())" > $mongostatus

# install jq package if it doesn't exist
if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y jq;
fi

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

echo "----- RESTORE MONGODB from $RESTOREDIR backup -----"

# we parse primary node address from mongostatus
jq '.members[] | select(.stateStr == "PRIMARY") | .name' mongostatus | sed 's/"//g' | cut -d \: -f1 > $DB_PRIMARY

# check if restore location exists and restore mongodb with oplog
if [[ ! -e $RESTOREDIR ]]; then
    echo "Location you want to restore from doesn't exist, please provide valid backup files location and try again."
else
    mongorestore --oplogReplay --drop -h $DB_PRIMARY -u $USER -p $PASS $RESTOREDIR
fi
}

function status {
echo "----- MONGODB STATUS -----"
# get mongo status
jq '.members[] | .stateStr + ": " + .name ' mongostatus
}

while [ "$1" != "" ]; do
    case $1 in
        -b | --backup )         backup
                                ;;
        -r | --restore )        restore $2
                                ;;
        * )                     status
                                exit 1
    esac
done

rm -f "$mongostatus"