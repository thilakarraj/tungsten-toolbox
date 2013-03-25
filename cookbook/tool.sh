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

SUPPORTED_TOOLS="help readme paths trepctl thl replicator heartbeat services log vilog vimlog emacslog conf vimconf emacsconf"

if [ -z "$1" ]
then
    echo "No tool or service specified. Require one of '$SUPPORTED_TOOLS'"
    exit 1
fi

function get_property_value
{
    LABEL=$1
    PROPERTY=$2
    for F in $CONF_DIR/static-*.properties
    do
        SERVICE=$(echo $F | perl -ne 'print $1 if /static-(\w+).properties/' )
        ACTION_STR="print \$1,\$/ if /^$PROPERTY=(.*)/"
        for VALUE in $(perl -ne "$ACTION_STR" $F)
        do
            printf "%15s : (service: %s) %s\n" $LABEL $SERVICE $VALUE
        done
    done
}

case "$1" 
    in
    help)
        less ./cookbook/REFERENCE
        shift
        ;;
    readme)
        less ./cookbook/README
        shift
        ;;
    paths)
        CONF_DIR="$TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/"
        printf "%15s : %s\n" 'trepctl' "$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/trepctl"
        printf "%15s : %s\n" 'thl' "$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/thl"
        printf "%15s : %s\n" 'log' "$TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log"
        printf "%15s : %s\n" 'conf' $CONF_DIR
        get_property_value 'backup-dir' 'replicator.storage.agent.fs.directory'
        get_property_value 'thl-dir' 'replicator.store.thl.log_dir'
        get_property_value 'backup-agent' 'replicator.backup.default'
        shift 
        if [ -n "$1" ]
        then
            get_property_value $1 $1
        fi
        ;;
    trepctl)
        shift
        $TREPCTL $@
        ;;
    services)
        shift
        $TREPCTL services
        ;;
    heartbeat)
        shift
        for NODE in ${MASTERS[*]}
        do
            $TREPCTL -host $NODE heartbeat
        done
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
    emacslog)
       emacs $TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log 
       ;;
    conf)
       less $TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/static*.properties 
       ;;
    vimconf)
       vim -o $TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/static*.properties 
       ;;
    emacsconf)
       emacs $TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/static*.properties 
       ;;
    *)
        echo "Unknown tool requested. Valid choices are '$SUPPORTED_TOOLS'"
        exit 1
esac
