#!/bin/bash

if [ ! -f ./CONFIG.sh ]
then
    echo "Configuration file CONFIG.sh not found"
    exit 1
fi

. ./CONFIG.sh

if [ ! -f $BANNER ]
then
   echo "Replication not installed"
   exit 1
fi

MYSQL="$BASEDIR/bin/mysql"
if [ ! -x $MYSQL ]
then
    echo "Could not find $MYSQL"
    exit 1
fi


MYSQL="$MYSQL --user=$DB_USER --password=$DB_PASSWORD --port=$DB_PORT"
MYSQL_SLAVE="$MYSQL --user=$REPL_USER --password=$REPL_PASSWORD --port=$DB_PORT"
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
