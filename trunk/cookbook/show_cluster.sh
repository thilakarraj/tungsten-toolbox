#!/bin/bash

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi

. ./cookbook/USER_VALUES.sh $NODES

for NODE in ${MASTERS[*]}
do
    SERVICE=$($TREPCTL -host $NODE services |simple_services -r master -a list)
    $TREPCTL -host $NODE -service $SERVICE heartbeat
done

for NODE in ${ALL_NODES[*]}
do
    echo "# node $NODE"
    $TREPCTL -host $NODE services | simple_services
done
