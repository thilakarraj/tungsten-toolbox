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
. ./cookbook/utilities.sh 

fill_roles

[ -z "$TMPDIR" ] && export TMPDIR=/tmp

if [ ! -d $TMPDIR ]
then
    export TMPDIR=$PWD
fi

TOPOLOGY=`cat CURRENT_TOPOLOGY`
if [ "$TOPOLOGY" == 'master_slave_direct' ]
then
    ALL_NODES=${ALL_SLAVES[*]}
else
    for NODE in ${MASTERS[*]}
    do
        SERVICE=$($TREPCTL -host $NODE services |$SIMPLE_SERVICES -r master -a list)
        $TREPCTL -host $NODE -service $SERVICE heartbeat
    done
fi

for NODE in ${ALL_NODES[*]}
do
    $TREPCTL -host $NODE services | $SIMPLE_SERVICES > $TMPDIR/services$$.$NODE &
done

wait

for NODE in ${ALL_NODES[*]}
do
    echo "# node $NODE"
    cat $TMPDIR/services$$.$NODE
    rm $TMPDIR/services$$.$NODE
done
