
if [ ! -f ./CONFIG.sh ]
then
    echo "Configuration file CONFIG.sh not found"
    exit 1
fi

. ./CONFIG.sh


MYSQL="$BASEDIR/bin/mysql"
if [ ! -x $MYSQL ]
then
    echo "Could not find $MYSQL"
    exit 1
fi

export user_cnf=user$$.cnf
export repl_cnf=repl$$.cnf

echo "[client]" > $user_cnf
echo "user=$DB_USER" >> $user_cnf
echo "password=$DB_PASSWORD" >> $user_cnf

echo "[client]" > $repl_cnf
echo "user=$DB_USER" >> $repl_cnf
echo "password=$DB_PASSWORD" >> $repl_cnf

export MYSQL_SLAVE="$MYSQL --defaults-file=$PWD/repl$$.cnf --port=$DB_PORT"
export MYSQL="$MYSQL --defaults-file=$PWD/user$$.cnf --port=$DB_PORT"

function cleanup
{
    rm $repl_cnf
    rm $user_cnf
}
