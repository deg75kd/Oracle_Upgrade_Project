#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GG_failback_2_LXOGG.sh
#
#  DESCRIPTION
#    Stop GG replicat from intermediary server
#
#  NOTES
#    Run as oracle
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         05/01/2018 - Created
#
#================================================================================================#

vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')

############################ Oracle Constants ############################
export ORACLE_BASE="/app/oracle"
export TNS_ADMIN=/app/oracle/tns_admin
export ORACLE_HOME="${ORACLE_BASE}/product/db/11g/1"
vHostName=$(hostname)
vCDBPrefix="c"
MAXNAMELENGTH=8

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts"
vUpgradeDir="${vScriptDir}/12cupgrade"
vLogDir="${vUpgradeDir}/logs"
vUpgradeDir="/app/oracle/scripts/12cupgrade"
vMissingFiles="FALSE"

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

vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE','SQLTUNE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE'"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	GGATE=/app/oragg/12.2_11g
else
	GGATE=/app/oracle/product/ggate/11g/1
fi

############################ Trap Function ###################################
# PURPOSE:                                                                   #
# This function writes appropirate message based on how script exits.        #
##############################################################################

function trap_fnc {
	if [[ $vExitCode -eq 0 ]]
	then
		echo "COMPLETE" | tee -a $vOutputLog
	elif [[ $vExitCode -eq 2 ]]
	then
		echo "Exiting at user's request" | tee -a $vOutputLog
	else
		vBgProcCt=$(jobs | wc -l)
		if [[ $vBgProcCt -gt 0 ]]
		then
			kill $(jobs -p)
		fi
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
}

############################ Error Check Function ############################
# PURPOSE:                                                                   #
# This function checks the log for critical errors.                          #
##############################################################################

function error_check_fnc {
	# copy Oracleand bash errors from log file to error log
	gawk '/^ORA-|^SP2-|^PLS-|^RMAN-|^TNS-|^bash:-/' $1 > $2

	# count number of errors
	vLineCt=$(wc -l $2 | awk '{print $1}')
	if [[ $vLineCt -gt 0 ]]
	then
		sleep 5
		echo " " | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo " " | tee -a $1
		echo "There are $vLineCt critical errors." | tee -a $1
		cat $2 | tee -a $1
		echo "Check $1 for the full details." | tee -a $1
		exit 1
	else
		echo " "
		echo "No errors to report." | tee -a $1
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
		vGGStatus=$(cat $vGGStatusOut | grep $vRepName | wc -l)
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
	# Check that GG replicat is running
	cd $GGATE
	./ggsci > $vGGStatusOut << EOF
status replicat $1
exit
EOF
	
	cat $vGGStatusOut | tee -a $vOutputLog
	vGGStatus=$(cat $vGGStatusOut | grep $1 | awk '{ print $6}')
	if [[ $vGGStatus != "RUNNING" ]]
	then
		echo ""  | tee -a $vOutputLog
		echo "The $1 process is $vGGStatus. It's probably out of sync." | tee -a $vOutputLog
		echo "Check $GGATE for report logs." | tee -a $vOutputLog
		exit 1
	else
		echo ""  | tee -a $vOutputLog
		echo "OK: The $1 process is $vGGStatus."  | tee -a $vOutputLog
	fi
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

# catch errors
trap 'vExitCode=$?; trap_fnc' EXIT

############################ User Prompts ############################

# Prompt for new DB name
echo ""
echo -e "Enter the database name: \c"  
while true
do
	read vNewDB
	if [[ -n "$vNewDB" ]]
	then
		vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
		DBCAPS=`echo $vNewDB | tr 'a-z' 'A-Z'`
		echo "The new database name is $vPDBName"
		break
	else
		echo -e "Enter a valid database name: \c"  
	fi
done
	
# Prompt for DB version
# echo ""
# echo -e "Select the Oracle version for this database: (a) 12c (b) 11g \c"
# while true
# do
	# read vReadVersion
	# if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
	# then
		# set Oracle home
		# export ORACLE_HOME=$vHome12c
		# export GGATE=$GGATE12
		# vDBVersion=12
		# echo "You have selected Oracle version 12c"
		# echo "The Oracle Home has been set to $vHome12c"
		# break
	# elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
	# then
		# set Oracle home
		# export ORACLE_HOME=$vHome11g
		# export GGATE=$GGATE11
		# vDBVersion=11
		# echo "You have selected Oracle version 11g"
		# echo "The Oracle Home has been set to $vHome11g"
		# break
	# else
		# echo -e "Select a valid database version: \c"  
	# fi
# done
	
# Prompt for the SYS password
stty -echo
while true
do
	echo ""
	echo -e "Enter the SYS password:"
	read vSysPwd
	if [[ -n "$vSysPwd" ]]
	then
		break
	else
		echo -e "You must enter a password\n"
	fi
done

# Prompt for the SYSTEM password
# while true
# do
	# echo ""
	# echo -e "Enter the SYSTEM password:"
	# read vSystemPwd
	# if [[ -n "$vSystemPwd" ]]
	# then
		# break
	# else
		# echo -e "You must enter a password\n"
	# fi
# done
# stty echo

############################ Oracle Variables ############################
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
export TNS_ADMIN="${ORACLE_BASE}/tns_admin"

############################ Script Variables ############################

export ORACLE_SID=$vPDBName

# set GG directories
DIROUT="${GGATE}/dirout"
DIRDAT="${GGATE}/dirdat"
DBDAT="${DIRDAT}/${vPDBName}"
vGGRevDir="${DBDAT}/RR"

# check for required directories
if [ ! -d $DIROUT ]
then
	echo " "
	echo "ERROR: The $DIROUT directory does not exist."
	exit 1
fi
if [ ! -d $DIRDAT ]
then
	echo " "
	echo "ERROR: The $DIRDAT directory does not exist."
	exit 1
fi

# check for directories that can be created
if [ ! -d $DBDAT ]
then
	mkdir $DBDAT
	if [[ $? -ne 0 ]]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: Could not create $DBDAT" | tee -a $vOutputLog
		exit 1
	else
		echo "" | tee -a $vOutputLog
		echo "$DBDAT created" | tee -a $vOutputLog
		chmod -R 777 $DBDAT
	fi
fi
if [ ! -d $vGGRevDir ]
then
	mkdir $vGGRevDir
	if [[ $? -ne 0 ]]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: Could not create $vGGRevDir" | tee -a $vOutputLog
		exit 1
	else
		echo "" | tee -a $vOutputLog
		echo "$vGGRevDir created" | tee -a $vOutputLog
		chmod -R 777 $vGGRevDir
	fi
fi

# set output log names
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${vLogDir}/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
vErrorLog="${vLogDir}/${vBaseName}_${vPDBName}_err.log"
vTableComp="${vLogDir}/TableComp_${vPDBName}.log"
vTableStatus="${vLogDir}/TableStatus_${vPDBName}.log"
vObjectStatus="${vLogDir}/ObjectStatus_${vPDBName}.log"
vGGStatusOut="${DIROUT}/procstatus_${vPDBName}.out"

# Remove existing logs
if [[ -f $vOutputLog ]]
then
	rm $vOutputLog
fi
if [[ -f $vErrorLog ]]
then
	rm $vErrorLog
fi
if [[ -f $vTableComp ]]
then
	rm $vTableComp
fi
if [[ -f $vTableStatus ]]
then
	rm $vTableStatus
fi
if [[ -f $vObjectStatus ]]
then
	rm $vObjectStatus
fi
if [[ -f $vGGStatusOut ]]
then
	rm $vGGStatusOut
fi
	
# set names for GG process (max 8 characters)
VarLen=$(echo $DBCAPS | awk '{ print length($0) }')
if [[ $VarLen -gt 6 ]]
then
	DBCAPS1=$(echo $DBCAPS | awk '{ print substr( $0, 1, 2 ) }')
	DBCAPS2=$(echo $DBCAPS | awk '{ print substr( $0, length($0)-2, length($0) ) }')
	DBShort="${DBCAPS1}_${DBCAPS2}"
else
	DBShort=$DBCAPS
fi
vRepName="R${DBShort}2"
VarLen=$(echo $vRepName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vRepName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The replicat name is set to $vRepName." | tee -a $vOutputLog
fi

# set variables for AIX files
TARFILE=GG_failback_${vPDBName}.tar
vObjectCountOut="object_count_linux_${vPDBName}.out"
vRowCountOut="row_count_linux_${vPDBName}.out"

# Set file array
unset vFileArray
vFileArray+=(${vLogDir}/${vObjectCountOut})
vFileArray+=(${vLogDir}/${vRowCountOut})

############################ Prep Work ############################

# verify process names
verify_names_fnc $vRepName

# make sure replicat is running
info_all_fnc $vRepName

# check for tar file
if [[ ! -e /tmp/${TARFILE} ]]
then
	if [[ ! -e ${vLogDir}/${TARFILE} ]]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: That tar file of scripts from AIX is missing: ${TARFILE}" | tee -a $vOutputLog
		echo "       It must be in /tmp or $vLogDir to continue." | tee -a $vOutputLog
		exit 1
	else
		echo "" | tee -a $vOutputLog
		echo "$TARFILE found in $vLogDir" | tee -a $vOutputLog
	fi
else
	echo "" | tee -a $vOutputLog
	echo "$TARFILE found in /tmp" | tee -a $vOutputLog
	# move it
	mv /tmp/${TARFILE} $vLogDir
fi

# unzip file
cd $vLogDir
tar -xf $TARFILE
if [ $? -ne 0 ]
then
	echo " " | tee -a $vOutputLog
	echo "ERROR: The tar file $TARFILE could not be unzipped." | tee -a $vOutputLog
	echo "       This file must be unzipped to continue." | tee -a $vOutputLog
	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The tar file $TARFILE was successfully unzipped." | tee -a $vOutputLog
fi
cd $vScriptDir

# check for unzipped files	
for vCheckArray in ${vFileArray[@]}
do
	# Issue warning if file does not exist
	ls -l $vCheckArray
	if [ $? -ne 0 ]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: The $vCheckArray file from the AIX host does not exist." | tee -a $vOutputLog
		exit 1
	else
		echo "$vCheckArray is here" | tee -a $vOutputLog
	fi
done

############################ Check GG Process Counts ############################

# get row counts from AIX files
vAIXRows=$(cat ${vLogDir}/${vRowCountOut})
vAIXObjects=$(cat ${vLogDir}/${vObjectCountOut})

# compare row count numbers
while true
do
	vLinuxRows=$( $ORACLE_HOME/bin/sqlplus -s sys/$vSysPwd@$vPDBName as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from $vRowTable;
exit;
EOF
)
	# compare results
	if [[ $vAIXRows -lt $vLinuxRows ]]
	then
		echo "" | tee -a $vOutputLog
		echo "ERROR: For $vRowTable there are more rows on Linux." | tee -a $vOutputLog
		exit 1
	elif [[ $vAIXRows -eq $vLinuxRows ]]
	then
		echo "" | tee -a $vOutputLog
		echo "There are $vAIXRows rows on both sides for $vRowTable." | tee -a $vOutputLog
		break
	else
		echo "" | tee -a $vOutputLog
		echo "For $vRowTable:" | tee -a $vOutputLog
		echo "   AIX:    $vAIXRows" | tee -a $vOutputLog
		echo "   Linux:  $vLinuxRows" | tee -a $vOutputLog
		sleep 10
	fi
done

# compare object count numbers
while true
do
	vLinuxObjects=$( $ORACLE_HOME/bin/sqlplus -s sys/$vSysPwd@$vPDBName as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from $vObjectTable;
exit;
EOF
)
	# compare results
	if [[ $vAIXObjects -lt $vLinuxObjects ]]
	then
		echo "" | tee -a $vOutputLog
		echo "ERROR: For $vObjectTable there are more rows on Linux." | tee -a $vOutputLog
		exit 1
	elif [[ $vAIXObjects -eq $vLinuxObjects ]]
	then
		echo ""
		echo "There are $vAIXObjects rows on both sides for $vObjectTable." | tee -a $vOutputLog
		break
	else
		echo "" | tee -a $vOutputLog
		echo "For $vObjectTable:" | tee -a $vOutputLog
		echo "   AIX:    $vAIXObjects" | tee -a $vOutputLog
		echo "   Linux:  $vLinuxObjects" | tee -a $vOutputLog
		sleep 10
	fi
done

############################ AIX vs. Linux Row Counts ############################

# get table counts
$ORACLE_HOME/bin/sqlplus -s sys/$vSysPwd@$vPDBName as sysdba <<EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 200
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
SPOOL $vOutputLog APPEND

WHENEVER SQLERROR EXIT

-- make sure tables are empty
truncate table $vLinuxRowTable;
truncate table $vLinuxObjectTable;
truncate table $vLinuxIndexTable;
truncate table $vLinuxConstraintTable;
truncate table $vLinuxPrivilegeTable;
truncate table $vLinuxRolesTable;
truncate table $vLinuxQuotaTable;

SET TIMING ON
-- insert object info
insert into $vLinuxObjectTable
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null
and (owner, object_name, object_type) not in
(select owner, object_name, object_type from DBA_OBJECTS where owner='PUBLIC' and object_type='SYNONYM');
commit;

-- insert table counts
set serveroutput on
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
--    dbms_output.put_line(rec.owner || ',' || rec.table_name || ',' || rec.status || ',' || record_count);
    insert into ${vLinuxRowTable}
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
	commit;
  end loop;
  close cf;
end;
/

-- insert Linux index counts
insert into $vLinuxIndexTable
select OWNER, INDEX_NAME, INDEX_TYPE, TABLE_OWNER, TABLE_NAME, STATUS
from DBA_INDEXES
where owner not in ($vExcludeUsers);
commit;

-- insert Linux constraint counts
insert into $vLinuxConstraintTable
select owner, table_name, constraint_name, constraint_type, status
from dba_constraints
where owner not in ($vExcludeUsers);
commit;

-- insert Linux privilege counts
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
commit;

-- insert Linux role counts
insert into $vLinuxRolesTable
select distinct granted_role, grantee, admin_option, default_role
from dba_role_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles);
commit;

-- insert Linux quota check
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

select 'There are '||count(*)||' tables.' "TABLES" from $vLinuxRowTable;
select 'There are '||count(*)||' objects.' "OBJECTS" from $vLinuxObjectTable;
select 'There are '||count(*)||' indexes.' "INDEXES" from $vLinuxIndexTable;
select 'There are '||count(*)||' constraints.' "CONSTRAINTS" from $vLinuxConstraintTable;
select 'There are '||count(*)||' privileges.' "PRIVILEGES" from $vLinuxPrivilegeTable;
select 'There are '||count(*)||' roles.' "ROLES" from $vLinuxRolesTable;
select 'There are '||count(*)||' quotas.' "QUOTAS" from $vLinuxQuotaTable;

SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET HEAD ON
SET TERMOUT ON
SET TIMING OFF
SET TRIMSPOOL ON
SET LINES 2500
SET PAGES 1000
SET FEEDBACK OFF

-- Index count comparison
col "AIX INDEX" format a50
col "LINUX INDEX" format a50
select aix.OWNER||'.'||aix.INDEX_NAME "AIX-INDEX", lx.OWNER||'.'||lx.INDEX_NAME "LX-INDEX"
from $vLinuxIndexTable lx full outer join $vIndexTable aix
  on aix.OWNER=lx.OWNER and aix.INDEX_NAME=lx.INDEX_NAME
where lx.INDEX_NAME is null and lx.owner not in ('GGS','GGTEST')
order by aix.OWNER, aix.INDEX_NAME, lx.OWNER, lx.INDEX_NAME;

-- Constraint comparison
select lx.owner, lx.table_name, lx.constraint_name, lx.constraint_type, aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxConstraintTable lx full outer join $vConstraintTable aix
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.constraint_name=lx.constraint_name
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGS','GGTEST')
order by 1;

-- Privilege comparison
col "AIX_PRIVILEGE" format a48
col "LINUX_PRIVILEGE" format a48
select NVL(aix.grantee,lx.grantee) "GRANTEE", 
NVL2(aix.privilege,
	CASE aix.owner
		WHEN 'n/a' THEN aix.privilege
		ELSE aix.privilege||' on '||aix.owner||'.'||aix.table_name
	END
	,'-') "AIX_PRIVILEGE", 
NVL2(lx.privilege,
	CASE lx.owner
		WHEN 'n/a' THEN lx.privilege
		ELSE lx.privilege||' on '||lx.owner||'.'||lx.table_name
	END
	,'-') "LINUX_PRIVILEGE"
from $vLinuxPrivilegeTable lx full outer join $vPrivilegeTable aix
	on aix.grantee=lx.grantee and aix.owner=lx.owner and aix.table_name=lx.table_name and aix.privilege=lx.privilege
where lx.grantee is null or aix.grantee is null
and lx.privilege not in ('SET CONTAINER','CREATE SESSION','SELECT ANY DICTIONARY')
and (lx.grantee, lx.privilege) not in
	(select b.grantee, b.privilege from ggtest.priv_count_linux b 
	 where b.grantee='AUTODDL_ADMIN' and b.privilege in ('ALTER ANY MATERIALIZED VIEW','GRANT ANY PRIVILEGE','DROP ANY MATERIALIZED VIEW'))
order by 1,2,3;

-- Role comparison
select NVL(aix.grantee,lx.grantee) "GRANTEE", aix.granted_role "AIX_ROLE", lx.granted_role "LINUX_ROLE"
from $vLinuxRolesTable lx full outer join $vRolesTable aix
	on aix.grantee=lx.grantee and aix.granted_role=lx.granted_role
where lx.grantee is null or aix.grantee is null
and lx.granted_role not in ('SECURITY_ADMIN_ROLE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE')
order by 1,2;

-- Quota comparison
select NVL(aix.username,lx.username) "USERNAME", NVL(aix.tablespace_name,lx.tablespace_name) "TABLESPACE", aix.quota "AIX_QUOTA", lx.quota "LINUX_QUOTA"
from $vLinuxQuotaTable lx full outer join $vQuotaTable aix
	on aix.username=lx.username and aix.tablespace_name=lx.tablespace_name
where aix.username not in (select role from dba_roles)
and (lx.quota!=aix.quota or lx.quota is null or aix.quota is null)
order by 1,2;
SPOOL OFF

-- Table count comparison
col "TABLE" format a40
col "AIX" format 999,999,990
col "LINUX" format 999,999,990
SPOOL $vTableComp
--select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.RECORD_COUNT "AIX", lx.RECORD_COUNT "LINUX", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFFERENCE"
--from $vLinuxRowTable lx full outer join $vRowTable aix
--  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
--where lx.RECORD_COUNT!=aix.RECORD_COUNT and lx.owner not in ('GGS','GGTEST')
--order by 1;
col MVIEW format a5
select diff.OWNER||'.'||diff.TABLE_NAME "TABLE", diff."AIX", diff."LINUX", diff."DIFFERENCE", NVL2(mv.mview_name,'YES',NULL) "MVIEW"
from dba_mviews mv right outer join
	(select NVL(lx.OWNER,aix.OWNER) "OWNER", NVL(lx.TABLE_NAME,aix.TABLE_NAME) "TABLE_NAME", aix.RECORD_COUNT "AIX", lx.RECORD_COUNT "LINUX", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFFERENCE"
	 from $vLinuxRowTable lx full outer join $vRowTable aix
		on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
	 where (lx.RECORD_COUNT!=aix.RECORD_COUNT OR lx.RECORD_COUNT IS NULL OR aix.RECORD_COUNT IS NULL)
		and lx.owner not in ('GGS','GGTEST')) diff
	on mv.owner=diff.owner and mv.mview_name=diff."TABLE_NAME"
order by 1;

-- Table status comparison
SPOOL $vTableStatus
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGS','GGTEST')
order by 1;

-- Object status comparison
col "OBJECT_NAME" format a40
SPOOL $vObjectStatus
select aix.OBJECT_TYPE, aix.OWNER||'.'||aix.OBJECT_NAME "OBJECT_NAME", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxObjectTable lx full outer join $vObjectTable aix
  on aix.OWNER=lx.OWNER and aix.OBJECT_NAME=lx.OBJECT_NAME and aix.OBJECT_TYPE=lx.OBJECT_TYPE
where lx.STATUS!=aix.STATUS and lx.STATUS!='VALID' OR lx.STATUS is null
--and lx.owner not in ('GGS','GGTEST')
order by aix.OBJECT_TYPE, aix.OWNER, aix.OBJECT_NAME;

exit;
EOF

# copy files to output log
cat $vTableComp >> $vOutputLog
cat $vTableStatus >> $vOutputLog
cat $vObjectStatus >> $vOutputLog

# compare table counts
vTableCompCt=$(wc -l $vTableComp | awk '{print $1}')
if [[ $vTableCompCt -ne 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: There are $vTableCompCt tables with row count differences. Correct this before continuing." | tee -a $vOutputLog
#	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The row counts for all the tables match." | tee -a $vOutputLog
fi

vTableStatusCt=$(wc -l $vTableStatus | awk '{print $1}')
if [[ $vTableStatusCt -ne 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: There are $vTableStatusCt tables with status differences. Correct this before continuing." | tee -a $vOutputLog
#	exit 1
else
	echo "" | tee -a $vOutputLog
	echo "The status for all the tables match." | tee -a $vOutputLog
fi
 
vObjectStatusCt=$(wc -l $vObjectStatus | awk '{print $1}')
if [[ $vObjectStatusCt -ne 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "WARNING: There are $vObjectStatusCt objects with status differences. Please check this afterwards." | tee -a $vOutputLog
else
	echo "" | tee -a $vOutputLog
	echo "The status for all the objects match." | tee -a $vOutputLog
fi

# check for SQL errors
error_check_fnc $vOutputLog $vErrorLog

# confirm data verification
echo ""
echo "Please resolve all above discrepancies before cutover"
continue_fnc
	

############################ Stop Replication ############################

# stop process
cd $GGATE
./ggsci >> $vOutputLog << EOF
stop replicat $vRepName
exit
EOF

while true
do
	# Check the GG status
	./ggsci > $vGGStatusOut << EOF
status replicat $vRepName
exit
EOF
	cat $vGGStatusOut | tee -a $vOutputLog
	vGGStatus=$(cat $vGGStatusOut | grep $vRepName | awk '{ print $6}')
	if [[ $vGGStatus = "STOPPED" ]]
	then
		echo "" | tee -a $vOutputLog
		echo "SUCCESS: The GG process $vRepName is now $vGGStatus."| tee -a $vOutputLog
		break
	#elif [[ $vGGStatus = "RUNNING" ]]
	#then
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
	#	echo "ERROR"  | tee -a $vOutputLog
	#	echo "The stop command did not take. Please try to stop it manually."  | tee -a $vOutputLog
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	#	exit 1
	else
		echo "Waiting 10 seconds..." | tee -a $vOutputLog
		sleep 10
	fi
done

############################ Summary ############################

# Report Timing of Script
vEndSec=$(date '+%s')
vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:       $vPDBName" | tee -a $vOutputLog
if [[ $vDBVersion -eq 12 ]]
then
	echo "Version:             12c" | tee -a $vOutputLog
else
	echo "Version:             11g" | tee -a $vOutputLog
fi
echo "GoldenGate Home:     $GGATE" | tee -a $vOutputLog
echo "GG Extract Status:   $vGGStatus" | tee -a $vOutputLog
echo "Count Differences:" | tee -a $vOutputLog
echo "   Table Rows:       $vTableCompCt" | tee -a $vOutputLog
echo "   Table Status:     $vTableStatusCt" | tee -a $vOutputLog
echo "   Object Status:    $vObjectStatusCt" | tee -a $vOutputLog
echo "Total Run Time:      $vTotalTime" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog

