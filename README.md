# HOWTO use scripts


###To list hw @ linux node: 
wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/hwlist.sh && chmod +x hwlist.sh && ./hwlist.sh --all

###To list hw @ windows node: 
wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/hwlist.ps1 -OutFile hwlist.ps1; .\hwlist.ps1


## HOWTO - purge_database.sh

###Prerequisite
- Atomia Database
- "atomia" user need to have paswordless login on local machine
eg. add to pg_hba.conf "local   all   atomia   trust"
- script need to be executed on local machine

###Execution
There are three modes: Single user, List of users, All except 100000

To remove user 100002 execute:: ./purge_database.sh 100002
To remove users from the baduser.list file execute:: ./purge_database.sh --list baduser.list
To remove all except 100000 user execute:: ./purge_database.sh --all