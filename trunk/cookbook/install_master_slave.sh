#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_MASTER_SLAVE.sh

./cookbook/clear_cluster.sh NODES_MASTER_SLAVE.sh

export MASTER=${MASTERS[0]}

echo "installing MASTER/SLAVE" >$INSTALL_LOG
date >> $INSTALL_LOG

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
    $MORE_OPTIONS --$START_OPTION"     

echo $INSTALL_COMMAND >> $INSTALL_LOG

$INSTALL_COMMAND

if [ "$?" != "0"  ]
then
    exit
fi

./cookbook/show_cluster.sh NODES_MASTER_SLAVE.sh
