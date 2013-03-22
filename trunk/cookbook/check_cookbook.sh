#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

cd `dirname $0`

MISSING=""
for F in `cat MANIFEST` 
do
    COMMENT=$(echo $F |grep '#')
    if [ -n "$COMMENT" ]
    then
        echo $COMMENT
    else
        if [ -f $F ]
        then
            echo "ok $F"
        else
            echo "not ok - $F not found"
            MISSING="$MISSING $F"
        fi
    fi
done

echo ""
if [ -z "$MISSING" ]
then
    echo "All files are accounted for"
else
    echo "*** WARNING"
    echo "Missing files: $MISSING"
    echo "****"
    exit 1
fi


