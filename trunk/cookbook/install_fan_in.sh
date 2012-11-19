#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_FAN_IN.sh

./cookbook/clear_cluster.sh NODES_FAN_IN.sh

echo "installing FAN-IN" >$INSTALL_LOG
date >> $INSTALL_LOG
# install all masters
INDEX=0
for NODE in ${MASTERS[*]} $FAN_IN_SLAVE
do

  INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$NODE \
    --datasource-port=$DATABASE_PORT \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-log-directory=/var/lib/mysql \
    --service-name=${MM_SERVICES[$INDEX]} \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$NODE \
    --datasource-mysql-conf=$MY_CNF \
    --$START_OPTION"     

echo $INSTALL_COMMAND >> $INSTALL_LOG
$INSTALL_COMMAND

    if [ "$?" != "0"  ]
    then
        exit
    fi
    INDEX=$(($INDEX+1))
done

FAN_IN_DS=`echo $FAN_IN_SLAVE|perl -lpe's/\W/_/g'`

TUNGSTEN_TOOLS=$TUNGSTEN_BASE/tungsten/tools
COMMON_OPTIONS="--advanced -C -q 
    --local-service-name=$FAN_IN_LOCAL_SERVICE
    --role=slave 
    --service-type=remote 
    --log-slave-updates=true
    --datasource=$FAN_IN_DS"

INDEX=0
# set -x
for REMOTE_MASTER in ${MASTERS[*]}
do
    INSTALL_COMMAND="$TUNGSTEN_TOOLS/configure-service \
        --host=$FAN_IN_SLAVE \
        ${COMMON_OPTIONS} \
        --master-thl-host=$REMOTE_MASTER \
        --svc-$START_OPTION ${MM_SERVICES[$INDEX]}"

    echo $INSTALL_COMMAND >> $INSTALL_LOG
    $INSTALL_COMMAND
    if [ "$?" != "0"  ]
    then
        exit
    fi
    INDEX=$(($INDEX+1))
done
#set +x

./cookbook/show_cluster.sh NODES_FAN_IN.sh

