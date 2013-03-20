#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

export VERBOSE=1
export VALIDATE_ONLY=1
COOKBOOK_DIR=$(dirname $0)

if [ -f $COOKBOOK_DIR/install_master_slave.sh ]
then
    $COOKBOOK_DIR/install_master_slave.sh
else
    echo "$COOKBOOK_DIR/install_master_slave.sh not found"
    exit 1
fi

