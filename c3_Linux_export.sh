#!/usr/bin/ksh
#================================================================================================#
#  NAME
#    GG_1_AIX_start_extract.sh
#
#  DESCRIPTION
#    Collect current 10g/11g settings for building 12c shell database
#    Prepare AIX databaes for GoldenGate
#
#  PROMPTS
#    DB11G        -- AIX 10g/11g database name
#    NEWHOST      -- host name where Linux DB being created
#
#  STEPS
#   1. 	Prompt user for DB name and new host name
#   2. 	Check connection to new host
#   3. 	Set names of output logs
#   4. 	Set Oracle variables
#   5. 	Connect to DB via sqlplus
#   6. 	Create script to reset initialization parameters + requirements for GoldenGate
#   7. 	Output log of redo log size
#   8. 	Create script to recreate tablespaces
#   9. 	Create script to recreate temp space
#   10. Create script to recreate SYS-owned DB links and directories specific to database
#   11. Create GG tablespace
#   12. Create GGS user and grant required privileges
#
#  MODIFIED     (MM/DD/YY)
#  KDJ           02/13/17 - Created
#  KDJ           02/24/17 - Added GoldenGate prep
#================================================================================================#

NOWwSECs=$(date '+%Y%m%d%H%M%S')
vStartSec=$(date '+%s')

export ORACLE_HOME=/app/oracle/product/db/12c/1
export TNS_ADMIN=/app/oracle/tns_admin
export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$GGATE
export RUNDIR=/app/oracle/scripts/12cupgrade
vHostName=$(hostname)

# Database constants
vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','SQLTXPLAIN','SQLTXADMIN'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC'"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	export DPMOUNT=/oragg
else
	export DPMOUNT=/oragg
fi

# ACL script
vACLScript="${RUNDIR}/network_acls_ddl.sql"

# 12c comparison tables
vRowTable="row_count_12c"
vObjectTable="object_count_12c"
vIndexTable="index_count_12c"
vConstraintTable="constraint_count_12c"
vPrivilegeTable="priv_count_12c"
vRolesTable="role_count_12c"

# 11g comparison tables
vLinuxRowTable="row_count_11g"
vLinuxObjectTable="object_count_11g"
vLinuxIndexTable="index_count_11g"
vLinuxConstraintTable="constraint_count_11g"
vLinuxPrivilegeTable="priv_count_11g"
vLinuxRolesTable="role_count_11g"

# acceptable errors
set -A vErrIgnore "ERROR: EXTRACT" "ORA-01918" "ORA-32588" "ORA-00959" "ORA-04043" "ORA-06550" "PLS-00201" "PLS-00320" "ORA-00942"
# ORA-00959: tablespace 'XXXX' does not exist
# ORA-01918: user 'XXXX' does not exist
# ORA-04043: object XXXX does not exist
# ORA-32588: supplemental logging attribute primary key exists
# ORA-06550: line 2, column 20:
# PLS-00201: identifier 'DBA_NETWORK_ACLS.ACL' must be declared
# PLS-00320: the declaration of the type of this expression is incomplete or
# ORA-00942: table or view does not exist


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
	echo "Do you wish to continue? (Y) or (N) \c"
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
			echo "Please enter (Y) or (N).\c"  
		fi
	done
}

############################ Error Check Function ############################
# PURPOSE:                                                                   #
# This function checks the log for critical errors.                          #
##############################################################################

function error_check_fnc {
	# number of required parameters
	vParamCt=3
	# check that all parameters passed
	if [[ $# -lt $vParamCt ]]
	then
		# exit script if not enough parameters passed
		echo "ERROR: This function requires $vParamCt parameter(s)!" | tee -a $vOutputLog
		false
	fi

	# copy Oracle and bash errors from log file to error log
	awk '/^ORA-|^SP2-|^PLS-|^TNS-|^LRM-|^ERROR:/' $1 > $2

	# copy critical errors to critical log by ignoring acceptable errors
	eval $vGawkCmd
	# count number of errors
	vLineCt=$(wc -l $3 | awk '{print $1}')
	if [[ $vLineCt -gt 0 ]]
	then
		sleep 5
		echo " " | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo " " | tee -a $vOutputLog
		echo "There are $vLineCt critical errors." | tee -a $vOutputLog
		cat $3
		echo "Check $1 for the full details." | tee -a $vOutputLog
		#exit 1
		continue_fnc
	else
		echo " "
		echo "No errors to report." | tee -a $vOutputLog
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

# When this exits, exit all background process also.
trap 'vExitCode=$?; trap_fnc' EXIT

############################ Array variables ############################

echo ""
echo "*********************************"
echo "* Checking required files/dirs  *"
echo "*********************************"

# Set directory array
unset vDirArray
set -A vDirArray $RUNDIR ${RUNDIR}/logs $DPMOUNT

# Check if required directories exist
echo ""
echo "Checking that all required directories exist..."
for vCheckArray in ${vDirArray[@]}
do
	if [[ -d $vCheckArray ]]
	then
		echo "Directory $vCheckArray exists"
	else
		echo "ERROR: The directory $vCheckArray does not exist!"
		exit 1
	fi
done

# set file array
unset vFileArray
set -A vFileArray $vACLScript

# check for required files
echo ""
echo "Checking that all required files exist..."
for vCheckArray in ${vFileArray[@]}
do
	if [[ -e $vCheckArray ]]
	then
		echo "The file $vCheckArray exists"
	else
		echo "ERROR: The file $vCheckArray does not exist!"
		exit 1
	fi
done

############################ User Prompts ############################

echo ""
echo "*********************************"
echo "* Setting DB name               *"
echo "*********************************"

# List running databases
echo ""
/app/oracle/scripts/pmonn.pm

#if [[ $vTier = 't' ]]
#then
#	vPDBName=c3appst
#elif [[ $vTier = 'd' ]]
#then
#	vPDBName=c3appsd
#elif [[ $vTier = 's' ]]
#then
#	vPDBName=c3appsd
#else
#	echo "" | tee -a $vOutputLog
#	echo "ERROR: This script was only written to work on Sandbox, UT and SIT!" | tee -a $vOutputLog
#	exit 1
#fi
#export ORACLE_SID="c${vPDBName}"

# Prompt for the database name
echo ""
echo ""
echo "Enter the database you will export: \c"  
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
		echo "Enter a valid database name: \c"  
	fi
done
export ORACLE_SID="c${vPDBName}"
vCDBName=$ORACLE_SID

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

############################ Confirmation ############################

vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${RUNDIR}/logs/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
vErrorLog="${RUNDIR}/logs/${vBaseName}_${vPDBName}_err.log"
vCritLog="${RUNDIR}/logs/${vBaseName}_${vPDBName}_crit.log"
DMPDIR="${DPMOUNT}/datapump"
vDPParDir="${DMPDIR}/${vPDBName}"

if [ -f $vOutputLog ]
then
	rm $vOutputLog
fi
if [ -f $vErrorLog ]
then
	rm $vErrorLog
fi
if [ -f $vCritLog ]
then
	rm $vCritLog
fi

# Display user entries
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
echo "Database Name:      $vCDBName" | tee -a $vOutputLog
echo "PDB Name:           $vPDBName" | tee -a $vOutputLog
echo "Oracle Home:        $ORACLE_HOME" | tee -a $vOutputLog
echo "Data Pump Dir:      $vDPParDir" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog

# Confirmation
echo ""
echo "Are these values correct? (Y) or (N) \c"
while true
do
	read vConfirm
	if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
	then
		echo "Proceeding with the installation..." | tee -a $vOutputLog
		break
	elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	then
		exit 2
	else
		echo "Please enter (Y) or (N).\c"  
	fi
done

############################ Additional prep-work ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Setting directory names       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set umask
vOldUmask=`umask`
umask 0000

# Data Pump directories
echo ""
echo "Checking Data Pump directory ${vDPParDir}" | tee -a $vOutputLog
if [[ ! -d ${vDPParDir} ]]
then
	if [[ ! -d ${DMPDIR} ]]
	then
		mkdir ${DMPDIR}
		if [[ $? -ne 0 ]]
		then
			echo "" | tee -a $vOutputLog
			echo "There was a problem creating ${DMPDIR}" | tee -a $vOutputLog
			exit 1
		else
			chmod 774 ${DMPDIR}
			echo "Directory ${DMPDIR} has been created." | tee -a $vOutputLog
		fi
	fi
	mkdir ${vDPParDir}
	if [[ $? -ne 0 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "There was a problem creating ${vDPParDir}" | tee -a $vOutputLog
		exit 1
	else
		chmod 774 ${vDPParDir}
		echo "Directory ${vDPParDir} has been created." | tee -a $vOutputLog
	fi
fi
umask ${vOldUmask}

# set directories
echo "" | tee -a $vOutputLog
echo "Checking output directories" | tee -a $vOutputLog
vOutputDir="/database/${vCDBName}_admn01/scripts"
vNewDir="/tmp"

# test output directory
if [[ ! -d $vOutputDir ]]
then
	# if directory does not exist try old folder structure
	vOutputDir="/database/${vPDBName}01/scripts"
	if [[ ! -d $vOutputDir ]]
	then
		mkdir $vOutputDir
		if [[ $? -ne 0 ]]
		then
			# setting output directory to /tmp
			vOutputDir="/tmp"
		fi
	fi
fi
echo "" | tee -a $vOutputLog
echo "Output files will be written to $vOutputDir" | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Setting file names            *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set sql file names
SETPARAM="${vOutputDir}/setparam_${vPDBName}.sql"
vOrigParams="${vOutputDir}/originalparam_${vPDBName}.txt"
CREATETS="${vOutputDir}/createts_${vPDBName}.sql"
REDOLOGS="${vOutputDir}/redologs_${vPDBName}.out"
UNDOSIZE="${vOutputDir}/undosize_${vPDBName}.sql"
TEMPSIZE="${vOutputDir}/tempsize_${vPDBName}.sql"
TSGROUPS="${vOutputDir}/tsgroups_${vPDBName}.sql"
SYSOBJECTS="${vOutputDir}/sysobjects_${vPDBName}.sql"
vCreateUsers=${vOutputDir}/3_create_users_${vPDBName}.sql
vCreateCommonUsers=${vOutputDir}/create_common_users_${vPDBName}.sql
CREATEQUOTAS=${vOutputDir}/4_create_quotas_${vPDBName}.sql
CREATEGRANTS=${vOutputDir}/6_create_grants_${vPDBName}.sql
CREATESYSPRIVS=${vOutputDir}/7_create_sys_privs_tousers_${vPDBName}.sql
DISABLETRIGGERS=${vOutputDir}/8_disable_triggers_${vPDBName}.sql
ENABLETRIGGERS=${vOutputDir}/8_enable_triggers_${vPDBName}.sql
CREATESYNS=${vOutputDir}/10_create_synonyms_${vPDBName}.sql
CREATEROLES=${vOutputDir}/5_create_roles_metadata_${vPDBName}.sql
CREATELOGON=${vOutputDir}/12_create_logon_triggers_${vPDBName}.sql
REVOKESYSPRIVS=${vOutputDir}/revoke_sys_privs_${vPDBName}.sql
vCreateExtTables=${vOutputDir}/create_ext_tables_${vPDBName}.sql
vProxyPrivs=${vOutputDir}/grant_proxy_privs_${vPDBName}.sql
vCreateDBLinks=${vOutputDir}/create_db_links_${vPDBName}.log
vRefreshGroups=${vOutputDir}/create_refresh_groups_${vPDBName}.sql
vCreateACL=${vOutputDir}/create_acls_${vPDBName}.sql

# set names of data pump param files/directories
TARFILE=Linux_setup_${vPDBName}.tar
vDPDataPar="${vDPParDir}/expdp_${vPDBName}.par"
vDPMetaPar="${vDPParDir}/expdp_metadata_${vPDBName}.par"
vDPImpPar="${vOutputDir}/impdp_${vPDBName}.par"
vDPDataLog="${vPDBName}.log"
vDPMetaLog="${vPDBName}_metadata.log"
vDPDataDump="${vPDBName}_%U.dmp"
vDPDumpMeta="${vPDBName}_metadata_%U.dmp"

echo "" | tee -a $vOutputLog
echo "Removing existing logs" | tee -a $vOutputLog
for file in /tmp/${TARFILE} $SETPARAM $vOrigParams $CREATETS $REDOLOGS $UNDOSIZE $TEMPSIZE $TSGROUPS $SYSOBJECTS $vCreateUsers $vCreateCommonUsers $CREATEQUOTAS $CREATEGRANTS $CREATESYSPRIVS $REVOKESYSPRIVS $DISABLETRIGGERS $ENABLETRIGGERS $CREATESYNS $CREATEROLES $CREATELOGON $vCreateExtTables $vCreateDBLinks $vRefreshGroups $vProxyPrivs $vDPDataPar $vDPMetaPar $vDPImpPar $SCNFILE ${vDPParDir}/${vDPDataLog} ${vDPParDir}/${vDPMetaLog} $vCreateACL
do
	if [[ -e $file ]]
	then
		echo "Deleting $file" | tee -a $vOutputLog
		rm $file
	fi
done

# create command for copying critical errors
echo "" | tee -a $vOutputLog
echo "Setting ignorable errors" | tee -a $vOutputLog
vGawkCmd="awk '!/"
i=1
for vErrorCheck in ${vErrIgnore[@]}
do
	echo "Set to ignore error $vErrorCheck" | tee -a $vOutputLog
	if [[ i -eq 1 ]]
	then
		vGawkCmd="$vGawkCmd($vErrorCheck)"
	else
		vGawkCmd="$vGawkCmd|($vErrorCheck)"
	fi
	(( i += 1 ))
done
vGawkCmd="$vGawkCmd/' $vErrorLog > $vCritLog"

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
echo "COMPLETE" | tee -a $vOutputLog

############################ SQL Plus ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Create scripts for Linux side *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set environment variables
unset LIBPATH
export ORAENV_ASK=NO
export PATH=/usr/local/bin:$PATH
. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib

# Run scripts in database
$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<RUNSQL
SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR CONTINUE
col "STMT" format a2500

spool $vOutputLog append
-- drop data verification tables
drop table ggtest.${vRowTable};
drop table ggtest.${vObjectTable};
drop table ggtest.${vIndexTable};
drop table ggtest.${vConstraintTable};
drop table ggtest.${vPrivilegeTable};
drop table ggtest.${vRolesTable};
drop table ggtest.${vLinuxRowTable};
drop table ggtest.${vLinuxObjectTable};
drop table ggtest.${vLinuxIndexTable};
drop table ggtest.${vLinuxConstraintTable};
drop table ggtest.${vLinuxPrivilegeTable};
drop table ggtest.${vLinuxRolesTable};

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
PROMPT *** Create tables for row count verification ***
-- AIX
create table ggtest.${vRowTable} (
	db_name 		varchar2(30),
	host_name 		varchar2(30),
	owner 			varchar2(30),
	table_name 		varchar2(50),
	status 			varchar2(8),
	record_count	number(12),
   CONSTRAINT ${vRowTable}_pk PRIMARY KEY (owner, table_name) 
      using index (CREATE INDEX ggtest.${vRowTable}_pk_ix ON ggtest.${vRowTable} (owner, table_name))
);
-- Linux
create table ggtest.${vLinuxRowTable} (
	db_name 		varchar2(30),
	host_name 		varchar2(30),
	owner 			varchar2(30),
	table_name 		varchar2(50),
	status 			varchar2(8),
	record_count	number(12),
   CONSTRAINT ${vLinuxRowTable}_pk PRIMARY KEY (owner, table_name) 
      using index (CREATE INDEX ggtest.${vLinuxRowTable}_pk_ix ON ggtest.${vLinuxRowTable} (owner, table_name))
);

PROMPT *** Create table for object status verification ***
-- AIX
create table ggtest.${vObjectTable} as
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null
and (owner, object_name, object_type) not in
(select owner, object_name, object_type from DBA_OBJECTS where owner='PUBLIC' and object_type='SYNONYM');
ALTER TABLE ggtest.${vObjectTable}
ADD CONSTRAINT ${vObjectTable}_pk
PRIMARY KEY (owner, object_name, object_type)
using index (CREATE INDEX ggtest.${vObjectTable}_pk_ix ON ggtest.${vObjectTable} (owner, object_name, object_type));
-- Linux
create table ggtest.${vLinuxObjectTable} as
select * from ggtest.${vObjectTable} where 1=0;
ALTER TABLE ggtest.${vLinuxObjectTable}
ADD CONSTRAINT ${vLinuxObjectTable}_pk
PRIMARY KEY (owner, object_name, object_type)
using index (CREATE INDEX ggtest.${vLinuxObjectTable}_pk_ix ON ggtest.${vLinuxObjectTable} (owner, object_name, object_type));

PROMPT *** Create table for privilege comparison ***
-- AIX
create table ggtest.${vPrivilegeTable} as
select grantee, owner, table_name, privilege
from dba_tab_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and owner not in ($vExcludeUsers)
and (OWNER,TABLE_NAME) not in (SELECT owner, object_name FROM dba_recyclebin)
UNION
select grantee, 'n/a', 'n/a', privilege
from dba_sys_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and privilege!='UNLIMITED TABLESPACE';
ALTER TABLE ggtest.${vPrivilegeTable}
ADD CONSTRAINT ${vPrivilegeTable}_pk
PRIMARY KEY (grantee, owner, table_name, privilege)
using index (CREATE INDEX ggtest.${vPrivilegeTable}_pk_ix ON ggtest.${vPrivilegeTable} (grantee, owner, table_name, privilege));
-- Linux
create table ggtest.${vLinuxPrivilegeTable} as
select * from ggtest.${vPrivilegeTable} where 1=0;
ALTER TABLE ggtest.${vLinuxPrivilegeTable}
ADD CONSTRAINT ${vLinuxPrivilegeTable}_pk
PRIMARY KEY (grantee, owner, table_name, privilege)
using index (CREATE INDEX ggtest.${vLinuxPrivilegeTable}_pk_ix ON ggtest.${vLinuxPrivilegeTable} (grantee, owner, table_name, privilege));

PROMPT *** Create table for role comparison ***
-- AIX
create table ggtest.${vRolesTable} as
select distinct granted_role, grantee, admin_option, default_role
from dba_role_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles);
ALTER TABLE ggtest.${vRolesTable}
ADD CONSTRAINT ${vRolesTable}_pk
PRIMARY KEY (granted_role, grantee)
using index (CREATE INDEX ggtest.${vRolesTable}_pk_ix ON ggtest.${vRolesTable} (granted_role, grantee));
-- Linux
create table ggtest.${vLinuxRolesTable} as
select * from ggtest.${vRolesTable} where 1=0;
ALTER TABLE ggtest.${vLinuxRolesTable}
ADD CONSTRAINT ${vLinuxRolesTable}_pk
PRIMARY KEY (granted_role, grantee)
using index (CREATE INDEX ggtest.${vLinuxRolesTable}_pk_ix ON ggtest.${vLinuxRolesTable} (granted_role, grantee));

PROMPT *** Create tables for index comparison ***
-- AIX
create table ggtest.${vIndexTable} as
select OWNER, INDEX_NAME, INDEX_TYPE, TABLE_OWNER, TABLE_NAME, STATUS
from DBA_INDEXES where 1=0;
ALTER TABLE ggtest.${vIndexTable}
ADD CONSTRAINT ${vIndexTable}_pk
PRIMARY KEY (OWNER, INDEX_NAME)
using index (CREATE INDEX ggtest.${vIndexTable}_pk_ix ON ggtest.${vIndexTable} (OWNER, INDEX_NAME));
-- Linux
create table ggtest.${vLinuxIndexTable} as
select * from ggtest.${vIndexTable} where 1=0;
ALTER TABLE ggtest.${vLinuxIndexTable}
ADD CONSTRAINT ${vLinuxIndexTable}_pk
PRIMARY KEY (OWNER, INDEX_NAME)
using index (CREATE INDEX ggtest.${vLinuxIndexTable}_pk_ix ON ggtest.${vLinuxIndexTable} (OWNER, INDEX_NAME));

PROMPT *** Create table for constraint comparison ***
-- AIX
create table ggtest.${vConstraintTable} as
select owner, table_name, constraint_name, constraint_type, status
from dba_constraints
where owner not in ($vExcludeUsers);
ALTER TABLE ggtest.${vConstraintTable}
ADD CONSTRAINT ${vConstraintTable}_pk
PRIMARY KEY (owner, table_name, constraint_name)
using index (CREATE INDEX ggtest.${vConstraintTable}_pk_ix ON ggtest.${vConstraintTable} (owner, table_name, constraint_name));
-- Linux
create table ggtest.${vLinuxConstraintTable} as
select * from ggtest.${vConstraintTable} where 1=0;
ALTER TABLE ggtest.${vLinuxConstraintTable}
ADD CONSTRAINT ${vLinuxConstraintTable}_pk
PRIMARY KEY (owner, table_name, constraint_name)
using index (CREATE INDEX ggtest.${vLinuxConstraintTable}_pk_ix ON ggtest.${vLinuxConstraintTable} (owner, table_name, constraint_name));

PROMPT *** Populate table for index comparison ***
-- AIX
insert into ggtest.${vIndexTable}
select OWNER, INDEX_NAME, INDEX_TYPE, TABLE_OWNER, TABLE_NAME, STATUS
from DBA_INDEXES
where owner not in ($vExcludeUsers);

PROMPT *** Loading tables counts (this may take a while) ***
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
    insert into ggtest.${vRowTable}
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
	commit;
  end loop;
  close cf;
end;
/

select 'There are '||count(*)||' tables.' from ggtest.${vRowTable};
select 'There are '||count(*)||' objects.' from ggtest.${vObjectTable};
select 'There are '||count(*)||' indexes.' from ggtest.${vIndexTable};
select 'There are '||count(*)||' constraints.' from ggtest.${vConstraintTable};
select 'There are '||count(*)||' privileges.' from ggtest.${vPrivilegeTable};

PROMPT *** Creating scripts for Linux side ***
spool off

SET FEEDBACK OFF
PROMPT +++++++++++++++++ INITIALIZATION PARAMETERS +++++++++++++++++
SPOOL $SETPARAM
-- unset mem parameters
select 'ALTER SYSTEM RESET ' || name || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
--where name in ('sga_max_size','sga_target','pga_aggregate_target','memory_max_target','memory_target')
where name in ('memory_max_target','memory_target')
	and value is NULL
order by 1;

-- set memory to highest value
select case
	when sap.SAP > 1572864000 then
		case when sap.SAP > to_number(pm.value) then 'ALTER SYSTEM SET ' || pm.name || '=' || sap.SAP || ' SCOPE=SPFILE;'
			else 'ALTER SYSTEM SET ' || pm.name || '=' || pm.value || ' SCOPE=SPFILE;'
		end
	when to_number(pm.value) > 1572864000 then 'ALTER SYSTEM SET ' || pm.name || '=' || pm.value || ' SCOPE=SPFILE;'
	else '-- new memory settings higher than current ones'
	end "STMT"
from v\$spparameter pm, (select sum(to_number(value)) "SAP" from v\$spparameter where name in ('sga_max_size','pga_aggregate_target')) sap
where pm.name in ('memory_max_target','memory_target') and pm.value is not NULL
order by 1;

-- increase SGA if set higher than 1200M
-- set SGA to accomodate bigger streams pool
select case
	when to_number(value) > 1423966208 then 'ALTER SYSTEM SET ' || name || '=' || value || ' SCOPE=SPFILE;'
	else 'ALTER SYSTEM SET ' || name || '=1423966208 SCOPE=SPFILE;'
end "STMT"
from v\$spparameter
where name in ('sga_max_size','sga_target')
order by 1;

-- increase PGA if set highter than 300M
select 'ALTER SYSTEM SET ' || name || '=' || value || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where name='pga_aggregate_target' and to_number(value) > 314572800
order by 1;

-- set string parameters using single quotes
select 'ALTER SYSTEM SET ' || name || '=''' || display_value || ''' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name in 
('nls_date_format','db_securefile','parallel_min_time_threshold','query_rewrite_enabled','query_rewrite_integrity','star_transformation_enabled','workarea_size_policy','utl_file_dir');

-- set non-string parameters
select 'ALTER SYSTEM SET ' || name || '=' || display_value || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name in ('optimizer_secure_view_merging','open_cursors','optimizer_dynamic_sampling','processes','sessions');

-- set data file max
select 'ALTER SYSTEM SET ' || name || '=' || value || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name='db_files';

-- set parameters above template values
select 'ALTER SYSTEM SET ' || name || '=' || value || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name='parallel_max_servers' and to_number(value)>8;
SPOOL OFF

-- get original values
SPOOL $vOrigParams
select case
	when type='string' then 'ALTER SYSTEM SET ' || name || '=''' || value || ''' SCOPE=SPFILE;'
	else 'ALTER SYSTEM SET ' || name || '=' || value || ' SCOPE=SPFILE;'
	end "STMT"
from v\$spparameter
where isspecified='TRUE'
order by name;
SPOOL OFF

PROMPT +++++++++++++++++ REDO LOG SIZES +++++++++++++++++
SPOOL $REDOLOGS
select 
	case
		when bytes >= 536870912 then to_char(bytes/1024/1024) || 'M'
		else '512M'
	end "MB"
from v\$log
where rownum=1;
SPOOL OFF

PROMPT +++++++++++++++++ TABLESPACES AND DATAFILES +++++++++++++++++
-- any TSs have different block sizes than DB
-- create tablespace with initial data file
SPOOL $CREATETS
select 'CREATE TABLESPACE '||tbs.TABLESPACE_NAME||' DATAFILE '''||
	case
	when dbf.FILE_NAME like '/database/${vPDBName}%' then replace(dbf.FILE_NAME,'/database/','/database/')
	else '/database/${vPDBName}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||''
	end ||
	''' SIZE '||to_char(dbf.BYTES)||
	case
	when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
	else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
	end ||
	'EXTENT MANAGEMENT '
	||tbs.EXTENT_MANAGEMENT|| ' UNIFORM SIZE 1048576 SEGMENT SPACE MANAGEMENT '||tbs.SEGMENT_SPACE_MANAGEMENT||';' "STMT"
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf,
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_DATA_FILES
	group by TABLESPACE_NAME) mf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and mf.MIN_FILE=dbf.FILE_ID
and tbs.TABLESPACE_NAME not in ('SYSTEM','SYSAUX','USERS','UNDO','TOOLS','LOGON_AUDIT_DATA')
order by tbs.TABLESPACE_NAME;

-- add other data files
select case
	when dbf.FILE_NAME like '/database/${vPDBName}%' then 'ALTER TABLESPACE '||tbs.TABLESPACE_NAME||' ADD DATAFILE '''||replace(dbf.FILE_NAME,'/database/','/database/')||''' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	else 'ALTER TABLESPACE '||tbs.TABLESPACE_NAME||' ADD DATAFILE ''/database/${vPDBName}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||'x'' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	end ||';' "STMT"
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and (dbf.FILE_ID, tbs.TABLESPACE_NAME) not in
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_DATA_FILES
	group by TABLESPACE_NAME)
and tbs.TABLESPACE_NAME not in ('SYSTEM','SYSAUX','USERS','UNDO','TOOLS')
order by 1;
SPOOL OFF

PROMPT +++++++++++++++++ TEMP FILE SIZE +++++++++++++++++
SPOOL $TEMPSIZE
-- alter existing TEMP tablespace
select case substr(dtf.FILE_NAME,-6,2)
	when '01' then 'ALTER DATABASE TEMPFILE ''/database/${vPDBName}01/oradata'||substr(dtf.FILE_NAME,instr(dtf.FILE_NAME,'/',-1))||''' RESIZE '||dtf.BYTES||';'
	else 'ALTER TABLESPACE TEMP ADD TEMPFILE '''||replace(dtf.FILE_NAME,'/database/','/database/')||''' SIZE '||dtf.BYTES||';'
	end "STMT"
--select FILE_NAME, substr(FILE_NAME,instr(FILE_NAME,'/',-1)+1) "FILE"
from DBA_TEMP_FILES dtf, V\$DATABASE vdb
where dtf.TABLESPACE_NAME='TEMP';

-- create additional temp tablespaces
select 'CREATE TEMPORARY TABLESPACE '||tbs.TABLESPACE_NAME||' TEMPFILE '''||replace(dbf.FILE_NAME,'/database/','/database/')||
	case AUTOEXTENSIBLE
	when 'ON' then ''' SIZE '||BYTES||' AUTOEXTEND ON NEXT '||INCREMENT_BY||' MAXSIZE '||MAXBYTES||';'
		else ''' SIZE '||BYTES||';'
	end "STMT"
from DBA_TABLESPACES tbs, DBA_TEMP_FILES dbf,
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_TEMP_FILES
	group by TABLESPACE_NAME) mf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and mf.MIN_FILE=dbf.FILE_ID
and tbs.TABLESPACE_NAME!='TEMP'
order by 1;

select 'ALTER TABLESPACE '||tbs.TABLESPACE_NAME||' ADD TEMPFILE '''||replace(dbf.FILE_NAME,'/database/','/database/')||''' SIZE '||BYTES||';' "STMT"
from DBA_TABLESPACES tbs, DBA_TEMP_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and (dbf.FILE_ID, tbs.TABLESPACE_NAME) not in
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_TEMP_FILES
	group by TABLESPACE_NAME)
and tbs.TABLESPACE_NAME!='TEMP'
order by 1;
SPOOL OFF

PROMPT +++++++++++++++++ TABLESPACE GROUPS +++++++++++++++++
SPOOL $TSGROUPS
select 'ALTER TABLESPACE '||dts.TABLESPACE_NAME||' TABLESPACE GROUP '||tsg.GROUP_NAME||';'
from DBA_TABLESPACES dts, DBA_TABLESPACE_GROUPS tsg
where dts.TABLESPACE_NAME=tsg.TABLESPACE_NAME 
order by 1;
SPOOL OFF

PROMPT +++++++++++++++++ SYSTEM-OWNED OBJECTS +++++++++++++++++
SPOOL $SYSOBJECTS
-- directories
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || 
	replace(replace(DIRECTORY_PATH,'/nomove/app','/app'),'11g/6','12c/1') || ''';' "STMT"
from dba_directories
where OWNER in ('SYS','SYSTEM') and DIRECTORY_PATH like '/nomove/app%';

select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/nonDR/','/') || ''';' "STMT"
from dba_directories
where OWNER in ('SYS','SYSTEM') and DIRECTORY_PATH like '/ora_backup/nonDR/%';

select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/DR/','/') || ''';' "STMT"
from dba_directories
where OWNER in ('SYS','SYSTEM') and DIRECTORY_PATH like '/ora_backup/DR/%';

select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || DIRECTORY_PATH || ''';' "STMT"
from dba_directories
where OWNER in ('SYS','SYSTEM')
and DIRECTORY_NAME not in ('MY_DIR','CNO_MIGRATE')
and DIRECTORY_PATH not like '/nomove/app%'
and DIRECTORY_PATH not like '/ora_backup/nonDR/%'
and DIRECTORY_PATH not like '/ora_backup/DR/%'
and DIRECTORY_PATH not like '/backup_ux%'
and DIRECTORY_PATH not like '/backup/%';

-- application directories for file shares
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/bpat01/scripts','/nfs/bpat/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/bpat01/scripts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/idwd01/','/actlgroomer/') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/idwd01/%' and DIRECTORY_PATH not like '%admin%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/idwt01/','/actlgroomer/') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/idwt01/%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/lbilld01/data','/nfs/lbillt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/lbilld01/data%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/blcnavt01/scripts','/nfs/blcnavt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/blcnavt01/scripts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/home/cpa7yd/Extracts','/nfs/bparptt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/home/cpa7yd/Extracts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/database/awdt01/scripts','/nfs/awdt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/database/awdt01/scripts%';
SPOOL OFF

PROMPT +++++++++++++++++ TABLESPACE QUOTAS +++++++++++++++++
spool $CREATEQUOTAS
SELECT 'alter user "'|| dtb.owner || '" quota UNLIMITED on ' || dtb.tablespace_name || ';' "STMT"
FROM dba_tables dtb, dba_tablespaces dts
WHERE dtb.tablespace_name=dts.tablespace_name and dtb.tablespace_name is not null and dtb.owner NOT IN ($vExcludeUsers)
	UNION
SELECT 'alter user "'|| din.owner || '" quota UNLIMITED on ' || din.tablespace_name || ';'
FROM dba_indexes din, dba_tablespaces dts
WHERE din.tablespace_name=dts.tablespace_name and din.tablespace_name is not null and din.owner NOT IN ($vExcludeUsers)
	UNION
select 'alter user '|| dtq.username ||
	case
		when dtq.max_bytes = -1 then ' quota UNLIMITED'
		else ' quota '||to_char(dtq.max_bytes)
	end ||
  ' on ' || dtq.tablespace_name || ';'
from dba_ts_quotas dtq, dba_tablespaces dts
WHERE dtq.tablespace_name=dts.tablespace_name and dtq.tablespace_name is not null and dtq.username NOT IN ($vExcludeUsers);
spool off;

PROMPT +++++++++++++++++ ROLES +++++++++++++++++
spool $CREATEROLES
SELECT dbms_metadata.get_ddl('ROLE',ROLE)||';' "STMT" FROM DBA_ROLES 
WHERE role not in ($vExcludeRoles)
ORDER BY role;
spool off;

PROMPT +++++++++++++++++ SYSTEM PRIVILEGES +++++++++++++++++
-- grant system privs
spool $CREATESYSPRIVS
SELECT 'grant '|| privilege ||' to "'|| grantee || '" ' ||
  (CASE
    WHEN admin_option = 'YES'
    THEN 'WITH admin OPTION'
    ELSE NULL
  END)
  || ';' "STMT"
FROM dba_sys_privs
WHERE GRANTEE NOT IN($vExcludeUsers)
AND grantee NOT IN ($vExcludeRoles)
UNION ALL
SELECT 'grant '|| granted_role || ' to "'|| grantee || '" '||
  (CASE
    WHEN admin_option = 'YES'
    THEN 'WITH ADMIN OPTION'
    ELSE NULL
  END)
  || ';' 
FROM dba_role_privs
WHERE GRANTEE NOT IN ($vExcludeUsers)
AND GRANTEE NOT IN ($vExcludeRoles);
spool off;

PROMPT +++++++++++++++++ OBJECT PRIVILEGES +++++++++++++++++
COLUMN row_order FORMAT 999 NOPRINT 
spool $CREATEGRANTS
SELECT 'GRANT '||PRIVILEGE||' on "'||OWNER||'".'||TABLE_NAME
  ||' to "'||grantee||'"'||DECODE(grantable,'YES',' with grant option','')
  || '     /* grantor '||grantor||'*/'||';' "STMT"
FROM
  (SELECT GRANTEE,
    OWNER,
    TABLE_NAME,
    PRIVILEGE,
    GRANTABLE,
    GRANTOR
  FROM dba_tab_privs
  WHERE grantee <>'PUBLIC'
  )
WHERE owner        IN ('SYSTEM','SYS')
AND grantee NOT    IN ($vExcludeUsers)
AND grantee NOT    IN ($vExcludeRoles)
AND table_name NOT IN
  (SELECT directory_name FROM dba_directories
  )
AND grantor NOT IN ('QUEST','SPOTLIGHT','SPOTLIGHT1')
AND (grantee NOT LIKE ('QUEST%')
OR grantee LIKE ('QUESTION%'))
ORDER BY grantee ;

-- grant index
select distinct 'GRANT INDEX ON "'||ind.table_owner||'".'||ind.table_name||' TO "'||ind.owner||'";' "STMT"
from dba_indexes ind 
where ind.owner!=ind.table_owner and not exists
	(select NVL(rp.grantee, tp.grantee)
	 from dba_tab_privs tp left outer join dba_role_privs rp on tp.grantee=rp.granted_role 
	 where (rp.grantee=ind.owner or tp.grantee=ind.owner) and tp.privilege='INDEX')
and ind.owner not in ($vExcludeUsers);

-- grant privileges for materialized views
select distinct 'GRANT CREATE '||obj.object_type||' TO "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='MATERIALIZED VIEW' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE MATERIALIZED VIEW')
and obj.owner not in ($vExcludeUsers);

-- grant privileges for procedures
select distinct 'GRANT CREATE PROCEDURE TO "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type in ('PACKAGE','PACKAGE BODY','PROCEDURE') and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE PROCEDURE')
and obj.owner not in ($vExcludeUsers);

-- grant privileges for sequences
select distinct 'GRANT CREATE '||obj.object_type||' TO "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='SEQUENCE' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE SEQUENCE')
and obj.owner not in ($vExcludeUsers);

-- grant privileges for tables
select distinct 'GRANT CREATE '||obj.object_type||' TO "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='TABLE' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE TABLE')
and obj.owner not in ($vExcludeUsers);

-- grant privileges for views
select distinct 'GRANT CREATE '||obj.object_type||' TO "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='VIEW' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE VIEW')
and obj.owner not in ($vExcludeUsers);
spool off

PROMPT +++++++++++++++++ REVOKE SYSTEM PRIVILEGES +++++++++++++++++
-- revoke privileges for indexes
spool $REVOKESYSPRIVS
select distinct 'REVOKE INDEX ON "'||ind.table_owner||'".'||ind.table_name||' FROM "'||ind.owner||'";' "STMT"
from dba_indexes ind 
where ind.owner!=ind.table_owner and not exists
	(select NVL(rp.grantee, tp.grantee)
	 from dba_tab_privs tp left outer join dba_role_privs rp on tp.grantee=rp.granted_role 
	 where (rp.grantee=ind.owner or tp.grantee=ind.owner) and tp.privilege='INDEX')
and ind.owner not in ($vExcludeUsers);

-- revoke privileges for materialized views
select distinct 'REVOKE CREATE '||obj.object_type||' FROM "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='MATERIALIZED VIEW' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE MATERIALIZED VIEW')
and obj.owner not in ($vExcludeUsers);

-- revoke privileges for procedures
select distinct 'REVOKE CREATE PROCEDURE FROM "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type in ('PACKAGE','PACKAGE BODY','PROCEDURE') and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE PROCEDURE')
and obj.owner not in ($vExcludeUsers);

-- revoke privileges for sequences
select distinct 'REVOKE CREATE '||obj.object_type||' FROM "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='SEQUENCE' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE SEQUENCE')
and obj.owner not in ($vExcludeUsers);

-- revoke privileges for tables
select distinct 'REVOKE CREATE '||obj.object_type||' FROM "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='TABLE' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE TABLE')
and obj.owner not in ($vExcludeUsers);

-- revoke privileges for views
select distinct 'REVOKE CREATE '||obj.object_type||' FROM "'||obj.owner||'";' "STMT"
from dba_objects obj 
where obj.object_type='VIEW' and not exists
  (select NVL(rp.grantee, sp.grantee)
   from dba_sys_privs sp full outer join dba_role_privs rp on sp.grantee=rp.granted_role 
   where (rp.grantee=obj.owner or sp.grantee=obj.owner) and sp.privilege='CREATE VIEW')
and obj.owner not in ($vExcludeUsers);
spool off

PROMPT +++++++++++++++++ PROXY GRANTS +++++++++++++++++
-- grant proxy privs
spool $vProxyPrivs
select 'ALTER USER '||client||' GRANT CONNECT THROUGH '||proxy||
	case FLAGS
		when 'PROXY MAY ACTIVATE ALL CLIENT ROLES' then ' '
		when 'NO CLIENT ROLES MAY BE ACTIVATED' then ' WITH NO ROLES'
		else ' !!! this one is complicated !!!'
	end ||
	case AUTHENTICATION
		when 'NO' then ';'
		else ' AUTHENTICATION REQUIRED;'
	end "STMT"
FROM proxy_users order by 1;
spool off

PROMPT +++++++++++++++++ DISABLE TRIGGERS +++++++++++++++++
spool $DISABLETRIGGERS
select 'ALTER TRIGGER "'||owner||'".'||trigger_name||' DISABLE'||';' "STMT" from dba_triggers
where owner NOT IN ($vExcludeUsers);
spool off;

PROMPT +++++++++++++++++ ENABLE TRIGGERS +++++++++++++++++
spool $ENABLETRIGGERS
select 'ALTER TRIGGER "'||owner||'".'||trigger_name||' ENABLE'||';' "STMT" from dba_triggers
where owner NOT IN ($vExcludeUsers);
spool off;

PROMPT +++++++++++++++++ SYNONYMS +++++++++++++++++
spool $CREATESYNS
select 'CREATE OR REPLACE SYNONYM "'||owner||'"."'||synonym_name||'" FOR "'||table_owner||'"."'||table_name||'";' "STMT"
from dba_synonyms
where ORIGIN_CON_ID!=1 and (table_owner NOT IN ($vExcludeUsers) or db_link is not null);
spool off;

PROMPT +++++++++++++++++ LOGON TRIGGERS +++++++++++++++++
spool $CREATELOGON
--select DBMS_METADATA.GET_DDL('TABLE','LOGON_AUDIT_LOG','SYS')||';' "STMT" from dual;
SELECT DBMS_METADATA.GET_DDL('TRIGGER',trigger_name,owner )||';' "STMT" FROM dba_triggers where triggering_event='LOGON ';
spool off;

PROMPT +++++++++++++++++ EXTERNAL TABLES +++++++++++++++++
set long 10000000
col "STMT" format a2500
spool $vCreateExtTables
select DBMS_METADATA.GET_DDL('TABLE',TABLE_NAME,OWNER)||';' "STMT"
from dba_external_tables
where owner NOT IN ($vExcludeUsers);
spool off

PROMPT +++++++++++++++++ DATABASE LINKS +++++++++++++++++
spool $vCreateDBLinks
--select case
--	when OWNER='PUBLIC' then 'DROP PUBLIC DATABASE LINK '
--	else 'DROP DATABASE LINK '||OWNER||'.'
--	end
--	||DB_LINK||';' "STMT"
--from dba_db_links;
select DBMS_METADATA.GET_DDL('DB_LINK',DB_LINK,OWNER)||';' "STMT" 
from dba_db_links
where db_link not in ('ORA_DSGP_DBL','ORA_DSGD_DBL');
spool off

PROMPT +++++++++++++++++ REFRESH GROUPS +++++++++++++++++
spool $vRefreshGroups
select DBMS_METADATA.GET_DDL('REFRESH_GROUP',RNAME,ROWNER)||chr(10)||'/' "STMT"
from DBA_REFRESH;
spool off

SPOOL $vOutputLog APPEND
-- Create DP directory
create or replace DIRECTORY CNO_MIGRATE as '$vDPParDir';
spool off

PROMPT *** Create data pump parameter file ***
SET ESCAPE OFF
SPOOL $vDPDataPar
DECLARE
  CURSOR c1 IS
    select case
		when username!=upper(username) then '\\"'||username||'\\"'
		else username
		end "STMT"
	from dba_users where username not in ($vExcludeUsers);
  vOwner	VARCHAR2(30);
  x			PLS_INTEGER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('DIRECTORY=CNO_MIGRATE');
  DBMS_OUTPUT.PUT_LINE('DUMPFILE=${vDPDataDump}');
  DBMS_OUTPUT.PUT_LINE('LOGFILE=${vDPDataLog}');
  DBMS_OUTPUT.PUT_LINE('PARALLEL=8');
  DBMS_OUTPUT.PUT_LINE('METRICS=Y');
  DBMS_OUTPUT.PUT_LINE('EXCLUDE=STATISTICS');
  DBMS_OUTPUT.PUT_LINE('VERSION=11.2.0.4');
  DBMS_OUTPUT.PUT('SCHEMAS=');
  
  x := 1;
  OPEN c1;
  LOOP
    FETCH c1 INTO vOwner;
	EXIT WHEN c1%NOTFOUND;
	  IF x = 1 THEN
        DBMS_OUTPUT.PUT(vOwner);
      ELSE
        DBMS_OUTPUT.PUT(','||vOwner);
      END IF;
	  x := x + 1;
  END LOOP;
  DBMS_OUTPUT.NEW_LINE;
  CLOSE c1;
END;
/
SPOOL OFF

PROMPT *** Create Data Pump metadata param file ***
SPOOL $vDPMetaPar
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDumpMeta}' from dual;
select 'LOGFILE=${vDPMetaLog}' from dual;
select 'CONTENT=METADATA_ONLY' from dual;
select 'VERSION=11.2.0.4' from dual;
select 'METRICS=Y' from dual;
select 'FULL=Y' from dual;
SPOOL OFF

exit;
RUNSQL

# check logs for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
for file in $SETPARAM $vOrigParams $REDOLOGS $CREATETS $TEMPSIZE $TSGROUPS $SYSOBJECTS $CREATEQUOTAS $CREATEROLES $CREATEGRANTS $CREATESYSPRIVS $REVOKESYSPRIVS $vProxyPrivs $DISABLETRIGGERS $ENABLETRIGGERS $CREATESYNS $CREATELOGON $vCreateExtTables $vDPDataPar $vDPMetaPar
do
	if [[ -e $file ]]
	then
		error_check_fnc $file $vErrorLog $vCritLog
	else
		echo "ERROR: $file could not be found" | tee -a $vOutputLog
		exit 1
	fi
done

# create version-specific files
# 11g databases
#$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<RUNSQL
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<RUNSQL
SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
col "STMT" format a2500

PROMPT +++++++++++++++++++++++ CREATE COMMON USERS +++++++++++++++++++++++
-- create common users
spool $vCreateUsers
-- create users (no changes needed for passwords or external users)
select dbms_metadata.get_ddl('USER', u.username)||';' "STMT"
from dba_users u
where u.common='YES' and u.username NOT IN  ($vExcludeUsers);
spool off;

PROMPT +++++++++++++++++ UNDO FILE SIZE +++++++++++++++++
SPOOL $UNDOSIZE
select case
	when SHORT_NAME='undo01.dbf' then
		case
			when BYTES > 209715200 then 'ALTER DATABASE DATAFILE '''||replace(FILE_NAME,'/database/${vCDBName}01','/database/${vPDBName}01')||''' RESIZE '||BYTES||';'
			else '-- undo01.dbf is less than 200 MB'
		end
	else 'ALTER TABLESPACE '||TABLESPACE_NAME||' ADD DATAFILE '''||replace(FILE_NAME,'/database/${vCDBName}01','/database/${vPDBName}01')||''' SIZE '||BYTES||';'
end "STMT"
from
	(select dbf.FILE_NAME, substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1)+1) "SHORT_NAME",
	 tbs.TABLESPACE_NAME, dbf.BYTES
	 from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
	 where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME
	 and tbs.TABLESPACE_NAME='UNDO')
order by 1;
SPOOL OFF

-- PDB activities
alter session set container=${vPDBName};

PROMPT +++++++++++++++++++++++ CREATE USERS +++++++++++++++++++++++
-- create non-common users
spool $vCreateUsers append
select dbms_metadata.get_ddl('USER', u.username)||';' "STMT"
from dba_users u
where u.common='NO' and u.username NOT IN  ($vExcludeUsers);
spool off;

PROMPT Create data pump import parameter file ***
SPOOL $vDPImpPar
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDataDump}' from dual;
select 'LOGFILE=impdp_${vPDBName}.log' from dual;
select 'table_exists_action=replace' from dual;
select 'PARALLEL=8' from dual;
select 'CLUSTER=Y' from dual;
select 'METRICS=Y' from dual;
SPOOL OFF

exit;
RUNSQL

# check logs for errors
for file in $vDPImpPar $vCreateUsers $UNDOSIZE
do
	if [[ -e $file ]]
	then
		error_check_fnc $file $vErrorLog $vCritLog
	else
		echo "ERROR: $file could not be found" | tee -a $vOutputLog
		exit 1
	fi
done

# create script for ACL, not set up on all DBs
ACL_COUNT=`sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<EOF
col acl_count format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from dba_views where view_name='DBA_NETWORK_ACLS';
exit;
EOF`
echo "ACL_COUNT is $ACL_COUNT"

# if ACL set up, run script to recreate
if [[ $ACL_COUNT -gt 0 ]]
then
	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<RUNSQL
SET ECHO OFF
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
PROMPT +++++++++++++++++ ACCESS CONTROL LISTS (ACL) +++++++++++++++++
SPOOL $vCreateACL
@${vACLScript}
SPOOL OFF
exit;
RUNSQL

else
	echo "-- no ACL set up" > $vCreateACL
fi

# check for errors
error_check_fnc $vCreateACL $vErrorLog $vCritLog

echo "COMPLETE" | tee -a $vOutputLog

############################ Get SCN and export data ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Export data                   *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "Starting Data Pump export process" | tee -a $vOutputLog

# get current scn
CURRENT_SCN=$( sqlplus -S "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" <<EOF
col current_scn format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select LTRIM(TO_CHAR(current_scn)) current_scn from v\$database;
exit;
EOF
)

# remove existing export files
if [ -f ${vDPParDir}/${vPDBName}*.dmp ]
then
	rm ${vDPParDir}/${vPDBName}*.dmp
fi
if [ -f ${vDPParDir}/${vPDBName}*.log ]
then
	rm ${vDPParDir}/${vPDBName}*.log
fi

# set connection string
vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"

# export data
expdp \"$vConnect\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataPar
cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLog} $vErrorLog $vCritLog

# export metadata
expdp \"$vConnect\" parfile=$vDPMetaPar
cat ${vDPParDir}/${vDPMetaLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPMetaLog} $vErrorLog $vCritLog

# get timing before copying scripts
vEndSec=$(date '+%s')

############################ Copy Scripts ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Copy scripts to new host      *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# add all files to archive
cd $vOutputDir
if [[ -e $$TARFILE ]]
then
	echo "Removing ${vOutputDir}/${TARFILE}" | tee -a $vOutputLog
	rm $TARFILE
fi
tar -cvf $TARFILE *${vPDBName}*

# move archive file
mv $TARFILE /tmp
if [ $? -ne 0 ]
then
	echo "" | tee -a $vOutputLog
	echo "There was a problem moving $TARFILE to /tmp. Please copy it manually." | tee -a $vOutputLog
else
	echo "$TARFILE successfully moved to /tmp." | tee -a $vOutputLog
fi

############################ Report Timing of Script ############################

vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:          $ORACLE_SID" | tee -a $vOutputLog
echo "Output log:             $vOutputLog" | tee -a $vOutputLog
echo "Data Pump directory:    $vDPParDir" | tee -a $vOutputLog
echo "Archive file:           /tmp/${TARFILE}" | tee -a $vOutputLog
echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
