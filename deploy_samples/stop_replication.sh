#!/bin/bash

if [ ! -f ./CONFIG.sh ]
then
    echo "Configuration file CONFIG.sh not found"
    exit 1
fi

. ./CONFIG.sh

echo "# stopping the slaves"
MYSQL="$BASEDIR/bin/mysql"
if [ ! -x $MYSQL ]
then
    echo "Could not find $MYSQL"
    exit 1
fi


MYSQL="$MYSQL --user=$DB_USER --password=$DB_PASSWORD --port=$DB_PORT"

for NODE in ${SLAVES[*]}
do
    $MYSQL -BN --host=$NODE -e 'stop slave'
done

