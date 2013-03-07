#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

INSTALL_LOG=install_log.txt
TEST_LOG=test_log.txt

echo "# `date`" > $INSTALL_LOG
echo "# `date`" > $TEST_LOG

for TOPOLOGY in master_slave fan_in all_masters star
do
    echo "# $TOPOLOGY" 
    echo "# $TOPOLOGY" >> $INSTALL_LOG
    echo "# $TOPOLOGY" >> $TEST_LOG
    UCTOPOLOGY=$(perl -e "print uc '$TOPOLOGY'")
    ./cookbook/install_$TOPOLOGY.sh >> $INSTALL_LOG 
    if [ -f /tmp/test_log$$ ] ; then rm /tmp/test_log$$ ; fi
    . ./cookbook/BOOTSTRAP.sh NODES_$UCTOPOLOGY.sh
    for MODE in row statement
    do
        for MASTER in ${MASTERS[*]}
        do
            mysql -h $MASTER -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT -e "set global binlog_format=$MODE"
        done 
        echo "# testing with binlog_format=$MODE" >> /tmp/test_log$$ 
        # echo "# testing with binlog_format=$MODE" 

        ./cookbook/test_$TOPOLOGY.sh >> /tmp/test_log$$
        cat /tmp/test_log$$ >> $TEST_LOG
    done
    cat /tmp/test_log$$
    rm /tmp/test_log$$
    export I_WANT_TO_UNINSTALL=1
    ./cookbook/clear_cluster_$TOPOLOGY.sh >> $INSTALL_LOG
    unset I_WANT_TO_UNINSTALL
done

OK=$(grep "^ok" $TEST_LOG| wc -l)
NOTOK=$(grep "^not ok" $TEST_LOG | wc -l)
if [ -z "$OK" ] ; then OK='0' ; fi
if [ -z "$NOTOK" ] ; then NOTOK='0' ; fi
TESTS=$(($OK+$NOTOK))
echo ""
echo "# tests : $TESTS"
echo "# pass  : $OK ($(($OK/$TESTS*100)))"
echo "# fail  : $NOTOK ($(($NOTOK/$TESTS*100)))"
