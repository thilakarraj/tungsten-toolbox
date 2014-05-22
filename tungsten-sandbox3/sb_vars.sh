#!/bin/bash
sandboxdir=$(dirname $0)

# testing if this file is called from a standalone shell script
# or if it runs under tungsten-sandbox.
# As long as RUNNING_SANDBOX_WRAPPER is enabled, the dynamic file is preserved
if [ -z "$RUNNING_SANDBOX_WRAPPER" -a -f $sandboxdir/sb_dynamic_vars.sh ]
then
    # running directly. No dynamyc vars should be used
    rm -f $sandboxdir/sb_dynamic_vars.sh 
fi

if [ -f $sandboxdir/sb_dynamic_vars.sh ]
then
    . $sandboxdir/sb_dynamic_vars.sh 
fi

export DOTS_LINE='# ---------------------------------------------------'

SANDBOX_BINARY=$HOME/opt/mysql
[ -z "$TUNGSTEN_SANDBOX_VERSION" ] && TUNGSTEN_SANDBOX_VERSION=3.0.02
LOCALHOST=$(hostname)
[ -z "$MYSQL_VERSION" ] && MYSQL_VERSION=5.5.37
[ -z "$HOW_MANY_NODES" ] && HOW_MANY_NODES=3

[ -z "$TUNGSTEN_SB" ] && TUNGSTEN_SB=$HOME/tsb3
SB_PREFIX=db
TUNGSTEN_SB_NODE1=$TUNGSTEN_SB/${SB_PREFIX}1
TUNGSTEN_SB_NODE2=$TUNGSTEN_SB/${SB_PREFIX}2
TUNGSTEN_SB_NODE3=$TUNGSTEN_SB/${SB_PREFIX}3
TUNGSTEN_SB_NODE4=$TUNGSTEN_SB/${SB_PREFIX}4

[ -z "$MYSQL_BASE_PORT" ] && MYSQL_BASE_PORT=6000
[ -z "$RMI_BASE_PORT" ] && RMI_BASE_PORT=10100
[ -z "$THL_BASE_PORT" ] && THL_BASE_PORT=12100

MYSQL_PORT_NODE1=$(($MYSQL_BASE_PORT+1))
MYSQL_PORT_NODE2=$(($MYSQL_BASE_PORT+2))
MYSQL_PORT_NODE3=$(($MYSQL_BASE_PORT+3))
MYSQL_PORT_NODE4=$(($MYSQL_BASE_PORT+4))

RMI_PORT_NODE1=$(($RMI_BASE_PORT+10))
RMI_PORT_NODE2=$(($RMI_BASE_PORT+20))
RMI_PORT_NODE3=$(($RMI_BASE_PORT+30))
RMI_PORT_NODE4=$(($RMI_BASE_PORT+40))

THL_PORT_NODE1=$(($THL_BASE_PORT+10))
THL_PORT_NODE2=$(($THL_BASE_PORT+20))
THL_PORT_NODE3=$(($THL_BASE_PORT+30))
THL_PORT_NODE4=$(($THL_BASE_PORT+40))

SB_DIRECTORY=tsb
MYSQL_SB_BASE=$HOME/sandboxes/$SB_DIRECTORY
MYSQL_SB_NODE1=$MYSQL_SB_BASE/node1
MYSQL_SB_NODE2=$MYSQL_SB_BASE/node2
MYSQL_SB_NODE3=$MYSQL_SB_BASE/node3
MYSQL_SB_NODE4=$MYSQL_SB_BASE/node4

MYSQL_USER=tungsten
MYSQL_PASSWORD=secret

VALIDATION_CHECKS="--skip-validation-check=ClusterMasterHost"
VALIDATION_CHECKS="$VALIDATION_CHECKS --skip-validation-check=MySQLSettingsCheck"
VALIDATION_CHECKS="$VALIDATION_CHECKS --skip-validation-check=OpenFilesLimitCheck"
VALIDATION_CHECKS="$VALIDATION_CHECKS --skip-validation-check=OSCheck"
VALIDATION_CHECKS="$VALIDATION_CHECKS --skip-validation-check=HomeDirectoryCheck"
VALIDATION_CHECKS="$VALIDATION_CHECKS --skip-validation-check=HostsFileCheck"

USERNAME_AND_PASSWORD="--replication-user=$MYSQL_USER --replication-password=$MYSQL_PASSWORD"

[ -z "$MM_SERVICES" ] && MM_SERVICES=(alpha bravo charlie delta echo foxtrot golf hotel india lima mike)
#Alternate values:
# MM_SERVICES=(Doc Grumpy Happy Sleepy Bashful Sneezy Dopey)
# MM_SERVICES=(One Two Tree Four Five Six Seven Eight Nine) 
# MM_SERVICES=(Black Blue Green Red Yellow White) 
# MM_SERVICES=(Australia Belgium Canada Denmark Estonia France Germany Hungary Italy Lithuania)

[ -z "$EDITOR" ] && EDITOR=vim

PATH=$SANDBOX_BINARY/$MYSQL_VERSION/bin:$PATH
