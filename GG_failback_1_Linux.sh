#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GG_failback_1_Linux.sh
#
#  DESCRIPTION
#    Stop GoldenGate extract process from Linux DB to failback to AIX
#
#  STEPS
#	Clear GG stats
#	Count DB objects
#	Check GG that count tables replicated
#	Stop GG
#	Lock users
#	Flush sequences
#	Bounce the DB
#	Copy files to AIX
#
#  MODIFIED     (MM/DD/YY)
#  KDJ           04/05/18 - Created
#================================================================================================#

vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')
MAXNAMELENGTH=8
vCDBPrefix="c"

############################ Oracle Constants ############################
vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')
export ORACLE_BASE="/app/oracle"
export TNS_ADMIN=/app/oracle/tns_admin
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHome11g="${ORACLE_BASE}/product/db/11g/1"

# set tier-specific constants
vHostName=$(hostname)
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	GGATE12=/oragg/12.2
	GGATE11=/app/oragg/12.2_11g
	GGHOST=lxora12cinfs02
elif [[ $vTier = 'p' ]]
then
	GGATE12=/app/oracle/product/ggate/12c/1
	GGATE11=/app/oracle/product/ggate/11g/1
	GGHOST=lxoggp01
else
	GGATE12=/app/oracle/product/ggate/12c/1
	GGATE11=/app/oracle/product/ggate/11g/1
	GGHOST=lxoggm01
fi

# Script directory
RUNDIR=/app/oracle/scripts/12cupgrade
LOGDIR=${RUNDIR}/logs

# AIX comparison tables
vRowTable="ggtest.row_count_aix"
vObjectTable="ggtest.object_count_aix"
vIndexTable="ggtest.index_count_aix"
vConstraintTable="ggtest.constraint_count_aix"
vPrivilegeTable="ggtest.priv_count_aix"
vRolesTable="ggtest.role_count_aix"
vQuotaTable="ggtest.quota_aix"

# Linux comparison tables
vLinuxRowTable="ggtest.row_count_linux"
vLinuxObjectTable="ggtest.object_count_linux"
vLinuxIndexTable="ggtest.index_count_linux"
vLinuxConstraintTable="ggtest.constraint_count_linux"
vLinuxPrivilegeTable="ggtest.priv_count_linux"
vLinuxRolesTable="ggtest.role_count_linux"
vLinuxQuotaTable="ggtest.quota_linux"

# excluded users and roles
vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE','SQLTUNE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE'"
vLockExclude="'GGS','SYS','SYSTEM','DBSNMP','UIMMONITOR'"

############################ Trap Function ###################################
# PURPOSE:                                                                   #
# This function writes appropriate message based on how script exits.        #
##############################################################################

function trap_fnc {
	if [[ $vExitCode -eq 0 ]]
	then
		echo "COMPLETE" | tee -a $vOutputLog
	elif [[ $vExitCode -eq 2 ]]
	then
		echo "Exiting at user's request" | tee -a $vOutputLog
	else
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
	fi
}

############################ Continue Function ###############################
# PURPOSE:                                                                   #
# This function asks for confirmation to continue.                           #
##############################################################################

function continue_fnc {
	echo "Do you wish to continue? (Y) or (N)"
	while true
	do
		read vConfirm
		if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
		then
			echo "Continuing..."  | tee -a $vOutputLog
			break
		elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
		then
			exit 2
		else
			echo "Please enter (Y) or (N)"  
		fi
	done
}

############################ Error Check Function ############################
# PURPOSE:                                                                   #
# This function checks the log for critical errors.                          #
##############################################################################

function error_check_fnc {
	# copy Oracle and bash errors from log file to error log
	gawk '/^ORA-|^SP2-|^PLS-|^RMAN-|^TNS-|^bash:-/' $1 > $2

	# count number of errors
	vLineCt=$(wc -l $2 | awk '{print $1}')
	if [[ $vLineCt -gt 0 ]]
	then
		sleep 5
		echo " " | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo " " | tee -a $vOutputLog
		echo "There are $vLineCt critical errors." | tee -a $vOutputLog
		cat $2 | tee -a $vOutputLog
		echo "Check $1 for the full details." | tee -a $vOutputLog
		#exit 1
		continue_fnc
	else
		echo " "
		echo "No errors to report." | tee -a $vOutputLog
	fi
}

############################ GoldenGate Set Name #############################
# PURPOSE:                                                                   #
# This function sets GG process names to old standard.                       #
##############################################################################

function verify_names_fnc {
	# Check that GG proc names
	cd $GGATE
	./ggsci > $vGGStatusOut << EOF
info all
exit
EOF

	cat $vGGStatusOut | tee -a $vOutputLog
	vGGStatus=$(cat $vGGStatusOut | grep $1 | wc -l)
	if [[ $vGGStatus -eq 0 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "Process $1 was not found. Checking with old naming standard." | tee -a $vOutputLog
		
		# set names according to old standard
		VarLen=$(echo $DBCAPS | awk '{ print length($0) }')
		if [[ $VarLen -gt 6 ]]
		then
			DBCAPS1=$(echo $DBCAPS | awk '{ print substr( $0, 1, 4 ) }')
			DBCAPS2=$(echo $DBCAPS | awk '{ print substr( $0, length($0), length($0) ) }')
			DBShort="${DBCAPS1}_${DBCAPS2}"
		else
			DBShort=$DBCAPS
		fi
		vExtName="E${DBShort}1"
		VarLen=$(echo $vExtName | awk '{ print length($0) }')
		if [[ $VarLen -gt 8 ]]
		then
			echo "" | tee -a $vOutputLog
			echo "ERROR: The extract name $vExtName is too long. Max is 8 characters." | tee -a $vOutputLog
			exit 1
		else
			echo "" | tee -a $vOutputLog
			echo "The extract process name has been set to $vExtName." | tee -a $vOutputLog
		fi
		vPushName="P${DBShort}1"
		VarLen=$(echo $vPushName | awk '{ print length($0) }')
		if [[ $VarLen -gt 8 ]]
		then
			echo "" | tee -a $vOutputLog
			echo "ERROR: The extract name $vPushName is too long. Max is 8 characters." | tee -a $vOutputLog
			exit 1
		else
			echo "" | tee -a $vOutputLog
			echo "The push process name has been set to $vPushName." | tee -a $vOutputLog
		fi
		vRepName="R${DBShort}1"
		VarLen=$(echo $vRepName | awk '{ print length($0) }')
		if [[ $VarLen -gt 8 ]]
		then
			echo "" | tee -a $vOutputLog
			echo "ERROR: The extract name $vRepName is too long. Max is 8 characters." | tee -a $vOutputLog
			exit 1
		else
			echo "" | tee -a $vOutputLog
			echo "The replicat name has been set to $vRepName." | tee -a $vOutputLog
		fi
	
		# Check using old GG proc names
		cd $GGATE
		./ggsci > $vGGStatusOut << EOF
info all
exit
EOF

		cat $vGGStatusOut | tee -a $vOutputLog
		vGGStatus=$(cat $vGGStatusOut | grep $vExtName | wc -l)
		if [[ $vGGStatus -eq 0 ]]
		then
			echo "" | tee -a $vOutputLog
			echo "ERROR: Process $1 was not found. Exiting script." | tee -a $vOutputLog
			exit 1
		else
			echo "" | tee -a $vOutputLog
			echo "Process $1 was found. Using old process naming standards." | tee -a $vOutputLog
		fi
	fi
}

############################ GoldenGate Process Check ########################
# PURPOSE:                                                                   #
# This function checks the status of a GG process.                           #
##############################################################################

function info_all_fnc {
	# Check that GG extract is running
	cd $GGATE
	./ggsci > $vGGStatusOut << EOF
status extract $1
exit
EOF

	cat $vGGStatusOut | tee -a $vOutputLog
	vGGStatus=$(cat $vGGStatusOut | grep $1 | awk '{ print $6}')
	if [[ $vGGStatus != "RUNNING" ]]
	then
		echo ""  | tee -a $vOutputLog
		echo "The $1 process is $vGGStatus. Please check the status."  | tee -a $vOutputLog
		exit 1
	else
		echo ""  | tee -a $vOutputLog
		echo "OK: The $1 process is $vGGStatus."  | tee -a $vOutputLog
	fi
}

############################ GoldenGate Fail Check ###########################
# PURPOSE:                                                                   #
# This function makes sure GG process is running.                            #
##############################################################################

function gg_run_check_fnc {
	while true
	do
		# Check the GG status
		cd $GGATE
		./ggsci > $vGGStatusOut << EOF
info all
exit
EOF
		cat $vGGStatusOut | tee -a $vOutputLog
		vGGStatus=$(cat $vGGStatusOut | grep "$1" | awk '{ print $2}')
		if [[ $vGGStatus = "STOPPED" || $vGGStatus = "ABENDED" ]]
		then
			GGRUNNING="FALSE"
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			echo "WARNING"  | tee -a $vOutputLog
			echo "The GG process $1 is $vGGStatus."  | tee -a $vOutputLog
			echo "Please make sure this is running before continuing."  | tee -a $vOutputLog
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			break
			#exit 1
		elif [[ $vGGStatus = "RUNNING" ]]
		then
			echo "SUCCESS: The GG process $1 is $vGGStatus."
			break
		else
			sleep 10
		fi
	done
}

############################ User Prompts ####################################
# PURPOSE:                                                                   #
# This function prompts the user for info.                                   #
##############################################################################

function prompt_fnc {
	echo ""
	echo "*********************************"
	echo "* User prompts                  *"
	echo "*********************************"
	
	# List running databases
	echo ""
	/app/oracle/scripts/pmonn.pm
	
	# Prompt for the database name
	echo ""
	echo ""
	echo "Enter the database to stop the GoldenGate extract (PDB for 12c):"  
	while true
	do
		read DB11G
		if [[ -n "$DB11G" ]]
		then
			vPDBName=`echo $DB11G | tr 'A-Z' 'a-z'`
			DBCAPS=`echo $DB11G | tr 'a-z' 'A-Z'`
			echo "You have entered database $vPDBName"
			break
		else
			echo "Enter a valid database name:"  
		fi
	done

	# Prompt for DB version
	echo ""
	echo -e "Select the Oracle version for this database: (a) 12c (b) 11g"
	while true
	do
		read vReadVersion
		if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
		then
			# set GG home
			export GGATE=$GGATE12
			vDBVersion=12
			break
		elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
		then
			# set GG home
			export GGATE=$GGATE11
			vDBVersion=11
			break
		else
			echo -e "Select a valid database version:"  
		fi
	done

	# Prompt for location of old database
	# echo ""
	# echo "Enter the AIX host for the database:"  
	# while true
	# do
		# read OLDHOST
		# if [[ -n "$OLDHOST" ]]
		# then
			# echo "You have entered new host $OLDHOST"
			# break
		# else
			# echo "Enter a valid host name:"  
		# fi
	# done

	# Prompt for the SYS password
	while true
	do
		echo ""
		echo -e "Enter the SYS password:"
		stty -echo
		read vSysPwd
		if [[ -n "$vSysPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
	
	# Prompt for the GGS password
	while true
	do
		echo ""
		echo "Enter the GGS password:"
		stty -echo
		read GGSPWD
		if [[ -n "$GGSPWD" ]]
		then
			break
		else
			echo "You must enter a password\n"
		fi
	done
	stty echo
}

############################ Lock User Function ##############################
# PURPOSE:                                                                   #
# This function locks accounts so data can't be changed directly.            #
##############################################################################

function lock_users_fnc {
	echo "" | tee -a $vOutputLog
	echo "***********************************" | tee -a $vOutputLog
	echo "* Locking user accounts on target *" | tee -a $vOutputLog
	echo "***********************************" | tee -a $vOutputLog

	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

--SPOOL $vOutputLog APPEND
--SHUTDOWN ABORT
--STARTUP

SPOOL $vLockUsers
select 'ALTER USER "'||username||'" ACCOUNT LOCK;'
from dba_users
where ACCOUNT_STATUS in ('OPEN','EXPIRED') and USERNAME not in ($vLockExclude)
order by 1;
SPOOL OFF

SPOOL $vUnlockUsers
select 'SET ECHO ON' from dual;
select 'ALTER USER "'||username||'" ACCOUNT UNLOCK;'
from dba_users
where ACCOUNT_STATUS in ('OPEN','EXPIRED') and USERNAME not in ($vLockExclude)
order by 1;
SPOOL OFF

REM Locking user accounts
SET ECHO ON
SET LINES 150 PAGES 1000
SPOOL $vOutputLog APPEND
@$vLockUsers
SPOOL OFF
EXIT
EOF

# check for errors
error_check_fnc $vLockUsers $vErrorLog
error_check_fnc $vUnlockUsers $vErrorLog
error_check_fnc $vOutputLog $vErrorLog
}

############################ Check User Function #############################
# PURPOSE:                                                                   #
# This function verified the locked accounts.                                #
##############################################################################

function check_users_fnc {
	echo "" | tee -a $vOutputLog
	echo "***********************************" | tee -a $vOutputLog
	echo "* Verify locked user accounts on $vPDBName *" | tee -a $vOutputLog
	echo "***********************************" | tee -a $vOutputLog

	$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vAccountStatus
col USERNAME format a30
col ACCOUNT_STATUS format a40
col LOCK_DATE format a12
col EXPIRY_DATE format a12
select username, account_status, lock_date, expiry_date
from dba_users
order by username, account_status;
SPOOL OFF
EXIT
EOF
	cat $vAccountStatus >> $vOutputLog

	# $ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vCheckUsers
select username, account_status
from dba_users
where username not in ($vLockExclude)
and account_status not like '%LOCK%'
order by username, account_status;
EOF

vOpenUserCount=$(cat $vCheckUsers | wc -l)
if [[ $vOpenUserCount -eq 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "SUCCESS: All user accounts have been locked." | tee -a $vOutputLog
else
	echo "" | tee -a $vOutputLog
	echo "ERROR: The following user accounts are NOT locked. Make sure there are locked before you continue." | tee -a $vOutputLog
	cat $vCheckUsers | tee -a $vOutputLog
fi

# check for errors
error_check_fnc $vOutputLog $vErrorLog
}

############################ Truncate counts #################################
# PURPOSE:                                                                   #
# This function truncates the count tables.                                  #
##############################################################################

function truncate_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Truncate count tables         *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<RUNSQL
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vOutputLog APPEND
-- truncate tables
truncate table $vLinuxObjectTable;
truncate table $vLinuxRowTable;
truncate table $vLinuxIndexTable;
truncate table $vLinuxConstraintTable;
truncate table $vLinuxPrivilegeTable;
truncate table $vLinuxRolesTable;
truncate table $vLinuxQuotaTable;
SPOOL OFF
RUNSQL

	# check for errors
	error_check_fnc $vOutputLog $vErrorLog
}

############################ Clear GG stats ##################################
# PURPOSE:                                                                   #
# This function clears stats from GG process.                                #
##############################################################################

function clear_stats_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Clearing GG stats             *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	cd $GGATE
	./ggsci >> $vOutputLog << EOF
stats extract $vExtName, reset
stats extract $vPushName, reset

sh sleep 10

stats extract $vExtName latest table ${vPDBName}.$vLinuxRowTable
stats extract $vExtName latest table ${vPDBName}.$vLinuxObjectTable

stats extract $vPushName latest table ${vPDBName}.$vLinuxRowTable
stats extract $vPushName latest table ${vPDBName}.$vLinuxObjectTable

exit
EOF
}

############################ Re-populate counts ##############################
# PURPOSE:                                                                   #
# This function re-populates the count tables.                               #
##############################################################################

function count_table_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Re-populate count tables      *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<RUNSQL
SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vOutputLog APPEND
-- insert object info
insert into $vLinuxObjectTable
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null
and (owner, object_name, object_type) not in
(select owner, object_name, object_type from DBA_OBJECTS where owner='PUBLIC' and object_type='SYNONYM');
commit;

-- insert table row counts
declare
  cursor cf is
    select db.name, ins.host_name,
	  tb.owner, tb.table_name, tb.status
	from DBA_TABLES tb, v\$instance ins, v\$database db
	where tb.IOT_TYPE is null and owner not in ($vExcludeUsers)
	and (tb.owner, tb.table_name) not in (select owner, table_name from dba_external_tables);
  record_count number;
  sql_str      varchar2(2000);
  rec cf%rowtype;
begin
  open cf;
  loop
    fetch cf
      into rec;
    exit when cf%notfound;
    sql_str := 'select count(1) from "' || rec.owner || '"."' || rec.table_name || '"';
    execute immediate sql_str into record_count;
    insert into ${vLinuxRowTable}
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
	commit;
  end loop;
  close cf;
end;
/

-- insert index info
insert into $vLinuxIndexTable
select OWNER, INDEX_NAME, INDEX_TYPE, TABLE_OWNER, TABLE_NAME, STATUS
from DBA_INDEXES
where owner not in ($vExcludeUsers);

-- insert constraint info
insert into $vLinuxConstraintTable
select owner, table_name, constraint_name, constraint_type, status
from dba_constraints
where owner not in ($vExcludeUsers);

-- insert privilege info
insert into $vLinuxPrivilegeTable
select grantee, owner, table_name, privilege
	/* DIRECT OBJ PRIVILEGES */ 	
from dba_tab_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and owner not in ($vExcludeUsers)
and (OWNER,TABLE_NAME) not in (SELECT owner, object_name FROM dba_recyclebin)
UNION 
	/* INDIRECT OBJ PRIVILEGES */ 
select rp.grantee, tp.owner, tp.table_name, tp.privilege
from dba_tab_privs tp, dba_role_privs rp, dba_users du
where tp.grantee=rp.granted_role and rp.grantee=du.username
and rp.grantee not in ($vExcludeUsers)
and tp.owner not in ($vExcludeUsers)
and (tp.OWNER,tp.TABLE_NAME) not in (SELECT owner, object_name FROM dba_recyclebin)
UNION
	/* DIRECT SYS PRIVILEGES */ 
select grantee, 'n/a', 'n/a', privilege
from dba_sys_privs
where (grantee, privilege) not in
	(select r.role, 'UNLIMITED TABLESPACE' from dba_roles r)
and grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
UNION 
	/* INDIRECT SYS PRIVILEGES */ 
select rp.grantee, 'n/a', 'n/a', sp.privilege
from dba_sys_privs sp, dba_role_privs rp, dba_users du
where sp.grantee=rp.granted_role and rp.grantee=du.username
and rp.grantee not in ($vExcludeUsers)
and sp.grantee not in ($vExcludeRoles);

-- insert role info
insert into $vLinuxRolesTable
select granted_role, grantee, admin_option, default_role
from dba_role_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and common='NO';

-- insert quota info
insert into $vLinuxQuotaTable
select username, tablespace_name,
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end "QUOTA"
from dba_ts_quotas
where username not in ($vExcludeUsers)
UNION
select rp.grantee, ts.tablespace_name, 'UNLIMITED'
from dba_sys_privs sp, dba_roles dr, dba_role_privs rp, dba_tablespaces ts
where sp.grantee=dr.role and rp.granted_role=dr.role
and sp.privilege='UNLIMITED TABLESPACE'
and ts.contents not in ('TEMPORARY','UNDO')
and rp.grantee not in ($vExcludeUsers)
UNION
select sp.grantee, ts.tablespace_name, 'UNLIMITED'
from dba_sys_privs sp, dba_tablespaces ts
where sp.privilege='UNLIMITED TABLESPACE'
and ts.contents not in ('TEMPORARY','UNDO')
and sp.grantee not in ($vExcludeUsers)
and sp.grantee not in ($vExcludeRoles);

select 'There are '||count(*)||' tables.' from $vLinuxRowTable;
select 'There are '||count(*)||' objects.' from $vLinuxObjectTable;
select 'There are '||count(*)||' indexes.' from $vLinuxIndexTable;
select 'There are '||count(*)||' constraints.' from $vLinuxConstraintTable;
select 'There are '||count(*)||' privileges.' from $vLinuxPrivilegeTable;
select 'There are '||count(*)||' roles.' from $vLinuxRolesTable;
select 'There are '||count(*)||' quotas.' from $vLinuxQuotaTable;
SPOOL OFF

/* flush sequences */
SPOOL $FLUSHSEQUENCES
select 'dblogin userid GGS@${vPDBName} password $GGSPWD' from dual;
select distinct 'FLUSH SEQUENCE ${vPDBName}.'||sequence_owner||'.*'
from dba_sequences 
where sequence_owner not in ($vExcludeUsers)
order by 1;
SPOOL OFF

exit;
RUNSQL

	# check for errors
	error_check_fnc $vOutputLog $vErrorLog

	# get row count number
	vRowCount=$( $ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<EOF
col current_scn format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from $vLinuxRowTable;
exit;
EOF
)

	# save row count number
	echo "There are $vRowCount tables" | tee -a vOutputLog
	echo $vRowCount > ${vOutputDir}/${vRowCountOut}
	
	# check for errors
	error_check_fnc ${vOutputDir}/${vRowCountOut} $vErrorLog

	# get object count number
	vObjectCount=$( $ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<EOF
col current_scn format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from $vLinuxObjectTable;
exit;
EOF
)

	# save object count number
	echo "There are $vObjectCount objects" | tee -a vOutputLog
	echo $vObjectCount > ${vOutputDir}/${vObjectCountOut}
	
	# check for errors
	error_check_fnc ${vOutputDir}/${vObjectCountOut} $vErrorLog
}

############################ Get GG stats ####################################
# PURPOSE:                                                                   #
# This function gets stats from GG process.                                  #
##############################################################################

function get_stats_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Stats from $1 for ${vPDBName}.${2} *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Get row processed
	cd $GGATE
	while true
	do
		# Check the GG status
		./ggsci > $vGGStatOut << EOF
stats extract $1 latest table ${vPDBName}.${2}
exit
EOF

		cat $vGGStatOut | tee -a $vOutputLog
		vGGStatCount=$(cat $vGGStatOut | grep "Total operations" | awk '{ print $3}' | awk -F. '{ print $1}')
		if [[ $vGGStatCount -gt $3 ]]
		then
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			echo "ERROR"  | tee -a $vOutputLog
			echo "GoldenGate has processed more rows than exist in the table."  | tee -a $vOutputLog
			echo "  Table:               ${vPDBName}.${2}"  | tee -a $vOutputLog
			echo "  Rows Added:          $3"  | tee -a $vOutputLog
			echo "  $1 processed:   $vGGStatCount"  | tee -a $vOutputLog
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			exit 1
		elif [[ $vGGStatCount -eq $3 ]]
		then
			echo ""  | tee -a $vOutputLog
			echo "SUCCESS: $1 has processed all the rows for ${vPDBName}.${2}."  | tee -a $vOutputLog
			break
		else
			sleep 10
		fi
	done
}

############################ GoldenGate Stop Process #########################
# PURPOSE:                                                                   #
# This function stops a GG process.                                          #
##############################################################################

function gg_stop_fnc {
	# stop process
	cd $GGATE
	./ggsci >> $vOutputLog << EOF
stop extract $1
exit
EOF

	while true
	do
		# Check the GG status
		./ggsci > $vGGStatusOut << EOF
status extract $1
exit
EOF
		cat $vGGStatusOut | tee -a $vOutputLog
		vGGStatus=$(cat $vGGStatusOut | grep $1 | awk '{ print $6}')
		if [[ $vGGStatus = "STOPPED" ]]
		then
			echo "" | tee -a $vOutputLog
			echo "SUCCESS: The GG process $1 is now $vGGStatus."| tee -a $vOutputLog
			break
		#elif [[ $vGGStatus = "RUNNING" ]]
		#then
		#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		#	echo "ERROR"  | tee -a $vOutputLog
		#	echo "The stop command did not take. Please quit and try again."  | tee -a $vOutputLog
		#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
		#	exit 1
		else
			echo "Waiting 10 seconds..." | tee -a $vOutputLog
			sleep 10
		fi
	done
	echo $vGGStatus
}

############################ File Copy #######################################
# PURPOSE:                                                                   #
# This function copies file to Linux host.                                   #
##############################################################################

function file_copy_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Copy scripts to new host      *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog

	# add all files to archive
	cd $vOutputDir
	tar -cvf $TARFILE *${vPDBName}*
	
	echo "" | tee -a $vOutputLog
	# copy files to new host
	if [[ AUTOMODE -eq 1 ]]
	then
		# echo "Copying archive file to $OLDHOST. You may be prompted for the password." | tee -a $vOutputLog
		# scp ${TARFILE} oracle@${OLDHOST}:/tmp | tee -a $vOutputLog
		# if [ $? -ne 0 ]
		# then
			# echo "" | tee -a $vOutputLog
			# echo "There was a problem copying $TARFILE to $OLDHOST. Please run this command manually:" | tee -a $vOutputLog
			# echo "scp ${vOutputDir}/${TARFILE} oracle@${OLDHOST}:/tmp" | tee -a $vOutputLog
		# fi
		# check if new DB host and GG host are different
		# if [[ $OLDHOST != $GGHOST ]]
		# then
			echo "Copying archive file to $GGHOST. You may be prompted for the password." | tee -a $vOutputLog
			scp ${vOutputDir}/${TARFILE} oracle@${GGHOST}:/tmp | tee -a $vOutputLog
			if [ $? -ne 0 ]
			then
				echo "" | tee -a $vOutputLog
				echo "There was a problem copying $TARFILE to $GGHOST. Please run this command manually:" | tee -a $vOutputLog
				echo "scp ${TARFILE} oracle@${GGHOST}:/tmp" | tee -a $vOutputLog
			fi
		# fi
	else
		# echo "Cannot connect to $OLDHOST and/or $GGHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
		echo "Cannot connect to $GGHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
		echo "scp ${TARFILE} oracle@${GGHOST}:/tmp" | tee -a $vOutputLog
	fi
}

############################ Summary #########################################
# PURPOSE:                                                                   #
# This function reports a summary.                                           #
##############################################################################

function summary_fnc {
	vEndSec=$(date '+%s')
	vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
	show_time $vRunSec

	echo "" | tee -a $vOutputLog
	echo "******************************************************************" | tee -a $vOutputLog
	echo "$0 is now complete." | tee -a $vOutputLog
	echo "Database Name:          $vPDBName" | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "CDB Name:               $vCDBName" | tee -a $vOutputLog
	fi
	echo "Count output archive:   ${vOutputDir}/${TARFILE}" | tee -a $vOutputLog
	echo "GoldenGate Home:        $GGATE" | tee -a $vOutputLog
	# echo "GG Extract Status:      $vExtStatus" | tee -a $vOutputLog
	# echo "GG Push Status:         $vPushStatus" | tee -a $vOutputLog
	echo "GG Remote Host:         $GGHOST" | tee -a $vOutputLog
	# echo "AIX DB Host:            $OLDHOST" | tee -a $vOutputLog
	echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
	echo "Output log:             $vOutputLog" | tee -a $vOutputLog
	echo "******************************************************************" | tee -a $vOutputLog
}

############################ Script Timing Function ##########################
# PURPOSE:                                                                   #
# This function calculates the runtime for the script.                       #
##############################################################################

function show_time {
    num=$1
    min=0
    hour=0
    day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    vTotalTime="${hour}H ${min}M ${sec}S"
}

#####################################################################
# PURPOSE:                                                          #
# MAIN PROGRAM EXECUTION BEGINS HERE.                               #
#####################################################################

# When this exits, exit all background process also.
trap 'vExitCode=$?; trap_fnc' EXIT

############################ User prompts ############################

prompt_fnc


############################ Set CDB Name ############################

# set CDB variable based on DB version
if [[ $vDBVersion -eq 12 ]]
then
	# set CDB name
	vCDBName="${vCDBPrefix}${vPDBName}"
	# check length of CDB name (max 8 char)
	vCDBLength=$(echo -n $vCDBName | wc -c)
	if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
	then
		# first3_last3
		vCDBName1=$(echo -n $vCDBName | awk '{ print substr( $0, 1, 4 ) }')
		vCDBName2=$(echo -n $vCDBName | awk '{ print substr( $0, length($0)-2, length($0) ) }')
		vCDBName="${vCDBName1}_${vCDBName2}"
	fi
	export ORACLE_HOME=$vHome12c
	echo "CDB name set to $vCDBName"
else
	vCDBName="$vPDBName"
	export ORACLE_HOME=$vHome11g
fi

export ORACLE_SID=${vCDBName}
export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64:$GGATE
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export ORAENV_ASK=NO
export LIBPATH=$ORACLE_HOME/lib

	
############################ Set GG Host ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Setting variables             *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set output log name
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${RUNDIR}/logs/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
vErrorLog="${RUNDIR}/logs/${vBaseName}_${vPDBName}_err.log"
vAccountStatus="${RUNDIR}/logs/AccountStatus_${vPDBName}_${NOWwSECs}.log"

if [ -f $vOutputLog ]
then
	rm $vOutputLog
fi
if [ -f $vAccountStatus ]
then
	rm $vAccountStatus
fi

# set names for GG processes (max 8 characters)
VarLen=$(echo $DBCAPS | awk '{ print length($0) }')
if [[ $VarLen -gt 6 ]]
then
	DBCAPS1=$(echo $DBCAPS | awk '{ print substr( $0, 1, 2 ) }')
	DBCAPS2=$(echo $DBCAPS | awk '{ print substr( $0, length($0)-2, length($0) ) }')
	DBShort="${DBCAPS1}_${DBCAPS2}"
else
	DBShort=$DBCAPS
fi
vExtName="E${DBShort}2"
VarLen=$(echo $vExtName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vExtName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The extract process name has been set to $vExtName." | tee -a $vOutputLog
fi
vPushName="P${DBShort}2"
VarLen=$(echo $vPushName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vPushName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The push process name has been set to $vPushName." | tee -a $vOutputLog
fi

# GG directories and files
DIRDAT="${GGATE}/dirdat"
DIRSQL="${GGATE}/dirsql"
vOutputDir="/database/${vCDBName}_admn01/scripts"

# check for required directories
if [ ! -d $DIRDAT ]
then
	echo " "
	echo "ERROR: The $DIRDAT directory does not exist."
	exit 1
fi
# check for required directories
if [ ! -d $DIRSQL ]
then
	echo " "
	echo "ERROR: The $DIRSQL directory does not exist."
	exit 1
fi

# set GG file names
TARFILE=GG_failback_${vPDBName}.tar
vObjectCountOut="object_count_linux_${vPDBName}.out"
vRowCountOut="row_count_linux_${vPDBName}.out"
# vHostOut="AIX_host_${vPDBName}.out"
FLUSHSEQUENCES="${DIRSQL}/FLUSH_SEQ_${vPDBName}.oby"

# GG status files
vGGStatOut="${LOGDIR}/statcount_${vPDBName}.out"
vGGStatusOut="${LOGDIR}/procstatus_${vPDBName}.out"

# scripts to create
vLockUsers="${DIRSQL}/LockUsers_${vPDBName}.sql"
vUnlockUsers="${DIRSQL}/RestoreUsers_${vPDBName}.sql"
vCheckUsers="${DIRSQL}/CheckUsers_${vPDBName}.sql"

# Display user entries
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
echo "Database Name:    $vPDBName" | tee -a $vOutputLog
if [[ $vDBVersion -eq 12 ]]
then
	echo "CDB Name:         $vCDBName" | tee -a $vOutputLog
fi
echo "Oracle Home:      $ORACLE_HOME" | tee -a $vOutputLog
echo "GoldenGate Home:  $GGATE" | tee -a $vOutputLog
# echo "AIX DB Host:      $OLDHOST" | tee -a $vOutputLog
echo "GG Processes to Stop:" | tee -a $vOutputLog
echo "                  $vExtName" | tee -a $vOutputLog
echo "                  $vPushName" | tee -a $vOutputLog
echo "Output Log:       $vOutputLog" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog

# Confirmation
echo ""
echo "Are these values correct? (Y) or (N)"
while true
do
	read vConfirm
	if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
	then
		echo "Proceeding with the script..." | tee -a $vOutputLog
		break
	elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	then
		exit 2
	else
		echo "Please enter (Y) or (N)"  
	fi
done
	
############################ Additional prep work ############################

# Check connection to GG host
echo ""
echo "Checking connections to $GGHOST" | tee -a $vOutputLog
AUTOMODE=0
ping -c 1 $GGHOST
if [[ $? -eq 0 ]]
then
	AUTOMODE=1
else
	echo "WARNING: Unable to ping $GGHOST." | tee -a $vOutputLog
fi

# test output directory
if [[ ! -d $vOutputDir ]]
then
	# if directory does not exist try old folder structure
	vOutputDir="/move/${vPDBName}01/scripts"
	if [[ ! -d $vOutputDir ]]
	then
		# setting output directory to /tmp
		vOutputDir="/tmp"
	fi
fi
echo "" | tee -a $vOutputLog
echo "Output files will be written to $vOutputDir" | tee -a $vOutputLog

# check directories
if [[ ! -d $DIRDAT ]]
then
	echo ""
	echo "The $DIRDAT directory does not exist. Please fix this before continuing."
fi

echo "" | tee -a $vOutputLog
echo "Removing existing logs" | tee -a $vOutputLog
rm ${vOutputDir}/${TARFILE}
rm ${vOutputDir}/${vObjectCountOut}
rm ${vOutputDir}/${vRowCountOut}
# rm ${vOutputDir}/${vHostOut}
rm $vGGStatOut
rm $vGGStatusOut

# capture host name
# hostname > ${vOutputDir}/${vHostOut}

############################ Call functions ############################

# verify process names
verify_names_fnc $vExtName

# check status of extract and push
info_all_fnc $vExtName
info_all_fnc $vPushName

# lock users
lock_users_fnc
# truncate count tables
truncate_fnc
# clear stats
clear_stats_fnc
# reload count tables
count_table_fnc

# check GG stats against table counts
get_stats_fnc $vExtName $vLinuxObjectTable $vObjectCount
get_stats_fnc $vExtName $vLinuxRowTable $vRowCount
get_stats_fnc $vPushName $vLinuxObjectTable $vObjectCount
get_stats_fnc $vPushName $vLinuxRowTable $vRowCount

# flush sequences
cd $GGATE
./ggsci >> $vOutputLog << EOF
obey $FLUSHSEQUENCES
EOF
sleep 10

# stop GG processes
vExtStatus=$(gg_stop_fnc $vExtName)
vPushStatus=$(gg_stop_fnc $vPushName)

echo "" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog
echo "* Bouncing database $ORACLE_SID *" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog

#$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vCDBName}))) as sysdba" << EOF
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vOutputLog APPEND
SHUTDOWN ABORT
STARTUP
EXIT
EOF

# verify locked accounts
check_users_fnc

# copy files to Linux host
file_copy_fnc

# report summary
summary_fnc
