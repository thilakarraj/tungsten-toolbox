#!/bin/bash

if [ ! -f ./bootstrap.sh ]
then
    echo "Configuration file bootstrap.sh not found"
    exit 1
fi

. ./bootstrap.sh

if [ ! -f $BANNER ]
then
   echo "Replication not installed"
   exit 1
fi


echo "# stopping the slaves"

for NODE in ${SLAVES[*]}
do
    $MYSQL -BN --host=$NODE -e 'stop slave'
    $MYSQL -BN --host=$NODE -e 'reset slave'
done
cleanup
rm -f $BANNER

# remove utility scripts
for script in mysql mysqldump mysqladmin
do
    rm -f $script
done  

