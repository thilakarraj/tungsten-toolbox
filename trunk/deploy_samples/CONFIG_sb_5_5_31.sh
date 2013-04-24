#!/bin/bash
export NODE1=host1
export NODE2=host2
export NODE3=host3
export NODE4=host4

## ==================

export BANNER=$HOME/current_replication.txt
export DB_PORT=15531
export SBDIR=$HOME/sandboxes/mysql_5_5_31
export DATADIR=$SBDIR/data
export BASEDIR=$HOME/opt/mysql/5.5.31
export DB_USER=msandbox
export DB_PASSWORD=msandbox
export REPL_USER=rsandbox
export REPL_PASSWORD=rsandbox

## ==================
export ALL_NODES=($NODE1 $NODE2 $NODE3 $NODE4)
export MASTERS=($NODE1)
export SLAVES=($NODE2 $NODE3 $NODE4)
export DASH_LINE='-----------------------------------------------------------'

