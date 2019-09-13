#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GGRR_3_RR_start_extract_Linux.sh
#
#  DESCRIPTION
#    Start GG extract on Linux DB host
#
#  NOTES
#    Run as oracle
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         03/18/17 - Created
#
# PREREQUISITES
#
#  STEPS
#    1. 
#================================================================================================#

vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')

############################ Oracle Constants ############################
export ORACLE_BASE="/app/oracle"
export TNS_ADMIN=/app/oracle/tns_admin
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHome11g="${ORACLE_BASE}/product/db/11g/1"
vCDBPrefix="c"
MAXNAMELENGTH=8

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts"
vUpgradeDir="${vScriptDir}/12cupgrade"
vLogDir="${vUpgradeDir}/logs"
vUpgradeDir="/app/oracle/scripts/12cupgrade"
vAIXGGHome="/nomove/app/oracle/ggate/12c/1"
gORATABFILE="/etc/oratab"

vMissingFiles="FALSE"

vLinuxObjectTable="GGTEST.OBJECT_COUNT_LINUX"
vLinuxRowTable="GGTEST.ROW_COUNT_LINUX"

vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE'"

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

# GoldenGate variables
GGMGROUT="${vLogDir}/GGMGROUT.out"
if [[ -e $GGMGROUT ]]
then
	rm $GGMGROUT
fi
GGRUNNING="TRUE"

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

############################ Prompt All Function #############################
# PURPOSE:                                                                   #
# This function prompts the user for all inputs.                             #
##############################################################################

function prompt_fnc {
	# shows DB running
	/app/oracle/scripts/pmonn.pm
	
	# Prompt for new DB name
	echo ""
	echo -e "Enter the new database name (use the PDB name for 12c): \c"  
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
	echo ""
	echo -e "Select the Oracle version for this database: (a) 12c (b) 11g \c"
	while true
	do
		read vReadVersion
		if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
		then
			# set GG home
			export GGATE=$GGATE12
			vDBVersion=12
			vGGHostPort=7819
			break
		elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
		then
			# set GG home
			export GGATE=$GGATE11
			vDBVersion=11
			vGGHostPort=7919
			break
		else
			echo -e "Select a valid database version: \c"  
		fi
	done
	
	# Prompt for character set
	echo ""
	echo "Please select the character set of the AIX database.  Run this if you don't know:"
	echo "select value from nls_database_parameters where parameter='NLS_CHARACTERSET';"
	echo ""
	echo "   (a) AL32UTF8"
	echo "   (b) US7ASCII"
	echo "   (c) WE8ISO8859P1"
	echo "   (d) other"
	while true
	do
		read vCharSetSelect
		if [[ "$vCharSetSelect" == "A" || "$vCharSetSelect" == "a" ]]
		then
			vOldCS=AL32UTF8
			break
		elif [[ "$vCharSetSelect" == "B" || "$vCharSetSelect" == "b" ]]
		then
			vOldCS=US7ASCII
			break
		elif [[ "$vCharSetSelect" == "C" || "$vCharSetSelect" == "c" ]]
		then
			vOldCS=WE8ISO8859P1
			break
		elif [[ "$vCharSetSelect" == "D" || "$vCharSetSelect" == "d" ]]
		then
			echo -e "Enter the character set: \c"
			read vOldCS
			if [[ -n "$vOldCS" ]]
			then
				break
			else
				echo -e "Enter a valid option: \c"  
			fi
		else
			echo -e "Choose a valid option: \c"  
		fi
	done
	
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
		echo -e "Enter the password for the GGS user :"
		stty -echo
		read vGGSPwd
		if [[ -n "$vGGSPwd" ]]
		then
			break
		else
			echo -e "You must enter a password\n"
		fi
	done
	stty echo
}

############################ GoldenGate Manager Check ########################
# PURPOSE:                                                                   #
# This function makes sure GG manager is running.                            #
##############################################################################

function gg_mgr_check_fnc {
	echo ""
	echo "*********************************"
	echo "* Checking GG manager           *"
	echo "*********************************"
	
	# Check that GG manager is running
	cd $GGATE
	./ggsci > $GGMGROUT << EOF
info mgr
exit
EOF

	sleep 5
	GGMGRSTATUS=$(cat $GGMGROUT | grep "Manager" | awk '{ print $3}')
	if [[ $GGMGRSTATUS != "running" ]]
	then
		echo "" 
		echo "The GoldenGate manager is $GGMGRSTATUS. Please fix before continuing." 
		exit 1
	else
		echo "" 
		echo "The GoldenGate manager is $GGMGRSTATUS." 
		echo "COMPLETE" 
	fi
}

############################ GoldenGate Run Check ############################
# PURPOSE:                                                                   #
# This function makes sure GG process is running.                            #
##############################################################################

function gg_run_check_fnc {
	cd $GGATE
	while true
	do
		# Check the GG status
		./ggsci > $vGGStatusOut << EOF
status extract $1
exit
EOF
		sleep 30
		vGGStatus=$(cat $vGGStatusOut | grep $1 | awk '{ print $6}')
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
		fi
	done
	cat $vGGStatusOut | tee -a $vOutputLog
	echo $vGGStatus
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

############################ GoldenGate RBA Check ############################
# PURPOSE:                                                                   #
# This function makes sure GG process is moving.                             #
##############################################################################

function gg_rba_check_fnc {
	echo "Checking the status of $1" | tee -a $vOutputLog
	# variable for RBA value
	GGRBASTATUS="0"
	# variable to prevent infinite loop
	vRBACheckCt=1
	
	# check 10 times or until it moves
	while [[ $GGRBASTATUS = "0" && $vRBACheckCt -lt 10 ]]
	do
		# wait 30 seconds
		sleep 30
		# Check the GG pump info
		cd $GGATE
		./ggsci > $vGGStatusOut << EOF
info $1
exit
EOF
		# get RBA value
		GGRBASTATUS=$(cat $vGGStatusOut | grep RBA | awk '{ print $4}')
		# is this the first check?
		if [[ $vRBACheckCt -eq 1 ]]
		then
			cat $vGGStatusOut | tee -a $vOutputLog
		else
			echo "" | tee -a $vOutputLog
			echo "RBA is $GGRBASTATUS" | tee -a $vOutputLog
		fi

		# increment counter
		vRBACheckCt=`expr $vRBACheckCt + 1`
	done
	
	# change GG status if not moving
	if [[ $GGRBASTATUS = "0" ]]
	then
		GGRUNNING="FALSE"
		echo "" | tee -a $vOutputLog
		echo "WARNING: $1 is not moving. Make sure this is processing data before the cutover." | tee -a $vOutputLog
	else
		echo "" | tee -a $vOutputLog
		echo "SUCCESS: $1 is processing data." | tee -a $vOutputLog
	fi
}

############################ Parameter 12c Function ##########################
# PURPOSE:                                                                   #
# This function creates parameter fils for the GG process.                   #
##############################################################################

function create_params_12_fnc {
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET DEFINE OFF
SET ESCAPE OFF
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

alter session set container=$vPDBName;

WHENEVER SQLERROR CONTINUE
SPOOL $vOutputLog APPEND
-- re-enable triggers
@$ENABLETRIGGERS
SPOOL OFF

WHENEVER SQLERROR EXIT
SPOOL $ADDTRANDATA
select 'dblogin userid GGS@${vCDBName} password $vGGSPwd' from dual;
select distinct 'ADD SCHEMATRANDATA ${vPDBName}."'||owner||'"' from dba_tables where owner not in
($vExcludeUsers)
order by 1;
SPOOL OFF

SPOOL $EPRMFILE
select '-- Extract Name' from dual;
select 'Extract $vExtName' from dual;
select ' ' from dual;
select '-- Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "${ORACLE_HOME}")' from dual;
select 'SETENV (NLS_LANG = "AMERICAN_AMERICA.'||value||'")' from nls_database_parameters where parameter='NLS_CHARACTERSET';
select ' ' from dual;
select '-- Database Login Information. ' from dual;
select 'USERID ggs@${vCDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- EXCLUDE USER GGS FROM BEING REPLICATING BACK OR CASCADING' from dual;
select 'TRANLOGOPTIONS EXCLUDEUSER GGS' from dual;
select 'TRANLOGOPTIONS INCLUDEREGIONID' from dual;
select ' ' from dual;
select 'DISCARDFILE ./dirrpt/$vExtName.dsc, APPEND, MEGABYTES 500' from dual;
select 'DISCARDROLLOVER AT 01:00 ON sunday' from dual;
select ' ' from dual;
select 'ExtTrail $vExtTrail' from dual;
select ' ' from dual;
select '--integrated extract' from dual;
select 'LOGALLSUPCOLS' from dual;
select 'UPDATERECORDFORMAT COMPACT' from dual;
select ' ' from dual;
select '--include files' from dual;
select 'INCLUDE $vDDLInclude' from dual;
select ' ' from dual;
select '-- Report any issues with fetching' from dual;
select 'FETCHOPTIONS USESNAPSHOT, USELATESTVERSION' from dual;
select 'FETCHOPTIONS MISSINGROW REPORT' from dual;
select ' ' from dual;
select '--ReportCount Every 100000 Records' from dual;
select 'ReportCount Every 5 minutes, rate' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE ${vPDBName}.'||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select distinct 'SEQUENCE ${vPDBName}.'||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select 'TABLE ${vPDBName}.GGTEST.*;' from dual;
select ' ' from dual;
-- Heartbeat Table
select 'TABLE ${vPDBName}.gghb.GGS_HEARTBEAT,' from dual;
select 'TOKENS (' from dual;
select '         CAPGROUP = @GETENV ("GGENVIRONMENT", "GROUPNAME"),' from dual;
select '         CAPTIME =  @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '       );' from dual;
SPOOL OFF

-- create parameter file for push process
SPOOL $PPRMFILE
select '-- Use EXTRACT to specify a Pump group to send the information to the target' from dual;
select 'EXTRACT $vPushName' from dual;
select ' ' from dual;
select '-- Database Login Information.' from dual;
select 'USERID ggs@${vCDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- Use RMTHOST to identify a remote system and the TCP/IP port number on that system where the Manager process is running.' from dual;
select 'RMTHOST $GGHOST, MGRPORT $vGGHostPort, TCPBUFSIZE 1000000, TCPFLUSHBYTES 1000000' from dual;
select ' ' from dual;
select '-- Use RMTTRAIL to specify a remote trail that was created with the ADD RMTTRAIL command in GGSCI.' from dual;
select 'RMTTRAIL $vRmtTrail' from dual;
select ' ' from dual;
select '-- Use WILDCARDRESOLVE to alter the rules for processing wildcard table' from dual;
select '-- specifications in a TABLE or MAP statement. WILDCARDRESOLVE must precede the' from dual;
select '-- associated TABLE or MAP statements in the parameter file.' from dual;
select 'WILDCARDRESOLVE DYNAMIC' from dual;
select ' ' from dual;
select 'ReportCount Every 30 Minutes, Rate' from dual;
select ' ' from dual;
select '--DDL' from dual;
select 'DDL INCLUDE ALL' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE ${vPDBName}.'||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select distinct 'SEQUENCE ${vPDBName}.'||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select 'TABLE ${vPDBName}.GGTEST.*;' from dual;
select ' ' from dual;
select '-- Heartbeat Table' from dual;
select 'table ${vPDBName}.gghb.ggs_heartbeat,' from dual;
select '   TOKENS (' from dual;
select '            PMPGROUP = @GETENV ("GGENVIRONMENT","GROUPNAME"),' from dual;
select '            PMPTIME = @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '          );' from dual;
SPOOL OFF

SPOOL $RPRMFILE
select 'REPLICAT $vRepName' from dual;
select ' ' from dual;
select '-- Oracle Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "$vHome11g")' from dual;
select 'SETENV (NLS_LAG = "AMERICAN_AMERICA.$vOldCS")' from dual;
select ' ' from dual;
select '-- Use USERID to specify the type of database authentication for GoldenGate to use.' from dual;
select 'USERID ggs@${vPDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- Use DISCARDFILE to generate a discard file to which Extract or Replicat can log-- records that it cannot process. ' from dual;
select 'DISCARDFILE ./dirrpt/$vRepName.dsc, APPEND, MEGABYTES 500' from dual;
select ' ' from dual;
select '-- discard file rollover , weekly or daily' from dual;
select 'DISCARDROLLOVER AT 18:00' from dual;
select ' ' from dual;
select '-- Use REPORTCOUNT to generate a count of records that have been processed since the Extract or Replicat process started' from dual;
select 'reportcount every 15 MINUTES, rate' from dual;
select 'REPORTROLLOVER AT 01:30 ON sunday' from dual;
select ' ' from dual;
select '-- Use ASSUMETARGETDEFS when the source and target tables specified with a MAP statement have the same column structure, such as when synchronizing a hot site' from dual;
select 'ASSUMETARGETDEFS' from dual;
select ' ' from dual;
select 'DBOPTIONS INTEGRATEDPARAMS(parallelism 6)' from dual;
select 'DBOPTIONS SUPPRESSTRIGGERS' from dual;
select ' ' from dual;
select 'REPERROR DEFAULT, ABEND' from dual;
select ' ' from dual;
select 'DDL INCLUDE MAPPED' from dual;
select 'DDLERROR DEFAULT IGNORE' from dual;
select ' ' from dual;
--select 'MAPEXCLUDE ${vPDBName}.'||owner||'.'||MVIEW_NAME from dba_mviews where UPDATABLE='N' and owner not in ($vExcludeUsers) order by 1;
select 'MAPEXCLUDE ${vPDBName}.'||owner||'.'||MVIEW_NAME from dba_mviews where owner not in ($vExcludeUsers) order by 1;
select 'MAPEXCLUDE ${vPDBName}.GGTEST.OBJECT_COUNT_AIX' from dual;
select 'MAPEXCLUDE ${vPDBName}.GGTEST.ROW_COUNT_AIX' from dual;
select ' ' from dual;
select distinct 'MAP ${vPDBName}.'||owner||'.*, TARGET '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select '-- add heartbeat table' from dual;
select 'MAP ${vPDBName}.GGHB.GGS_HEARTBEAT, TARGET GGHB.GGS_HEARTBEAT_DC2,' from dual;
select 'INSERTALLRECORDS, KEYCOLS (ID, EXTRACT),' from dual;
select 'COLMAP (USEDEFAULTS,' from dual;
select '        ID = 1,' from dual;
select '        EXTRACT = "PCONCPT1",' from dual;
select '        SOURCE_COMMIT = @GETENV ("GGHEADER", "COMMITTIMESTAMP"),' from dual;
select '        CAPGROUP = @TOKEN ("CAPGROUP"),' from dual;
select '        CAPTIME = @TOKEN ("CAPTIME"),' from dual;
select '        PMPGROUP = @TOKEN ("PMPGROUP"),' from dual;
select '        PMPTIME = @TOKEN ("PMPTIME"),' from dual;
select '        DELGROUP = @GETENV ("GGENVIRONMENT", "GROUPNAME"),' from dual;
select '        DELTIME =  @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '       );' from dual;
SPOOL OFF

exit
RUNSQL
}

############################ Parameter 11g Function ##########################
# PURPOSE:                                                                   #
# This function creates parameter fils for the GG process.                   #
##############################################################################

function create_params_11_fnc {
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET DEFINE OFF
SET ESCAPE OFF
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
WHENEVER SQLERROR CONTINUE
-- re-enable triggers
@$ENABLETRIGGERS
SPOOL OFF

SPOOL $ADDTRANDATA
select 'dblogin userid GGS@${vCDBName} password $vGGSPwd' from dual;
select distinct 'ADD SCHEMATRANDATA "'||owner||'"' from dba_tables where owner not in
($vExcludeUsers)
order by 1;
SPOOL OFF

SPOOL $EPRMFILE
select '-- Extract Name' from dual;
select 'Extract $vExtName' from dual;
select ' ' from dual;
select '-- Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "${ORACLE_HOME}")' from dual;
select 'SETENV (NLS_LANG = "AMERICAN_AMERICA.'||value||'")' from nls_database_parameters where parameter='NLS_CHARACTERSET';
select ' ' from dual;
select '-- Database Login Information. ' from dual;
select 'USERID ggs@${vCDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- EXCLUDE USER GGS FROM BEING REPLICATING BACK OR CASCADING' from dual;
select 'TRANLOGOPTIONS EXCLUDEUSER GGS' from dual;
select 'TRANLOGOPTIONS INCLUDEREGIONID' from dual;
select ' ' from dual;
select 'DISCARDFILE ./dirrpt/$vExtName.dsc, APPEND, MEGABYTES 500' from dual;
select 'DISCARDROLLOVER AT 01:00 ON sunday' from dual;
select ' ' from dual;
select 'ExtTrail $vExtTrail' from dual;
select ' ' from dual;
select '--integrated extract' from dual;
select 'LOGALLSUPCOLS' from dual;
select 'UPDATERECORDFORMAT COMPACT' from dual;
select ' ' from dual;
select '--include files' from dual;
select 'INCLUDE $vDDLInclude' from dual;
select ' ' from dual;
select '-- Report any issues with fetching' from dual;
select 'FETCHOPTIONS USESNAPSHOT, USELATESTVERSION' from dual;
select 'FETCHOPTIONS MISSINGROW REPORT' from dual;
select ' ' from dual;
select '--ReportCount Every 100000 Records' from dual;
select 'ReportCount Every 5 minutes, rate' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select distinct 'SEQUENCE '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select 'TABLE GGTEST.*;' from dual;
select ' ' from dual;
-- Heartbeat Table
select 'TABLE gghb.GGS_HEARTBEAT,' from dual;
select 'TOKENS (' from dual;
select '         CAPGROUP = @GETENV ("GGENVIRONMENT", "GROUPNAME"),' from dual;
select '         CAPTIME =  @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '       );' from dual;
SPOOL OFF

-- create parameter file for push process
SPOOL $PPRMFILE
select '-- Use EXTRACT to specify a Pump group to send the information to the target' from dual;
select 'EXTRACT $vPushName' from dual;
select ' ' from dual;
select '-- Database Login Information.' from dual;
select 'USERID ggs@${vCDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- Use RMTHOST to identify a remote system and the TCP/IP port number on that system where the Manager process is running.' from dual;
select 'RMTHOST $GGHOST, MGRPORT $vGGHostPort, TCPBUFSIZE 1000000, TCPFLUSHBYTES 1000000' from dual;
select ' ' from dual;
select '-- Use RMTTRAIL to specify a remote trail that was created with the ADD RMTTRAIL command in GGSCI.' from dual;
select 'RMTTRAIL $vRmtTrail' from dual;
select ' ' from dual;
select '-- Use WILDCARDRESOLVE to alter the rules for processing wildcard table' from dual;
select '-- specifications in a TABLE or MAP statement. WILDCARDRESOLVE must precede the' from dual;
select '-- associated TABLE or MAP statements in the parameter file.' from dual;
select 'WILDCARDRESOLVE DYNAMIC' from dual;
select ' ' from dual;
select 'ReportCount Every 30 Minutes, Rate' from dual;
select ' ' from dual;
select '--DDL' from dual;
select 'DDL INCLUDE ALL' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select distinct 'SEQUENCE '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select 'TABLE GGTEST.*;' from dual;
select ' ' from dual;
select '-- Heartbeat Table' from dual;
select 'table gghb.ggs_heartbeat,' from dual;
select '   TOKENS (' from dual;
select '            PMPGROUP = @GETENV ("GGENVIRONMENT","GROUPNAME"),' from dual;
select '            PMPTIME = @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '          );' from dual;
SPOOL OFF

SPOOL $RPRMFILE
select 'REPLICAT $vRepName' from dual;
select ' ' from dual;
select '-- Oracle Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "$vHome11g")' from dual;
select 'SETENV (NLS_LAG = "AMERICAN_AMERICA.$vOldCS")' from dual;
select ' ' from dual;
select '-- Use USERID to specify the type of database authentication for GoldenGate to use.' from dual;
select 'USERID ggs@${vPDBName}, PASSWORD $vGGSPwd' from dual;
select ' ' from dual;
select '-- Use DISCARDFILE to generate a discard file to which Extract or Replicat can log-- records that it cannot process. ' from dual;
select 'DISCARDFILE ./dirrpt/$vRepName.dsc, APPEND, MEGABYTES 500' from dual;
select ' ' from dual;
select '-- discard file rollover , weekly or daily' from dual;
select 'DISCARDROLLOVER AT 18:00' from dual;
select ' ' from dual;
select '-- Use REPORTCOUNT to generate a count of records that have been processed since the Extract or Replicat process started' from dual;
select 'reportcount every 15 MINUTES, rate' from dual;
select 'REPORTROLLOVER AT 01:30 ON sunday' from dual;
select ' ' from dual;
select '-- Use ASSUMETARGETDEFS when the source and target tables specified with a MAP statement have the same column structure, such as when synchronizing a hot site' from dual;
select 'ASSUMETARGETDEFS' from dual;
select ' ' from dual;
select 'DBOPTIONS INTEGRATEDPARAMS(parallelism 6)' from dual;
select 'DBOPTIONS SUPPRESSTRIGGERS' from dual;
select ' ' from dual;
select 'REPERROR DEFAULT, ABEND' from dual;
select ' ' from dual;
select 'DDL INCLUDE MAPPED' from dual;
select 'DDLERROR DEFAULT IGNORE' from dual;
select ' ' from dual;
--select 'MAPEXCLUDE '||owner||'.'||MVIEW_NAME from dba_mviews where UPDATABLE='N' and owner not in ($vExcludeUsers) order by 1;
select 'MAPEXCLUDE '||owner||'.'||MVIEW_NAME from dba_mviews where owner not in ($vExcludeUsers) order by 1;
select 'MAPEXCLUDE GGTEST.OBJECT_COUNT_AIX' from dual;
select 'MAPEXCLUDE GGTEST.ROW_COUNT_AIX' from dual;
select ' ' from dual;
select distinct 'MAP '||owner||'.*, TARGET '||owner||'.*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select '-- add heartbeat table' from dual;
select 'MAP GGHB.GGS_HEARTBEAT, TARGET GGHB.GGS_HEARTBEAT_DC2,' from dual;
select 'INSERTALLRECORDS, KEYCOLS (ID, EXTRACT),' from dual;
select 'COLMAP (USEDEFAULTS,' from dual;
select '        ID = 1,' from dual;
select '        EXTRACT = "PCONCPT1",' from dual;
select '        SOURCE_COMMIT = @GETENV ("GGHEADER", "COMMITTIMESTAMP"),' from dual;
select '        CAPGROUP = @TOKEN ("CAPGROUP"),' from dual;
select '        CAPTIME = @TOKEN ("CAPTIME"),' from dual;
select '        PMPGROUP = @TOKEN ("PMPGROUP"),' from dual;
select '        PMPTIME = @TOKEN ("PMPTIME"),' from dual;
select '        DELGROUP = @GETENV ("GGENVIRONMENT", "GROUPNAME"),' from dual;
select '        DELTIME =  @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '       );' from dual;
SPOOL OFF

exit
RUNSQL
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

############################ User Prompts ############################

prompt_fnc

############################ Oracle Variables ############################
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
export TNS_ADMIN="${ORACLE_BASE}/tns_admin"

############################ Check GG Manager ############################

gg_mgr_check_fnc

############################ Set DB Name ############################

# set initial CDB name
if [[ $vDBVersion -eq 12 ]]
then
	# set CDB name
	vCDBName="${vCDBPrefix}${vPDBName}"
	vCDBFull=$vCDBName
	# check length of CDB name (max 8 char)
	vCDBLength=$(echo -n $vCDBName | wc -c)
	if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
	then
		# vCDBName1=$(echo -n $vCDBName | awk '{ print substr( $0, 1, 6 ) }')
		# vCDBName2=$(echo -n $vCDBName | awk '{ print substr( $0, length($0), length($0) ) }')
		# first3_last3
		vCDBName1=$(echo -n $vCDBName | awk '{ print substr( $0, 1, 4 ) }')
		vCDBName2=$(echo -n $vCDBName | awk '{ print substr( $0, length($0)-2, length($0) ) }')
		vCDBName="${vCDBName1}_${vCDBName2}"
	fi
else
	vCDBName="$vPDBName"
	vCDBFull=$vCDBName
fi
# set Oracle SID
export ORACLE_SID=$vCDBName

# Get DB home/version from oratab file
lCDBExists=`grep ^${vCDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | wc -l`
lExists=`grep ^${vPDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | wc -l`
if [[ ${lCDBExists} -eq 1 ]]
then
	# version 12
	export ORACLE_HOME=`grep ^${vCDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | cut -d: -f2`
elif [[ ${lExists} -eq 1 ]]
then
	# version 11
	export ORACLE_HOME=`grep ^${vPDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | cut -d: -f2`
else
	echo ""
	echo "ERROR: There are ${lCDBExists} occurrence(s) of ${vCDBName} and ${lExists} occurrence(s) of ${vPDBName} in ${gORATABFILE}."
	echo "       Make sure only 1 entry for the CDB or 11g database exists."
	exit 1
fi

############################ Set GG Process Names ############################

# set output log names
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${vLogDir}/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
vErrorLog="${vLogDir}/${vBaseName}_${vPDBName}_err.log"

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
vExtName="E${DBShort}2"
VarLen=$(echo $vExtName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vExtName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
fi
vPushName="P${DBShort}2"
VarLen=$(echo $vPushName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vPushName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
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

############################ Confirmation ############################

# Display user entries
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
if [[ $vDBVersion -eq 12 ]]
then
	echo "CDB Name:             $vCDBName" | tee -a $vOutputLog
	echo "PDB Name:             $vPDBName" | tee -a $vOutputLog
	echo "Database Version:     12c" | tee -a $vOutputLog
else                        
	echo "Database Name:        $ORACLE_SID" | tee -a $vOutputLog
	echo "Database Version:     11g" | tee -a $vOutputLog                            
fi                          
echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
echo "GoldenGate Home:      $GGATE" | tee -a $vOutputLog
echo "GG Extract Name:      $vExtName" | tee -a $vOutputLog
echo "GG Push Name:         $vPushName" | tee -a $vOutputLog
echo "Output Log:           $vOutputLog" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog

# Confirmation
echo ""
echo -e "Are these values correct? (Y) or (N) \c"
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
		echo -e "Please enter (Y) or (N).\c"  
	fi
done

############################ Check for patch ############################

## check for required 11g patch
#if [[ $vDBVersion -eq 11 ]]
#then
#	echo "" | tee -a $vOutputLog
#	echo "*********************************" | tee -a $vOutputLog
#	echo "* Checking for patch 24491261   *" | tee -a $vOutputLog
#	echo "*********************************" | tee -a $vOutputLog
#
#	# Get patch status
#	PATCHED=$( $ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
#set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on
#select comments from registry\$history where id=24491261;
#exit;
#EOF
#)
#
#	if [[ $PATCHED = "Patch 24491261 applied" ]]
#	then
#		echo "" | tee -a $vOutputLog
#		echo "Patch 24491261 has been applied.  Continuing..." | tee -a $vOutputLog
#	else
#		echo "" | tee -a $vOutputLog
#		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
#		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
#		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
#		echo "" | tee -a $vOutputLog
#		echo "Patch 24491261 must be applied before you can run GoldenGate on $ORACLE_SID." | tee -a $vOutputLog
#		exit 1
#	fi
#fi

############################ Check Files and Directories ############################

# set script directory
vAdminDir="/database/E${vCDBFull}/${vCDBFull}_admn01"
vDBScripts="${vAdminDir}/scripts"
ENABLETRIGGERS=${vDBScripts}/8_enable_triggers_${vPDBName}.sql
if [[ ! -e $ENABLETRIGGERS ]]
then
	echo "" | tee -a $vOutputLog
	echo "$vDBScripts does not contain the needed scripts. Now checking for unencrypted mount point." | tee -a $vOutputLog
	vAdminDir="/database/${vCDBFull}_admn01"
	vDBScripts="${vAdminDir}/scripts"
	ENABLETRIGGERS=${vDBScripts}/8_enable_triggers_${vPDBName}.sql
	if [[ ! -e $ENABLETRIGGERS ]]
	then
		echo "" | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
		echo "" | tee -a $vOutputLog
		echo "Could not find scripts in $vDBScripts." | tee -a $vOutputLog
		exit 1
	else
		echo "Mount point $vAdminDir found." | tee -a $vOutputLog
	fi
else
	echo "Mount point $vAdminDir found." | tee -a $vOutputLog
fi	
vRRScripts="${vDBScripts}/RR"

# GG directories
DIRDAT="${GGATE}/dirdat"
DIROUT="${GGATE}/dirout"
DIRPRM="${GGATE}/dirprm"
DBDAT="${DIRDAT}/${vPDBName}"
vGGRevDir="${DBDAT}/RR"

# GG Host directory
vDirOut11=${GGATE11}/dirout

# set directory array
unset vDirArray
vDirArray+=($DIRDAT)
vDirArray+=($DIROUT)
vDirArray+=($DIRPRM)

unset vMkdirArray
vMkdirArray+=($vDBScripts)
vMkdirArray+=($DBDAT)
vMkdirArray+=($vGGRevDir)
vMkdirArray+=($vRRScripts)

# set log names
vGGStatusOut="${DIROUT}/GGProcessStatus_${vPDBName}.out"
vLinuxStartSCN="${vRRScripts}/RR_replicat_${vPDBName}_start_scn.out"

# GG files
ADDTRANDATA="${DIRPRM}/ADD_TRANDATA_Linux_RR_${vPDBName}.oby"
CREATEEXTRACT="${DIRPRM}/${vPDBName}_create_RR_extract.oby"
STARTEXTRACT="${DIRPRM}/${vPDBName}_start_RR_extract.oby"
vDDLIncGen="${DIRPRM}/generic_DDL.inc"
vDDLInclude="${DIRPRM}/${vExtName}_DDL.inc"
EPRMFILE="${DIRPRM}/${vExtName}.prm"
PPRMFILE="${DIRPRM}/${vPushName}.prm"
RPRMFILE="${vRRScripts}/${vRepName}.prm"
vStartGGOut="${DIROUT}/StartRR_${vPDBName}.out"
	
# GG trails
vExtTrail="${vGGRevDir}/ea"
vRmtTrail="${vGGRevDir}/ra"

# Files from AIX script
TARFILE_RR="Linux_RR_${vPDBName}.tar"
#vHostOut="${vDBScripts}/AIX_host_${vPDBName}.out"

# set array of files to check
unset vFileArray
#vFileArray+=($vDDLIncGen)
#vFileArray+=($vHostOut)
vFileArray+=($ENABLETRIGGERS)

# set array of files to remove
unset vRemoveArray
vRemoveArray+=($vGGStatusOut)
vRemoveArray+=($vLinuxStartSCN)
vRemoveArray+=($CREATEEXTRACT)
vRemoveArray+=($STARTEXTRACT)
vRemoveArray+=($vDDLInclude)
vRemoveArray+=($ADDTRANDATA)
vRemoveArray+=($EPRMFILE)
vRemoveArray+=($PPRMFILE)
vRemoveArray+=($vStartGGOut)

# Remove existing logs/param files
for vCheckArray in ${vRemoveArray[@]}
do
	if [[ -f $vCheckArray ]]
	then
		rm $vCheckArray
	fi
done

############################ Prep Work ############################

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

# check for required directories
for vCheckArray in ${vDirArray[@]}
do
	# Issue warning if directory does not exist
	if [[ ! -d $vCheckArray ]]
	then
		echo " "
		echo "ERROR: The $vCheckArray directory does not exist."
		exit 1
	fi
done

# check for directories that can be created
for vCheckArray in ${vMkdirArray[@]}
do
	if [[ ! -d $vCheckArray ]]
	then
		mkdir $vCheckArray
		if [[ $? -ne 0 ]]
		then
			echo " " | tee -a $vOutputLog
			echo "ERROR: Could not create $vCheckArray" | tee -a $vOutputLog
			exit 1
		else
			echo "" | tee -a $vOutputLog
			echo "$vCheckArray created" | tee -a $vOutputLog
			chmod 777 $vCheckArray
		fi
	fi
done

# check for AIX file
#if [[ ! -e $vHostOut ]]
#then
#	echo "" | tee -a $vOutputLog
#	echo "$vHostOut is not present" | tee -a $vOutputLog
#	# check for tar file
#	if [[ ! -e /tmp/${TARFILE_RR} ]]
#	then
#		if [[ ! -e ${vDBScripts}/${TARFILE_RR} ]]
#		then
#			echo " " | tee -a $vOutputLog
#			echo "ERROR: That tar file of scripts from AIX is missing: ${TARFILE_RR}" | tee -a $vOutputLog
#			echo "       It must be in /tmp or $vDBScripts to continue." | tee -a $vOutputLog
#			exit 1
#		else
#			echo "" | tee -a $vOutputLog
#			echo "$TARFILE_RR found in $vDBScripts" | tee -a $vOutputLog
#		fi
#	else
#		echo "" | tee -a $vOutputLog
#		echo "$TARFILE_RR found in /tmp" | tee -a $vOutputLog
#		# move it
#		mv /tmp/${TARFILE_RR} $vDBScripts
#	fi
#	# unzip file
#	cd $vDBScripts
#	tar -xf $TARFILE_RR
#	if [[ $? -ne 0 ]]
#	then
#		echo " " | tee -a $vOutputLog
#		echo "ERROR: The tar file $TARFILE_RR could not be unzipped." | tee -a $vOutputLog
#		echo "       This file must be unzipped to continue." | tee -a $vOutputLog
#		exit 1
#	else
#		echo "" | tee -a $vOutputLog
#		echo "The tar file $TARFILE_RR was successfully unzipped." | tee -a $vOutputLog
#	fi
#fi
#cd $vScriptDir

# check for required files	
for vCheckArray in ${vFileArray[@]}
do
	# Issue warning if file does not exist
	if [[ ! -e $vCheckArray ]]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: The $vCheckArray file does not exist." | tee -a $vOutputLog
		exit 1
	fi
done

# Create include DDL file
if [[ $vDBVersion -eq 12 ]]
then
	sed "s/<dbname>/${vPDBName}/g" $vDDLIncGen > $vDDLInclude
else
	vDDLInclude="${DIRPRM}/ealldbs_DDL.inc"
fi

############################ Build param files ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Enable archive log mode       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# add supplemental logging data
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET ECHO ON
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
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SPOOL $vOutputLog APPEND
-- alter session set container=cdb\$root;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
SPOOL OFF
exit
RUNSQL

# check for errors
error_check_fnc $vOutputLog $vErrorLog

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SPOOL $vOutputLog APPEND
-- turn on archive log mode
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
SPOOL OFF

exit
RUNSQL

# check for errors
error_check_fnc $vOutputLog $vErrorLog

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Creating GG parameter files   *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# create GG parameter files
if [[ $vDBVersion -eq 12 ]]
then
	create_params_12_fnc
else
	create_params_11_fnc
fi

# check for errors
error_check_fnc $vOutputLog $vErrorLog
error_check_fnc $RPRMFILE $vErrorLog
error_check_fnc $PPRMFILE $vErrorLog
error_check_fnc $EPRMFILE $vErrorLog
error_check_fnc $ADDTRANDATA $vErrorLog

############################ Start GG processes ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Starting GG processes         *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# Build script to create GG extract and pump
echo "delete extract $vExtName" > $CREATEEXTRACT
echo "DBLOGIN USERID GGS@${vCDBName} PASSWORD $vGGSPwd" >> $CREATEEXTRACT
echo "add extract $vExtName, integrated tranlog, begin now" >> $CREATEEXTRACT
echo "add exttrail $vExtTrail, extract $vExtName, megabytes 1000" >> $CREATEEXTRACT
echo "add extract $vPushName, exttrailsource ${vExtTrail}" >> $CREATEEXTRACT
echo "add rmttrail $vRmtTrail, extract $vPushName, megabytes 1000" >> $CREATEEXTRACT
# Add register command based on DB version
if [[ $vDBVersion -eq 12 ]]
then
	echo "register extract $vExtName database CONTAINER ($vPDBName)" >> $CREATEEXTRACT
else
	# for 11g
	echo "register extract $vExtName database" >> $CREATEEXTRACT
fi

# start GG processes
cd $GGATE
./ggsci >> $vStartGGOut << EOF
obey $ADDTRANDATA
sh sleep 10

obey $CREATEEXTRACT
sh sleep 10

exit
EOF

# check for errors
cat $vStartGGOut >> $vOutputLog
vGGErrorCt=$(cat $vStartGGOut | grep OGG- | grep ERROR | wc -l)
if [[ $vGGErrorCt -gt 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "There was an error creating the GoldenGate services." | tee -a $vOutputLog
	cat $vStartGGOut | grep OGG- | grep ERROR | tee -a $vOutputLog
	exit 1
fi

# Build script to start GG extract and pump
echo "start extract $vExtName" > $STARTEXTRACT
echo "sh sleep 5" >> $STARTEXTRACT
echo "start $vPushName" >> $STARTEXTRACT
echo "sh sleep 5" >> $STARTEXTRACT

./ggsci >> $vOutputLog << EOF
obey $STARTEXTRACT

exit
EOF

# get SCN number
SOURCE_CURRENT_SCN=$(cat $vStartGGOut | grep "SCN" | awk '{print $13}' | awk -F. '{print $1}')
echo $SOURCE_CURRENT_SCN > $vLinuxStartSCN

# copy SCN file to shared mount point
cp $vLinuxStartSCN $vDBScripts
echo "$vExtName has been registered at SCN $SOURCE_CURRENT_SCN" | tee -a $vOutputLog

# Check the GG extract status
gg_run_check_fnc $vExtName

# Check the GG pump status
gg_run_check_fnc $vPushName

# Check if replicat is processing data
gg_rba_check_fnc $vPushName

############################ Truncate Row/Object Counts ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Collect table/object counts   *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# update table counts
#$ORACLE_HOME/bin/sqlplus -s sys/$vSysPwd@$vPDBName as sysdba <<EOF
$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING ON
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
    insert into $vLinuxRowTable
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
      commit;
  end loop;
  close cf;
end;
/

select count(*) from $vLinuxRowTable;
select count(*) from $vLinuxObjectTable;

exit;
EOF

error_check_fnc $vOutputLog $vErrorLog

############################ Copy files to GG host ############################

# add all files to archive
cd $vRRScripts
tar -cvf $TARFILE_RR *

echo "" | tee -a $vOutputLog
# copy files to new host
if [[ AUTOMODE -eq 1 ]]
then
	echo "Copying archive file to $GGHOST. You may be prompted for the password." | tee -a $vOutputLog
	scp ${TARFILE_RR} oracle@${GGHOST}:${vDirOut11} | tee -a $vOutputLog
	if [[ $? -ne 0 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "There was a problem copying $vLinuxStartSCN to $GGHOST. Please run this command manually:" | tee -a $vOutputLog
		echo "scp ${vRRScripts}/${TARFILE_RR} oracle@${GGHOST}:${vDirOut11}" | tee -a $vOutputLog
	fi
else
	echo "Cannot connect to $GGHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
	echo "${vRRScripts}/${TARFILE_RR}" | tee -a $vOutputLog
fi

############################ Summary ############################

# Report Timing of Script
vEndSec=$(date '+%s')
vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:          $vPDBName" | tee -a $vOutputLog
if [[ $vDBVersion -eq 12 ]]
then
	echo "Version:                12c" | tee -a $vOutputLog
else
	echo "Version:                11g" | tee -a $vOutputLog
fi
echo "GoldenGate Home:        $GGATE" | tee -a $vOutputLog
if [[ $GGRUNNING = "FALSE" ]]
then
	echo "GG Status:              !!BROKEN!!" | tee -a $vOutputLog
else
	echo "GG Status:              Running" | tee -a $vOutputLog
fi
echo "TAR File:               ${vRRScripts}/${TARFILE_RR}" | tee -a $vOutputLog
echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
echo "Output log:             $vOutputLog" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog

