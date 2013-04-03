#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.5 - 2013-04-03

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

if [ ! -f ./cookbook/utilities.sh ]
then
    echo "./cookbook/utilities.sh not found"
    exit 1
fi

. ./cookbook/BOOTSTRAP.sh $NODES
. ./cookbook/utilities.sh

SUPPORTED_TOOLS="help readme paths backups copy_backup trepctl thl replicator heartbeat services log vilog vimlog emacslog conf vimconf emacsconf"
CONF_DIR="$TUNGSTEN_BASE/tungsten/tungsten-replicator/conf/"

if [ -z "$1" ]
then
    echo "No tool or service specified. Require one of '$SUPPORTED_TOOLS'"
    exit 1
fi


function show_paths
{
    for BIN in replicator trepctl thl
    do
        printf "%15s : %s\n" $BIN "$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/$BIN"
    done
    printf "%15s : %s\n" 'log' "$TUNGSTEN_BASE/tungsten/tungsten-replicator/log/trepsvc.log"
    printf "%15s : %s\n" 'conf' $CONF_DIR
    get_property_value $CONF_DIR 'thl-dir' 'replicator.store.thl.log_dir'
    get_property_value $CONF_DIR 'backup-dir' 'replicator.storage.agent.fs.directory'
    get_property_value $CONF_DIR 'backup-agent' 'replicator.backup.default'
    shift 
    if [ -n "$1" ]
    then
        get_property_value $CONF_DIR $1 $1
    fi
}

function show_backups
{
    get_property_value $CONF_DIR 'backup-agent' 'replicator.backup.default'
    get_property_value $CONF_DIR 'backup-dir' 'replicator.storage.agent.fs.directory' 
    for DIR in $(get_property_value $CONF_DIR '0' 'replicator.storage.agent.fs.directory' 1) 
    do
        echo $(dirname $DIR) >> dirs$$
    done
    for DIR in $(sort dirs$$ | uniq)
    do
        for NODE in ${ALL_NODES[*]}
        do
            HOW_MANY=$(ssh $NODE find $DIR -type f | wc -l)
            echo "# [node: $NODE] $HOW_MANY files found"
            if [ "$HOW_MANY" != "0" ]
            then
                for SUBDIR in $(ssh $NODE ls -d "$DIR/*")
                do
                    HOW_MANY=$(ssh $NODE find $SUBDIR -type f | wc -l)
                    if [ "$HOW_MANY" != "0" ]
                    then
                        echo "++ $SUBDIR"
                        ssh $NODE ls -lh $SUBDIR
                    fi
                done
                echo ''
            fi
        done
    done
    rm dirs$$
}

function copy_backup_files
{
    SERVICE=$1
    SOURCE_NODE=$2
    DESTINATION_NODE=$3
    if [ -z "$DESTINATION_NODE" ]
    then
        echo "syntax: copy_backup SERVICE SOURCE_NODE DESTINATION_NODE"
        exit 1
    fi
    BACKUP_DIRECTORY=$( get_specific_property_value $CONF_DIR 'replicator.storage.agent.fs.directory'  $SERVICE)
    if [ "$(remote_file_exists $SOURCE_NODE $BACKUP_DIRECTORY '-d' )" != "yes" ]
    then
        echo "Backup directory $BACKUP_DIRECTORY not found in $SOURCE_NODE"
        exit 1
    fi
    if [ "$(remote_file_exists $DESTINATION_NODE $BACKUP_DIRECTORY '-d' )" != "yes" ]
    then
        echo "Backup directory $BACKUP_DIRECTORY not found in $DESTINATION_NODE"
        exit 1
    fi
    ssh $SOURCE_NODE "scp -pr $BACKUP_DIRECTORY/* $DESTINATION_NODE:$BACKUP_DIRECTORY/"
}

ARG=$1
shift

case "$ARG" 
    in
    help)
        less ./cookbook/REFERENCE.txt
        ;;
    readme)
        less ./cookbook/README.txt
        ;;
    paths)
        show_paths $1
       ;;
    backups)
        show_backups
       ;;
    copy_backup)
        copy_backup_files $1 $2 $3
       ;;
    trepctl)
        $TREPCTL $@
        ;;
    services)
        $TREPCTL services
        ;;
    heartbeat)
        for NODE in ${MASTERS[*]}
        do
            $TREPCTL -host $NODE heartbeat
        done
        ;;
    thl)
        $THL $@
        ;;
    replicator)
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
