#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

# User defined values for the cluster to be installed.

export TUNGSTEN_BASE=$HOME/installs/cookbook
export DATABASE_USER=tungsten
export BINLOG_DIRECTORY=/var/lib/mysql
export MY_CNF=/etc/my.cnf
export DATABASE_PASSWORD=secret
export DATABASE_PORT=3306
export TUNGSTEN_SERVICE=cookbook
export RMI_PORT=10000
export THL_PORT=2112
[ -z "$START_OPTION" ] && export START_OPTION=start

# Options used by the "direct slave " installer only
# Modify only if you are using 'install_master_slave_direct.sh'
export DIRECT_MASTER_BINLOG_DIRECTORY=$BINLOG_DIRECTORY
export DIRECT_SLAVE_BINLOG_DIRECTORY=$BINLOG_DIRECTORY
export DIRECT_MASTER_MY_CNF=$MY_CNF
export DIRECT_SLAVE_MY_CNF=$MY_CNF
