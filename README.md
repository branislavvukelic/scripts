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
There are four modes: Single product, Products having specific string as part of article name, Pre-defined list of products, All products

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

## HOWTO - ail.sh
### Prerequisite
- MongoDB replication setup
##### Replication guide

install mongodb on secondary nodes:: 
```sh
$ echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
$ apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
$ apt-get update
$ apt-get install -y mongodb-org
```
ensure you have proper dns records for all mongodb nodes by populating `hosts` file eg.:: 
```sh
127.0.0.1           localhost mongo0
123.456.789.111     mongo0.domain.tld
123.456.789.222     mongo1.domain.tld
```
also make sure that `hostname -f` resolves properly:: 
```sh
$ hostname mongo0.domain.tld
```
create key for replication and copy created key to all replication nodes:: 
```sh
$ openssl rand -base64 756 > /etc/mongod.key
$ chown mongodb:mongodb /etc/mongod.key && chmod 400 /etc/mongod.key
```
initiate replication after login to primary mongodb node (mongo0):: 
```sh
$ mongo
> rs.initiate()
> rs.add("mongo2.domain.tld")
> rs.status()
```
ensure you have user with admin rights (you can create one with):: 
```sh
> db.createUser({user:"admin",pwd:"admin",roles:[{role:"root",db:"admin"}]});
```
edit mongodb.conf and add section:: 
```sh
security:
  keyFile: /etc/mongod.key
  authorization: enabled
  
replication:
   oplogSizeMB: 100
   replSetName: rs0
```
restart mongod service on all nodes:: 
```sh
$ service mongod restart
```
finally, check replication status after login to mongodb node:: 
```sh
$ mongo -u admin -p admin --authenticationDatabase admin
> rs.status()
```

wget https://raw.githubusercontent.com/branislavvukelic/scripts/master/ail.sh && chmod +x ail.sh

##### Execution
There are two functions: Backup and Restore

To create full backup of MongoDB database execute:: 
```sh
$ ./ail.sh --backup
```
To restore latest full backup of MongoDB database execute:: 
```sh
$ ./ail.sh --restore
```
If you want to restore the MongoDB backup from specific date/hour (lets say 2017-07-24 at 11h) execute:: 
```sh
$ ./ail.sh --restore 2017-07-42_11
```