#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GG_Linux_upgrade.sh
#
#  DESCRIPTION
#    Create a new database, import data from AIX and start GG replicat
#
#  NOTES
#    Run as oracle
#    Requires gold standard template DBs linked to RMAN repository
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         02/07/17 - Created
#  KDJ         02/14/17 - Adapted to work for 11g and 12c databases
#
# PREREQUISITES
#   /database/<NEWCDB>_admn01
#   /database/<NEWCDB>_redo01
#   /database/<NEWCDB>_redo02
#   /database/<NEWCDB>_arch01
#   /database/<NEWCDB>0n
#   /database/<NEWPDB>0n
#
#  STEPS
#    1. Set variables (including prompting user for some)
#    2. Perform pre-install checks
#    3. Create database directories
#    4. Update .bash_profile and oratab files
#    5. Create set environment script, password file and init.ora file
#    6. RMAN: Duplicate gold standard template to new database name
#    7. Move spfile and create links for param & password files
#    8. Put DB in archivelog mode
#    9. Reset parameters based on AIX settings (call script from AIX)
#    10. Create pluggable database
#    11. Recreate tablespaces for database (call scripts from AIX)
#    12. RMAN: Register DB, configure settings and take full backup
#    13. Add CDB and PDB to tnsnames.ora
#    14. Print timing of script
#
#================================================================================================#

############################ Oracle Constants ############################
export ORACLE_BASE="/app/oracle/product"
export MIDDLEWARE_HOME=/u01/OracleHomes/Middleware
export OMS_HOME=$MIDDLEWARE_HOME/oms
export TNS_ADMIN=/app/oracle/tns_admin
ORATAB="/etc/oratab"
MAXNAMELENGTH=8
vCDBPrefix="c"
vRMANUser=rman

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts/12cupgrade"
vEnvScriptDir="/app/oracle/setenv"
vProfile="/home/oracle/.bash_profile"
vMissingFiles="FALSE"
vHostName=$(hostname)

vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','SQLTXPLAIN','SQLTXADMIN'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC'"

NOWwSECs=$(date '+%Y%m%d%H%M%S')
vStartSec=$(date '+%s')

# 12c comparison tables
vRowTable="ggtest.row_count_12c"
vObjectTable="ggtest.object_count_12c"
vIndexTable="ggtest.index_count_12c"
vConstraintTable="ggtest.constraint_count_12c"
vPrivilegeTable="ggtest.priv_count_12c"
vRolesTable="ggtest.role_count_12c"

# 11g comparison tables
vLinuxRowTable="ggtest.row_count_11g"
vLinuxObjectTable="ggtest.object_count_11g"
vLinuxIndexTable="ggtest.index_count_11g"
vLinuxConstraintTable="ggtest.constraint_count_11g"
vLinuxPrivilegeTable="ggtest.priv_count_11g"
vLinuxRolesTable="ggtest.role_count_11g"

############################ Version-specific Constants ############################
vHome11g="${ORACLE_BASE}/db/11g/1"
vInit11g="/app/oracle/scripts/init11g.ora"
vGS11=gs11g

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	export GGATE=/oragg/12.2
	vBkpLoc=/app/rman
	export GGMOUNT=/oragg
else
	export GGATE=/app/oracle/product/ggate/12c/1
	vBkpLoc=/oragg
	export GGMOUNT=/oragg
fi

# array of acceptable Oracle errors
vErrIgnore+=(ORA-00604)         # error occurred at recursive SQL level 3
vErrIgnore+=(ORA-00959)         # tablespace 'XXX' does not exist
vErrIgnore+=(ORA-00911)         # invalid character
vErrIgnore+=(ORA-00942)         # table or view does not exist
#vErrIgnore+=(ORA-00959)         # tablespace 'XXX' does not exist
vErrIgnore+=(ORA-00987)         # missing or invalid username(s) 
vErrIgnore+=(ORA-00990)         # missing or invalid privilege
vErrIgnore+=(ORA-01435)         # user does not exist
vErrIgnore+=(ORA-01507)         # database not mounted
vErrIgnore+=(ORA-01918)         # user 'XXX' does not exist
vErrIgnore+=(ORA-01920)         # user name 'XXX' conflicts with another user or role name
vErrIgnore+=(ORA-01921)         # role name 'XXX' conflicts with another user or 
vErrIgnore+=(ORA-01927)         # cannot REVOKE privileges you did not grant 
vErrIgnore+=(ORA-01931)         # cannot grant UNLIMITED TABLESPACE to a role 
vErrIgnore+=(ORA-02085)         # database link XXX connects to XXX
vErrIgnore+=(ORA-03297)         # file contains used data beyond requested RESIZE value
vErrIgnore+=(ORA-04042)         # procedure, function, package, or package body does not exist
vErrIgnore+=(ORA-04043)         # object XXX does not exist
vErrIgnore+=(ORA-04052)         # error occurred when looking up remote object XXX@XXX
vErrIgnore+=(ORA-12154)         # TNS:could not resolve the connect identifier specified
vErrIgnore+=(ORA-31625)         # Schema XXX is needed to import this object, but is unaccessible
vErrIgnore+=(ORA-31684)         # Object type XXX:"XXX" already exists
vErrIgnore+=(ORA-32004)         # obsolete or deprecated parameter(s) specified for RDBMS instance
vErrIgnore+=(ORA-32010)         # cannot find entry to delete in SPFILE
vErrIgnore+=(ORA-39082)         # Object type PROCEDURE:"XXX"."XXX" created with compilation warnings
vErrIgnore+=(ORA-39083)         # Object type XXX failed to create with error:

# array of acceptable errors for data pump only
vErrPumpIgnore+=(ORA-00604)     # error occurred at recursive SQL level 3
vErrPumpIgnore+=(ORA-01110)     # data file XX: '/database/XXX/oradata/XXX.dbf'
vErrPumpIgnore+=(ORA-01116)     # error in opening database file 12
vErrPumpIgnore+=(ORA-04052)     # error occurred when looking up remote object XXX@XXX
vErrPumpIgnore+=(ORA-12154)     # TNS:could not resolve the connect identifier specified
vErrPumpIgnore+=(ORA-27041)     # unable to open file

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
	# number of required parameters
	vParamCt=3
	# check that all parameters passed
	if [[ $# -lt $vParamCt ]]
	then
		# exit script if not enough parameters passed
		echo "ERROR: This function requires $vParamCt parameter(s)!" | tee -a $vOutputLog
		exit 1
	fi

	# copy Oracleand bash errors from log file to error log
	gawk '/^ORA-|^SP2-|^PLS-|^RMAN-|^TNS-|^bash:-/' $1 > $2

	# copy critical errors to critical log by ignoring acceptable errors
	eval $vGawkCmd
	# count number of errors
	vLineCt=$(wc -l $3 | awk '{print $1}')
	if [[ $vLineCt -gt 0 ]]
	then
		sleep 5
		echo " " | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo " " | tee -a $1
		echo "There are $vLineCt critical errors." | tee -a $1
		cat $3 | tee -a $1
		echo "Check $1 for the full details." | tee -a $1
		#exit 1
		continue_fnc
	else
		echo " "
		echo "No errors to report." | tee -a $1
	fi
}

############################ DP Error Check Function #########################
# PURPOSE:                                                                   #
# This function checks the data pump log for critical errors.                #
# Note: this function is more permissive than error_check_fnc                #
##############################################################################

function dp_error_check_fnc {
	# number of required parameters
	vParamCt=3
	# check that all parameters passed
	if [[ $# -lt $vParamCt ]]
	then
		# exit script if not enough parameters passed
		echo "ERROR: This function requires $vParamCt parameter(s)!" | tee -a $vOutputLog
		exit 1
	fi

	# copy Oracleand bash errors from log file to error log
	gawk '/ORA-|^SP2-|^PLS-|^RMAN-|^TNS-|^bash:-/' $1 > $2

	# copy critical errors to critical log by ignoring acceptable errors
	eval $vGawkPumpCmd
	# count number of errors
	vLineCt=$(wc -l $3 | awk '{print $1}')
	if [[ $vLineCt -gt 0 ]]
	then
		sleep 5
		echo " " | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $1
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $1
		echo " " | tee -a $1
		echo "There are $vLineCt critical errors." | tee -a $1
		cat $3 | tee -a $1
		echo "Check $1 for the full details." | tee -a $1
		#exit 1
		continue_fnc
	else
		echo " "
		echo "No errors to report." | tee -a $1
	fi
}

############################ GoldenGate Process Check ########################
# PURPOSE:                                                                   #
# This function checks the status of a GG process.                           #
##############################################################################

function info_all_fnc {
	# Check that GG extract is running
	./ggsci > $GGALLOUT << EOF
info all
exit
EOF
	
	cat $GGALLOUT | tee -a $vOutputLog
	GGALLSTATUS=$(cat $GGALLOUT | grep "${1}101" | awk '{ print $2}')
	if [[ $GGALLSTATUS != "RUNNING" ]]
	then
		echo "" | tee -a $vOutputLog
		echo "The ${1}101 process is $GGALLSTATUS. Please check the status."  | tee -a $vOutputLog
		#false
	else
		echo "" | tee -a $vOutputLog
		echo "OK: The ${1}101 process is $GGALLSTATUS."  | tee -a $vOutputLog
	fi
}

############################ RMAN 11g Duplicate Function #####################
# PURPOSE:                                                                   #
# This function runs the RMAN duplicate command for a 11g database.          #
##############################################################################

#  DUPLICATE DATABASE TO $vCDBName
# CONNECT CATALOG '$vRMANUser/$vRmanPwd@$vRMANSid'
  
function duplicate_11g_fnc {
	echo "" | tee -a $vOutputLog
	echo "Duplicating an 11g AL32UTF8 database" | tee -a $vOutputLog
	
	# connect to RMAN
	$ORACLE_HOME/bin/rman >> ${vOutputLog} << RUNRMAN
CONNECT AUXILIARY /
RUN
{
  ALLOCATE AUXILIARY CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL c3 DEVICE TYPE DISK;
  SET NEWNAME FOR DATABASE TO '/database/${vCDBFull}01/oradata/%b';
  DUPLICATE DATABASE $vGCSID TO $vCDBName
  BACKUP LOCATION '${vBkpLoc}/${vGCSID}'
    LOGFILE
      GROUP 1 ('/database/${vCDBFull}_redo01/oralog/redo101.log', 
               '/database/${vCDBFull}_redo02/oralog/redo102.log') SIZE $vRedoSize REUSE, 
      GROUP 2 ('/database/${vCDBFull}_redo01/oralog/redo201.log', 
               '/database/${vCDBFull}_redo02/oralog/redo202.log') SIZE $vRedoSize REUSE,
      GROUP 3 ('/database/${vCDBFull}_redo01/oralog/redo301.log', 
               '/database/${vCDBFull}_redo02/oralog/redo302.log') SIZE $vRedoSize REUSE
  SPFILE
    set audit_file_dest='/database/${vCDBFull}_admn01/admin/audit/'
	set background_dump_dest='/database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull}/trace'
    set control_files='/database/${vCDBFull}_redo02/oractl/control02.ctl','/database/${vCDBFull}_redo01/oractl/control01.ctl'
    set diagnostic_dest='/database/${vCDBFull}_admn01/admin/'
    set log_archive_dest_1='LOCATION=/database/${vCDBFull}_arch01/arch'
	set user_dump_dest='/database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull}/trace'
    set utl_file_dir='/database/${vCDBFull}_admn01/admin/utldump/'
  NOREDO;
}
exit
RUNRMAN
}

############################ Shutdown Function ###############################
# PURPOSE:                                                                   #
# This function shuts down the database.                                     #
##############################################################################

function shutdown_db_fnc {
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Shutting down database $vCDBName               *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog

	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SHUTDOWN ABORT;
exit
RUNSQL
}

############################ Duplicate Function ##############################
# PURPOSE:                                                                   #
# This function duplicates the DB from RMAN backup.                          #
##############################################################################

function dup_db_fnc {
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Duplicating the GS template as $vCDBName       *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	
	# Get size for redo logs
	ls -l $vRedoLogs
	if [ $? -eq 0 ]
	then
		vRedoSize=$(cat $vRedoLogs)
	else
		vRedoSize=512M
	fi
	
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
STARTUP NOMOUNT PFILE='${vPfileLoc}/init${vCDBName}.ora';
exit
RUNSQL

	# Call function to run duplicate process
	if [[ $vDBVersion -eq 11 && $vCharSet = AL32UTF8 ]]
	then
		vGCSID=$vGS11
		duplicate_11g_fnc
	else
		echo "" | tee -a $vOutputLog
		echo "This script can only be used for 11g AL32UTF8 databases. " | tee -a $vOutputLog
		exit 1
	fi
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Prompt Short Function ###########################
# PURPOSE:                                                                   #
# This function prompts the user for a few inputs.                           #
##############################################################################

function prompt_short_fnc {
	# set new DB name
	if [[ $vTier = 't' ]]
	then
		vPDBName=c3appst
	elif [[ $vTier = 'd' ]]
	then
		vPDBName=c3appsd
	elif [[ $vTier = 's' ]]
	then
		vPDBName=c3appsd
	else
		echo "" | tee -a $vOutputLog
		echo "ERROR: This script was only written to work on Sandbox, UT and SIT!" | tee -a $vOutputLog
		exit 1
	fi
	export ORACLE_SID="c${vPDBName}"
	
	# set DB version
	export ORACLE_HOME=$vHome11g
	vDBVersion=11
	
	# Prompt for character set
	vCharSet=AL32UTF8
	
	# Prompt for the SYS password
	while true
	do
		echo ""
		echo -e "Enter the SYS password:"
		stty -echo
		read vSysPwd
		echo -e "Verify the SYS password:"
		read vSysPwdVerf
		if [[ $vSysPwd != $vSysPwdVerf ]]
		then
			echo -e "The passwords do not match\n"
		elif [[ -n "$vSysPwd" ]]
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


}

############################ Prompt RMAN Function ############################
# PURPOSE:                                                                   #
# This function prompts for RMAN-related inputs.                             #
##############################################################################

function prompt_rman_fnc {
	# Prompt for the RMAN user password
	while true
	do
		echo ""
		echo -e "Enter the password for the RMAN user, $vRMANUser :"
		stty -echo
		read vRmanPwd
		if [[ -n "$vRmanPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
}

############################ Prompt OEM Function #############################
# PURPOSE:                                                                   #
# This function prompts for OEM-related inputs.                              #
##############################################################################

function prompt_oem_fnc {
	# Prompt for the SYSMAN password
	while true
	do
		echo ""
		echo -e "Enter the password for the OEM SYSMAN user :"
		stty -echo
		read vSysmanPwd
		if [[ -n "$vSysmanPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
	
	# Prompt for the DBSNMP password
	while true
	do
		echo ""
		echo -e "Enter the password for the DBSNMP user :"
		stty -echo
		read vDBSNMPPwd
		if [[ -n "$vDBSNMPPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
}

############################ Prompt TNS Function #############################
# PURPOSE:                                                                   #
# This function prompts for TNS-related inputs.                              #
##############################################################################

function prompt_tns_fnc {
	# Prompt for application group
	echo ""
	echo -e "Enter the name of the application SD group: \c"  
	while true
	do
		read vSDGroup
		if [[ -n "$vSDGroup" ]]
		then
			break
		else
			echo -e "Enter a valid SD group name: \c"  
		fi
	done
	
	# Prompt for the SYSTEM password
	while true
	do
		echo ""
		echo -e "Enter the SYSTEM password:"
		stty -echo
		read vSystemPwd
		#echo -e "Verify the SYSTEM password:"
		#read vSystemPwdVerf
		#if [[ $vSystemPwd != $vSystemPwdVerf ]]
		#then
		#	echo -e "The passwords do not match\n"
		#el
		if [[ -n "$vSystemPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
}

############################ Pre-Check Function ##############################
# PURPOSE:                                                                   #
# This function checks script prerequisites.                                 #
##############################################################################

function pre_check_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Performing pre-install checks *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Check that database with this name not already running
	echo "" | tee -a $vOutputLog
	echo "Checking for conflicts with currently running databases..." | tee -a $vOutputLog
	vDBlist=$(ps -eo args | grep ora_pmon | sed 's/ora_pmon_//' | grep -Ev "grep|sed")
	for vCheckArray in ${vDBlist[@]}
	do
		if [[ $vCheckArray = $vCDBName ]]
		then
			echo "ERROR: There is already a database named $vCDBName running on this host."
			exit 1
		elif [[ $vCheckArray = $vPDBName ]]
		then
			echo "ERROR: There is already a database named $vPDBName running on this host."
			exit 1
		fi
	done

	# Check that database alias not in .bash_profile already
	echo "" | tee -a $vOutputLog
	echo "Checking that the database aliases not already in .bash_profile..." | tee -a $vOutputLog
	vAliasCt=$(grep ^"alias $vCDBName" $vProfile | wc -l)
	if [[ $vAliasCt -gt 0 ]]
	then
		echo "ERROR: There are already $vAliasCt alias(es) in $vProfile for $vCDBName."
		exit 1
	fi
	vAliasCt=$(grep ^"alias $vPDBName" $vProfile | wc -l)
	if [[ $vAliasCt -gt 0 ]]
	then
		echo "ERROR: There is already an alias in $vProfile for $vPDBName."
		exit 1
	fi
	
	# Check that database not already in oratab file
	echo "" | tee -a $vOutputLog
	echo "Checking that $ORATAB does not already have an entry for ${vCDBName}..." | tee -a $vOutputLog
	vOratabCheck=$(grep ^${vCDBName}: $ORATAB | wc -l)
	if [[ $vOratabCheck -gt 0 ]]
	then
		echo "ERROR: The database $vCDBName is already in $ORATAB"
		exit 1
	fi

	# Check if directories exist
	echo "" | tee -a $vOutputLog
	echo "Checking that all required directories exist..." | tee -a $vOutputLog
	for vCheckArray in ${vDirArray[@]}
	do
		df -h $vCheckArray
		if [ $? -ne 0 ]
		then
			echo "ERROR: $vCheckArray does not exist!" | tee -a $vOutputLog
			exit 1
		fi
	done
	
	# Check if files exist
	echo "" | tee -a $vOutputLog
	echo "Checking that all required files exist..." | tee -a $vOutputLog
	for vCheckArray in ${vFileArray[@]}
	do
		ls -l $vCheckArray
		if [ $? -ne 0 ]
		then
			echo "ERROR: $vCheckArray does not exist!" | tee -a $vOutputLog
			exit 1
		fi
	done
	
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Create Directories Function #####################
# PURPOSE:                                                                   #
# This function creates new database directories.                            #
##############################################################################

function create_dirs_fnc {
	echo "" | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	echo "* Creating new directories  *" | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	
	# set standard file permissions
	vOldUmask=`umask`
	umask 0027		#from OEM installation
	#umask 0022		from 11g create DB script
	
	# Create all database directory structures and add to array to check later
	unset vDirArray
	echo "" | tee -a $vOutputLog
	echo "Creating directories for ${vCDBName}..." | tee -a $vOutputLog
	mkdir /database/${vCDBFull}_admn01/admin | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/admin)
	mkdir /database/${vCDBFull}_admn01/admin/adump | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/admin/adump)
	mkdir /database/${vCDBFull}_admn01/admin/audit | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/admin/audit)
	mkdir /database/${vCDBFull}_admn01/admin/pfile | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/admin/pfile)
	mkdir /database/${vCDBFull}_admn01/admin/utldump | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/admin/utldump)
	mkdir /database/${vCDBFull}_admn01/scripts | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/scripts)
	mkdir /database/${vCDBFull}_admn01/scripts/cron | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_admn01/scripts/cron)
	mkdir /database/${vCDBFull}_redo01/oralog | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_redo01/oralog)
	mkdir /database/${vCDBFull}_redo01/oractl | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_redo01/oractl)
	mkdir /database/${vCDBFull}_redo02/oralog | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_redo02/oralog)
	mkdir /database/${vCDBFull}_redo02/oractl | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_redo02/oractl)
	mkdir /database/${vCDBFull}_arch01/arch | tee -a $vOutputLog
	vDirArray+=(/database/${vCDBFull}_arch01/arch)
	# added for misplaced dump files (July 10)
	# mkdir /database/${vCDBFull}_admn01/admin/diag
	# vDirArray+=(/database/${vCDBFull}_admn01/admin/diag)
	# mkdir /database/${vCDBFull}_admn01/admin/diag/rdbms
	# vDirArray+=(/database/${vCDBFull}_admn01/admin/diag/rdbms)
	# mkdir /database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}
	# vDirArray+=(/database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull})
	# mkdir /database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull}
	# vDirArray+=(/database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull})
	# mkdir /database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull}/trace
	# vDirArray+=(/database/${vCDBFull}_admn01/admin/diag/rdbms/${vCDBFull}/${vCDBFull}/trace)

	# Create oradata directory on every data mount point
	echo "" | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		# create data directory for CDB
		echo "Creating data directories for ${vCDBName}..." | tee -a $vOutputLog
		mkdir /database/${vCDBFull}01/oradata
		if [ $? -eq 0 ]
		then
			echo "Directory /database/${vCDBFull}01/oradata created successfully" | tee -a $vOutputLog
		fi
		vDirArray+=(/database/${vCDBFull}01/oradata)
		mkdir /database/${vCDBFull}01/oradata/pdbseed
		if [ $? -eq 0 ]
		then
			echo "Directory /database/${vCDBFull}01/oradata/pdbseed created successfully" | tee -a $vOutputLog
		fi
		vDirArray+=(/database/${vCDBFull}01/oradata/pdbseed)
		
		# create data directories for PDB
		echo "" | tee -a $vOutputLog
		echo "Creating data directories for ${vPDBName}..." | tee -a $vOutputLog
		vDataDirs=$(ls /database | grep ${vPDBName}0 | grep -v ${vCDBFull}01)
		for vDirName in ${vDataDirs[@]}
		do
			df -h /database/${vDirName}	#mountpoint -q ${vDirName}
			if [ $? -eq 0 ]
			then
				echo "Creating directory /database/${vDirName}/oradata" | tee -a $vOutputLog
				mkdir /database/${vDirName}/oradata
				vDirArray+=(/database/${vDirName}/oradata)
			else
				echo "ERROR: ${vDirName} is not a mount point!" | tee -a $vOutputLog
				exit 1
			fi
		done
	else
		# create data directories for 11g DB
		echo "" | tee -a $vOutputLog
		echo "Creating data directories for ${vPDBName}..." | tee -a $vOutputLog
		vDataDirs=$(ls /database | grep ${vPDBName}0)
		for vDirName in ${vDataDirs[@]}
		do
			df -h /database/${vDirName}	#mountpoint -q ${vDirName}
			if [ $? -eq 0 ]
			then
				echo "Creating directory /database/${vDirName}/oradata" | tee -a $vOutputLog
				mkdir /database/${vDirName}/oradata
				vDirArray+=(/database/${vDirName}/oradata)
			else
				echo "ERROR: ${vDirName} is not a mount point!" | tee -a $vOutputLog
				exit 1
			fi
		done
	fi

	# reset file permissions
	umask ${vOldUmask}
	
	# Confirm new directories
	echo "" | tee -a $vOutputLog
	echo "Confirming that all directories created successfully..." | tee -a $vOutputLog
	for vCheckArray in ${vDirArray[@]%:}
	do
		if [ ! -d $vCheckArray ]
		then
			# try to create it again
			echo "Trying again to create $vCheckArray..." | tee -a $vOutputLog
			mkdir $vCheckArray
			if [ ! -d $vCheckArray ]
			then
				echo "ERROR: Unable to create $vCheckArray!" | tee -a $vOutputLog
				exit 1
			fi
		else
			echo "Directory $vCheckArray is here." | tee -a $vOutputLog
		fi
	done
	
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ AIX Files Function ##############################
# PURPOSE:                                                                   #
# This function unzips archive of files from AIX.                            #
##############################################################################

function aix_files_fnc {
	# Check for scripts from existing database
	unset vFileArray
	unset vCheckArray
	vFileArray+=(${vRedoLogs})
	vFileArray+=(${vSetParam})
	vFileArray+=(${vCreateTbs})
	vFileArray+=(${vUndoSize})
	vFileArray+=(${vTempSize})
	vFileArray+=(${vTSGroups})
	vFileArray+=(${vCreateACL})
	vFileArray+=(${vSysObjects})
	vFileArray+=(${vProxyPrivs})
	vFileArray+=(${vCreateUsers})
	vFileArray+=(${CREATEQUOTAS})
	vFileArray+=(${CREATEGRANTS})
	vFileArray+=(${CREATESYSPRIVS})
	vFileArray+=(${REVOKESYSPRIVS})
	vFileArray+=(${DISABLETRIGGERS})
	vFileArray+=(${ENABLETRIGGERS})
	vFileArray+=(${CREATESYNS})
	vFileArray+=(${CREATEROLES})
	vFileArray+=(${CREATELOGON})
	vFileArray+=(${CURRENTSCN})
	vFileArray+=(${vDPImpPar})

	echo "" | tee -a $vOutputLog
	echo "Checking for scripts from old 12c database..." | tee -a $vOutputLog
	
	# check for tar file
	if [[ ! -e $TARFILE ]]
	then
		TARFILE="${vDBScripts}/Linux_setup_${vPDBName}.tar"
		if [[ ! -e $TARFILE ]]
		then
			echo " " | tee -a $vOutputLog
			echo "ERROR: That tar file of scripts from AIX is missing: $TARFILE" | tee -a $vOutputLog
			echo "       This file is required to continue." | tee -a $vOutputLog
			exit 1
		fi
	else
		mv $TARFILE $vDBScripts
	fi
	# unzip file
	cd $vDBScripts
	rm *.sql
	rm *.out
	rm *.par
	rm *.oby
	rm *.out
	tar -xf Linux_setup_${vPDBName}.tar
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
		if [[ ! -e $vCheckArray ]]
		then
			echo " " | tee -a $vOutputLog
			echo "WARNING: The $vCheckArray file from the old DB does not exist." | tee -a $vOutputLog
			continue_fnc
			vMissingFiles="TRUE"
		else
			echo "${vCheckArray} is here" | tee -a $vOutputLog
		fi
	done
	
	# add slash to logon trigger script for PL/SQL block
	echo "" | tee -a $vOutputLog
	echo "Editing $CREATELOGON to add slashes (/)" | tee -a $vOutputLog
	sed -i.$NOWwSECs "/END;/s/END;/END;\n\//" $CREATELOGON
}

############################ Create Files Function ###########################
# PURPOSE:                                                                   #
# This function creates files for new DB.                                    #
##############################################################################

function create_files_fnc {
	# Make sure parameter files do not exist
	echo "" | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	echo " Creating files and links   *" | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	if [ -f ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora ]
	then
		echo "Removing ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora..." | tee -a $vOutputLog
		rm ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora
	fi
	if [ -f ${ORACLE_HOME}/dbs/init${vCDBName}.ora ]
	then
		echo "Removing ${ORACLE_HOME}/dbs/init${vCDBName}.ora..." | tee -a $vOutputLog
		rm ${ORACLE_HOME}/dbs/init${vCDBName}.ora
	fi
	
	# Add new entry to oratab file
	echo "" | tee -a $vOutputLog
	echo "Adding the database to the oratab file..." | tee -a $vOutputLog
	cp $ORATAB ${vLogDir}/oratab_${NOWwSECs}
	echo "${vCDBName}:${ORACLE_HOME}:Y" | tee -a $ORATAB
	# Verify only one entry exists for the DB
	vOratabCheck=$(grep ^${vCDBName}: $ORATAB | wc -l)
	if [[ $vOratabCheck -eq 0 ]]
	then
		echo "ERROR: The database $vCDBName was not added to $ORATAB" | tee -a $vOutputLog
		exit 1
	elif [[ $vOratabCheck -ne 1 ]]
	then
		echo "ERROR: There are multiple lines for database $vCDBName in $ORATAB" | tee -a $vOutputLog
		exit 1
	else
		echo "Database $vCDBName successfully added to $ORATAB" | tee -a $vOutputLog
	fi

	# Add new entries to .profile script and save existing as new file
	echo "" | tee -a $vOutputLog
	echo "Adding aliases for the CDB and PDB to the .bash_profile file..." | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		sed -i.$NOWwSECs "/###NEW_DB_ALIAS_HERE###/s/###NEW_DB_ALIAS_HERE###/alias $vPDBName='. \$ORA_SETENV_SCRIPT_PATH\/set${vPDBName}.sh'\nalias $vCDBName='. \$ORA_SETENV_SCRIPT_PATH\/set${vCDBName}.sh'\n&/" $vProfile
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating the new version of $vProfile!" | tee -a $vOutputLog
			exit 1
		else
			echo "Aliases for $vPDBName and $vCDBName successfully added to $vProfile" | tee -a $vOutputLog
		fi
	else
		sed -i.$NOWwSECs "/###NEW_DB_ALIAS_HERE###/s/###NEW_DB_ALIAS_HERE###/alias $vPDBName='. \$ORA_SETENV_SCRIPT_PATH\/set${vPDBName}.sh'\n&/" $vProfile
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating the new version of $vProfile!" | tee -a $vOutputLog
			exit 1
		else
			echo "Alias for $vPDBName successfully added to $vProfile" | tee -a $vOutputLog
		fi
	fi
	
	# Build the Set Environment Scripts
	echo "" | tee -a $vOutputLog
	echo "Creating the environment scripts..." | tee -a $vOutputLog
	if [ -f $vEnvScriptPDB ]
	then
		rm $vEnvScriptPDB
	fi
	sed "s/<newdb>/${vPDBName}/g" ${vEnvScriptDir}/setnewdb.sh > $vEnvScriptPDB
	chmod 744 $vEnvScriptPDB
	if [ $? -ne 0 ]
	then
		echo "ERROR: There was a problem creating $vEnvScriptPDB!" | tee -a $vOutputLog
		exit 1
	else
		echo "$vEnvScriptPDB successfully created." | tee -a $vOutputLog
	fi
	# Build the Set Environment Scripts for CDB for 12c databases
	if [[ $vDBVersion -eq 12 ]]
	then
		if [ -f $vEnvScriptCDB ]
		then
			rm $vEnvScriptCDB
		fi
		sed "s/<newdb>/${vCDBName}/g" ${vEnvScriptDir}/setnewdb.sh > $vEnvScriptCDB
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating $vEnvScriptCDB!" | tee -a $vOutputLog
			exit 1
		else
			echo "$vEnvScriptCDB successfully created." | tee -a $vOutputLog
		fi
		chmod 744 $vEnvScriptCDB
		# Check environment scripts
		ls -l $vEnvScriptPDB
		if [ $? -ne 0 ]
		then
			echo "ERROR: $vEnvScriptPDB was not created!" | tee -a $vOutputLog
			exit 1
		fi
		ls -l $vEnvScriptCDB
		if [ $? -ne 0 ]
		then
			echo "ERROR: $vEnvScriptCDB was not created!" | tee -a $vOutputLog
			exit 1
		fi
	fi

	# Build the password file
	echo "" | tee -a $vOutputLog
	echo "Creating the password file..." | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/orapwd file="${vPfileLoc}/orapw${vCDBName}" password=$vSysPwd force=y format=12
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating ${vPfileLoc}/orapw${vCDBName}!" | tee -a $vOutputLog
			exit 1
		else
			echo "Password file ${vPfileLoc}/orapw${vCDBName} created successfully" | tee -a $vOutputLog
		fi
		# Check password file
		ls -l ${vPfileLoc}/orapw${vCDBName}
		if [ $? -ne 0 ]
		then
			echo "ERROR: ${vPfileLoc}/orapw${vCDBName} was not created!" | tee -a $vOutputLog
			exit 1
		fi
	else
		$ORACLE_HOME/bin/orapwd file="${vPfileLoc}/orapw${vCDBName}" password=$vSysPwd force=y
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating ${vPfileLoc}/orapw${vCDBName}!" | tee -a $vOutputLog
			exit 1
		else
			echo "Password file ${vPfileLoc}/orapw${vCDBName} created successfully" | tee -a $vOutputLog
		fi
		# Check password file
		ls -l ${vPfileLoc}/orapw${vCDBName}
		if [ $? -ne 0 ]
		then
			echo "ERROR: ${vPfileLoc}/orapw${vCDBName} was not created!" | tee -a $vOutputLog
			exit 1
		fi
	fi

	# Build the init.ora file
	echo "" | tee -a $vOutputLog
	echo "Creating the init.ora parameter file..." | tee -a $vOutputLog
	if [ -f ${vPfileLoc}/init${vCDBName}.ora ]
	then
		rm ${vPfileLoc}/init${vCDBName}.ora
	fi
	if [[ $vDBVersion -eq 12 ]]
	then
		sed "s/<newcdb>/${vCDBFull}/g;s/<cdb_short>/${vCDBName}/g" $vInit12c > ${vPfileLoc}/init${vCDBName}.ora
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating ${vPfileLoc}/init${vCDBName}.ora!" | tee -a $vOutputLog
			exit 1
		else
			echo "Parameter file ${vPfileLoc}/init${vCDBName}.ora created successfully" | tee -a $vOutputLog
		fi
		# Check init.ora file
		ls -l ${vPfileLoc}/init${vCDBName}.ora
		if [ $? -ne 0 ]
		then
			echo "ERROR: ${vPfileLoc}/init${vCDBName}.ora was not created!" | tee -a $vOutputLog
			exit 1
		fi
	else
		sed "s/<newdb>/${vCDBName}/g" $vInit11g > ${vPfileLoc}/init${vCDBName}.ora
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was a problem creating ${vPfileLoc}/init${vCDBName}.ora!" | tee -a $vOutputLog
			exit 1
		else
			echo "Parameter file ${vPfileLoc}/init${vCDBName}.ora created successfully" | tee -a $vOutputLog
		fi
		# Check init.ora file
		ls -l ${vPfileLoc}/init${vCDBName}.ora
		if [ $? -ne 0 ]
		then
			echo "ERROR: ${vPfileLoc}/init${vCDBName}.ora was not created!" | tee -a $vOutputLog
			exit 1
		fi
	fi
	
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Update Param Function ###########################
# PURPOSE:                                                                   #
# This function updates the DB parameter files.                              #
##############################################################################

function update_param_fnc {
	echo "" | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	echo "* Updating file links       *"  | tee -a $vOutputLog
	echo "*****************************" | tee -a $vOutputLog
	
	# Shutdown database
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
spool $vOutputLog append
alter session set container=cdb\$root;
shutdown immediate;
RUNSQL

	else
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
spool $vOutputLog append
shutdown immediate;
RUNSQL
	fi
	
	# Remove/move existing links or files
	if [ -f ${ORACLE_HOME}/dbs/init${vCDBName}.ora ]
	then
		rm ${ORACLE_HOME}/dbs/init${vCDBName}.ora | tee -a $vOutputLog
	fi
	if [ -f ${vPfileLoc}/spfile${vCDBName}.ora ]
	then
		rm ${vPfileLoc}/spfile${vCDBName}.ora | tee -a $vOutputLog
	fi
	mv ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora ${vPfileLoc}
	
	# Create symbolic link to init parameter file
	echo "" | tee -a $vOutputLog
	echo "Creating the links for the password and parameter files..." | tee -a $vOutputLog
	ln -f -s ${vPfileLoc}/init${vCDBName}.ora ${ORACLE_HOME}/dbs/init${vCDBName}.ora
	if [ $? -ne 0 ]
	then
		echo "ERROR: There was a problem creating ${ORACLE_HOME}/dbs/init${vCDBName}.ora!" | tee -a $vOutputLog
		exit 1
	fi

	# Create symbolic link to spfile parameter file
	ln -f -s ${vPfileLoc}/spfile${vCDBName}.ora ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora
	if [ $? -ne 0 ]
	then
		echo "ERROR: There was a problem creating ${ORACLE_HOME}/dbs/spfile${vCDBName}.ora!" | tee -a $vOutputLog
		exit 1
	fi
	
	# Create symbolic link for password file
	echo "" | tee -a $vOutputLog
	echo "Creating the link for the password file..." | tee -a $vOutputLog
	if [ -f ${ORACLE_HOME}/dbs/orapw${vCDBName} ]
	then
		rm ${ORACLE_HOME}/dbs/orapw${vCDBName}
	fi
	ln -f -s ${vPfileLoc}/orapw${vCDBName} ${ORACLE_HOME}/dbs/orapw${vCDBName}
	if [ $? -ne 0 ]
	then
		echo "ERROR: There was a problem creating ${ORACLE_HOME}/dbs/orapw${vCDBName}!" | tee -a $vOutputLog
		exit 1
	fi

	# Check files
	unset vFileArray
	vFileArray+=(${ORACLE_HOME}/dbs/init${vCDBName}.ora)
	vFileArray+=(${ORACLE_HOME}/dbs/orapw${vCDBName})
	vFileArray+=(${ORACLE_HOME}/dbs/spfile${vCDBName}.ora)
	
	for vCheckArray in ${vFileArray[@]}
	do
		ls -l $vCheckArray | tee -a $vOutputLog
		if [ $? -ne 0 ]
		then
			echo "ERROR: $vCheckArray does not exist!" | tee -a $vOutputLog
			exit 1
		fi
	done
	
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Tablespace Function #############################
# PURPOSE:                                                                   #
# This function creates the tablespaces.                                     #
##############################################################################

function create_ts_fnc {
	echo "" | tee -a $vOutputLog
	echo "*******************************" | tee -a $vOutputLog
	echo "* Creating tablespaces        *" | tee -a $vOutputLog
	echo "*******************************" | tee -a $vOutputLog
	
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
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
WHENEVER SQLERROR EXIT
SPOOL $vOutputLog APPEND

/*--- start the DB ---*/
startup force;

-- set initialization parameters
WHENEVER SQLERROR CONTINUE
@$vSetParam
shutdown immediate
startup

WHENEVER SQLERROR EXIT
-- create system objects
@$vSysObjects
-- create tablespaces
host echo "Recreating database-specific objects..."
@$vCreateTbs
-- add temp tablespace files
@$vTempSize
-- add undo space
@$vUndoSize
-- add tablespace groups
@$vTSGroups

/*--- shutdown DB ---*/
WHENEVER SQLERROR CONTINUE
select name, dbid, open_mode from V\$DATABASE;
--shutdown immediate;

exit
RUNSQL

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Archive Function ################################
# PURPOSE:                                                                   #
# This function turns on archiving for DB.                                   #
##############################################################################

function archive_fnc {
	echo "" | tee -a $vOutputLog
	echo "*******************************" | tee -a $vOutputLog
	echo "* Turning on archive log mode *"  | tee -a $vOutputLog
	echo "*******************************" | tee -a $vOutputLog
	
#	export ORACLE_SID=$vCDBName
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET LINES 150
SET PAGES 200
WHENEVER SQLERROR EXIT
SPOOL $vOutputLog APPEND

REM ********************************
REM *** Turn on Archive Log Mode ***
REM ********************************

startup mount;
alter database archivelog;
alter database open;

-- database checks
alter session set container=cdb\$root;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;

col "CON_NAME" format a10
col "DF_NAME" format a60
select con.NAME "CON_NAME", df.FILE#, ts.NAME "TS_NAME", df.NAME "DF_NAME"
from v\$datafile df, v\$tablespace ts, V\$CONTAINERS con
where df.TS#=ts.TS# AND df.CON_ID=con.CON_ID and ts.CON_ID=con.CON_ID
order by 1,2,3;

select con.NAME "CON_NAME", df.FILE#, ts.NAME "TS_NAME", df.NAME "DF_NAME"
from v\$tempfile df, v\$tablespace ts, V\$CONTAINERS con
where df.TS#=ts.TS# AND df.CON_ID=con.CON_ID and ts.CON_ID=con.CON_ID
order by 1,2,3;

select display_value from v\$parameter where name='control_files';

exit
RUNSQL

	else
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET LINES 150
SET PAGES 200
WHENEVER SQLERROR EXIT
SPOOL $vOutputLog APPEND

REM ********************************
REM *** Turn on Archive Log Mode ***
REM ********************************

startup mount;
alter database archivelog;
alter database open;
select name, dbid, open_mode, log_mode from V\$DATABASE;

-- database checks
col "DF_NAME" format a60
select df.FILE#, ts.NAME "TS_NAME", df.NAME "DF_NAME"
from v\$datafile df, v\$tablespace ts
where df.TS#=ts.TS#
order by 1,2,3;

select df.FILE#, ts.NAME "TS_NAME", df.NAME "DF_NAME"
from v\$tempfile df, v\$tablespace ts
where df.TS#=ts.TS#
order by 1,2,3;

select display_value from v\$parameter where name='control_files';

exit
RUNSQL
	fi

	# confirm DB in archive log mode
	vLogMode=$( $ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select log_mode from v\$database;
exit;
EOF
)
	
	if [[ $vLogMode != 'ARCHIVELOG' ]]
	then
		echo "" | tee -a $vOutputLog
		echo "ERROR: The database is NOT in archive log mode. The status is $vLogMode." | tee -a $vOutputLog
		echo "       Please fix this and restart the script." | tee -a $vOutputLog
		exit 1
	fi
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ RMAN Function ###################################
# PURPOSE:                                                                   #
# This function takes an RMAN backup with connection to catalog.             #
##############################################################################

function rman_catalog_fnc {
	echo "" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	echo "* Taking RMAN backup         *"  | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	
	$ORACLE_HOME/bin/rman >> ${vOutputLog} << RUNRMAN
CONNECT TARGET '/ as sysdba'
CONNECT CATALOG '$vRMANUser/$vRmanPwd@$vRMANSid'

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
REGISTER DATABASE;
ALTER DATABASE OPEN;
LIST DB_UNIQUE_NAME ALL;
REPORT SCHEMA;

CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE MAXSETSIZE TO 32G;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE DEVICE TYPE DISK PARALLELISM 3;
CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${Backupdir}/control_%d_%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '${Backupdir}/BK_%d_%s_%p_%t';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${Backupdir}/snap_${ORACLE_SID}.f';
CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET;
SHOW ALL;

backup
  incremental level 0 database plus archivelog;
delete noprompt force obsolete;
show all;
report schema;

exit
RUNRMAN
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ RMAN Function ###################################
# PURPOSE:                                                                   #
# This function takes an RMAN backup w/o catalog connection.                 #
##############################################################################

function rman_nocat_fnc {
	echo "" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	echo "* Taking RMAN backup         *"  | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	
	$ORACLE_HOME/bin/rman >> ${vOutputLog} << RUNRMAN
CONNECT TARGET '/ as sysdba'

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
REGISTER DATABASE;
ALTER DATABASE OPEN;
LIST DB_UNIQUE_NAME ALL;
REPORT SCHEMA;

CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE MAXSETSIZE TO 32G;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE DEVICE TYPE DISK PARALLELISM 3;
CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${Backupdir}/control_%d_%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '${Backupdir}/BK_%d_%s_%p_%t';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${Backupdir}/snap_${ORACLE_SID}.f';
CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET;
SHOW ALL;

backup
  incremental level 0 database plus archivelog;
delete noprompt force obsolete;
show all;
report schema;

exit
RUNRMAN
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ TNSNAMES Function ###############################
# PURPOSE:                                                                   #
# This function adds the CDB and PDB to the tnsnames.ora file.               #
##############################################################################

function tnsnames_fnc {
	echo "" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	echo "* Updating tnsnames.ora file *" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog

	# Append the PDB to the tnsnames.ora
	${vTNSScriptDir}/tns_update_auto.sh $vPDBName $vSDGroup $vSystemPwd | tee -a $vOutputLog
	# Check for errors
	tnsping $vPDBName | tee -a $vOutputLog
	
	# If 12c, append the CDB to the tnsnames.ora
	if [[ $vDBVersion -eq 12 ]]
	then
		${vTNSScriptDir}/tns_update_auto.sh $vCDBName $vSDGroup $vSystemPwd | tee -a $vOutputLog
		# Check for errors
		tnsping $vCDBName | tee -a $vOutputLog
	fi
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Missing Files Function ##########################
# PURPOSE:                                                                   #
# This function pauses the script if there are files missing.                #
##############################################################################

function missing_files_fnc {
	# Pause if files from AIX are missing
	if [[ vMissingFiles = "TRUE" ]]
	then
		echo ""
		echo "WARNING! Some of the files from AIX are missing. Please copy them to $vDBScripts before continuing."
		echo "         If you skip this step, the next section WILL fail."
		echo ""
		echo "The existing files are:"
		ls -l $vDBScripts
		echo -e "Type (Y) and Enter when you're ready to continue? \c"
		
		while true
		do
			read vConfirm
			if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
			then
				echo "Continuing..."  | tee -a $vOutputLog
				break
			else
				echo -e "Still waiting...\c"  
			fi
		done
	fi
}

############################ Metadata Function ###############################
# PURPOSE:                                                                   #
# This function imports the metadata.                                        #
##############################################################################

function import_meta_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing AIX metadata        *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create data pump param file
	echo "logfile=${vDPMetaLog}" > $vDPImpMeta
	echo "directory=CNO_MIGRATE" >> $vDPImpMeta
	echo "dumpfile=${vDPMetaDump}" >> $vDPImpMeta
	echo "METRICS=Y" >> $vDPImpMeta
	echo "INCLUDE=DB_LINK" >> $vDPImpMeta
	echo "FULL=Y" >> $vDPImpMeta
	echo "CONTENT=METADATA_ONLY" >> $vDPImpMeta

	# Recreate objects from AIX
	echo "" | tee -a $vOutputLog
	echo "Creating users, roles, synonyms and logon triggers..." | tee -a $vOutputLog
	$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
spool $vOutputLog append
create or replace DIRECTORY CNO_MIGRATE as '$vDPParDir';
create or replace DIRECTORY RUN_DIR as '${RUNDIR}';
@${vCreateUsers}
@${CREATEQUOTAS}
@${CREATEROLES}
@${CREATEGRANTS}
@${CREATESYSPRIVS}
@${CREATESYNS}
--@${CREATELOGON}
@${vProxyPrivs}
@${vCreateACL}
spool off
exit;
EOF

	# import metadata and db links
	vConnect="ggs/${vGGSPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpMeta}
	
	# check log for errors
	cat ${vDPParDir}/${vDPMetaLog} >> $vOutputLog
	dp_error_check_fnc ${vDPParDir}/${vDPMetaLog} $vErrorLog $vCritLog
}

############################ Import Data Function ############################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing AIX data            *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# import data
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpPar}

	# check log for errors
	cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
	dp_error_check_fnc ${vDPParDir}/${vDPDataLog} $vErrorLog $vCritLog

	# disable trigger, revoke privileges and check objects
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
spool $vOutputLog append
alter session set container=${vPDBName};
@${DISABLETRIGGERS}
WHENEVER SQLERROR CONTINUE
@${REVOKESYSPRIVS}
@$ORACLE_HOME/rdbms/admin/utlrp.sql
spool off
exit;
EOF
	else
		$ORACLE_HOME/bin/sqlplus "/ as sysdba" << EOF
spool $vOutputLog append
@${DISABLETRIGGERS}
WHENEVER SQLERROR CONTINUE
@${REVOKESYSPRIVS}
@$ORACLE_HOME/rdbms/admin/utlrp.sql
spool off
exit;
EOF
	fi

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ OEM Job Function ################################
# PURPOSE:                                                                   #
# This function adds DB and RMAN job to OEM.                                 #
##############################################################################

function add_oem_fnc {
	echo "" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	echo "* Updating tnsnames.ora file *" | tee -a $vOutputLog
	echo "******************************" | tee -a $vOutputLog
	
	# Create OEM job template for the DB
	vDBJobDetails="${vDBScripts}/rman_coldfull_${vCDBFull}.txt"
	# sed "s/<newcdb>/${vCDBName}/g" $vColdTemplate > $vDBJobDetails | tee -a $vOutputLog
	
	# Use EM command-line utility to add DB to OEM and create weekly RMAN backup job
	#$OMS_HOME/bin/emcli login -username="sysman" -password="$vSysmanPwd" | tee -a $vOutputLog
	#$OMS_HOME/bin/emcli add_target -name="$vCDBName" -type="oracle_database" -host="$vOEMHost" -credentials="UserName:dbsnmp;password:${vDBSNMPPwd};Role:Normal" -properties="SID:${vCDBName};Port:1521;OracleHome:${ORACLE_HOME};MachineName:${vOEMHost}" | tee -a $vOutputLog
	#$OMS_HOME/bin/emcli create_job -input_file=property_file:${vDBJobDetails} | tee -a $vOutputLog
	#$OMS_HOME/bin/emcli logout | tee -a $vOutputLog
	#
	## check log for errors
	#error_check_fnc $vOutputLog $vErrorLog $vCritLog
	#echo "COMPLETE" | tee -a $vOutputLog
}

############################ Pure Storage Check ##############################
# PURPOSE:                                                                   #
# This function runs a recommendation from Pure Storage doc.                 #
##############################################################################

function pure_check_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Running Pure recommendation   *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" >> $vOutputLog << RUNSQL
alter session set container=cdb\$root;
SET SERVEROUTPUT ON
SET TIMING ON
DECLARE
	lat INTEGER;
	iops INTEGER;
	mbps INTEGER;
BEGIN
	DBMS_RESOURCE_MANAGER.CALIBRATE_IO (1000, 10, iops, mbps, lat);
	DBMS_OUTPUT.PUT_LINE ('max_iops = ' || iops);
	DBMS_OUTPUT.PUT_LINE ('latency = ' || lat);
	dbms_output.put_line('max_mbps = ' || mbps);
end;
/
RUNSQL

	else
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" >> $vOutputLog << RUNSQL
SET SERVEROUTPUT ON
SET TIMING ON
DECLARE
	lat INTEGER;
	iops INTEGER;
	mbps INTEGER;
BEGIN
	DBMS_RESOURCE_MANAGER.CALIBRATE_IO (1000, 10, iops, mbps, lat);
	DBMS_OUTPUT.PUT_LINE ('max_iops = ' || iops);
	DBMS_OUTPUT.PUT_LINE ('latency = ' || lat);
	dbms_output.put_line('max_mbps = ' || mbps);
end;
/
RUNSQL

	fi
}

############################ Summary Function ################################
# PURPOSE:                                                                   #
# This function displays summary.                                            #
##############################################################################

function summary_fnc {
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Final items                                    *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog

	# run pure recommended check in background
	(pure_check_fnc &)

	# get database version
	ORACLE_FULL_VERSION=$($ORACLE_HOME/bin/sqlplus -s "sys/$vSysPwd as sysdba" <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select version from v\$instance;
exit;
EOF
)

	# delete data pump logs
	echo -e "Do you want to delete the data pump dump files? (Y) or (N) \c"
	while true
	do
		read vConfirm
		if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
		then
			echo "Deleteing dump files from $vDPParDir"  | tee -a $vOutputLog
			rm ${vDPParDir}/*.dmp
			break
		elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
		then
			echo " "
			echo "Dump files will NOT be deleted"  | tee -a $vOutputLog
			break
		else
			echo -e "Please enter (Y) or (N).\c"  
		fi
	done
	
	# Report Timing of Script
	vEndSec=$(date '+%s')
	vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
	show_time $vRunSec

	echo "" | tee -a $vOutputLog
	echo "***************************************" | tee -a $vOutputLog
	echo "$0 is now complete." | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "CDB Name:             $vCDBName" | tee -a $vOutputLog
		echo "PDB Name:             $vPDBName" | tee -a $vOutputLog
	else                        
		echo "Database Name:        $vPDBName" | tee -a $vOutputLog
	fi
	echo "Version:              $ORACLE_FULL_VERSION" | tee -a $vOutputLog
	echo "Data Pump Directory:  $vDPParDir" | tee -a $vOutputLog
	# echo "Started:              $NOWwSECs" | tee -a $vOutputLog
	# echo "Finished:             $ENDwSECs" | tee -a $vOutputLog
	echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
	echo "***************************************" | tee -a $vOutputLog
}

############################ Variable Function ###############################
# PURPOSE:                                                                   #
# This function sets variables.                                              #
##############################################################################

function variables_fnc {
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Verify script variables                        *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog

	# reset array variables
	unset vDirArray
	
	# set output log names
	vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
	vLogDir="${vScriptDir}/logs"
	vOutputLog="${vLogDir}/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
	vErrorLog="${vLogDir}/${vBaseName}_${vPDBName}_err.log"
	vCritLog="${vLogDir}/${vBaseName}_${vPDBName}_crit.log"

	# Create log directory if they do not exist
	df -h $vLogDir
	if [ $? -ne 0 ]
	then
		echo "Making directory $vLogDir"
		mkdir $vLogDir
		if [ $? -ne 0 ]
		then
			echo "ERROR: There was an error creating $vLogDir!"
			exit 1
		fi
	fi

	# set CDB variable based on DB version
	vCDBName="$vPDBName"
	vCDBFull=$vCDBName

	# check length of CDB name
	vNameLength=$(echo -n $vCDBName | wc -c)
	if [[ $vNameLength -gt $MAXNAMELENGTH ]]
	then
			echo "ERROR: The CDB name, $vCDBName, is too long! The max length is $MAXNAMELENGTH."
			exit 1
	fi

	# set environment variables
	vPfileLoc="/database/${vCDBFull}_admn01/admin/pfile"
	vEnvScriptPDB="${vEnvScriptDir}/set${vPDBName}.sh"
	vEnvScriptCDB="${vEnvScriptDir}/set${vCDBName}.sh"
	vDirArray+=($vPfileLoc)

	# Files from AIX host
	vDBScripts="/database/${vCDBFull}_admn01/scripts"
	TARFILE="/tmp/Linux_setup_${vPDBName}.tar"
	vRedoLogs="${vDBScripts}/redologs_${vPDBName}.out"
	vSetParam="${vDBScripts}/setparam_${vPDBName}.sql"
	vCreateTbs="${vDBScripts}/createts_${vPDBName}.sql"
	vUndoSize="${vDBScripts}/undosize_${vPDBName}.sql"
	vTempSize="${vDBScripts}/tempsize_${vPDBName}.sql"
	vTSGroups="${vDBScripts}/tsgroups_${vPDBName}.sql"
	vCreateACL=${vDBScripts}/create_acls_${vPDBName}.sql
	vSysObjects="${vDBScripts}/sysobjects_${vPDBName}.sql"
	vProxyPrivs="${vDBScripts}/grant_proxy_privs_${vPDBName}.sql"
	vCreateUsers="${vDBScripts}/3_create_users_${vPDBName}.sql"
	vCreateCommonUsers="${vDBScripts}/create_common_users_${vPDBName}.sql"
	CREATEQUOTAS="${vDBScripts}/4_create_quotas_${vPDBName}.sql"
	CREATEGRANTS="${vDBScripts}/6_create_grants_${vPDBName}.sql"
	CREATESYSPRIVS="${vDBScripts}/7_create_sys_privs_tousers_${vPDBName}.sql"
	REVOKESYSPRIVS="${vDBScripts}/revoke_sys_privs_${vPDBName}.sql"
	DISABLETRIGGERS="${vDBScripts}/8_disable_triggers_${vPDBName}.sql"
	ENABLETRIGGERS="${vDBScripts}/8_enable_triggers_${vPDBName}.sql"
	CREATESYNS="${vDBScripts}/10_create_synonyms_${vPDBName}.sql"
	CREATEROLES="${vDBScripts}/5_create_roles_metadata_${vPDBName}.sql"
	CREATELOGON="${vDBScripts}/12_create_logon_triggers_${vPDBName}.sql"
	vDefaultDates="${vDBScripts}/default_dates_${vPDBName}.log"
	vRefreshGroups="${vDBScripts}/create_refresh_groups_${vPDBName}.sql"
	vDirArray+=($vDBScripts)

	# create command for copying critical errors
	vGawkCmd="gawk '!/"
	i=1
	for vErrorCheck in ${vErrIgnore[@]}
	do
		if [[ i -eq 1 ]]
		then
			vGawkCmd="$vGawkCmd($vErrorCheck)"
		else
			vGawkCmd="$vGawkCmd|($vErrorCheck)"
		fi
		(( i += 1 ))
	done
	# add additional errors for data pump error check
	i=1
	vGawkPumpCmd="$vGawkCmd"
	for vErrorCheck in ${vErrPumpIgnore[@]}
	do
		vGawkPumpCmd="$vGawkPumpCmd|($vErrorCheck)"
		(( i += 1 ))
	done
	vGawkCmd="$vGawkCmd/' $vErrorLog > $vCritLog"
	vGawkPumpCmd="$vGawkPumpCmd/' $vErrorLog > $vCritLog"
	
	# set data pump variables
	DMPDIR="${GGMOUNT}/datapump"
	vDPParDir="${DMPDIR}/${vPDBName}"
	vDPDataLog="impdp_${vPDBName}.log"
	vDPMetaLog="impdp_metadata_db_link_${vPDBName}.log"
	vDPDataDump="${vPDBName}_%U.dmp"
	vDPMetaDump="${vPDBName}_metadata_%U.dmp"
	vDPImpPar="${vDBScripts}/impdp_${vPDBName}.par"
	vDPImpMeta="${vDBScripts}/impdp_metadata_db_link_${vPDBName}.par"
}

############################ Confirmation Function ###########################
# PURPOSE:                                                                   #
# This function sets confirms variables.                                     #
##############################################################################

function confirmation_fnc {
	# Display user entries
	if [ -f $vOutputLog ]
	then
		rm $vOutputLog | tee -a $vOutputLog
	fi
	echo "" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	echo "Today is `date`"  | tee -a $vOutputLog
	echo "You have entered the following values:"
	echo "Database Name:        $vPDBName" | tee -a $vOutputLog
	echo "Oracle Version:       11g" | tee -a $vOutputLog
	echo "Character Set:        $vCharSet" | tee -a $vOutputLog
	echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
	echo "Datafiles:            /database/${vCDBFull}01/oradata" | tee -a $vOutputLog
	echo "Data Pump Directory:  $vDPParDir" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog

	# Confirmation
	echo ""
	echo -e "Are these values correct? (Y) or (N) \c"
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
			echo -e "Please enter (Y) or (N).\c"  
		fi
	done
}

############################ Check Variables Function ########################
# PURPOSE:                                                                   #
# This function checks variables.                                            #
##############################################################################

function check_vars_fnc {
	############################ Oracle Variables ############################
	export ORACLE_SID=$vCDBName
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
	export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
	export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
	echo $ORACLE_SID
	
	############################ Array variables ############################
	
	# Set directory array
	unset vDirArray
	vDirArray+=(/database/${vCDBFull}_admn01) 
	vDirArray+=(/database/${vCDBFull}_redo01) 
	vDirArray+=(/database/${vCDBFull}_redo02) 
	vDirArray+=(/database/${vCDBFull}_arch01) 
	vDirArray+=($vScriptDir)
	vDirArray+=($vEnvScriptDir)
	vDirArray+=($RUNDIR)
	vDirArray+=($GGMOUNT)

	# Add Oracle Home and data mount points to array based on DB version
	if [[ $vDBVersion -eq 12 ]]
	then
		vDirArray+=($vHome12c)
		vDirArray+=(/database/${vCDBFull}01)
		#vDirArray+=(/database/${vPDBName}01)
	else
		vDirArray+=($vHome11g)
	fi
	vDataDirs=$(df -h /database/${vPDBName}0* | grep ${vPDBName} | awk '{ print $7}')
	for vDirName in ${vDataDirs[@]}
	do
		vDirArray+=($vDirName)
	done
	
	# Set file array
	unset vFileArray
	vFileArray+=(${vEnvScriptDir}/setnewdb.sh)
	vFileArray+=($ORATAB)
	if [[ $vDBVersion -eq 12 ]]
	then
		vFileArray+=($vInit12c)
	else
		vFileArray+=($vInit11g)
	fi
	
	# check permissions of data pump file
	echo "Current permissions of ${vDPParDir}" | tee -a $vOutputLog
	ls -l ${vDPParDir} | tee -a $vOutputLog
	# change permissions of data pump dump files
	# sudo su - -c "chmod 777 ${vDPParDir}/${vPDBName}_*.dmp"
	sudo su - -c "chown -R oracle:dba ${vDPParDir}"
	if [ $? -ne 0 ]
	then
		echo "WARNING: Could not change ownership of ${vDPParDir}" | tee -a $vOutputLog
		# exit 1
	else
		echo "Successfully changed ownership of ${vDPParDir}" | tee -a $vOutputLog
	fi
	sudo su - -c "chmod -R 777 ${vDPParDir}"
	if [ $? -ne 0 ]
	then
		echo "WARNING: Could not change permissions on ${vDPParDir}" | tee -a $vOutputLog
		# exit 1
	else
		echo "Successfully changed permissions on ${vDPParDir}" | tee -a $vOutputLog
		ls -l ${vDPParDir} | tee -a $vOutputLog
	fi
	# check permissions
	touch ${vDPParDir}/test.txt
	if [ $? -ne 0 ]
	then
		echo "ERROR: Not able to write to ${vDPParDir}" | tee -a $vOutputLog
		echo "       Please change permissions then restart the script. Work with Unix team if need be." | tee -a $vOutputLog
		exit 1
	else
		echo "Permissions are good on ${vDPParDir}" | tee -a $vOutputLog
		rm ${vDPParDir}/test.txt
	fi
}

############################ Data Verify Function ############################
# PURPOSE:                                                                   #
# This function verifies the data.                                           #
##############################################################################

function verify_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Verify data in $vPDBName               *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog

#	export ORACLE_SID=$vPDBName
#	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << RUNSQL
SET ECHO ON
SET DEFINE ON
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
SPOOL $vOutputLog APPEND

SET DEFINE OFF
SET TIMING ON
-- insert Linux object info
insert into $vLinuxObjectTable
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null
and (owner, object_name, object_type) not in
(select owner, object_name, object_type from DBA_OBJECTS where owner='PUBLIC' and object_type='SYNONYM');
commit;

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
select distinct grantee, owner, table_name, privilege
from dba_tab_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and owner not in ($vExcludeUsers)
UNION
select distinct grantee, 'n/a', 'n/a', privilege
from dba_sys_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles);
commit;

-- insert Linux role counts
insert into $vLinuxRolesTable
select distinct granted_role, grantee, admin_option, default_role
from dba_role_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles);
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
	--dbms_output.put_line(sql_str);
    execute immediate sql_str into record_count;
    --dbms_output.put_line(rec.owner || ',' || rec.table_name || ',' || rec.status || ',' || record_count);
    insert into $vLinuxRowTable
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
      commit;
  end loop;
  close cf;
end;
/

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

select 'There are '||count(*)||' tables.' "TABLES" from $vLinuxRowTable;
select 'There are '||count(*)||' objects.' "OBJECTS" from $vLinuxObjectTable;
select 'There are '||count(*)||' indexes.' "INDEXES" from $vLinuxIndexTable;
select 'There are '||count(*)||' constraints.' "CONSTRAINTS" from $vLinuxConstraintTable;
select 'There are '||count(*)||' privileges.' "PRIVILEGES" from $vLinuxPrivilegeTable;
select 'There are '||count(*)||' roles.' "ROLES" from $vLinuxRolesTable;

-- Table count comparison
col "TABLE" format a40
col "12C" format 999,999,990
col "11G" format 999,999,990
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.RECORD_COUNT "12C", lx.RECORD_COUNT "11G", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFFERENCE"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.RECORD_COUNT!=aix.RECORD_COUNT and lx.owner not in ('GGS','GGTEST')
order by 1;

-- Index count comparison
col "12C-INDEX" format a50
col "11G-INDEX" format a50
select aix.OWNER||'.'||aix.INDEX_NAME "12C-INDEX", lx.OWNER||'.'||lx.INDEX_NAME "11G-INDEX"
from $vLinuxIndexTable lx full outer join $vIndexTable aix
  on aix.OWNER=lx.OWNER and aix.INDEX_NAME=lx.INDEX_NAME
where lx.INDEX_NAME is null and lx.owner not in ('GGS','GGTEST')
order by aix.OWNER, aix.INDEX_NAME, lx.OWNER, lx.INDEX_NAME;

-- Table status comparison
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.STATUS "12C", lx.STATUS "11G"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGS','GGTEST')
order by 1;

-- Object status comparison
col "OBJECT_NAME" format a40
select aix.OBJECT_TYPE, aix.OWNER||'.'||aix.OBJECT_NAME "OBJECT_NAME", aix.STATUS "12C", lx.STATUS "11G"
from $vLinuxObjectTable lx full outer join $vObjectTable aix
  on aix.OWNER=lx.OWNER and aix.OBJECT_NAME=lx.OBJECT_NAME and aix.OBJECT_TYPE=lx.OBJECT_TYPE
where lx.STATUS!=aix.STATUS and lx.STATUS!='VALID' and lx.owner not in ('GGS','GGTEST')
order by aix.OBJECT_TYPE, aix.OWNER, aix.OBJECT_NAME;

-- Constraint comparison
select lx.owner, lx.table_name, lx.constraint_name, lx.constraint_type, aix.STATUS "12C", lx.STATUS "11G"
from $vLinuxConstraintTable lx full outer join $vConstraintTable aix
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.constraint_name=lx.constraint_name
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGS','GGTEST')
order by 1;

-- Privilege comparison
col "GRANTEE" format a30
col "12C_PRIVILEGE" format a48
col "11G_PRIVILEGE" format a48
select NVL(aix.grantee,lx.grantee) "GRANTEE", 
NVL2(aix.privilege,
	CASE aix.owner
		WHEN 'n/a' THEN aix.privilege
		ELSE aix.privilege||' on '||aix.owner||'.'||aix.table_name
	END
	,'-') "12C_PRIVILEGE", 
NVL2(lx.privilege,
	CASE lx.owner
		WHEN 'n/a' THEN lx.privilege
		ELSE lx.privilege||' on '||lx.owner||'.'||lx.table_name
	END
	,'-') "11G_PRIVILEGE"
from $vLinuxPrivilegeTable lx full outer join $vPrivilegeTable aix
	on aix.grantee=lx.grantee and aix.owner=lx.owner and aix.table_name=lx.table_name and aix.privilege=lx.privilege
where lx.grantee is null or aix.grantee is null
and lx.privilege not in ('SET CONTAINER','CREATE SESSION','SELECT ANY DICTIONARY')
order by 1,2;

-- Role comparison
col "12C_ROLE" format a30
col "11G_ROLE" format a30
select NVL(aix.grantee,lx.grantee) "GRANTEE", aix.granted_role "12C_ROLE", lx.granted_role "11G_ROLE"
from $vLinuxRolesTable lx full outer join $vRolesTable aix
	on aix.grantee=lx.grantee and aix.granted_role=lx.granted_role
where lx.grantee is null or aix.grantee is null
order by 1,2;

SPOOL OFF

exit;
RUNSQL

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog
	
	# confirm data verification
	echo ""
	echo "Please resolve all above discrepancies before cutover"
	continue_fnc
	
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Verify database links in $vPDBName              *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	
	# check database links
	vDBLinks=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT db_link FROM dba_db_links;
EXIT;
RUNSQL
)

	for checkarray in ${vDBLinks[@]}
	do
		vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${checkarray};
EXIT;
RUNSQL
)
		if [[ $vLinkTest != "1" ]]
		then
			vHSLinkCheck=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dba_db_links where host like '%HS%' and db_link='${checkarray}';
EXIT;
RUNSQL
)
			if [[ $vHSLinkCheck != "1" ]]
			then
				echo "$checkarray needs to be fixed!" | tee -a $vOutputLog
			else
				echo "Heterogeneous link $checkarray needs to be fixed!" | tee -a $vOutputLog
			fi
		fi
	done
	
	# confirm db links
	echo ""
	echo "Please resolve all above discrepancies before cutover"
	if [[ -e ${vDBScripts}/create_db_links_${vPDBName}.log ]]
	then
		echo "The file ${vDBScripts}/create_db_links_${vPDBName}.log has the DDL for creating all DB links."
	fi
	continue_fnc
	
	echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Checking for refresh groups in $vPDBName       *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog

	# check refresh groups
	vRGCount=$(wc -l $vRefreshGroups | awk '{print $1}')
	if [[ $vRGCount -gt 0 ]]
	then
		echo "This database has refresh groups." | tee -a $vOutputLog
		echo "If there were ORA-39083 and ORA-23421 errors in the import, use $vRefreshGroups to create them." | tee -a $vOutputLog
		echo "You must remove the section with the job number, e.g. 'job=>225'." | tee -a $vOutputLog
		continue_fnc
	else
		echo "" | tee -a $vOutputLog
		echo "No refresh groups exist" | tee -a $vOutputLog
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
unset TWO_TASK

############################ Set host variables ############################
export EDITOR=vim
vPrefix=`hostname | awk '{ print substr( $0, length($0) - 5, length($0) ) }' | cut -c 1- | tr 'A-Z' 'a-z'`

############################ Start Menu ############################

while :
do
	echo ""
    echo -e "\tWhere would you like to start/continue this script?"
    echo -e "\t---------------------------------------------"
    echo -e "\t1) Beginning"
    echo -e "\t2) Create the Database"
	echo -e "\t4) Create DB Objects"
	echo -e "\t8) Prep Database for GG"
	echo -e "\t9) Import 12C data and metadata"
	echo -e "\t10) Import 12C data only"
	echo -e "\t12) Verify data"
	echo -e "\tq) Quit"
    echo
    echo -e "\tEnter your selection: r\b\c"
    read selection
    if [[ -z "$selection" ]]
        then selection=r
    fi

    case $selection in
        1)  prompt_short_fnc
			# prompt_tns_fnc
			# prompt_rman_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			create_dirs_fnc
			aix_files_fnc
			create_files_fnc
			dup_db_fnc
			update_param_fnc
			create_ts_fnc
			# archive_fnc
			# tnsnames_fnc
			# rman_catalog_fnc
			missing_files_fnc
			import_meta_fnc
			import_data_fnc
			# add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        2)  prompt_short_fnc
			# prompt_tns_fnc
			# prompt_rman_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			shutdown_db_fnc
			dup_db_fnc
			update_param_fnc
			create_ts_fnc
			# archive_fnc
			# tnsnames_fnc
			# rman_catalog_fnc
			missing_files_fnc
			import_meta_fnc
			import_data_fnc
			# add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
		4)  prompt_short_fnc
			# prompt_tns_fnc
			# prompt_rman_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			create_ts_fnc
			# archive_fnc
			# tnsnames_fnc
			# rman_catalog_fnc
			missing_files_fnc
			import_meta_fnc
			import_data_fnc
			#add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
			;;
        8)  prompt_short_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			missing_files_fnc
			import_meta_fnc
			import_data_fnc
			#add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
		9)  prompt_short_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			import_meta_fnc
			import_data_fnc
			#add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
		10)  prompt_short_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			import_data_fnc
			#add_oem_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
		12) prompt_short_fnc
			# prompt_oem_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
      q|Q)  echo "You have chosen to quit"
            exit
            ;;
        *)  echo -e "\n Invalid selection"
            sleep 1
            ;;
    esac
done



