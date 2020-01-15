#!/usr/bin/ksh
#================================================================================================#
#  NAME
#    cigfdsp_1_AIX_pre_cutover.sh
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

# ACL script
vACLScript="${RUNDIR}/network_acls_ddl.sql"

# AIX comparison tables
vRowTable="big_row_count_aix"
vLobTable="big_lob_aix"
vIndexTable="big_index_count_aix"
vConstraintTable="big_cnstrnt_count_aix"
vSysGenIndexTable="big_sys_gen_index_aix"

# Linux comparison tables
vLinuxRowTable="big_row_count_linux"
vLinuxLobTable="big_lob_linux"
vLinuxIndexTable="big_index_count_linux"
vLinuxConstraintTable="big_cnstrnt_count_linux"
vLinuxSysGenIndexTable="big_sys_gen_index_linux"

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
		# continue_fnc
		echo ""
		echo "Are these errors acceptable?"
		echo "Waiting for 1 minute"
		sleep 60
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

. ${RUNDIR}/cigfdsp_1_AIX_param.sh

# echo ""
# echo "*********************************"
# echo "* User prompts                  *"
# echo "*********************************"

# List running databases
echo ""
/nomove/home/oracle/pmonn.pm

# Prompt for the database name
# echo ""
# echo ""
# echo "Enter the database you will export: \c"  
# while true
# do
	# read DB11G
	# if [[ -n "$DB11G" ]]
	# then
		DBNAME=`echo $DB11G | tr 'A-Z' 'a-z'`
		# DBCAPS=`echo $DB11G | tr 'a-z' 'A-Z'`
		# echo "You have entered database $DBNAME"
		# break
	# else
		# echo "Enter a valid database name: \c"  
	# fi
# done
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
# CURRENT_CharSet=`sqlplus -S / as sysdba <<EOF
# set pagesize 0 linesize 32767 feedback off verify off heading off echo off
# select value from nls_database_parameters where parameter='NLS_CHARACTERSET';
# exit;
# EOF`

# Prompt for character set
# echo ""
# echo "The current character set is $CURRENT_CharSet."
# echo "Please choose the character set for the new database:"
# echo "   (a) AL32UTF8"
# echo "   (b) US7ASCII"
# echo "   (c) WE8ISO8859P1"
# echo "Choose AL32UTF8 unless you have confirmed there are data loss issues. \c"
# while true
# do
	# read vCharSetSelect
	# if [[ "$vCharSetSelect" == "A" || "$vCharSetSelect" == "a" ]]
	# then
		# vCharSet=AL32UTF8
		# break
	# elif [[ "$vCharSetSelect" == "B" || "$vCharSetSelect" == "b" ]]
	# then
		# vCharSet=US7ASCII
		# break
	# elif [[ "$vCharSetSelect" == "C" || "$vCharSetSelect" == "c" ]]
	# then
		# vCharSet=WE8ISO8859P1
		# break
	# else
		# echo -e "Choose a valid option: \c"  
	# fi
# done

# Prompt for parallelism
# re='^[1-8]+$'
# echo ""
# echo "How much parallelism do you want for the export/import?"  
# echo "   (a) 2"
# echo "   (b) 8"
# echo "   (c) 10"
# echo "   (d) 12"
# echo "   (e) 14"
# while true
# do
	# read vParallelOption
	# if [[ "$vParallelOption" == "A" || "$vParallelOption" == "a" ]]
	# then
		# vParallelLevel=2
		# break
	# elif [[ "$vParallelOption" == "B" || "$vParallelOption" == "b" ]]
	# then
		# vParallelLevel=8
		# break
	# elif [[ "$vParallelOption" == "C" || "$vParallelOption" == "c" ]]
	# then
		# vParallelLevel=10
		# break
	# elif [[ "$vParallelOption" == "D" || "$vParallelOption" == "d" ]]
	# then
		# vParallelLevel=12
		# break
	# elif [[ "$vParallelOption" == "E" || "$vParallelOption" == "e" ]]
	# then
		# vParallelLevel=14
		# break
	# else
		# echo "Choose a valid option. \c"  
	# fi
# done
# echo "You have entered parallelism $vParallelLevel"

# Prompt for the SYSTEM password
# while true
# do
	# echo ""
	# echo "Enter the SYSTEM password:"
	# stty -echo
	# read vSystemPwd
	# if [[ -n "$vSystemPwd" ]]
	# then
		# break
	# else
		# echo "You must enter a password\n"
	# fi
# done
# stty echo
	
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
sleep 10
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
# echo "AIX Character Set:    $CURRENT_CharSet" | tee -a $vOutputLog
echo "Linux Character Set:  $vCharSet" | tee -a $vOutputLog
echo "Parallelism:          $vParallelLevel" | tee -a $vOutputLog
echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
echo "New Host:             $NEWHOST" | tee -a $vOutputLog
echo "Data Pump Dir:        $vDPParDir" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog

# Confirmation
echo ""
echo "Are these values correct?"
echo "Waiting for 1 minute"
sleep 60
# echo "Are these values correct? (Y) or (N) \c"
# while true
# do
	# read vConfirm
	# if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
	# then
		# echo "Proceeding with the installation..." | tee -a $vOutputLog
		# break
	# elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	# then
		# exit 2
	# else
		# echo "Please enter (Y) or (N).\c"  
	# fi
# done

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

# Data Pump directories
echo ""
echo "Checking Data Pump directory ${vDPParDir}" | tee -a $vOutputLog
if [[ ! -d ${vDPParDir} ]]
then
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
SETPARAM="${vOutputDir}/setparam_${DBNAME}.sql"
vOrigParams="${vOutputDir}/originalparam_${DBNAME}.txt"
CREATETS="${vOutputDir}/createts_${DBNAME}.sql"
REDOLOGS="${vOutputDir}/redologs_${DBNAME}.out"
UNDOSIZE="${vOutputDir}/undosize_${DBNAME}.sql"
TEMPSIZE="${vOutputDir}/tempsize_${DBNAME}.sql"
TSGROUPS="${vOutputDir}/tsgroups_${DBNAME}.sql"
SYSOBJECTS="${vOutputDir}/sysobjects_${DBNAME}.sql"
vCreateUsers=${vOutputDir}/3_create_users_${DBNAME}.sql
vCreateCommonUsers=${vOutputDir}/create_common_users_${DBNAME}.sql
CREATEQUOTAS=${vOutputDir}/4_create_quotas_${DBNAME}.sql
CREATEGRANTS=${vOutputDir}/6_create_grants_${DBNAME}.sql
CREATESYSPRIVS=${vOutputDir}/7_create_sys_privs_tousers_${DBNAME}.sql
CREATESYNS=${vOutputDir}/10_create_synonyms_${DBNAME}.sql
CREATEROLES=${vOutputDir}/5_create_roles_metadata_${DBNAME}.sql
# CREATELOGON=${vOutputDir}/12_create_logon_triggers_${DBNAME}.sql
CREATETRIGGERS=${vOutputDir}/12_create_other_triggers_${DBNAME}.sql
REVOKESYSPRIVS=${vOutputDir}/revoke_sys_privs_${DBNAME}.sql
vCreateExtTables=${vOutputDir}/create_ext_tables_${DBNAME}.sql
vProxyPrivs=${vOutputDir}/grant_proxy_privs_${DBNAME}.sql
vCreateDBLinks=${vOutputDir}/create_db_links_${DBNAME}.log
vRefreshGroups=${vOutputDir}/create_refresh_groups_${DBNAME}.sql
vCreateACL=${vOutputDir}/create_acls_${DBNAME}.sql

# set GG file names
TARFILE=Linux_setup_${DBNAME}.tar
SCNFILE="${vOutputDir}/current_scn_AIX_${ORACLE_SID}.out"

# set names of data pump param files/directories
vDPDataPar="${vDPParDir}/expdp_${DBNAME}.par"
vDPDataLog="${ORACLE_SID}.log"
vDPDataDump="${ORACLE_SID}_%U.dmp"
vDPImpPar="${vOutputDir}/impdp_${DBNAME}.par"

vDPMetaPar="${vDPParDir}/expdp_metadata_${DBNAME}.par"
vDPMetaLog="${ORACLE_SID}_metadata.log"
vDPDumpMeta="${ORACLE_SID}_metadata_%U.dmp"

vDPDataParGG="${vDPParDir}/expdp_ggtest_${DBNAME}.par"
vDPDataLogGG="${ORACLE_SID}_ggtest.log"
vDPDataDumpGG="${ORACLE_SID}_ggtest_%U.dmp"
vDPImpParGG="${vOutputDir}/impdp_ggtest_${DBNAME}.par"

echo "" | tee -a $vOutputLog
echo "Removing existing logs" | tee -a $vOutputLog
for file in $SETPARAM $vOrigParams $CREATETS $REDOLOGS $UNDOSIZE $TEMPSIZE $TSGROUPS $SYSOBJECTS $vCreateUsers $vCreateCommonUsers $CREATEQUOTAS $CREATEGRANTS $CREATESYSPRIVS $CREATESYNS $CREATEROLES $vCreateExtTables $vDefaultDates $vCreateDBLinks $vRefreshGroups $vProxyPrivs /tmp/${TARFILE} $vCreateACL $REVOKESYSPRIVS
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
PROMPT *** Create GGTEST user ***
DROP TABLESPACE GGS INCLUDING CONTENTS AND DATAFILES;
DROP user GGTEST cascade;

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- Create GG tablespace
CREATE TABLESPACE GGS DATAFILE '$DATAFILE_LOC/ggs01.dbf' SIZE 500M REUSE
AUTOEXTEND ON
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 4194304
SEGMENT SPACE MANAGEMENT AUTO;

select * from v\$instance;

create user GGTEST identified by gg#te#st01
default tablespace GGS;
--temporary tablespace TEMP;
ALTER USER GGTEST QUOTA UNLIMITED ON GGS;

grant connect, resource to GGTEST;

-- create DataPump directory
create or replace DIRECTORY CNO_MIGRATE as '$vDPParDir';

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

PROMPT *** Create table for LOB comparison ***
-- AIX
create table ggtest.${vLobTable} as
select owner, table_name, column_name, tablespace_name
from dba_lobs
where (owner||'.'||table_name) in
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

PROMPT *** Populate table for index comparison ***
-- AIX
insert into ggtest.${vIndexTable}
select ix.OWNER, ix.INDEX_NAME, ix.INDEX_TYPE, ix.TABLE_OWNER, ix.TABLE_NAME, ix.STATUS
from DBA_INDEXES ix, dba_objects ob
where ob.object_name=ix.index_name and ob.owner=ix.owner
and ob.object_type='INDEX' and ob.generated='N'
and (ix.TABLE_OWNER||'.'||ix.TABLE_NAME) in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');

PROMPT *** Create table for comparison of indexes with system-generated names ***
-- AIX
create table ggtest.${vSysGenIndexTable} as
select ic.table_owner, ic.table_name, ic.column_name, di.index_type, di.uniqueness, di.status, ic.descend 
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
join dba_objects ob
	on ob.object_name=di.index_name and ob.owner=di.owner
where ob.object_type='INDEX' and ob.generated='Y'
and (di.TABLE_OWNER||'.'||di.TABLE_NAME) in
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

PROMPT *** Create table for constraint comparison ***
-- AIX
create table ggtest.${vConstraintTable} as
select owner, table_name, constraint_name, constraint_type, status
from dba_constraints
where (owner||'.'||table_name) in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES');
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

PROMPT *** Loading tables counts (this may take a while) ***
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
    insert into ggtest.${vRowTable}
    values
      (rec.name, rec.host_name, rec.owner, rec.table_name, rec.status, record_count);
	commit;
  end loop;
  close cf;
end;
/

select 'There are '||count(*)||' tables.' from ggtest.${vRowTable};
select 'There are '||count(*)||' indexes.' from ggtest.${vIndexTable};
select 'There are '||count(*)||' indexes with system-generated names.' from ggtest.${vSysGenIndexTable};
select 'There are '||count(*)||' constraints.' from ggtest.${vConstraintTable};
select 'There are '||count(*)||' LOBs.' from ggtest.${vLobTable};

PROMPT *** Creating scripts for Linux side ***
spool off

SET FEEDBACK OFF
PROMPT +++++++++++++++++ INITIALIZATION PARAMETERS +++++++++++++++++
SPOOL $SETPARAM
-- unset mem parameters
select 'ALTER SYSTEM RESET ' || name || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
--where name in ('sga_max_size','sga_target','pga_aggregate_target','memory_max_target','memory_target')
--where name in ('memory_max_target','memory_target')
where value is NULL and name in
('memory_max_target','memory_target','sga_max_size','sga_target','shared_pool_size','streams_pool_size','large_pool_size','java_pool_size','pga_aggregate_target','db_cache_size')
order by 1;

select case
	when pm.value > (ms.MAXSGA+mp.MAXPGA) then 'ALTER SYSTEM SET ' || pm.name || '=' || pm.value || ' SCOPE=SPFILE;'
	else 'ALTER SYSTEM SET ' || pm.name || '=' || (ms.MAXSGA+mp.MAXPGA) || ' SCOPE=SPFILE;'
	end "STMT"
from v\$spparameter pm,
	(select case
		when max(to_number(value)) > 1258291200 then max(to_number(value))
		else 1258291200
		end "MAXSGA" 
	from v\$spparameter where name in ('sga_max_size','sga_target')
	) ms,
	(select case
		when max(to_number(value)) > 314572800 then max(to_number(value))
		else 314572800
		end "MAXPGA" 
	from v\$spparameter where name='pga_aggregate_target'
	) mp
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

select case
	when mx."max_mem" < 1258291200 then 'ALTER SYSTEM SET ' || sp.name || ' = 188743680 SCOPE=SPFILE;'
	else
		case 
			when to_number(sp.value) > mx."max_mem" * 0.15 then 'ALTER SYSTEM SET ' || sp.name || ' = ' || sp.value || ' SCOPE=SPFILE;'
			else 'ALTER SYSTEM SET ' || sp.name || ' = ' || mx."max_mem" * 0.15 || ' SCOPE=SPFILE;'
		end
	end "STMT"
from v\$spparameter sp,
	(select max(to_number(value)) "max_mem"
	from v\$spparameter
	where name in ('sga_max_size','sga_target','memory_max_target','memory_target')) mx
where sp.name='streams_pool_size';

-- set string parameters using single quotes
select 'ALTER SYSTEM SET ' || name || '=''' || display_value || ''' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name in 
('nls_date_format','db_securefile','parallel_min_time_threshold','query_rewrite_enabled','query_rewrite_integrity','star_transformation_enabled','workarea_size_policy','utl_file_dir');

-- set non-string parameters
select 'ALTER SYSTEM SET ' || name || '=' || display_value || ' SCOPE=SPFILE;' "STMT"
from v\$spparameter
where isspecified='TRUE' and name in ('optimizer_secure_view_merging','open_cursors','optimizer_dynamic_sampling','processes','sessions','global_names','undo_retention');

-- set data file max with extra for CDB
select 'ALTER SYSTEM SET ' || name || '=' || to_char(to_number(value)+10) || ' SCOPE=SPFILE;' "STMT"
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
select 'CREATE TABLESPACE "'||tbs.TABLESPACE_NAME||'" DATAFILE '''||
	case
		when dbf.FILE_NAME like '/move/${DBNAME}%trail%' then '/database/E${DBNAME}/${DBNAME}01/oradata'||substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1))
		when dbf.FILE_NAME like '/move/${DBNAME}%' then '/database/E${DBNAME}/'||substr(dbf.FILE_NAME,7,instr(dbf.FILE_NAME,'/',7)-7)||'/oradata'||substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1))
		else '/database/E${DBNAME}/${DBNAME}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||''
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
	when dbf.FILE_NAME like '/move/${DBNAME}_trail01/%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move/${DBNAME}_trail01/oradata/','/database/E${DBNAME}/${DBNAME}01/oradata/')||'00.dbf'' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	when dbf.FILE_NAME like '/move/${DBNAME}/exports/oradata/%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move/${DBNAME}/exports/oradata/','/database/E${DBNAME}/${DBNAME}01/oradata/')||''' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	when dbf.FILE_NAME like '/move/${DBNAME}%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||'/database/E${DBNAME}/'||substr(dbf.FILE_NAME,7,instr(dbf.FILE_NAME,'/',7)-7)||'/oradata'||substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1))||''' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	else 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE ''/database/E${DBNAME}/${DBNAME}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||'x'' SIZE '||to_char(dbf.BYTES)||
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
	when '01' then 'ALTER DATABASE TEMPFILE ''/database/E'||lower(vdb.name)||'/'||lower(vdb.name)||'01/oradata'||substr(dtf.FILE_NAME,instr(dtf.FILE_NAME,'/',-1))||''' RESIZE '||dtf.BYTES||';'
	else 
		case
			when dtf.FILE_NAME like '/move/idwptmp/%' then 'ALTER TABLESPACE TEMP ADD TEMPFILE '''||'/database/E'||lower(vdb.name)||'/'||lower(vdb.name)||'01/oradata'||substr(dtf.FILE_NAME,instr(dtf.FILE_NAME,'/',-1))||''' SIZE '||dtf.BYTES||';'
			else 'ALTER TABLESPACE TEMP ADD TEMPFILE '''||replace(dtf.FILE_NAME,'/move/','/database/E'||lower(vdb.name)||'/')||''' SIZE '||dtf.BYTES||';'
			end
	end "STMT"
from DBA_TEMP_FILES dtf, V\$DATABASE vdb
where dtf.TABLESPACE_NAME='TEMP';

-- create additional temp tablespaces
select 'CREATE TEMPORARY TABLESPACE "'||tbs.TABLESPACE_NAME||'" TEMPFILE '''||replace(dbf.FILE_NAME,'/move/','/database/E${DBNAME}/')||
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

select 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD TEMPFILE '''||replace(dbf.FILE_NAME,'/move/','/database/E${DBNAME}/')||''' SIZE '||BYTES||';' "STMT"
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
select 'ALTER TABLESPACE "'||dts.TABLESPACE_NAME||'" TABLESPACE GROUP '||tsg.GROUP_NAME||';'
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
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/bpat01/scripts','/nfs/bpat/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/bpat01/scripts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/idwd01/','/actlgroomer/') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/idwd01/%' and DIRECTORY_PATH not like '%admin%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/idwt01/','/actlgroomer/') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/idwt01/%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/lbilld01/data','/nfs/lbillt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/lbilld01/data%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/blcnavt01/scripts','/nfs/blcnavt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/blcnavt01/scripts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/home/cpa7yd/Extracts','/nfs/bparptt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/home/cpa7yd/Extracts%';
select 'CREATE OR REPLACE DIRECTORY ' || DIRECTORY_NAME || ' AS ''' || replace(DIRECTORY_PATH,'/move/awdt01/scripts','/nfs/awdt/appdata') || ''';' "STMT"
	from dba_directories
	where DIRECTORY_PATH like '/move/awdt01/scripts%';
SPOOL OFF

PROMPT +++++++++++++++++ TABLESPACE QUOTAS +++++++++++++++++
spool $CREATEQUOTAS
SELECT 'alter user "'|| dtb.owner || '" quota UNLIMITED on "' || dtb.tablespace_name || '";' "STMT"
FROM dba_tables dtb, dba_tablespaces dts
WHERE dtb.tablespace_name=dts.tablespace_name and dtb.tablespace_name is not null and dtb.owner NOT IN ($vExcludeUsers)
	UNION
SELECT 'alter user "'|| din.owner || '" quota UNLIMITED on "' || din.tablespace_name || '";'
FROM dba_indexes din, dba_tablespaces dts
WHERE din.tablespace_name=dts.tablespace_name and din.tablespace_name is not null and din.owner NOT IN ($vExcludeUsers)
	UNION
select 'alter user "'|| dtq.username ||'"'||
	case
		when dtq.max_bytes = -1 then ' quota UNLIMITED'
		else ' quota '||to_char(dtq.max_bytes)
	end ||
  ' on "' || dtq.tablespace_name || '";'
from dba_ts_quotas dtq, dba_tablespaces dts
WHERE dtq.tablespace_name=dts.tablespace_name and dtq.tablespace_name is not null and dtq.username NOT IN ($vExcludeUsers);
spool off;

-- set DDL output parameters
--SPOOL $vOutputLog APPEND
--EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
--EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',true);
--EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
--EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS',false);
--spool off;

PROMPT +++++++++++++++++ ROLES +++++++++++++++++
spool $CREATEROLES
SELECT dbms_metadata.get_ddl('ROLE',ROLE)||';' "STMT" FROM DBA_ROLES 
WHERE role not in ($vExcludeRoles)
ORDER BY role;
spool off;

PROMPT +++++++++++++++++ SYSTEM PRIVILEGES +++++++++++++++++
-- grant system privs
spool $CREATESYSPRIVS
SELECT 'grant '|| dsp.privilege ||' to "'|| dsp.grantee || '" ' ||
  (CASE
    WHEN dsp.admin_option = 'YES'
    THEN 'WITH admin OPTION'
    ELSE NULL
  END)
  || ';' "STMT"
FROM dba_sys_privs dsp
WHERE (dsp.grantee, dsp.privilege) NOT IN
	(select dr.role, sp.privilege
	 from dba_sys_privs sp, dba_roles dr
	 where sp.grantee=dr.role and sp.privilege='UNLIMITED TABLESPACE')
AND dsp.GRANTEE NOT IN ($vExcludeUsers)
AND dsp.grantee NOT IN ($vExcludeRoles)
UNION
SELECT 'grant '|| drp.granted_role || ' to "'|| drp.grantee || '" '||
  (CASE
    WHEN drp.admin_option = 'YES'
    THEN 'WITH ADMIN OPTION'
    ELSE NULL
  END)
  || ';' 
FROM dba_role_privs drp
WHERE drp.GRANTEE NOT IN ($vExcludeUsers)
AND drp.GRANTEE NOT IN ($vExcludeRoles)
UNION
SELECT 'grant '|| sp.privilege || ' to "'|| rp.grantee || '" '||
  (CASE
    WHEN sp.admin_option = 'YES'
    THEN 'WITH ADMIN OPTION'
    ELSE NULL
  END)
  || ';' 
from dba_sys_privs sp, dba_roles dr, dba_role_privs rp, dba_users du
where sp.grantee=dr.role and rp.granted_role=dr.role and du.username=rp.grantee
and sp.privilege='UNLIMITED TABLESPACE'
and rp.grantee not in ($vExcludeUsers);
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
select 'GRANT INDEX ON "DM_AGT_DIST"."RPT_LAPSE_NOTICE" TO CORE;' from dual;

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
select 'revoke INDEX ON "DM_AGT_DIST"."RPT_LAPSE_NOTICE" from core;' from dual;

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
select 'ALTER USER "'||client||'" GRANT CONNECT THROUGH '||proxy||
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

PROMPT +++++++++++++++++ SYNONYMS +++++++++++++++++
spool $CREATESYNS
select dbms_metadata.get_ddl('SYNONYM',synonym_name,owner)||';' "STMT" from dba_synonyms
where table_owner NOT IN ($vExcludeUsers) or db_link is not null;
spool off;

--PROMPT +++++++++++++++++ LOGON TRIGGERS +++++++++++++++++
--spool $CREATELOGON
--select DBMS_METADATA.GET_DDL('TABLE','LOGON_AUDIT_LOG','SYS')||';' "STMT" from dual;
--select DBMS_METADATA.GET_DDL('TABLE','LOGON_AUDIT_LOG_ARCHIVE','SYS')||';' "STMT" from dual;
--SELECT DBMS_METADATA.GET_DDL('TRIGGER',trigger_name,owner )||';' "STMT" FROM dba_triggers where triggering_event='LOGON ';
--spool off;

PROMPT +++++++++++++++++ OTHER TRIGGERS +++++++++++++++++
spool $CREATETRIGGERS
SELECT DBMS_METADATA.GET_DDL('TRIGGER',trigger_name,owner )||';' "STMT" 
FROM dba_triggers where triggering_event like 'LOGON%' and owner not in ($vExcludeUsers);
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
PROMPT *** Create data pump parameter files ***
SET ESCAPE OFF
SPOOL $vDPDataPar
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDataDump}' from dual;
select 'LOGFILE=${vDPDataLog}' from dual;
select 'PARALLEL=${vParallelLevel}' from dual;
select 'METRICS=Y' from dual;
select 'EXCLUDE=STATISTICS' from dual;
select 'TABLES=FISERV_GTWY.WS_TRXN_LOG,FISERV_GTWY.APP_TRANSMISSION,BLC_EAPP_GTWY.APP_EMP_DTL_FORM,BLC_EAPP_GTWY.APP_PAYLD,FISERV_GTWY.APP_EMP_DTL_FORM,STG.S1_XML_ACORD,FISERV_GTWY.APP_PAYLD' from dual;
--select 'TABLES=JIRA.PROPERTYSTRING,SONAR.ISSUE_FILTER_FAVOURITES' from dual;
SPOOL OFF

SPOOL $vDPDataParGG
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDataDumpGG}' from dual;
select 'LOGFILE=${vDPDataLogGG}' from dual;
select 'PARALLEL=1' from dual;
select 'METRICS=Y' from dual;
select 'EXCLUDE=STATISTICS' from dual;
select 'SCHEMAS=GGTEST' from dual;
SPOOL OFF

--DECLARE
--  CURSOR c1 IS
--    select case
--		when username!=upper(username) then '\\"'||username||'\\"'
--		else username
--		end "STMT"
--	from dba_users where username not in ($vExcludeUsers);
--  vOwner	VARCHAR2(30);
--  x			PLS_INTEGER;
--BEGIN
--  DBMS_OUTPUT.PUT_LINE('DIRECTORY=CNO_MIGRATE');
--  DBMS_OUTPUT.PUT_LINE('DUMPFILE=${vDPDataDump}');
--  DBMS_OUTPUT.PUT_LINE('LOGFILE=${vDPDataLog}');
--  DBMS_OUTPUT.PUT_LINE('PARALLEL=${vParallelLevel}');
--  DBMS_OUTPUT.PUT_LINE('METRICS=Y');
--  DBMS_OUTPUT.PUT_LINE('EXCLUDE=STATISTICS');
--  DBMS_OUTPUT.PUT('SCHEMAS=');
--  
--  x := 1;
--  OPEN c1;
--  LOOP
--    FETCH c1 INTO vOwner;
--	EXIT WHEN c1%NOTFOUND;
--	  IF x = 1 THEN
--        DBMS_OUTPUT.PUT(vOwner);
--      ELSE
--        DBMS_OUTPUT.PUT(','||vOwner);
--      END IF;
--	  x := x + 1;
--  END LOOP;
--  DBMS_OUTPUT.NEW_LINE;
--  CLOSE c1;
--END;
--/
--SPOOL OFF

PROMPT *** Create Data Pump metadata param file ***
SPOOL $vDPMetaPar
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDumpMeta}' from dual;
select 'LOGFILE=${vDPMetaLog}' from dual;
select 'CONTENT=METADATA_ONLY' from dual;
select 'METRICS=Y' from dual;
select 'FULL=Y' from dual;
SPOOL OFF

exit;
RUNSQL

# check logs for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
for file in $SETPARAM $vOrigParams $REDOLOGS $CREATETS $TEMPSIZE $TSGROUPS $SYSOBJECTS $CREATEQUOTAS $CREATEROLES $CREATEGRANTS $CREATESYSPRIVS $vProxyPrivs $CREATESYNS $vCreateExtTables $vCreateDBLinks $vRefreshGroups $REVOKESYSPRIVS
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

PROMPT +++++++++++++++++++++++ CREATE USERS +++++++++++++++++++++++
spool $vCreateUsers
-- create users accounting for password compatibility and tablespaces
WITH pt AS
	(select tablespace_name from dba_tablespaces where contents='PERMANENT'),
tt AS
	(select tablespace_name from dba_tablespaces where contents='TEMPORARY'),
us AS
	(select name, password, translate(password,'0123456789ABCDEF','----------------') dashes from user\$)
select 'CREATE USER "'||du.username||'" IDENTIFIED BY VALUES '''||
	DECODE(us.dashes,'----------------',us.password,'S:0F9DDB9E51A96D66D8754952C4F1D987FE5E527F5E3BD9C7C5F08983B532;T:5BB9FF165DF9261D3D9B0A99BF37BD5985E8A0A59D42046185BFF0326950CB3A8FBF7E4A39EBDA3BF521F2D28D3C31AB27ABA24A19F43C3F1B5CD3BC0421A1DA0920DC6A88647656CAC1E87CC8937F0D;DE50D6C930ACAF6E')||
	''' DEFAULT TABLESPACE "'||NVL(pt.tablespace_name,'USERS')||'"'||
	' TEMPORARY TABLESPACE "'||NVL(tt.tablespace_name,'TEMP')||'"'||
	' PROFILE '||du.profile||';' "STMT"
from dba_users du join us on du.username=us.name
	full outer join pt on du.default_tablespace=pt.tablespace_name
	full outer join tt on du.temporary_tablespace=tt.tablespace_name
where du.AUTHENTICATION_TYPE!='EXTERNAL'
and du.username NOT IN ($vExcludeUsers);
spool off

spool $vCreateCommonUsers
-- create external users with tier name
select 'CREATE USER "'||
case INSTR(us.username, pf.value)
	when 1 then substr(us.username,NVL(length(pf.value),0)+1) 
	else us.username
end
	||'${vTierCap}" IDENTIFIED EXTERNALLY CONTAINER=ALL'||
	' DEFAULT TABLESPACE '||us.default_tablespace||
	' TEMPORARY TABLESPACE '||us.temporary_tablespace||
	' PROFILE '||us.profile||';'
	"STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL'
and (us.username like '%UT' or us.username like '%SIT' or us.username like '%UAT' or us.username like '%PROD');

select 'GRANT SET CONTAINER TO "'||substr(us.username,NVL(length(pf.value),0)+1)||'" CONTAINER=ALL;' "STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL'
and (us.username like '%UT' or us.username like '%SIT' or us.username like '%UAT' or us.username like '%PROD');

select 'GRANT CREATE SESSION TO "'||substr(us.username,NVL(length(pf.value),0)+1)||'" CONTAINER=ALL;' "STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL'
and (us.username like '%UT' or us.username like '%SIT' or us.username like '%UAT' or us.username like '%PROD');

-- create external users without tier name
select 'CREATE USER "'||
case INSTR(us.username, pf.value)
	when 1 then substr(us.username,NVL(length(pf.value),0)+1) 
	else us.username
end
	||'${vTierCap}" IDENTIFIED EXTERNALLY CONTAINER=ALL'||
	' DEFAULT TABLESPACE '||us.default_tablespace||
	' TEMPORARY TABLESPACE '||us.temporary_tablespace||
	' PROFILE '||us.profile||';'
	"STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
and us.username not like '%UT' and us.username not like '%SIT' and us.username not like '%UAT' and us.username not like '%PROD';

select 'GRANT SET CONTAINER TO "'||substr(us.username,NVL(length(pf.value),0)+1)||'${vTierCap}" CONTAINER=ALL;' "STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
and us.username not like '%UT' and us.username not like '%SIT' and us.username not like '%UAT' and us.username not like '%PROD';

select 'GRANT CREATE SESSION TO "'||substr(us.username,NVL(length(pf.value),0)+1)||'${vTierCap}" CONTAINER=ALL;' "STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
and us.username not like '%UT' and us.username not like '%SIT' and us.username not like '%UAT' and us.username not like '%PROD';
spool off

PROMPT +++++++++++++++++ UNDO FILE SIZE +++++++++++++++++
SPOOL $UNDOSIZE
select 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" RETENTION '||tbs.retention||';' "STMT"
from DBA_TABLESPACES tbs
where tbs.TABLESPACE_NAME='UNDO'
order by 1;
select 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(FILE_NAME,'/move/','/database/E${DBNAME}/')||''' SIZE '||dbf.BYTES||';' "STMT"
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME
and tbs.TABLESPACE_NAME='UNDO' and dbf.BYTES>5368709120
order by 1;
SPOOL OFF

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
  DBMS_OUTPUT.PUT_LINE('LOGFILE=impdp_${ORACLE_SID}.log');
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

PROMPT +++++++++++++++++++++++ CREATE USERS +++++++++++++++++++++++
spool $vCreateUsers
-- OS authenticated users with tier name
select 'CREATE USER "'||substr(us.username,NVL(length(pf.value),0)+1)||'" IDENTIFIED EXTERNALLY'||
	' DEFAULT TABLESPACE '||us.default_tablespace||
	' TEMPORARY TABLESPACE '||us.temporary_tablespace||
	' PROFILE '||us.profile||';'
	"STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL'
and (us.username like '%UT' or us.username like '%SIT' or us.username like '%UAT' or us.username like '%PROD');

-- add tier letter to OS-authenticated users
select 'CREATE USER "'||substr(us.username,NVL(length(pf.value),0)+1)||'${vTierCap}" IDENTIFIED EXTERNALLY'||
	' DEFAULT TABLESPACE '||us.default_tablespace||
	' TEMPORARY TABLESPACE '||us.temporary_tablespace||
	' PROFILE '||us.profile||';'
	"STMT"
from dba_users us,
(select upper(value) "VALUE" from v\$parameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL' and us.username!='OPS\$ORACLE'
and us.username not like '%UT' and us.username not like '%SIT' and us.username not like '%UAT' and us.username not like '%PROD';

WITH pt AS
	(select tablespace_name from dba_tablespaces where contents='PERMANENT'),
tt AS
	(select tablespace_name from dba_tablespaces where contents='TEMPORARY'),
us AS
	(select name, password from user\$)
select 'CREATE USER "'||du.username||'" IDENTIFIED BY VALUES '''||NVL(us.password,'127CCE670C325256')||
	''' DEFAULT TABLESPACE "'||NVL(pt.tablespace_name,'USERS')||'"'||
	' TEMPORARY TABLESPACE "'||NVL(tt.tablespace_name,'TEMP')||'"'||
	' PROFILE '||du.profile||';' "STMT"
from dba_users du join us on du.username=us.name
	full outer join pt on du.default_tablespace=pt.tablespace_name
	full outer join tt on du.temporary_tablespace=tt.tablespace_name
where du.AUTHENTICATION_TYPE!='EXTERNAL'
and du.username NOT IN ($vExcludeUsers)
and du.username not in ('SQLTUNE','TNS_USER','ECORA');
spool off;

PROMPT +++++++++++++++++ UNDO FILE SIZE +++++++++++++++++
SPOOL $UNDOSIZE
select case
	when SHORT_NAME='undo01.dbf' then
		case
			when BYTES > 5368709120 then 'ALTER DATABASE DATAFILE '''||replace(FILE_NAME,'/move/','/database/E${DBNAME}/')||''' RESIZE '||BYTES||';'
			else '-- undo01.dbf is less than 5120 MB'
		end
	else 'ALTER TABLESPACE "'||TABLESPACE_NAME||'" ADD DATAFILE '''||replace(FILE_NAME,'/move/','/database/E${DBNAME}/')||''' SIZE '||BYTES||';'
end "STMT"
from
	(select dbf.FILE_NAME, substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1)+1) "SHORT_NAME",
	 tbs.TABLESPACE_NAME, dbf.BYTES
	 from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
	 where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME
	 and tbs.TABLESPACE_NAME='UNDO')
order by 1;
SPOOL OFF

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
for file in $vCreateUsers $UNDOSIZE
do
	if [[ -e $file ]]
	then
		error_check_fnc $file $vErrorLog $vCritLog
	else
		echo "ERROR: $file could not be found" | tee -a $vOutputLog
		exit 1
	fi
done
# check 12c only logs for errors
if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
then
	if [[ -e $vCreateCommonUsers ]]
	then
		error_check_fnc $vCreateCommonUsers $vErrorLog $vCritLog
	else
		echo "ERROR: $vCreateCommonUsers could not be found" | tee -a $vOutputLog
		exit 1
	fi
fi

# create script for ACL, not set up on all DBs
ACL_COUNT=`sqlplus -s / as sysdba <<EOF
col acl_count format 999999999999999
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from dba_views where view_name='DBA_NETWORK_ACLS';
exit;
EOF`
echo "ACL_COUNT is $ACL_COUNT"

# if ACL set up, run script to recreate
if [[ $ACL_COUNT -gt 0 ]]
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
echo "The time is `date`"  | tee -a $vOutputLog

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
if [ -f ${vDPParDir}/${ORACLE_SID}*.dmp ]
then
	rm ${vDPParDir}/${ORACLE_SID}*.dmp
fi
if [ -f ${vDPParDir}/${ORACLE_SID}*.log ]
then
	rm ${vDPParDir}/${ORACLE_SID}*.log
fi

# export data
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataPar
cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLog} $vErrorLog $vCritLog

# export ggtest schema
expdp \"/ as sysdba\" flashback_scn=${CURRENT_SCN} parfile=$vDPDataParGG
cat ${vDPParDir}/${vDPDataLogGG} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPDataLogGG} $vErrorLog $vCritLog

# export metadata
expdp \"/ as sysdba\" parfile=$vDPMetaPar
cat ${vDPParDir}/${vDPMetaLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPMetaLog} $vErrorLog $vCritLog

############################ Check DB Links ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Checking Database Links       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# find database links
vDBLinks=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL`

for linkname in ${vDBLinks[@]}
do
	# find all owners with a link with this name
	vLinkOwner=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL`

	for ownername in ${vLinkOwner[@]}
	do
		# check public links
		if [[ $ownername = "PUBLIC" ]]
		then
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${linkname};
EXIT;
RUNSQL`
			# if link did not work, check if it is HS
			if [[ $vLinkTest != "1" ]]
			then
				vHSLinkCheck=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
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
			vLinkTest=`$ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@${ORACLE_SID}" << RUNSQL
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

############################ Copy Scripts ############################

# echo "" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog
# echo "* Copy scripts to new host      *" | tee -a $vOutputLog
# echo "*********************************" | tee -a $vOutputLog

# add all files to archive
cd $vOutputDir
tar -cvf $TARFILE *${ORACLE_SID}* *${DBShort}*

# echo ""
# copy files to new host
# if [[ AUTOMODE -eq 1 ]]
# then
	# echo "Copying archive file to $NEWHOST. You may be prompted for the password." | tee -a $vOutputLog
	# scp ${TARFILE} oracle@${NEWHOST}:${vNewDir} | tee -a $vOutputLog
	# if [ $? -ne 0 ]
	# then
		# echo "" | tee -a $vOutputLog
		# echo "There was a problem copying $TARFILE to $NEWHOST. Please run this command manually:" | tee -a $vOutputLog
		# echo "scp ${TARFILE} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog
	# fi
# else
	# echo "Cannot connect to $NEWHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
	# echo "${TARFILE}" | tee -a $vOutputLog
# fi

############################ Report Timing of Script ############################

vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:          $ORACLE_SID" | tee -a $vOutputLog
echo "Linux host:             $NEWHOST" | tee -a $vOutputLog
echo "Output log:             $vOutputLog" | tee -a $vOutputLog
echo "Script archive:         ${vOutputDir}/${TARFILE}" | tee -a $vOutputLog
echo "Data Pump directory:    $vDPParDir" | tee -a $vOutputLog
echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "Run this command to copy the scripts to ${NEWHOST}" | tee -a $vOutputLog
echo "scp ${TARFILE} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog