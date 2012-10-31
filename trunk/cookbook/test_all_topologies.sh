#!/bin/bash

INSTALL_LOG=install_log.txt
TEST_LOG=test_log.txt

echo "# `date`" > $INSTALL_LOG
echo "# `date`" > $TEST_LOG

for TOPOLOGY in master_slave fan_in all_masters star
do
    echo "# $TOPOLOGY" 
    echo "# $TOPOLOGY" >> $INSTALL_LOG
    echo "# $TOPOLOGY" >> $TEST_LOG
    ./cookbook/install_$TOPOLOGY.sh >> $INSTALL_LOG 
    if [ -f /tmp/test_log$$ ] ; then rm /tmp/test_log$$ ; fi
    ./cookbook/test_$TOPOLOGY.sh | tee /tmp/test_log$$
    cat /tmp/test_log$$ >> $TEST_LOG
    ./cookbook/clear_cluster_$TOPOLOGY.sh >> $INSTALL_LOG
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
