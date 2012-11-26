#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi

if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/utilities.sh not found"
    exit 1
fi

. ./cookbook/BOOTSTRAP.sh NODES_MASTER_SLAVE.sh
. ./cookbook/utilities.sh

check_current_topology "master_slave"

function find_roles {
    SLAVE_COUNT=0
    SLAVES=()
    for NODE in ${ALL_NODES[*]} 
    do 
        echo -n "$NODE "
        role=$($TREPCTL -host $NODE services |grep role | awk '{print $3}')
        if [ "$role" == "master" ]
        then
            export MASTER=$NODE
            echo "master"
        else
            SLAVES[$SLAVE_COUNT]=$NODE
            SLAVE_COUNT=$(($SLAVE_COUNT+1))
            echo "slave"
        fi
    done

    if [ -z "$MASTER" ]
    then
        echo "unable to find a master"
        exit 1
    fi
    export  MASTERS=($MASTER)
    export SLAVES=(${SLAVES[*]})
}

find_roles

#This script will first take the 1st Slave out of the cluster
#then it will add it back in

NODE_TO_ADD=${SLAVES[0]}

echo "Removing $NODE_TO_ADD from cluster"
clear_node $NODE_TO_ADD

DONOR=${SLAVES[1]}

echo "Populating $NODE_TO_ADD with data from $DONOR"
MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"
MYSQLDUMP="mysqldump -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"

$MYSQLDUMP --all-databases --single-transaction -h $DONOR > /tmp/donor.dmp
$MYSQL -h $NODE_TO_ADD < /tmp/donor.dmp

echo "Adding $NODE_TO_ADD into the cluster"

 
date >> $INSTALL_LOG

INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$MASTER \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-port=$DATABASE_PORT \
    --service-name=$TUNGSTEN_SERVICE \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$NODE_TO_ADD \
    --datasource-mysql-conf=$MY_CNF \
    --datasource-log-directory=$BINLOG_DIRECTORY \
     --skip-validation-check=InstallerMasterSlaveCheck \
    $MORE_OPTIONS --$START_OPTION"     

if [ -n "$VERBOSE" ]
then
    echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
fi

echo $INSTALL_COMMAND >> $INSTALL_LOG

$INSTALL_COMMAND

if [ "$?" != "0"  ]
then
    exit
fi

./cookbook/show_master_slave.sh
