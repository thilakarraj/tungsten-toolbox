#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

CURDIR=`dirname $0`

if [ -x "$CURDIR/simple_services" ]
then
    SIMPLE_SERVICES=$CURDIR/simple_services
else
    for P in `echo $PATH |tr ':' ' '` 
    do
        if [ -x $P/simple_services ]
        then
            SIMPLE_SERVICES=$P/simple_services
            continue
        fi
    done
fi

if [ -z "$SIMPLE_SERVICES" ]
then
    echo "simple_services is not installed. "
    echo "While not strictly necessary for the recipes installation, it is needed to run the auxuliary scripts."
    echo "Please get it from http://code.google.com/p/tungsten-toolbox/ and put it in the \$PATH"
    exit 1
fi

if [ ! -f ./cookbook/$NODES ]
then
    echo "./cookbook/$NODES not found"
    exit 1
fi

. ./cookbook/$NODES

if [ -z "${ALL_NODES[0]}" ]
then
    echo "Nodes variables not set"
    echo "Please edit cookbook/COMMON_NODES.sh or cookbook/NODES*.sh"
    echo "Make sure that NODE1, NODE2, etc are filled"
    exit 1
fi

HOSTS_LIST=""
MASTERS_LIST=""
SLAVES_LIST=""

for NODE in ${ALL_NODES[*]}
do
   [ -n "$HOSTS_LIST" ] && HOSTS_LIST="$HOSTS_LIST,"
   HOSTS_LIST="$HOSTS_LIST$NODE"
done

for NODE in ${SLAVES[*]}
do
   [ -n "$SLAVES_LIST" ] && SLAVES_LIST="$SLAVES_LIST,"
   SLAVES_LIST="$SLAVES_LIST$NODE"
done

for NODE in ${MASTERS[*]}
do
   [ -n "$MASTERS_LIST" ] && MASTERS_LIST="$MASTERS_LIST,"
   MASTERS_LIST="$MASTERS_LIST$NODE"
done

export MASTERS_LIST
export SLAVES_LIST
export HOSTS_LIST

CURRENT_HOST=$(hostname)

for HOST in ${ALL_NODES[*]}
do
    if [ "$HOST" == "$CURRENT_HOST" ]
    then
        INSTALLER_IN_CLUSTER=1
    fi
done

if [ -z "$INSTALLER_IN_CLUSTER" ]
then
    echo "This framework is designed to act within the cluster that is installing"
    echo "The current host ($CURRENT_HOST) is not among the designated servers (${ALL_NODES[*]})"
    exit 1
fi

. ./cookbook/USER_VALUES.sh

[ -z "$MY_CNF" ] && export MY_CNF=/etc/my.cnf
if [ ! -f $MY_CNF ]
then
    UBUNTU_MY_CNF=/etc/mysql/my.cnf
    if [ -f $UBUNTU_MY_CNF ]
    then
        MY_CNF=$UBUNTU_MY_CNF
    else
        echo "could not find a configuration file (either $MY_CNF or $UBUNTU_MY_CNF)"
        exit 1
    fi
fi


export REPLICATOR=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/replicator
export TREPCTL=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/trepctl
export THL=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/thl

export INSTALL_LOG=./cookbook/current_install.log

CURRENT_TOPOLOGY=./CURRENT_TOPOLOGY

function check_installed
{
    if [ -f $CURRENT_TOPOLOGY ]
    then
        echo "There is a previous installation recorded in $CURRENT_TOPOLOGY"
        cat $CURRENT_TOPOLOGY
        TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
        echo "Run cookbook/clear_cluster_$TOPOLOGY.sh to remove this installation"
        exit 1
    fi 
}

function check_current_topology
{
    if [ -f $CURRENT_TOPOLOGY ]
    then
        WANTED=$1
        TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
        if [ "$TOPOLOGY" != "$WANTED" ]
        then
            echo "this script requires a $WANTED topology."
            echo "Found a different topology ($TOPOLOGY) in $CURRENT_TOPOLOGY"
            exit 1
        fi
    else
        echo "$CURRENT_TOPOLOGY not found"
        echo "Cannot determine if $WANTED topology is deployed"
        exit 1
    fi
}

