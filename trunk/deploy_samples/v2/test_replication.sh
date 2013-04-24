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


ALL_RUNNING=1

for MASTER in ${MASTERS[*]}
do  
    $MYSQL --host=$MASTER -e 'drop schema if exists test'
    $MYSQL --host=$MASTER -e 'create schema test'
    $MYSQL --host=$MASTER -e 'create table test.t1 ( id int not null primary key)'
    $MYSQL --host=$MASTER -e 'insert into test.t1 values ( 1), (2), (3)'

    sleep 2
    for NODE in $MASTER ${SLAVES[*]}
    do
        echo -n "node $NODE - "
        $MYSQL -BN --host=$NODE -e 'select count(*) from test.t1'
    done
done
cleanup
