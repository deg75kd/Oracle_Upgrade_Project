#!/usr/bin/ksh
#================================================================================================#
#  NAME
#    cigfdsp_3_AIX_export.sh
#
#  SPECS
#    uxp33
#    LXORAODSP04
#    11g
#    US7ASCII
#    Encrypted
#================================================================================================#

NOWwSECs=$(date '+%Y%m%d%H%M%S')
vStartSec=$(date '+%s')

export ORACLE_HOME=/nomove/app/oracle/db/11g/6
export TNS_ADMIN=/nomove/app/oracle/tns_admin
export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export RUNDIR=/nomove/app/oracle/scripts/12cupgrade

# Database constants
vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE','SQLTUNE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE'"
vLockExclude="'GGS','SYS','SYSTEM','DBSNMP','UIMMONITOR'"
vNewHome12c="/app/oracle/product/db/12c/1"
vNewHome11g="/app/oracle/product/db/11g/1"

# array of 11g databases
# set -A List11g "idevt cigfdsd cigfdst cigfdsm cigfdsp inf91d infgix8d infgix8t infgix8m infgix8p fdlzd fdlzt fdlzm fdlzp trecscd trecsct trecscm trecscp obieed obieet obieem obieep obiee2d opsm opsp bpad bpat bpam bpap fnp8d fnp8t fnp8m fnp8p portalm portalp c3appsd c3appst c3appsm c3appsp cpsmrtsm cpsmrtsp"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
vTierCap=`echo $vTier | tr 'a-z' 'A-Z'`
export GGMOUNT="/nfs/oraexport"

# AIX comparison tables
vRowTable="row_count_aix"
vObjectTable="object_count_aix"
vIndexTable="index_count_aix"
vConstraintTable="constraint_count_aix"
vPrivilegeTable="priv_count_aix"
vColPrivTable="col_priv_count_aix"
vRolesTable="role_count_aix"
vQuotaTable="quota_aix"
vProxyUsersTable="proxy_users_aix"
vPubPrivTable="pub_privs_aix"
vLobTable="lob_aix"
vSysGenIndexTable="sys_gen_index_aix"

# Linux comparison tables
vLinuxRowTable="row_count_linux"
vLinuxObjectTable="object_count_linux"
vLinuxIndexTable="index_count_linux"
vLinuxConstraintTable="constraint_count_linux"
vLinuxPrivilegeTable="priv_count_linux"
vLinuxColPrivTable="col_priv_count_linux"
vLinuxRolesTable="role_count_linux"
vLinuxQuotaTable="quota_linux"
vLinuxProxyUsersTable="proxy_users_linux"
vLinuxPubPrivTable="pub_privs_linux"
vLinuxLobTable="lob_linux"
vLinuxSysGenIndexTable="sys_gen_index_linux"

# big table comparison table
vBigRowTable="big_row_count_aix"

# acceptable errors
set -A vErrIgnore "ERROR: EXTRACT" "ORA-01918" "ORA-32588" "ORA-00959" "ORA-04043" "ORA-06550" "PLS-00201" "PLS-00320"
# ORA-00959: tablespace 'XXXX' does not exist
# ORA-01918: user 'XXXX' does not exist
# ORA-04043: object XXXX does not exist
# ORA-32588: supplemental logging attribute primary key exists
# ORA-06550: line 2, column 20:
# PLS-00201: identifier 'DBA_NETWORK_ACLS.ACL' must be declared
# PLS-00320: the declaration of the type of this expression is incomplete or


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
set -A vDirArray $RUNDIR ${RUNDIR}/logs $GGMOUNT

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
echo "* User prompts                  *"
echo "*********************************"

# List running databases
echo ""
/nomove/home/oracle/pmonn.pm

# Prompt for the database name
echo ""
echo ""
echo "Enter the database you will export: \c"  
while true
do
	read DB11G
	if [[ -n "$DB11G" ]]
	then
		DBNAME=`echo $DB11G | tr 'A-Z' 'a-z'`
		DBCAPS=`echo $DB11G | tr 'a-z' 'A-Z'`
		echo "You have entered database $DBNAME"
		break
	else
		echo "Enter a valid database name: \c"  
	fi
done
#DBNAME=cigfdsp
export ORACLE_SID=${DBNAME}

# Prompt for location of 12c database
# echo ""
# echo "Enter the new Linux host for the database: \c"  
# while true
# do
	# read NEWHOST
	# if [[ -n "$NEWHOST" ]]
	# then
		# echo "You have entered new host $NEWHOST"
		# break
	# else
		# echo "Enter a valid host name: \c"  
	# fi
# done

# Prompt for new DB version
#echo ""
#echo "Which Oracle version are you migrating to: (a) 12c (b) 11g \c"
#while true
#do
#	read vReadVersion
#	if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
#	then
#		# set Oracle home
#		NEW_ORACLE_HOME=$vNewHome12c
#		break
#	elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
#	then
#		# set Oracle home
#		NEW_ORACLE_HOME=$vNewHome11g
#		break
#	else
#		echo "Select a valid database version: \c"  
#	fi
#done
NEW_ORACLE_HOME=$vNewHome11g

# get current character set
CURRENT_CharSet=`sqlplus -S / as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select value from nls_database_parameters where parameter='NLS_CHARACTERSET';
exit;
EOF`

# Prompt for character set
echo ""
echo "The current character set is $CURRENT_CharSet."
echo "Please choose the character set for the new database:"
echo "   (a) AL32UTF8"
echo "   (b) US7ASCII"
echo "   (c) WE8ISO8859P1"
echo "Choose AL32UTF8 unless you have confirmed there are data loss issues. \c"
while true
do
	read vCharSetSelect
	if [[ "$vCharSetSelect" == "A" || "$vCharSetSelect" == "a" ]]
	then
		vCharSet=AL32UTF8
		break
	elif [[ "$vCharSetSelect" == "B" || "$vCharSetSelect" == "b" ]]
	then
		vCharSet=US7ASCII
		break
	elif [[ "$vCharSetSelect" == "C" || "$vCharSetSelect" == "c" ]]
	then
		vCharSet=WE8ISO8859P1
		break
	else
		echo -e "Choose a valid option: \c"  
	fi
done

# Prompt for parallelism
re='^[1-8]+$'
echo ""
echo "How much parallelism do you want for the export/import?"  
echo "   (a) 2"
echo "   (b) 8"
echo "   (c) 10"
echo "   (d) 12"
echo "   (e) 14"
while true
do
	read vParallelOption
	if [[ "$vParallelOption" == "A" || "$vParallelOption" == "a" ]]
	then
		vParallelLevel=2
		break
	elif [[ "$vParallelOption" == "B" || "$vParallelOption" == "b" ]]
	then
		vParallelLevel=8
		break
	elif [[ "$vParallelOption" == "C" || "$vParallelOption" == "c" ]]
	then
		vParallelLevel=10
		break
	elif [[ "$vParallelOption" == "D" || "$vParallelOption" == "d" ]]
	then
		vParallelLevel=12
		break
	elif [[ "$vParallelOption" == "E" || "$vParallelOption" == "e" ]]
	then
		vParallelLevel=14
		break
	else
		echo "Choose a valid option. \c"  
	fi
done
echo "You have entered parallelism $vParallelLevel"

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
	
############################ Set New DB Version ############################

# NEW_ORACLE_HOME=$vNewHome12c
# for dblist in ${List11g[@]}
# do
	# if [[ $dblist = $DBNAME ]]
	# then
		# NEW_ORACLE_HOME=$vNewHome11g
		# break
	# fi
# done

############################ Confirmation ############################

vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_${NOWwSECs}.log"
vErrorLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_err.log"
vCritLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_crit.log"
# DMPDIR="${GGMOUNT}/datapump"
vDPParDir="${GGMOUNT}/${ORACLE_SID}"

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
echo "Database Name:        $ORACLE_SID" | tee -a $vOutputLog
if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
then
	echo "New DB Version:       12c" | tee -a $vOutputLog
else
	echo "New DB Version:       11g" | tee -a $vOutputLog
fi
echo "AIX Character Set:    $CURRENT_CharSet" | tee -a $vOutputLog
echo "Linux Character Set:  $vCharSet" | tee -a $vOutputLog
echo "Parallelism:          $vParallelLevel" | tee -a $vOutputLog
echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
# echo "New Host:             $NEWHOST" | tee -a $vOutputLog
echo "Data Pump Dir:        $vDPParDir" | tee -a $vOutputLog
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

############################ Set DB environment variables ############################

# set environment variables
unset LIBPATH
export ORACLE_SID=$DBNAME
export ORAENV_ASK=NO
export PATH=/usr/local/bin:$PATH
. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib

############################ Additional prep-work ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Setting directory names       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set umask
vOldUmask=`umask`
umask 0000

# Check connection to new host
# echo ""
# echo "Checking connections to $NEWHOST" | tee -a $vOutputLog
# AUTOMODE=0
# ping -c 1 $NEWHOST
# if [[ $? -eq 0 ]]
# then
	# AUTOMODE=1
# else
	# echo "WARNING: Unable to ping $NEWHOST." | tee -a $vOutputLog
# fi

# set data directory to most recent one
for OradataDir in /move/${DBNAME}*/oradata
do
	DATAFILE_LOC=$OradataDir
done
if [[ -d $DATAFILE_LOC ]]
then
	echo "" | tee -a $vOutputLog
	echo "Will create GG tablespace in $DATAFILE_LOC" | tee -a $vOutputLog
else
	echo "ERROR: $DATAFILE_LOC data directory does not exist!" | tee -a $vOutputLog
	exit 1
fi

# set directories
echo "" | tee -a $vOutputLog
echo "Checking output directories" | tee -a $vOutputLog
vOutputDir="/move/${DBNAME}_adm01/scripts"
vNewDir="/tmp"

# test output directory
if [[ ! -d $vOutputDir ]]
then
	# if directory does not exist try old folder structure
	vOutputDir="/move/${DBNAME}01/scripts"
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
vLockUsers="${vOutputDir}/LockUsers_${DBNAME}.sql"
vUnlockUsers="${vOutputDir}/RestoreUsers_${DBNAME}.sql"
vCheckUsers="${vOutputDir}/CheckUsers_${DBNAME}.sql"
vAccountStatus="${vOutputDir}/UserAccountStatus_${DBNAME}.txt"

# set GG file names
# TARFILE=Linux_cutover_${DBNAME}.tar
SCNFILE="${vOutputDir}/current_scn_AIX_${ORACLE_SID}.out"

# set names of data pump param files/directories
vDPDataPar="${vDPParDir}/${DBNAME}_expdp_cutover.par"
vDPImpPar="${vDPParDir}/${DBNAME}_impdp_cutover.par"
vDPDataLog="${DBNAME}_expdp_cutover.log"
vDPDataDump="${DBNAME}_cutover_%U.dmp"

vDPDataParFS="${vDPParDir}/${DBNAME}_expdp_cutover_fiserv.par"
vDPDataLogFS="${DBNAME}_expdp_cutover_fiserv.log"
vDPDataDumpFS="${DBNAME}_cutover_fiserv_%U.dmp"

vDPDataParBLC="${vDPParDir}/${DBNAME}_expdp_cutover_blc.par"
vDPDataLogBLC="${DBNAME}_expdp_cutover_blc.log"
vDPDataDumpBLC="${DBNAME}_cutover_blc_%U.dmp"

vDPDataParSTG="${vDPParDir}/${DBNAME}_expdp_cutover_stg.par"
vDPDataLogSTG="${DBNAME}_expdp_cutover_stg.log"
vDPDataDumpSTG="${DBNAME}_cutover_stg_%U.dmp"

vDPDataParGG="${vDPParDir}/${DBNAME}_expdp_cutover_ggtest.par"
vDPDataLogGG="${DBNAME}_expdp_cutover_ggtest.log"
vDPDataDumpGG="${DBNAME}_cutover_ggtest_%U.dmp"

echo "" | tee -a $vOutputLog
echo "Removing existing logs" | tee -a $vOutputLog
# for file in $SETPARAM $vOrigParams $CREATETS $REDOLOGS $UNDOSIZE $TEMPSIZE $TSGROUPS $SYSOBJECTS $vCreateUsers $vCreateCommonUsers $CREATEQUOTAS $CREATEGRANTS $CREATESYSPRIVS $CREATESYNS $CREATEROLES $vCreateExtTables $vDefaultDates $vCreateDBLinks $vRefreshGroups $vProxyPrivs /tmp/${TARFILE} $vCreateACL
for file in $vLockUsers $vUnlockUsers $vCheckUsers $vAccountStatus
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

############################ Restricted Mode ############################

# echo "" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog
# echo "* Restart database in restrict mode *" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog

# restart database in restricted mode
# $ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
# SET ECHO ON
# SET DEFINE OFF
# SET ESCAPE OFF
# SET FEEDBACK OFF
# SET HEAD ON
# SET SERVEROUTPUT ON SIZE 1000000
# SET TERMOUT ON
# SET TIMING OFF
# SET LINES 200
# SET PAGES 0
# SET TRIMSPOOL ON
# SET LONG 10000
# SET NUMFORMAT 999999999999999990
# WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

# SPOOL $vOutputLog APPEND
# SHUTDOWN ABORT
# STARTUP RESTRICT
# RUNSQL

# vLogins=$( sqlplus -S / as sysdba <<EOF
# set pagesize 0 linesize 32767 feedback off verify off heading off echo off
# select logins from v\$instance;
# exit;
# EOF
# )

# if [[ $vLogins = "RESTRICTED" ]]
# then
	# echo "$DBNAME is in $vLogins mode" | tee -a $vOutputLog
# else
	# echo "$DBNAME is NOT in restricted mode. It is in $vLogins mode." | tee -a $vOutputLog
	# continue_fnc
# fi

# echo "" | tee -a $vOutputLog
# echo "Please start cigfdsp_5_Linux_big_tables.sh on LXORAODSP04" | tee -a $vOutputLog
# sleep 60

############################ SQL Plus ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Create scripts for Linux side *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set environment variables
unset LIBPATH
export ORACLE_SID=$DBNAME
export ORAENV_ASK=NO
export PATH=/usr/local/bin:$PATH
. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib

# Run scripts in database
$ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
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
select * from v\$instance;

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
and SUBOBJECT_NAME is null and generated='N'
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

PROMPT *** Create table for comparison of indexes with system-generated names ***
-- AIX
create table ggtest.${vSysGenIndexTable} as
select ic.table_owner, ic.table_name, ic.column_name, di.index_type, di.uniqueness, di.status, ic.descend 
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
join dba_objects ob
	on ob.object_name=di.index_name and ob.owner=di.owner
where ob.object_type='INDEX' and ob.generated='Y'
and di.owner not in ($vExcludeUsers)
and (di.TABLE_OWNER||'.'||di.TABLE_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');
ALTER TABLE ggtest.${vSysGenIndexTable}
ADD CONSTRAINT ${vSysGenIndexTable}_pk
PRIMARY KEY (table_owner, table_name, column_name, index_type, uniqueness, status, descend)
using index (CREATE INDEX ggtest.${vSysGenIndexTable}_pk_ix ON ggtest.${vSysGenIndexTable} (table_owner, table_name, column_name, index_type, uniqueness, status, descend));
-- Linux
create table ggtest.${vLinuxSysGenIndexTable} as
select * from ggtest.${vSysGenIndexTable} where 1=0;
ALTER TABLE ggtest.${vLinuxSysGenIndexTable}
ADD CONSTRAINT ${vLinuxSysGenIndexTable}_pk
PRIMARY KEY (table_owner, table_name, column_name, index_type, uniqueness, status, descend)
using index (CREATE INDEX ggtest.${vLinuxSysGenIndexTable}_pk_ix ON ggtest.${vLinuxSysGenIndexTable} (table_owner, table_name, column_name, index_type, uniqueness, status, descend));

PROMPT *** Create table for LOB comparison ***
-- AIX
create table ggtest.${vLobTable} as
select owner, table_name, column_name, tablespace_name
from dba_lobs
where owner not in ($vExcludeUsers)
and (owner||'.'||table_name) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');
ALTER TABLE ggtest.${vLobTable}
ADD CONSTRAINT ${vLobTable}_pk
PRIMARY KEY (owner, table_name, column_name, tablespace_name)
using index (CREATE INDEX ggtest.${vLobTable}_pk_ix ON ggtest.${vLobTable} (owner, table_name, column_name, tablespace_name));
-- Linux
create table ggtest.${vLinuxLobTable} as
select * from ggtest.${vLobTable} where 1=0;
ALTER TABLE ggtest.${vLinuxLobTable}
ADD CONSTRAINT ${vLinuxLobTable}_pk
PRIMARY KEY (owner, table_name, column_name, tablespace_name)
using index (CREATE INDEX ggtest.${vLinuxLobTable}_pk_ix ON ggtest.${vLinuxLobTable} (owner, table_name, column_name, tablespace_name));

PROMPT *** Create table for privilege comparison ***
-- AIX
create table ggtest.${vPrivilegeTable} as
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

PROMPT *** Create table for public privilege comparison ***
-- AIX
create table ggtest.${vPubPrivTable} as
	/* DIRECT OBJ PRIVILEGES */ 	
select grantee, owner, table_name, privilege
from dba_tab_privs
where grantee='PUBLIC'
and (OWNER,TABLE_NAME) not in (SELECT owner, object_name FROM dba_recyclebin)
UNION 
	/* DIRECT SYS PRIVILEGES */ 
select grantee, 'n/a', 'n/a', privilege
from dba_sys_privs
where grantee='PUBLIC';

ALTER TABLE ggtest.${vPubPrivTable}
ADD CONSTRAINT ${vPubPrivTable}_pk
PRIMARY KEY (grantee, owner, table_name, privilege)
using index (CREATE INDEX ggtest.${vPubPrivTable}_pk_ix ON ggtest.${vPubPrivTable} (grantee, owner, table_name, privilege));
-- Linux
create table ggtest.${vLinuxPubPrivTable} as
select * from ggtest.${vPubPrivTable} where 1=0;
ALTER TABLE ggtest.${vLinuxPubPrivTable}
ADD CONSTRAINT ${vLinuxPubPrivTable}_pk
PRIMARY KEY (grantee, owner, table_name, privilege)
using index (CREATE INDEX ggtest.${vLinuxPubPrivTable}_pk_ix ON ggtest.${vLinuxPubPrivTable} (grantee, owner, table_name, privilege));

PROMPT *** Create table for column privilege comparison ***
-- AIX
create table ggtest.${vColPrivTable} as
select grantee, owner, table_name, column_name, privilege
	/* DIRECT COL PRIVILEGES */ 	
from dba_col_privs
where grantee not in ($vExcludeUsers)
and grantee not in ($vExcludeRoles)
and owner not in ($vExcludeUsers)
and (owner, table_name) not in (SELECT owner, object_name FROM dba_recyclebin)
UNION 
	/* INDIRECT COL PRIVILEGES */ 
select rp.grantee, cp.owner, cp.table_name, cp.column_name, cp.privilege
from dba_col_privs cp, dba_role_privs rp, dba_users du
where cp.grantee=rp.granted_role and rp.grantee=du.username
and rp.grantee not in ($vExcludeUsers)
and cp.owner not in ($vExcludeUsers)
and (cp.OWNER,cp.TABLE_NAME) not in (SELECT owner, object_name FROM dba_recyclebin)
;

ALTER TABLE ggtest.${vColPrivTable}
ADD CONSTRAINT ${vColPrivTable}_pk
PRIMARY KEY (grantee, owner, table_name, column_name, privilege)
using index (CREATE INDEX ggtest.${vColPrivTable}_pk_ix ON ggtest.${vColPrivTable} (grantee, owner, table_name, column_name, privilege));
-- Linux
create table ggtest.${vLinuxColPrivTable} as
select * from ggtest.${vColPrivTable} where 1=0;
ALTER TABLE ggtest.${vLinuxColPrivTable}
ADD CONSTRAINT ${vLinuxColPrivTable}_pk
PRIMARY KEY (grantee, owner, table_name, column_name, privilege)
using index (CREATE INDEX ggtest.${vLinuxColPrivTable}_pk_ix ON ggtest.${vLinuxColPrivTable} (grantee, owner, table_name, column_name, privilege));

PROMPT *** Create table for role comparison ***
-- AIX
create table ggtest.${vRolesTable} as
select granted_role, grantee, admin_option, default_role
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

PROMPT *** Create empty table for index comparison ***
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
select owner, table_name, constraint_type, status, count(*) "CNSTR_CT"
from dba_constraints
where owner not in ($vExcludeUsers) and table_name not like 'BIN$%'
and (owner||'.'||table_name) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
group by owner, table_name, constraint_type, status;
ALTER TABLE ggtest.${vConstraintTable}
ADD CONSTRAINT ${vConstraintTable}_pk
PRIMARY KEY (owner, table_name, constraint_type, status)
using index (CREATE INDEX ggtest.${vConstraintTable}_pk_ix ON ggtest.${vConstraintTable} (owner, table_name, constraint_type, status));
-- Linux
create table ggtest.${vLinuxConstraintTable} as
select * from ggtest.${vConstraintTable} where 1=0;
ALTER TABLE ggtest.${vLinuxConstraintTable}
ADD CONSTRAINT ${vLinuxConstraintTable}_pk
PRIMARY KEY (owner, table_name, constraint_type, status)
using index (CREATE INDEX ggtest.${vLinuxConstraintTable}_pk_ix ON ggtest.${vLinuxConstraintTable} (owner, table_name, constraint_type, status));

PROMPT *** Create table for quota comparison ***
-- AIX
create table ggtest.${vQuotaTable} as
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

ALTER TABLE ggtest.${vQuotaTable}
ADD CONSTRAINT ${vQuotaTable}_pk
PRIMARY KEY (username, tablespace_name, quota)
using index (CREATE INDEX ggtest.${vQuotaTable}_pk_ix ON ggtest.${vQuotaTable} (username, tablespace_name, quota));
-- Linux
create table ggtest.${vLinuxQuotaTable} as
select * from ggtest.${vQuotaTable} where 1=0;
ALTER TABLE ggtest.${vLinuxQuotaTable}
ADD CONSTRAINT ${vLinuxQuotaTable}_pk
PRIMARY KEY (username, tablespace_name, quota)
using index (CREATE INDEX ggtest.${vLinuxQuotaTable}_pk_ix ON ggtest.${vLinuxQuotaTable} (username, tablespace_name, quota));

PROMPT *** Create table for proxy user comparison ***
-- AIX
create table ggtest.${vProxyUsersTable} as
select PROXY, CLIENT, AUTHENTICATION, FLAGS
from proxy_users 
where client like 'APP%'
and proxy not in ($vExcludeUsers)
;

ALTER TABLE ggtest.${vProxyUsersTable}
ADD CONSTRAINT ${vProxyUsersTable}_pk
PRIMARY KEY (PROXY, CLIENT)
using index (CREATE INDEX ggtest.${vProxyUsersTable}_pk_ix ON ggtest.${vProxyUsersTable} (PROXY, CLIENT));
-- Linux
create table ggtest.${vLinuxProxyUsersTable} as
select * from ggtest.${vProxyUsersTable} where 1=0;
ALTER TABLE ggtest.${vLinuxProxyUsersTable}
ADD CONSTRAINT ${vLinuxProxyUsersTable}_pk
PRIMARY KEY (PROXY, CLIENT)
using index (CREATE INDEX ggtest.${vLinuxProxyUsersTable}_pk_ix ON ggtest.${vLinuxProxyUsersTable} (PROXY, CLIENT));

PROMPT *** Populate table for index comparison ***
-- AIX
insert into ggtest.${vIndexTable}
select ix.OWNER, ix.INDEX_NAME, ix.INDEX_TYPE, ix.TABLE_OWNER, ix.TABLE_NAME, ix.STATUS
from DBA_INDEXES ix, dba_objects ob
where ob.object_name=ix.index_name and ob.owner=ix.owner
and ob.object_type='INDEX' and ob.generated='N'
and (ix.TABLE_OWNER||'.'||ix.TABLE_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
and ix.owner not in ($vExcludeUsers);

PROMPT *** Loading tables counts (this may take a while) ***
declare
  cursor cf is
    select db.name, ins.host_name,
	  tb.owner, tb.table_name, tb.status
	from DBA_TABLES tb, v\$instance ins, v\$database db
	where tb.IOT_TYPE is null and owner not in ($vExcludeUsers)
	and (tb.owner, tb.table_name) not in (select owner, table_name from dba_external_tables)
	and (tb.owner||'.'||tb.table_name) not in
	('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');
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

PROMPT *** Loading big table counts (this may take a while) ***
truncate table ggtest.${vBigRowTable};

declare
  cursor cf is
    select db.name, ins.host_name,
	  tb.owner, tb.table_name, tb.status
	from DBA_TABLES tb, v\$instance ins, v\$database db
	where tb.IOT_TYPE is null and (tb.owner||'.'||tb.table_name) in
	('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');
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
    insert into ggtest.${vBigRowTable}
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
select 'There are '||count(*)||' column privileges.' from ggtest.${vColPrivTable};
select 'There are '||count(*)||' roles.' from ggtest.${vRolesTable};
select 'There are '||count(*)||' quotas.' from ggtest.${vQuotaTable};
select 'There are '||count(*)||' proxy users.' from ggtest.${vProxyUsersTable};
select 'There are '||count(*)||' public privileges.' from ggtest.${vPubPrivTable};
select 'There are '||count(*)||' LOBs.' from ggtest.${vLobTable};
select 'There are '||count(*)||' system-generated names.' from ggtest.${vSysGenIndexTable};
select 'There are '||count(*)||' BIG tables.' from ggtest.${vBigRowTable};

PROMPT *** Loading SQL plan information to staging tables ***
exec DBMS_SPM.CREATE_STGTAB_BASELINE ('STGTAB_BASELINE','GGTEST','GGS');

declare
	my_plans	pls_integer;
begin
	my_plans := DBMS_SPM.PACK_STGTAB_BASELINE (
		table_name	=> 'STGTAB_BASELINE',
		table_owner	=> 'GGTEST',
		enabled		=> 'YES',
		accepted	=> 'YES');
	dbms_output.put_line('Plans loaded: '||my_plans);
end;
/
select count(*) from GGTEST.STGTAB_BASELINE;

EXEC DBMS_SQLTUNE.CREATE_STGTAB_SQLPROF ('PROFILE_STGTAB', 'GGTEST', 'GGS');
EXEC DBMS_SQLTUNE.PACK_STGTAB_SQLPROF (profile_category => '%', staging_table_name => 'PROFILE_STGTAB', staging_schema_owner => 'GGTEST');

SET FEEDBACK OFF
SPOOL $vOutputLog APPEND
PROMPT *** Create data pump parameter file ***
SET ESCAPE OFF
SPOOL $vDPDataPar
DECLARE
  CURSOR c1 IS
    select case
		when username!=upper(username) then '\\"'||username||'\\"'
		else username
		end "STMT"
	from dba_users where username not in ($vExcludeUsers)
	and username not in ('FISERV_GTWY','BLC_EAPP_GTWY','STG','JIRA','SONAR','GGTEST');
  vOwner	VARCHAR2(30);
  x			PLS_INTEGER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('DIRECTORY=CNO_MIGRATE');
  DBMS_OUTPUT.PUT_LINE('DUMPFILE=${vDPDataDump}');
  DBMS_OUTPUT.PUT_LINE('LOGFILE=${vDPDataLog}');
  DBMS_OUTPUT.PUT_LINE('PARALLEL=${vParallelLevel}');
  DBMS_OUTPUT.PUT_LINE('METRICS=Y');
  DBMS_OUTPUT.PUT_LINE('EXCLUDE=STATISTICS');
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

exit;
RUNSQL

# check logs for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
# for file in $SETPARAM $vOrigParams $REDOLOGS $CREATETS $TEMPSIZE $TSGROUPS $SYSOBJECTS $CREATEQUOTAS $CREATEROLES $CREATEGRANTS $CREATESYSPRIVS $vProxyPrivs $CREATESYNS $vCreateExtTables
# do
	# if [[ -e $file ]]
	# then
		# error_check_fnc $file $vErrorLog $vCritLog
	# else
		# echo "ERROR: $file could not be found" | tee -a $vOutputLog
		# exit 1
	# fi
# done

# create version-specific files
if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
then
	$ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
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

PROMPT *** Create data pump import parameter file ***
SPOOL $vDPImpPar
DECLARE
  CURSOR c1 IS
    select us.username||':'||substr(us.username,length(pf.value)+1)||'${vTierCap}'
	from dba_users us, (select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
	where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
	and us.username not like '%UT' and us.username not like '%SIT' and us.username not like '%UAT' and us.username not like '%PROD'
	UNION
	select us.username||':'||substr(us.username,length(pf.value)+1)
	from dba_users us, (select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
	where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
	and (us.username like '%UT' or us.username like '%SIT' or us.username like '%UAT' or us.username like '%PROD');
  vOwner	VARCHAR2(30);
  x			PLS_INTEGER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('DIRECTORY=CNO_MIGRATE');
  DBMS_OUTPUT.PUT_LINE('DUMPFILE=${vDPDataDump}');
  DBMS_OUTPUT.PUT_LINE('LOGFILE=${ORACLE_SID}_impdp_cutover.log.log');
  DBMS_OUTPUT.PUT_LINE('TABLE_EXISTS_ACTION=REPLACE');
  DBMS_OUTPUT.PUT_LINE('PARALLEL=${vParallelLevel}');
  DBMS_OUTPUT.PUT_LINE('CLUSTER=Y');
  DBMS_OUTPUT.PUT_LINE('METRICS=Y');
  DBMS_OUTPUT.PUT_LINE('LOGTIME=ALL');
  
  x := 1;
  OPEN c1;
  LOOP
    FETCH c1 INTO vOwner;
	EXIT WHEN c1%NOTFOUND;
	  IF x = 1 THEN
		DBMS_OUTPUT.PUT('REMAP_SCHEMA='||vOwner);
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

exit;
RUNSQL
else
	# 11g databases
	$ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
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

PROMPT Create data pump import parameter file ***
SPOOL $vDPImpPar
DECLARE
  CURSOR c1 IS
    select us.username||':'||substr(us.username,length(pf.value)+1)||'${vTierCap}'
	from dba_users us, (select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
	where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE';
  vOwner	VARCHAR2(30);
  x			PLS_INTEGER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('DIRECTORY=CNO_MIGRATE');
  DBMS_OUTPUT.PUT_LINE('DUMPFILE=${vDPDataDump}');
  DBMS_OUTPUT.PUT_LINE('LOGFILE=impdp_${ORACLE_SID}.log');
  DBMS_OUTPUT.PUT_LINE('TABLE_EXISTS_ACTION=REPLACE');
  DBMS_OUTPUT.PUT_LINE('PARALLEL=${vParallelLevel}');
  DBMS_OUTPUT.PUT_LINE('CLUSTER=Y');
  DBMS_OUTPUT.PUT_LINE('METRICS=Y');
  
  x := 1;
  OPEN c1;
  LOOP
    FETCH c1 INTO vOwner;
	EXIT WHEN c1%NOTFOUND;
	  IF x = 1 THEN
		DBMS_OUTPUT.PUT('REMAP_SCHEMA='||vOwner);
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

exit;
RUNSQL

fi

# check logs for errors
error_check_fnc $vDPImpPar $vErrorLog $vCritLog
# for file in $vCreateUsers $UNDOSIZE
# do
	# if [[ -e $file ]]
	# then
		# error_check_fnc $file $vErrorLog $vCritLog
	# else
		# echo "ERROR: $file could not be found" | tee -a $vOutputLog
		# exit 1
	# fi
# done
# check 12c only logs for errors
# if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
# then
	# if [[ -e $vCreateCommonUsers ]]
	# then
		# error_check_fnc $vCreateCommonUsers $vErrorLog $vCritLog
	# else
		# echo "ERROR: $vCreateCommonUsers could not be found" | tee -a $vOutputLog
		# exit 1
	# fi
# fi

echo "COMPLETE" | tee -a $vOutputLog

############################ Get SCN and export data ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Export data                   *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "Starting Data Pump export process" | tee -a $vOutputLog
echo "The time is `date`"  | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "Create parameter files for individual schema exports" | tee -a $vOutputLog
echo "DIRECTORY=CNO_MIGRATE" > $vDPDataParFS
echo "DUMPFILE=${vDPDataDumpFS}" >> $vDPDataParFS
echo "LOGFILE=${vDPDataLogFS}" >> $vDPDataParFS
echo "PARALLEL=${vParallelLevel}" >> $vDPDataParFS
echo "METRICS=Y" >> $vDPDataParFS
echo "EXCLUDE=STATISTICS" >> $vDPDataParFS
# echo "EXCLUDE=TABLE:\"in ('PROPERTYSTRING')\"" >> $vDPDataParFS
echo "EXCLUDE=TABLE:\"in ('WS_TRXN_LOG','APP_TRANSMISSION','APP_PAYLD','APP_EMP_DTL_FORM')\"" >> $vDPDataParFS
# echo "SCHEMAS=JIRA" >> $vDPDataParFS
echo "SCHEMAS=FISERV_GTWY" >> $vDPDataParFS

echo ""
echo "DIRECTORY=CNO_MIGRATE" > $vDPDataParBLC
echo "DUMPFILE=${vDPDataDumpBLC}" >> $vDPDataParBLC
echo "LOGFILE=${vDPDataLogBLC}" >> $vDPDataParBLC
echo "PARALLEL=${vParallelLevel}" >> $vDPDataParBLC
echo "METRICS=Y" >> $vDPDataParBLC
echo "EXCLUDE=STATISTICS" >> $vDPDataParBLC
# echo "EXCLUDE=TABLE:\"in ('ISSUE_FILTER_FAVOURITES')\"" >> $vDPDataParBLC
echo "EXCLUDE=TABLE:\"in ('APP_EMP_DTL_FORM','APP_PAYLD')\"" >> $vDPDataParBLC
# echo "SCHEMAS=SONAR" >> $vDPDataParBLC
echo "SCHEMAS=BLC_EAPP_GTWY" >> $vDPDataParBLC

echo ""
echo "DIRECTORY=CNO_MIGRATE" > $vDPDataParSTG
echo "DUMPFILE=${vDPDataDumpSTG}" >> $vDPDataParSTG
echo "LOGFILE=${vDPDataLogSTG}" >> $vDPDataParSTG
echo "PARALLEL=${vParallelLevel}" >> $vDPDataParSTG
echo "METRICS=Y" >> $vDPDataParSTG
echo "EXCLUDE=STATISTICS" >> $vDPDataParSTG
echo "EXCLUDE=TABLE:\"in ('S1_XML_ACORD')\"" >> $vDPDataParSTG
echo "SCHEMAS=STG" >> $vDPDataParSTG

echo ""
echo "DIRECTORY=CNO_MIGRATE" > $vDPDataParGG
echo "DUMPFILE=${vDPDataDumpGG}" >> $vDPDataParGG
echo "LOGFILE=${vDPDataLogGG}" >> $vDPDataParGG
echo "PARALLEL=1" >> $vDPDataParGG
echo "METRICS=Y" >> $vDPDataParGG
echo "EXCLUDE=STATISTICS" >> $vDPDataParGG
echo "EXCLUDE=TABLE:\"in ('BIG_CNSTRNT_COUNT_AIX','BIG_CNSTRNT_COUNT_LINUX','BIG_INDEX_COUNT_AIX','BIG_INDEX_COUNT_LINUX','BIG_LOB_AIX','BIG_LOB_LINUX','BIG_ROW_COUNT_AIX','BIG_ROW_COUNT_LINUX','BIG_SYS_GEN_INDEX_AIX','BIG_SYS_GEN_INDEX_LINUX')\"" >> $vDPDataParGG
echo "SCHEMAS=GGTEST" >> $vDPDataParGG

# get current scn
CURRENT_SCN=$( sqlplus -S / as sysdba <<EOF
col current_scn format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select LTRIM(TO_CHAR(current_scn)) current_scn from v\$database;
exit;
EOF
)

echo "${ORACLE_SID} ${CURRENT_SCN}" > $SCNFILE

# remove existing export files
for f in ${vDPParDir}/${DBNAME}_cutover*.dmp
do
	echo "Deleting $f" | tee -a $vOutputLog
	rm $f
done
for f in ${vDPParDir}/${DBNAME}_expdp_cutover*.log
do
	echo "Deleting $f" | tee -a $vOutputLog
	rm $f
done

# export FISERV_GTWY schema
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataParFS
cat ${vDPParDir}/${vDPDataLogFS} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLogFS} $vErrorLog $vCritLog

# export BLC_EAPP_GTWY schema
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataParBLC
cat ${vDPParDir}/${vDPDataLogBLC} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLogBLC} $vErrorLog $vCritLog

# export STG schema
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataParSTG
cat ${vDPParDir}/${vDPDataLogSTG} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLogSTG} $vErrorLog $vCritLog

# export GGTEST schema
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataParGG
cat ${vDPParDir}/${vDPDataLogGG} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLogGG} $vErrorLog $vCritLog

# export remaining schemas
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataPar
cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLog} $vErrorLog $vCritLog

############################ Check DB Links ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Checking Database Links       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# find database links
vDBLinks=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL`

for linkname in ${vDBLinks[@]}
do
	# find all owners with a link with this name
	vLinkOwner=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL`

	for ownername in ${vLinkOwner[@]}
	do
		# check public links
		if [[ $ownername = "PUBLIC" ]]
		then
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${linkname};
EXIT;
RUNSQL`
			# if link did not work, check if it is HS
			if [[ $vLinkTest != "1" ]]
			then
				vHSLinkCheck=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dba_db_links where host like '%HS%' and db_link='${linkname}';
EXIT;
RUNSQL`
				# report failures
				if [[ $vHSLinkCheck != "1" ]]
				then
					echo "Public link $linkname is broken!" | tee -a $vOutputLog
				else
					echo "Heterogeneous link $linkname is broken!"  | tee -a $vOutputLog
				fi
				# echo "$vLinkTest"
			# report success
			else
				echo "$linkname is working" | tee -a $vOutputLog
			fi
			
		# check schema-owned links
		else
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on define on flush off
alter user $ownername grant connect through system;
connect system[${ownername}]/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
select '1' from dual@${linkname};
connect system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))
alter user $ownername revoke connect through system;
EXIT;
RUNSQL`
			# report failues
			if [[ $vLinkTest != "1" ]]
			then
				echo "Link $linkname owned by $ownername is broken!" | tee -a $vOutputLog
				# echo "$vLinkTest"
			# report success
			else
				echo "Link $linkname owned by $ownername is working" | tee -a $vOutputLog
			fi
		fi
	done
done

# get timing before copying scripts
vEndSec=$(date '+%s')

############################ Lock Users ############################

echo "" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog
echo "* Locking user accounts on $DBNAME *" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 200
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

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
EXIT
EOF

$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
SET ECHO ON
SET LINES 150 PAGES 1000
SPOOL $vOutputLog APPEND
REM Locking user accounts
@$vLockUsers
SPOOL OFF
EXIT
EOF

# check for errors
error_check_fnc $vLockUsers $vErrorLog $vCritLog
error_check_fnc $vUnlockUsers $vErrorLog $vCritLog
error_check_fnc $vOutputLog $vErrorLog $vCritLog

echo "" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog
echo "* Verify locked user accounts on $DBNAME *" | tee -a $vOutputLog
echo "***********************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD ON
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

$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET FEEDBACK OFF
SET HEAD ON
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
SPOOL OFF
EXIT
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
error_check_fnc $vOutputLog $vErrorLog $vCritLog

############################ Copy Scripts ############################

# echo "" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog
# echo "* Copy scripts to new host      *" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog

# add all files to archive
# cd $vOutputDir
# tar -cvf $TARFILE $vDPImpPar

# echo ""
# copy files to new host
# if [[ AUTOMODE -eq 1 ]]
# then
	# echo "Copying archive file to $NEWHOST. You may be prompted for the password." | tee -a $vOutputLog
	# scp ${TARFILE} oracle@${NEWHOST}:${vNewDir} | tee -a $vOutputLog
	# scp ${vDPImpPar} oracle@${NEWHOST}:${vNewDir} | tee -a $vOutputLog
	# if [ $? -ne 0 ]
	# then
		# echo "" | tee -a $vOutputLog
		# echo "There was a problem copying $TARFILE to $NEWHOST. Please run this command manually:" | tee -a $vOutputLog
		# echo "scp ${TARFILE} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog
		# echo "There was a problem copying $vDPImpPar to $NEWHOST. Please run this command manually:" | tee -a $vOutputLog
		# echo "scp ${vDPImpPar} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog
	# fi
# else
	# echo "Cannot connect to $NEWHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
	# echo "${TARFILE}" | tee -a $vOutputLog
	# echo "scp ${vDPImpPar} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog
# fi

############################ Report Timing of Script ############################

vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:          $ORACLE_SID" | tee -a $vOutputLog
# echo "Database Mode:          $vLogins" | tee -a $vOutputLog
# echo "Linux host:             $NEWHOST" | tee -a $vOutputLog
echo "Output log:             $vOutputLog" | tee -a $vOutputLog
# echo "Script archive:         ${vOutputDir}/${TARFILE}" | tee -a $vOutputLog
echo "Unlock user script:     $vUnlockUsers" | tee -a $vOutputLog
echo "Data Pump directory:    $vDPParDir" | tee -a $vOutputLog
echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
