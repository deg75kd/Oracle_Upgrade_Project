#!/bin/bash

export ORACLE_BASE="/app/oracle"
export GGATE=/oragg/12.2		# export GGATE=/app/oracle/product/oragg/12.2
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHome11g="${ORACLE_BASE}/product/db/11g/1"
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

# Prompt for DB version
echo ""
echo -e "Select the Oracle version for this database: (a) 12c (b) 11g \c"
while true
do
	read vReadVersion
	if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
	then
		# set Oracle home
		export ORACLE_HOME=$vHome12c
		vDBVersion=12
		echo "You have selected Oracle version 12c"
		echo "The Oracle Home has been set to $vHome12c"
		break
	elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
	then
		# set Oracle home
		export ORACLE_HOME=$vHome11g
		vDBVersion=11
		echo "You have selected Oracle version 11g"
		echo "The Oracle Home has been set to $vHome11g"
		break
	else
		echo -e "Select a valid database version: \c"  
	fi
done

# set CDB variable based on DB version
if [[ $vDBVersion -eq 12 ]]
then
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
else
	vCDBName="$vPDBName"
	vCDBFull="$vCDBName"
fi

export ORACLE_SID=$vCDBName
export TNS_ADMIN="${ORACLE_BASE}/tns_admin"

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "WARNING:"
if [[ $vDBVersion -eq 12 ]]
then
	echo "This will DROP cdb $vCDBName and $vPDBName"
else
	echo "This will DROP the database $vPDBName"
fi
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

if [[ $vDBVersion -eq 12 ]]
then
	# Drop pluggable and container databases
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
shutdown immediate;
startup;
select name, dbid, created from v\$database;
alter session set container=cdb\$root;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;
alter pluggable database all close;
DROP PLUGGABLE DATABASE ${vPDBName} INCLUDING DATAFILES;

shutdown immediate;
startup restrict mount;
DROP DATABASE;
exit;
RUNSQL
else
	# Drop 11g database
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
shutdown immediate;
startup restrict mount;
select name, dbid, created from v\$database;
DROP DATABASE;
exit;
RUNSQL
fi

# move tar file back
if [[ -e /database/${vCDBName}_admn01/scripts/Linux_setup_${vPDBName}.tar ]]
then
	cp /database/${vCDBName}_admn01/scripts/Linux_setup_${vPDBName}.tar /tmp
else
	cp /database/E${vCDBName}/${vCDBName}_admn01/scripts/Linux_setup_${vPDBName}.tar /tmp
fi

# remove data files
if [[ -d /database/${vCDBName}01 ]]
then
	rm -r /database/${vCDBName}01/*
fi
if [[ -d /database/${vCDBName}_admn01 ]]
then
	rm -r /database/${vCDBName}_admn01/*
fi
if [[ -d /database/${vCDBName}_arch01 ]]
then
	rm -r /database/${vCDBName}_arch01/*
fi
if [[ -d /database/${vCDBName}_redo01 ]]
then
	rm -r /database/${vCDBName}_redo01/*
fi
if [[ -d /database/${vCDBName}_redo02 ]]
then
	rm -r /database/${vCDBName}_redo02/*
fi
if [[ -d /database/${vPDBName}01 ]]
then
	rm -r /database/${vPDBName}01/*
fi

# remove encrypted files
if [[ -d /database/E${vCDBName}/${vCDBName}01 ]]
then
	rm -r /database/E${vCDBName}/${vCDBName}01/*
fi
if [[ -d /database/E${vCDBName}/${vCDBName}_admn01 ]]
then
	rm -r /database/E${vCDBName}/${vCDBName}_admn01/*
fi
if [[ -d /database/E${vCDBName}/${vCDBName}_arch01 ]]
then
	rm -r /database/E${vCDBName}/${vCDBName}_arch01/*
fi
if [[ -d /database/E${vCDBName}/${vCDBName}_redo01 ]]
then
	rm -r /database/E${vCDBName}/${vCDBName}_redo01/*
fi
if [[ -d /database/E${vCDBName}/${vCDBName}_redo02 ]]
then
	rm -r /database/E${vCDBName}/${vCDBName}_redo02/*
fi
if [[ -d /database/E${vPDBName}/${vPDBName}01 ]]
then
	rm -r /database/E${vPDBName}/${vPDBName}01/*
fi

# remove other files
rm $ORACLE_HOME/dbs/init${vCDBName}.ora
rm $ORACLE_HOME/dbs/orapw${vCDBName}
rm $ORACLE_HOME/dbs/spfile${vCDBName}.ora
rm -r /orasbackup/${vCDBName}
rm -r /orasbackup/${vCDBName}/rman

# Replace AIX files
echo "You may need to run this from the AIX host: "
echo "scp /tmp/Linux_setup_${vPDBName}.tar oracle@${vHostName}:/tmp/"

# revert to original tnsnames files
echo ""
echo "Remove reference to this database from these files:"
echo "   /home/oracle/.bash_profile"
echo "   /etc/oratab"

# remove failed changes from tns_create script
echo ""
echo "Then run these commands:"
echo "   . /home/oracle/.bash_profile"

