#!/usr/bin/bash

export ORACLE_BASE="/app/oracle/product"
vHome12c="${ORACLE_BASE}/db/12c/1"
vHome11g="${ORACLE_BASE}/db/11g/1"
vHostName=$(hostname)

# array of 11g databases
List11g=(cigfdsd cigfdst cigfdsm cigfdsp inf91d infgix8d infgix8t infgix8m infgix8p fdlzd fdlzt fdlzm fdlzp trecscd trecsct trecscm trecscp obieed obieet obieem obieep obiee2d opsm opsp bpad bpat bpam bpap fnp8d fnp8t fnp8m fnp8p)

# Prompt for new DB name
echo ""
echo -e "Enter the new database name: \c"  
while true
do
	read vNewDB
	if [[ -n "$vNewDB" ]]
	then
		vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
		break
	else
		echo -e "Enter a valid database name: \c"  
	fi
done

# Prompt for the SYSTEM password
while true
do
	echo ""
	echo -e "Enter the SYSTEM password:"
	stty -echo
	read vSystemPwd
	if [[ -n "$vSystemPwd" ]]
	then
		break
	else
		echo -e "You must enter a password\n"
	fi
done
stty echo

# set DB version
export ORACLE_HOME=$vHome12c
vDBVersion=12
for dblist in ${List11g[@]}
do
	if [[ $dblist = $vPDBName ]]
	then
		export ORACLE_HOME=$vHome11g
		vDBVersion=11
		break
	fi
done

# check database links
#echo "$ORACLE_HOME/bin/sqlplus -S system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
vDBLinks=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL
)

for linkname in ${vDBLinks[@]}
do
	# echo $linkname
	vLinkOwner=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL
)

	for ownername in ${vLinkOwner[@]}
	do
		# echo $ownername
		# check public links
		if [[ $ownername = "PUBLIC" ]]
		then
			vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${linkname};
EXIT;
RUNSQL
)
			# echo $vLinkTest
			if [[ $vLinkTest != "1" ]]
			then
				vHSLinkCheck=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dba_db_links where host like '%HS%' and db_link='${linkname}';
EXIT;
RUNSQL
)
				if [[ $vHSLinkCheck != "1" ]]
				then
					echo "$linkname needs to be fixed!"
				else
					echo "Heterogeneous link $linkname needs to be fixed!" 
				fi
				echo "$vLinkTest"
			# else
				# echo "$linkname is working" 
			fi
			
		# check schema-owned links
		else
			vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on define on flush off
alter user $ownername grant connect through system;
connect system[${ownername}]/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
select '1' from dual@${linkname};
connect system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
alter user $ownername revoke connect through system;
EXIT;
RUNSQL
)
			# echo $vLinkTest
			if [[ $vLinkTest != "1" ]]
			then
				echo "$linkname needs to be fixed!"
				echo "$vLinkTest"
			# else
				# echo "$linkname is working" 
			fi
		fi
	done
done

# check for hard-coded links
echo ""
echo "Now checking for hard-coded links..."
vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set lines 150 pages 0
set echo off
set feedback off
col "STMT" format a150
select 'Link '||db_link||' is hard-coded to '||
SUBSTR(host, INSTR(UPPER(host),'HOST')+5, INSTR(UPPER(host),')',INSTR(UPPER(host),'HOST')) - INSTR(UPPER(host),'HOST') - 5)||'\n' "STMT"
from dba_db_links
where (INSTR(UPPER(host),'UX') + INSTR(UPPER(host),'LX'))>0;
RUNSQL
)
echo -e $vLinkTest
