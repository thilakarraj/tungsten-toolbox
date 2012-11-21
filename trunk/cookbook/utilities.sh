#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh COMMON_NODES.sh


function fill_roles {
    SLAVE_COUNT=0
    MASTER_COUNT=0
    SLAVES=()
    MASTERS=()
    for NODE in ${ALL_NODES[*]} 
    do 
        for role in $($TREPCTL -host $NODE services |grep role | awk '{print $3}')
        do
            if [ "$role" == "master" ]
            then
                MASTERS[$MASTER_COUNT]=$NODE
                MASTER_COUNT=$(($MASTER_COUNT+1))
            fi
            if [ "$role" == "slave" ]
            then
                SLAVES[$SLAVE_COUNT]=$NODE
                SLAVE_COUNT=$(($SLAVE_COUNT+1))
            fi
        done
    done
    export  MASTERS=(${MASTERS[*]})
    export SLAVES=(${SLAVES[*]})
}
