#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

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
INSTALLER_IN_CLUSTER=0
CURRENT_HOST_IP=$(hostname --ip)

function check_if_installer_is_in_cluster
{
    for HOST in ${ALL_NODES[*]}
    do
        if [ "$HOST" == "$CURRENT_HOST" ]
        then
            INSTALLER_IN_CLUSTER=1
            return
        else
            # Check if the IP for the hostname is associated with
            # one of the hosts defined for this cluster
            for LINE in $(grep $CURRENT_HOST_IP /etc/hosts | grep -v '^#')
            do
                for ITEM in $LINE
                do
                    if [ "$ITEM" == "$HOST" ]
                    then
                        INSTALLER_IN_CLUSTER=1
                        return
                    fi
                done 
            done
        fi
    done
}

check_if_installer_is_in_cluster

if [ "$INSTALLER_IN_CLUSTER" != "1" ]
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
export TREPCTL="$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/trepctl -port $RMI_PORT"
export THL=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/thl
##############################################################################
# Variables used when removing the cluster
##############################################################################
[ -z "$STOP_REPLICATORS" ] && export STOP_REPLICATORS=1
[ -z "$REMOVE_TUNGSTEN_BASE" ] && export REMOVE_TUNGSTEN_BASE=1
[ -z "$REMOVE_SERVICE_SCHEMA" ] && export REMOVE_SERVICE_SCHEMA=1
[ -z "$REMOVE_TEST_SCHEMAS" ] && export REMOVE_TEST_SCHEMAS=1
[ -z "$REMOVE_DATABASE_CONTENTS" ] && export REMOVE_DATABASE_CONTENTS=0
[ -z "$CLEAN_NODE_DATABASE_SERVER" ] && export CLEAN_NODE_DATABASE_SERVER=1
##############################################################################

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

function are_you_sure_you_want_to_clear
{
    echo "--------------------------------------------------------------------------------------"
    echo "!!! WARNING !!!"
    echo "--------------------------------------------------------------------------------------"
    echo "'clear-cluster' is a potentially damaging operation."
    echo "This command will do all the following:"
    if [ "$STOP_REPLICATORS" == 1 ]
    then
        echo "* Stop the replication software in all servers. [\$STOP_REPLICATORS]"
    fi
    if [ "$REMOVE_TUNGSTEN_BASE" == "1" ]
    then
        echo "* REMOVE ALL THE CONTENTS from $TUNGSTEN_BASE/.[\$REMOVE_TUNGSTEN_BASE]"
    fi
    if [ "$REMOVE_SERVICE_SCHEMA" == "1" ]
    then
        echo "* REMOVE the tungsten_<service_name> schemas in all nodes (${ALL_NODES[*]}) [\$REMOVE_SERVICE_SCHEMA] "
    fi
    if [ "$REMOVE_TEST_SCHEMAS" == "1" ]
    then
        echo "* REMOVE the schemas created for testing (test, evaluator) in all nodes (${ALL_NODES[*]})  [\$REMOVE_TEST_SCHEMAS]"
    fi
    if [ "$REMOVE_DATABASE_CONTENTS" == "1" ]
    then
        echo "* REMOVE *** ALL THE DATABASE CONTENTS *** in all nodes (${ALL_NODES[*]}) [\$REMOVE_DATABASE_CONTENTS] "
    fi
    if [ "$CLEAN_NODE_DATABASE_SERVER" == "1" ]
    then
        echo "* Create the test server anew;                [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Unset the read_only variable;               [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Set the binlog formato to MIXED;            [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Reset the master (removes all binary logs); [\$CLEAN_NODE_DATABASE_SERVER]"
    fi
    echo "If this is what you want, either set the variable I_WANT_TO_UNINSTALL "
    echo "or answer 'y' to the question below"
    echo "You may also set the variables in brackets to fine tune the execution."
    echo "Alternatively, have a look at $0 and customize it to your needs."
    echo "--------------------------------------------------------------------------------------"

    while [ -z "$I_WANT_TO_UNINSTALL" ] ; do
        read -p 'Do you wish to uninstall this cluster? [y/n] ' yn 
        case $yn in 
            [Yy]* ) I_WANT_TO_UNINSTALL=YES;; 
            [Nn]* ) exit;;
            * ) echo 'Please answer (y) or (n).';;
        esac
    done
}

function post_installation
{
    for NODE in ${ALL_NODES[*]}
    do  
        DEPLOYED=$(ssh $NODE "if [ -d $TUNGSTEN_BASE ] ; then echo 'yes' ; fi")
        if [ "$DEPLOYED" == "yes" ]
        then
            scp -q $CURRENT_TOPOLOGY $NODE:$TUNGSTEN_BASE/tungsten/  
        fi
    done
    TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
    echo "Deployment completed "
    echo "Topology      :'$TOPOLOGY'"
    echo "Tungsten path : $TUNGSTEN_BASE "
    echo "Nodes         : (${ALL_NODES[*]})"
}

