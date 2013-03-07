#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07


if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi
. ./cookbook/BOOTSTRAP.sh NODES_MASTER_SLAVE.sh

check_installed

# ./cookbook/clear_cluster.sh NODES_MASTER_SLAVE.sh

export MASTER=${MASTERS[0]}

echo "installing MASTER/SLAVE" >$INSTALL_LOG
date >> $INSTALL_LOG

if [ -n "$VALIDATE_ONLY"  ]
then
    MORE_OPTIONS="--validate-only -a"
    if [ -n "$VERBOSE" ]
    then
        MORE_OPTIONS="$MORE_OPTIONS --info"
    fi
    echo "# Performing validation check ..."
fi

INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$MASTER \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-port=$DATABASE_PORT \
    --service-name=$TUNGSTEN_SERVICE \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$HOSTS_LIST \
    --datasource-mysql-conf=$MY_CNF \
    --datasource-log-directory=$BINLOG_DIRECTORY \
    --rmi-port=$RMI_PORT \
    --thl-port=$THL_PORT \
    $MORE_OPTIONS --$START_OPTION"     

if [ -n "$VERBOSE" ]
then
    echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
fi

echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g' >> $INSTALL_LOG

$INSTALL_COMMAND

if [ "$?" != "0"  ]
then
    exit 1
fi

if [ -n "$VALIDATE_ONLY" ]
then
    exit 0
fi

echo "master_slave" > $CURRENT_TOPOLOGY

./cookbook/show_cluster.sh NODES_MASTER_SLAVE.sh
