#!/bin/bash

export ORACLE_BASE="/app/oracle"
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHostName=`hostname`
vScriptDir="/app/oracle/scripts/12cupgrade"
vCDBPrefix="c"
MAXNAMELENGTH=8

# Prompt for new DB name
echo ""
echo -e "Enter the new database name: \c"  
while true
do
	read vNewDB
	if [[ -n "$vNewDB" ]]
	then
		vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
		DBCAPS=`echo $vPDBName | tr 'a-z' 'A-Z'`
		echo "The new database name is $vPDBName"
		break
	else
		echo -e "Enter a valid database name: \c"  
	fi
done

# set CDB name
vCDBName="${vCDBPrefix}${vPDBName}"
vCDBFull="$vCDBName"
# check length of CDB name (max 8 char)
vCDBLength=$(echo -n $vCDBName | wc -c)
if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
then
	vCDBName1=$(echo -n $vCDBName | awk '{ print substr( $0, 1, 6 ) }')
	vCDBName2=$(echo -n $vCDBName | awk '{ print substr( $0, length($0), length($0) ) }')
	vCDBName="${vCDBName1}_${vCDBName2}"
fi

export ORACLE_SID=$vCDBName
export TNS_ADMIN="${ORACLE_BASE}/tns_admin"

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "WARNING:"
echo "This will DROP the pluggable database $vPDBName"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
echo -e "Do you wish to continue? (Y) or (N) \c"
while true
do
	read vConfirm
	if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
	then
		echo "Continuing..."  | tee -a $vOutputLog
		break
	elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	then
		echo " "
		echo "Exiting at user's request..."  | tee -a $vOutputLog
		exit 2
	else
		echo -e "Please enter (Y) or (N).\c"  
	fi
done

##################################################### drop database #####################################################

cd $vScriptDir
unset LIBPATH
#export ORAENV_ASK=NO
#. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib
echo "================================"
echo "Your Oracle Environment Settings:"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "ORACLE_SID            = ${ORACLE_SID}"
echo "ORACLE_HOME           = ${ORACLE_HOME}"
echo "TNS_ADMIN             = ${TNS_ADMIN}"
echo "LD_LIBRARY_PATH       = ${LD_LIBRARY_PATH}"
echo ""

# Drop pluggable databases
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
--shutdown immediate;
--startup;
select name, dbid, created from v\$database;
alter session set container=cdb\$root;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;
alter pluggable database all close;
DROP PLUGGABLE DATABASE ${vPDBName} INCLUDING DATAFILES;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;
exit;
RUNSQL
