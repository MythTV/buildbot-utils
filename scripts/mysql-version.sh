#!/bin/sh

# List of possible mysql_config locations
MLOC="/usr/bin/mysql_config \
    /usr/local/bin/mysql_config \
    /usr/bin/mariadb_config \
"
for m in $MLOC ; do
    if [ -x $m ] ; then
        exec $m --version
    fi
done
echo "Can't find mysql_config"
