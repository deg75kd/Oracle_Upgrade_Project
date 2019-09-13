#!/usr/bin/ksh

export ORACLE_BASE="/nomove/app/oracle"
export ORACLE_HOME="${ORACLE_BASE}/db/11g/6"
vHostName=$(hostname)

# Prompt for new DB name
echo ""
echo "Enter the new database name: \c"  
while true
do
	read vNewDB
	if [[ -n "$vNewDB" ]]
	then
		ORACLE_SID=`echo $vNewDB | tr 'A-Z' 'a-z'`
		break
	else
		echo "Enter a valid database name: \c"  
	fi
done

# Prompt for the SYSTEM password
while true
do
	echo ""
	echo "Enter the SYSTEM password:"
	stty -echo
	read vSystemPwd
	if [[ -n "$vSystemPwd" ]]
	then
		break
	else
		echo "You must enter a password\n"
	fi
done
stty echo

# check database links
#echo "$ORACLE_HOME/bin/sqlplus -S system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
vDBLinks=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL`

for linkname in ${vDBLinks[@]}
do
	# echo $linkname
	vLinkOwner=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL`

	for ownername in ${vLinkOwner[@]}
	do
		# echo $ownername
		# check public links
		if [[ $ownername = "PUBLIC" ]]
		then
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${linkname};
EXIT;
RUNSQL`
			# echo $vLinkTest
			if [[ $vLinkTest != "1" ]]
			then
				vHSLinkCheck=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dba_db_links where host like '%HS%' and db_link='${linkname}';
EXIT;
RUNSQL`
				if [[ $vHSLinkCheck != "1" ]]
				then
					echo "$linkname is broken!"
				else
					echo "Heterogeneous link $linkname is broken!" 
				fi
				# echo "$vLinkTest"
			else
				echo "$linkname is working" 
			fi
			
		# check schema-owned links
		else
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on define on flush off
alter user $ownername grant connect through system;
connect system[${ownername}]/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
select '1' from dual@${linkname};
connect system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
alter user $ownername revoke connect through system;
EXIT;
RUNSQL`
			# echo $vLinkTest
			if [[ $vLinkTest != "1" ]]
			then
				echo "$linkname is broken!"
				# echo "$vLinkTest"
			else
				echo "$linkname is working" 
			fi
		fi
	done
done
