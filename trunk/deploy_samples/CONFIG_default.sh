#!/bin/bash
export NODE1=host1
export NODE2=host2
export NODE3=host3
#export NODE4=host4

## ==================
export BANNER=$HOME/current_replication.txt
export DB_PORT=3306
# export DB_SOCKET=/tmp/mysql.sock
export DATADIR=/var/lib/mysql
export BASEDIR=/usr
export DB_USER=powerful
export DB_PASSWORD=can_do_all
export REPL_USER=slave_user
export REPL_PASSWORD=can_do_little
export MY_CNF_TEMPLATE=my_hp.cnf

## ==================
export ALL_NODES=($NODE1 $NODE2 $NODE3 $NODE4)
export MASTERS=($NODE1)
export SLAVES=($NODE2 $NODE3 $NODE4)
export DASH_LINE='-----------------------------------------------------------'
