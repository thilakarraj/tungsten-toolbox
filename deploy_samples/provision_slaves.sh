#!/bin/bash
#set -x
if [ ! -f ./CONFIG.sh ]
then
    echo "Configuration file CONFIG.sh not found"
    exit 1
fi

. ./CONFIG.sh

if [ -f $BANNER ]
then
   echo "Replication already installed"
   exit 1
fi

MASTER=${MASTERS[0]}
MYSQL="$BASEDIR/bin/mysql --user=$DB_USER --password=$DB_PASSWORD --port=$DB_PORT"
MYSQLDUMP="$BASEDIR/bin/mysqldump --events --triggers --routines --user=$DB_USER --password=$DB_PASSWORD --port=$DB_PORT"
echo taking backup

$MYSQLDUMP --host=$MASTER --all-databases > dump.sql

echo restoring on slaves
date
for SLAVE in ${SLAVES[*]} 
do
    echo "restore started in node $SLAVE"
    $MYSQL --host=$SLAVE < dump.sql
    echo "restore done"
done
date

