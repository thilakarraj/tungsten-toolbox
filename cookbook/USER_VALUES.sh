#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

# User defined values for the cluster to be installed.

export TUNGSTEN_BASE=$HOME/installs/cookbook
export DATABASE_USER=tungsten
export BINLOG_DIRECTORY=/var/lib/mysql
export MY_CNF=/etc/my.cnf
export DATABASE_PASSWORD=secret
export DATABASE_PORT=3306
export TUNGSTEN_SERVICE=cookbook
[ -z "$START_OPTION" ] && export START_OPTION=start

