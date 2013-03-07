#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

function gethelp
{
    echo "syntax: $0 {start|stop|print}"
    echo "Starts (or stops) a Bristlecone load in every master deployed in the current topology"
    exit
}

if [ -f CURRENT_TOPOLOGY ]
then
    TOPOLOGY=$(cat CURRENT_TOPOLOGY| tr '[:lower:]' '[:upper:]')
    NODES=NODES_$TOPOLOGY
else
    echo "CURRENT_TOPOLOGY not found" 
    exit
fi

OPERATION=start
if [ -n "$1" ]
then
    OPERATION=$1
fi

case $OPERATION in
    start)
        ;;
    stop)
        ;;
    print)
        ;;
    *)
        echo "unrecognized operation '$OPERATION'"
        gethelp
        ;;
esac

for REQUIRED in USER_VALUES $NODES
do
    if [ ! -f ./cookbook/$REQUIRED.sh ]
    then
        echo "could not find ./cookbook/$REQUIRED.sh"
        exit 1
    fi
done

. ./cookbook/USER_VALUES.sh
. ./cookbook/$NODES.sh

DRYRUN=
if [ "$OPERATION" == "print" ]
then
    DRYRUN=1
    OPERATION=start
    VERBOSE=1
fi

JOB_INFO_PATH=$TUNGSTEN_BASE/tungsten/load

for HOST in  ${MASTERS[*]}
do
   db=$(echo $HOST | tr '\.' '_' )
   if [ -d $JOB_INFO_PATH/$db ]
   then
       rm -rf $JOB_INFO_PATH/$db/*
   else
       mkdir -p $JOB_INFO_PATH/$db
   fi
   BRISTLECONE_OPTIONS="--deletes=1 --updates=1 --inserts=3 --test-duration=100"
   EVALUATOR="$TUNGSTEN_BASE/tungsten/bristlecone/bin/concurrent_evaluator.pl"
   DB_OPTIONS="--host=$HOST --port=$DATABASE_PORT -u $DATABASE_USER -p $DATABASE_PASSWORD "
   EV_OPTIONS="--continuent-root=$TUNGSTEN_BASE -d $db -s $JOB_INFO_PATH/$db"
   CMD="$EVALUATOR $BRISTLECONE_OPTIONS $DB_OPTIONS $EV_OPTIONS $OPERATION"
    if [ -n "$VERBOSE" ]
    then
        echo "$CMD"
    fi
    if [ -z "$DRYRUN" ]
    then
        $CMD
    fi
done
