# HOWTO use scripts

### To list hw @ linux node: 
wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/hwlist.sh && chmod +x hwlist.sh && ./hwlist.sh --all

### To list hw @ windows node: 
wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/hwlist.ps1 -OutFile hwlist.ps1; .\hwlist.ps1

## HOWTO - purge_database.sh
### Prerequisite
- Atomia Database
- "atomia" user need to have paswordless login on local machine
eg. add to pg_hba.conf "local   all   atomia   trust"
- script need to be executed on local machine

wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/purge_database.sh && chmod +x purge_database.sh

### Execution
There are three modes: Single user, List of users, All except 100000

To remove user 100002 execute:: 
```sh
$ ./purge_database.sh 100002
```
To remove users from the baduser.list file execute:: 
```sh
$ ./purge_database.sh --list baduser.list
```
To remove all except 100000 user execute:: 
```sh
$ ./purge_database.sh --all
```

## HOWTO - purge_products.sh
### Prerequisite
- Atomia Database
- "atomia" user need to have paswordless login on local machine
eg. add to pg_hba.conf "local   all   atomia   trust"
- script need to be executed on local machine

wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/purge_products.sh && chmod +x purge_products.sh

### Execution
There are three modes: Single user, List of users, All except 100000

To remove product with DMN-COM2 article number execute:: 
```sh
$ ./purge_products.sh DMN-COM2
```
To remove products which article number contains XSV- string execute:: 
```sh
$ ./purge_products.sh --mask XSV-
```
To remove products from the productstoremove.list file execute:: 
```sh
$ ./purge_products.sh --list productstoremove.list
```
To remove all products from the database execute:: 
```sh
$ ./purge_products.sh --all
```