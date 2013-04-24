#!/bin/bash

if [ ! -f ./bootstrap.sh ]
then
    echo "Configuration file bootstrap.sh not found"
    exit 1
fi

. ./bootstrap.sh

echo "# stopping the slaves"

for NODE in ${SLAVES[*]}
do
    $MYSQL -BN --host=$NODE -e 'stop slave'
done
cleanup
