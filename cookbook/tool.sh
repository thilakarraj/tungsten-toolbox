#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

if [ ! -f CURRENT_TOPOLOGY ]
then
    echo "This command requires an installed cluster"
    exit 1
fi

TOPOLOGY=$(echo $(cat CURRENT_TOPOLOGY) | tr '[a-z]' '[A-Z]')

NODES=NODES_$TOPOLOGY.sh

if [ ! -f ./cookbook/$NODES ]
then
    echo "./cookbook/$NODES not found"
    exit 1
fi
if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi

. ./cookbook/BOOTSTRAP.sh $NODES

SUPPORTED_TOOLS="trepctl thl replicator log vilog vimlog conf vimconf"

if [ -z "$1" ]
then
    echo "No tool specified. Required one of '$SUPPORTED_TOOLS'"
    exit 1
fi

case "$1" 
    in
    trepctl)
        shift
        $TREPCTL $@
        ;;
    thl)
        shift
        $THL $@
        ;;
    replicator)
        shift
       $REPLICATOR  $@
       ;;
    log)
       less $TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log 
       ;;
    vilog)
       vi $TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log 
       ;;
    vimlog)
       vim $TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log 
       ;;
    conf)
       less $TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/static*.properties 
       ;;
    vimconf)
       vim -o $TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/static*.properties 
       ;;
    *)
        echo "Unknown tool requested. Valid choices are '$SUPPORTED_TOOLS'"
        exit 1
esac
