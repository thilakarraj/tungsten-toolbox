#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi

if [ ! -f ./cookbook/utilities.sh ]
then
    echo "./cookbook/utilities.sh not found"
    exit 1
fi

. ./cookbook/BOOTSTRAP.sh $NODES

REPLICATOR_LOGS_DIR=$TUNGSTEN_BASE/tungsten/tungsten-replicator/log
LOGS_DIR=replicator_logs$$
for NODE in ${ALL_NODES[*]}
do
    mkdir -p $LOGS_DIR/$NODE
    scp $NODE:$REPLICATOR_LOGS_DIR/*.log $LOGS_DIR/$NODE
    for SERVICE in $($TREPCTL -host $NODE services | grep serviceName| awk '{print $3}') 
    do
        $TREPCTL -host $NODE -service $SERVICE status > $LOGS_DIR/$NODE/trepctl_status_$SERVICE.txt
        ssh $NODE $THL -service $SERVICE info > $LOGS_DIR/$NODE/thl_info_$SERVICE.txt
        ssh $NODE $THL -service $SERVICE index > $LOGS_DIR/$NODE/thl_index_$SERVICE.txt
    done
done
LOGS_ARCHIVE="TR_LOGS_$(date "+%Y-%m-%d_%H:%M:%S").tar.gz"
tar -c $LOGS_DIR | gzip -c9 > $LOGS_ARCHIVE
echo "$PWD/$LOGS_ARCHIVE saved"


