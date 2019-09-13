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

export ORACLE_HOME=/nomove/app/oracle/db/11g/6
export TNS_ADMIN=/nomove/app/oracle/tns_admin
export PATH=/usr/sbin:$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$GGATE
export RUNDIR=/nomove/app/oracle/scripts/12cupgrade

# Database constants
vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE','SQLTUNE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE'"
vNewHome12c="/app/oracle/product/db/12c/1"
vNewHome11g="/app/oracle/product/db/11g/1"

# array of 11g databases
set -A List11g "cigfdsd cigfdst cigfdsm cigfdsp inf91d infgix8d infgix8t infgix8m infgix8p fdlzd fdlzt fdlzm trecscd trecsct trecscm trecscp obieed obieet obieem obieep obiee2d opsm opsp bpad bpat bpam bpap fnp8d fnp8t fnp8m fnp8p portalm c3appsd c3appst c3appsm c3appsp cpsmrtsm cpsmrtsp idmp p8legalp"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
vTierCap=`echo $vTier | tr 'a-z' 'A-Z'`
if [[ $vTier = 's' ]]
then
	export GGATE=/backup_uxs33/ggate/12.2
	export GGLINUX12=/oragg/12.2
	export GGLINUX11=/app/oragg/12.2_11g
	export GGMOUNT=/backup_uxs33/dpdump
else
	export GGATE=/nomove/app/oracle/ggate/12c/1
	export GGLINUX12=/app/oracle/product/ggate/12c/1
	export GGLINUX11=/app/oracle/product/ggate/11g/1
	export GGMOUNT=/oragg
fi

# GoldenGate constants
GGOUT="${GGATE}/dirout"
GGDAT="${GGATE}/dirdat"
GGPRM="${GGATE}/dirprm"
GGTMP="${GGMOUNT}/dirtmp"
GGMGROUT="${GGOUT}/mgrstatus_${ORACLE_SID}.out"
vSeqScript=${GGATE}/sequence_auto.sql

# ACL script
vACLScript="${RUNDIR}/network_acls_ddl.sql"

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

############################ GoldenGate View Report ##########################
# PURPOSE:                                                                   #
# This function views the errors in a GG process report.                     #
##############################################################################

function view_report_fnc {
	cd $GGATE
	# Check report file
	./ggsci > $GGALLOUT << EOF
view report $1
exit
EOF

	# display errors
	echo "" | tee -a $vOutputLog
	echo "Report errors for $1:" | tee -a $vOutputLog
	cat $GGALLOUT | grep ERROR | tee -a $vOutputLog
}

############################ GoldenGate Process Check ########################
# PURPOSE:                                                                   #
# This function checks if a GG process already running.                      #
##############################################################################

function gg_pre_check_fnc {
	# Check if GG extract is running
	./ggsci > $GGALLOUT << EOF
info all
exit
EOF
	
	cat $GGALLOUT | tee -a $vOutputLog
	GGALLSTATUS=$(cat $GGALLOUT | grep "$1" | wc -l)
	if [[ $GGALLSTATUS -ne 0 ]]
	then
		echo ""  | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
		echo "ERROR"  | tee -a $vOutputLog
		echo "The GG process $1 is already running here."  | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
		exit 1
	else
		echo ""  | tee -a $vOutputLog
		echo "No $1 process exists."  | tee -a $vOutputLog
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
		./ggsci > $GGALLOUT << EOF
info all
exit
EOF
		cat $GGALLOUT | tee -a $vOutputLog
		GGALLSTATUS=$(cat $GGALLOUT | grep "$1" | awk '{ print $2}')
		if [[ $GGALLSTATUS = "STOPPED" || $GGALLSTATUS = "ABENDED" ]]
		then
			GGRUNNING="FALSE"
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			echo "WARNING"  | tee -a $vOutputLog
			echo "The GG process $1 is $GGALLSTATUS."  | tee -a $vOutputLog
			echo "Please make sure this is running before continuing."  | tee -a $vOutputLog
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			view_report_fnc $1
			break
			#exit 1
		elif [[ $GGALLSTATUS = "RUNNING" ]]
		then
			echo "" | tee -a $vOutputLog
			echo "SUCCESS: The GG process $1 is $GGALLSTATUS." | tee -a $vOutputLog
			break
		else
			sleep 10
		fi
	done
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
		./ggsci > $GGRBAOUT << EOF
info $1
exit
EOF
		# get RBA value
		GGRBASTATUS=$(cat $GGRBAOUT | grep RBA | awk '{ print $4}')
		# is this the first check?
		if [[ $vRBACheckCt -eq 1 ]]
		then
			cat $GGRBAOUT | tee -a $vOutputLog
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

############################ Array variables ############################

echo ""
echo "*********************************"
echo "* Checking required files/dirs  *"
echo "*********************************"

if [[ -d $GGTMP ]]
then
	echo ""
	echo "Creating directory $GGTMP"
	mkdir $GGTMP
fi

# Set directory array
unset vDirArray
set -A vDirArray $GGATE $GGDAT ${GGPRM} $RUNDIR ${RUNDIR}/logs $GGMOUNT

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
set -A vFileArray $vACLScript $vSeqScript

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
export ORACLE_SID=${DBNAME}

# Prompt for location of 12c database
echo ""
echo "Enter the new Linux host for the database: \c"  
while true
do
	read NEWHOST
	if [[ -n "$NEWHOST" ]]
	then
		echo "You have entered new host $NEWHOST"
		break
	else
		echo "Enter a valid host name: \c"  
	fi
done

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
echo "   (a) 1"
echo "   (b) 2"
echo "   (c) 4"
echo "   (d) 6"
echo "   (e) 8"
while true
do
	read vParallelOption
	if [[ "$vParallelOption" == "A" || "$vParallelOption" == "a" ]]
	then
		vParallelLevel=1
		break
	elif [[ "$vParallelOption" == "B" || "$vParallelOption" == "b" ]]
	then
		vParallelLevel=2
		break
	elif [[ "$vParallelOption" == "C" || "$vParallelOption" == "c" ]]
	then
		vParallelLevel=4
		break
	elif [[ "$vParallelOption" == "D" || "$vParallelOption" == "d" ]]
	then
		vParallelLevel=6
		break
	elif [[ "$vParallelOption" == "E" || "$vParallelOption" == "e" ]]
	then
		vParallelLevel=8
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
	
# Prompt for the GGS password
while true
do
	echo ""
	echo "Enter the GGS password:"
	stty -echo
	read GGSPWD
	echo "Verify the GGS password:"
	read GGSPWDVerf
	if [[ $GGSPWD != $GGSPWDVerf ]]
	then
		echo "The passwords do not match\n"
	elif [[ -n "$GGSPWD" ]]
	then
		break
	else
		echo "You must enter a password\n"
	fi
done
stty echo

############################ Set New DB Version ############################

NEW_ORACLE_HOME=$vNewHome12c
for dblist in ${List11g[@]}
do
	if [[ $dblist = $DBNAME ]]
	then
		NEW_ORACLE_HOME=$vNewHome11g
		break
	fi
done

############################ Set GG Host ############################

# Set GoldenGate output files
GGALLOUT="${GGOUT}/allstatus_${ORACLE_SID}.out"
GGRBAOUT="${GGOUT}/rbastatus_${ORACLE_SID}.out"

# Set GoldenGate host based on tier
# Set trail location based on new DB version
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
then
	if [[ $vTier = 'p' ]]
	then
		GGHOST=lxoggp01
		vRmtTrail="${GGLINUX12}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 'm' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX12}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 't' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX12}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 'd' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX12}/dirdat/${ORACLE_SID}/ra"
		#vRmtTrail="${DBTRAIL}/ra"
	elif [[ $vTier = 's' ]]
	then
		GGHOST=lxora12cinfs02
	#	GGHOST=$NEWHOST
		vRmtTrail="${GGLINUX12}/dirdat/${ORACLE_SID}/ra"
	else
		echo "" | tee -a $vOutputLog
		echo "ERROR: The tier for this host, $vTier, is not recognized!" | tee -a $vOutputLog
		exit 1
	fi
else
	if [[ $vTier = 'p' ]]
	then
		GGHOST=lxoggp01
		vRmtTrail="${GGLINUX11}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 'm' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX11}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 't' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX11}/dirdat/${ORACLE_SID}/ra"
	elif [[ $vTier = 'd' ]]
	then
		GGHOST=lxoggm01
		vRmtTrail="${GGLINUX11}/dirdat/${ORACLE_SID}/ra"
		#vRmtTrail="${DBTRAIL}/ra"
	elif [[ $vTier = 's' ]]
	then
		GGHOST=lxora12cinfs02
	#	GGHOST=$NEWHOST
		vRmtTrail="${GGLINUX11}/dirdat/${ORACLE_SID}/ra"
	else
		echo "" | tee -a $vOutputLog
		echo "ERROR: The tier for this host, $vTier, is not recognized!" | tee -a $vOutputLog
		exit 1
	fi
fi

############################ Confirmation ############################

vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_${NOWwSECs}.log"
vErrorLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_err.log"
vCritLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_crit.log"
vGGLog="${RUNDIR}/logs/${vBaseName}_${ORACLE_SID}_GG.log"
DMPDIR="${GGMOUNT}/datapump"
vDPParDir="${DMPDIR}/${ORACLE_SID}"

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
echo "Database Name:      $ORACLE_SID" | tee -a $vOutputLog
if [[ $NEW_ORACLE_HOME = $vNewHome12c ]]
then
	echo "New DB Version:     12c" | tee -a $vOutputLog
else
	echo "New DB Version:     11g" | tee -a $vOutputLog
fi
echo "New Character Set:  $vCharSet" | tee -a $vOutputLog
echo "Export parallelism: $vParallelLevel" | tee -a $vOutputLog
echo "Oracle Home:        $ORACLE_HOME" | tee -a $vOutputLog
echo "New Host:           $NEWHOST" | tee -a $vOutputLog
echo "GG Remote Host:     $GGHOST" | tee -a $vOutputLog
echo "GG Manager:         $GGMGRSTATUS" | tee -a $vOutputLog
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

############################ Check for patch ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Checking for patch 24491261   *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set environment variables
unset LIBPATH
export ORACLE_SID=$DBNAME
export ORAENV_ASK=NO
export PATH=/usr/local/bin:$PATH
. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib

# Get patch status
PATCHED=$( $ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on
select comments from registry\$history where id=24491261 and rownum=1;
exit;
EOF
)

if [[ $PATCHED = "Patch 24491261 applied" ]]
then
	echo "" | tee -a $vOutputLog
	echo "Patch 24491261 has been applied.  Continuing..." | tee -a $vOutputLog
else
	echo "" | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
	echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	echo "Patch 24491261 must be applied before you can run GoldenGate on this DB." | tee -a $vOutputLog
	echo "The status is $PATCHED" | tee -a $vOutputLog
	exit 1
fi

############################ Add memory ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Add memory to streams pool    *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

echo "The current memory settings are as follows:"
$ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
SET ECHO ON
SET DEFINE OFF
SET ESCAPE OFF
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 2500
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL $vOutputLog APPEND
col name format a20
col DISPLAY_VALUE format a15
select name, DISPLAY_VALUE 
from v\$parameter 
where name in ('sga_max_size','sga_target','memory_max_target','memory_target','streams_pool_size') 
and value!='0' and value is not null
order by 1;

! echo ""
! echo "The streams pool will be set to 15% of SGA."
BEGIN
  FOR i IN
    (select case
		when (mx.maxsga*0.15) > NVL(value,0) then 'alter system set '||sp.name||'='||TRUNC(mx.maxsga*0.15,0)||' comment=''original '||NVL2(sp.DISPLAY_VALUE,sp.DISPLAY_VALUE,0)||''' scope=both'
		end as cmd
	from v\$spparameter sp,
		(select max(value) maxsga from v\$spparameter 
		 where name in ('sga_max_size','sga_target','memory_max_target','memory_target') 
		 and value!='0' and value is not null) mx
	where name='streams_pool_size' and (mx.maxsga*0.15) > NVL(value,0))
  LOOP
    dbms_output.put_line(i.cmd);
    execute immediate i.cmd;
  END LOOP;
END;
/
SPOOL OFF
exit
RUNSQL

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
echo "COMPLETE" | tee -a $vOutputLog

############################ Additional prep-work ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Setting directory names       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# set umask
vOldUmask=`umask`
umask 0000

# GoldenGate trail file directory
echo ""
echo "Checking GoldenGate directory ${DBTRAIL}" | tee -a $vOutputLog
DBTRAIL="${GGDAT}/${ORACLE_SID}"
EXTTRAIL="${DBTRAIL}/ea"
if [[ ! -d ${DBTRAIL} ]]
then
	mkdir ${DBTRAIL}
	if [[ $? -ne 0 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "There was a problem creating ${DBTRAIL}" | tee -a $vOutputLog
		exit 1
	else
		echo "Directory ${DBTRAIL} has been created." | tee -a $vOutputLog
	fi
fi

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

# Check connection to new host
echo ""
echo "Checking connections to $NEWHOST and $GGHOST" | tee -a $vOutputLog
AUTOMODE=0
ping -c 1 $NEWHOST
if [[ $? -eq 0 ]]
then
	ping -c 1 $GGHOST
	if [[ $? -eq 0 ]]
	then
		AUTOMODE=1
	else
		echo "WARNING: Unable to ping $GGHOST." | tee -a $vOutputLog
	fi
else
	echo "WARNING: Unable to ping $NEWHOST." | tee -a $vOutputLog
fi

# set data directory to most recent one
#set -A vDataDirs $(ls /move | grep ^${DBNAME}0 | sort -r)
#set -A vDataDirs $(df -g | grep /move/${DBNAME} | awk '{ print $7}' | grep -Ev "adm|redo|arch|diag|${DBNAME}_|old" | sort -r)
#for vDirName in ${vDataDirs[@]}
#do
#	DATAFILE_LOC="${vDirName}/oradata"
#	if [[ -d $DATAFILE_LOC ]]
#	then
#		echo "" | tee -a $vOutputLog
#		echo "Will create GG tablespace in $DATAFILE_LOC" | tee -a $vOutputLog
#		break
#	fi
#done
#if [[ ! -d $DATAFILE_LOC ]]
#then
#        echo "ERROR: $DATAFILE_LOC data directory does not exist!" | tee -a $vOutputLog
#        exit 1
#fi
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
echo "* Setting GoldenGate names      *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "" | tee -a $vOutputLog

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
vExtName="E${DBShort}1"
echo "Extract name is set to $vExtName" | tee -a $vOutputLog
VarLen=$(echo $vExtName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vExtName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
fi
vPushName="P${DBShort}1"
echo "Pump name is set to $vPushName" | tee -a $vOutputLog
VarLen=$(echo $vPushName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vPushName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
fi
vRepName="R${DBShort}1"
echo "Replicat name is set to $vRepName" | tee -a $vOutputLog
VarLen=$(echo $vRepName | awk '{ print length($0) }')
if [[ $VarLen -gt 8 ]]
then
	echo "" | tee -a $vOutputLog
	echo "ERROR: The extract name $vRepName is too long. Max is 8 characters." | tee -a $vOutputLog
	exit 1
fi

# make sure GG processes don't exist
gg_pre_check_fnc $vExtName
gg_pre_check_fnc $vPushName

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
DISABLETRIGGERS=${vOutputDir}/8_disable_triggers_${DBNAME}.sql
ENABLETRIGGERS=${vOutputDir}/8_enable_triggers_${DBNAME}.sql
CREATESYNS=${vOutputDir}/10_create_synonyms_${DBNAME}.sql
CREATEROLES=${vOutputDir}/5_create_roles_metadata_${DBNAME}.sql
CREATELOGON=${vOutputDir}/12_create_logon_triggers_${DBNAME}.sql
REVOKESYSPRIVS=${vOutputDir}/revoke_sys_privs_${DBNAME}.sql
vCreateExtTables=${vOutputDir}/create_ext_tables_${DBNAME}.sql
vProxyPrivs=${vOutputDir}/grant_proxy_privs_${DBNAME}.sql
vCreateDBLinks=${vOutputDir}/create_db_links_${DBNAME}.log
vRefreshGroups=${vOutputDir}/create_refresh_groups_${DBNAME}.sql
vCreateACL=${vOutputDir}/create_acls_${DBNAME}.sql

# set GG file names
TARFILE=Linux_setup_${DBNAME}.tar
EPRMFILE="${GGPRM}/${vExtName}.prm"
PPRMFILE="${GGPRM}/${vPushName}.prm"
RPRMFILE="${vOutputDir}/${vRepName}.prm"
# RevRPRMFILE="${GGPRM}/${vRepName}.prm"
ADDTRANDATA="${GGPRM}/ADD_TRANDATA_${ORACLE_SID}.oby"
CREATEEXTRACT="${GGPRM}/${ORACLE_SID}_create_extract.oby"
STARTEXTRACT="${GGPRM}/${ORACLE_SID}_start_extract.oby"
#FLUSHSEQUENCES="${GGPRM}/FLUSH_SEQ_${ORACLE_SID}.oby"
SCNFILE="${vOutputDir}/current_scn_AIX_${ORACLE_SID}.out"

# set names of data pump param files/directories
vDPDataPar="${vDPParDir}/expdp_${DBNAME}.par"
vDPMetaPar="${vDPParDir}/expdp_metadata_${DBNAME}.par"
vDPImpPar="${vOutputDir}/impdp_${DBNAME}.par"
vDPDataLog="${ORACLE_SID}.log"
vDPMetaLog="${ORACLE_SID}_metadata.log"
vDPDataDump="${ORACLE_SID}_%U.dmp"
vDPDumpMeta="${ORACLE_SID}_metadata_%U.dmp"

echo "" | tee -a $vOutputLog
echo "Removing existing logs" | tee -a $vOutputLog
for file in $SETPARAM $vOrigParams $CREATETS $REDOLOGS $UNDOSIZE $TEMPSIZE $TSGROUPS $SYSOBJECTS $vCreateUsers $vCreateCommonUsers $CREATEQUOTAS $CREATEGRANTS $CREATESYSPRIVS $REVOKESYSPRIVS $DISABLETRIGGERS $ENABLETRIGGERS $CREATESYNS $CREATEROLES $CREATELOGON $vCreateExtTables $vDefaultDates $vCreateDBLinks $vRefreshGroups $vProxyPrivs /tmp/${TARFILE} $vDPDataPar $vDPMetaPar $vDPImpPar $EPRMFILE $PPRMFILE $RPRMFILE $SCNFILE ${vDPParDir}/${vDPDataLog} ${vDPParDir}/${vDPMetaLog} $vCreateACL
do
	if [[ -e $file ]]
	then
		echo "Deleting $file" | tee -a $vOutputLog
		rm $file
	fi
done

# set DDL variables
vDDLInclude="${GGPRM}/ealldbs_DDL.inc"

# Check if DDL file exist
echo "" | tee -a $vOutputLog
echo "Checking that all required files exist..." | tee -a $vOutputLog
if [ ! -e $vDDLInclude ]
then
	echo "ERROR: $vDDLInclude does not exist!" | tee -a $vOutputLog
	exit 1
fi

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
PROMPT *** Create GoldenGate users ***
DROP TABLESPACE GGS INCLUDING CONTENTS AND DATAFILES;
DROP user GGS cascade;
DROP user GGTEST cascade;

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- Create GG tablespace
CREATE TABLESPACE GGS DATAFILE '$DATAFILE_LOC/ggs01.dbf' SIZE 500M REUSE
AUTOEXTEND ON
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 4194304
SEGMENT SPACE MANAGEMENT AUTO;

select * from v\$instance;

create user GGS identified by $GGSPWD
default tablespace GGS;
--temporary tablespace TEMP;

grant connect, resource, DBA to GGS;
grant connect,resource,unlimited tablespace to ggs;
grant execute on utl_file to ggs;
grant select any table to ggs;
grant select any dictionary to ggs;

PROMPT *** Set parameters for GoldenGate ***
--11.2.0.2 or above
exec dbms_goldengate_auth.grant_admin_privilege('GGS');
--grant permission to user can issue  add schematrandata
exec dbms_streams_auth.grant_admin_privilege('GGS');
--or --for both capture and apply
--11.2.0.3
exec dbms_goldengate_auth.grant_admin_privilege('GGS',grant_select_privileges=>true);   

--enable_goldengate_replication
alter system set enable_goldengate_replication=TRUE scope=both;

-- added to improve performance
--alter system set "_log_read_buffers" = 64 scope=both;
alter system set "_log_read_buffer_size" = 128 scope=both;

-- create objects for handling sequences
WHENEVER SQLERROR CONTINUE
SET DEFINE ON
@$vSeqScript
-- add supplemntal log data
WHENEVER SQLERROR CONTINUE
SET DEFINE OFF
spool $vOutputLog append
ALTER TABLE sys.seq$ ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

create user GGTEST identified by gg#te#st01
default tablespace GGS;
--temporary tablespace TEMP;
ALTER USER GGTEST QUOTA UNLIMITED ON GGS;

grant connect, resource to GGTEST;

CREATE TABLE ggtest.table1 (
   tabid	NUMBER(10,0),
   tabname	VARCHAR2(10),
	CONSTRAINT table1_pk01 PRIMARY KEY (tabid) 
	using index (CREATE INDEX ggtest.table1_pk_ix ON ggtest.table1 (tabid))
);

insert into ggtest.table1 values (1,'employee');
insert into ggtest.table1 values (2,'department');
commit;

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

-- set memory to highest value
--select case
--	when sap.SAP > 1572864000 then
--		case when sap.SAP > to_number(pm.value) then 'ALTER SYSTEM SET ' || pm.name || '=' || sap.SAP || ' SCOPE=SPFILE;'
--			else 'ALTER SYSTEM SET ' || pm.name || '=' || pm.value || ' SCOPE=SPFILE;'
--		end
--	when to_number(pm.value) > 1572864000 then 'ALTER SYSTEM SET ' || pm.name || '=' || pm.value || ' SCOPE=SPFILE;'
--	else '-- new memory settings higher than current ones'
--	end "STMT"
--from v\$spparameter pm, (select sum(to_number(value)) "SAP" from v\$spparameter where name in ('sga_max_size','pga_aggregate_target')) sap
--where pm.name in ('memory_max_target','memory_target') and pm.value is not NULL
--order by 1;
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
		when dbf.FILE_NAME like '/move/${DBNAME}%' then '/database/'||substr(dbf.FILE_NAME,7,instr(dbf.FILE_NAME,'/',7)-7)||'/oradata'||substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1))
		else '/database/${DBNAME}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||''
	end ||
--	case
--	when dbf.FILE_NAME like '/move/${DBNAME}%' then replace(dbf.FILE_NAME,'/move/','/database/')
--	else '/database/${DBNAME}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||''
--	end ||
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
	when dbf.FILE_NAME like '/move/${DBNAME}/exports/oradata/%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move/${DBNAME}/exports/oradata/','/database/${DBNAME}01/oradata/')||''' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
	when dbf.FILE_NAME like '/move/${DBNAME}%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||'/database/'||substr(dbf.FILE_NAME,7,instr(dbf.FILE_NAME,'/',7)-7)||'/oradata'||substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1))||''' SIZE '||to_char(dbf.BYTES)||
		case
		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
		end
--	when dbf.FILE_NAME like '/move/${DBNAME}%' then 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move/','/database/')||''' SIZE '||to_char(dbf.BYTES)||
--		case
--		when dbf.BYTES > 33554432000 then ' AUTOEXTEND ON NEXT 256M MAXSIZE '||to_char(dbf.BYTES)
--		else ' AUTOEXTEND ON NEXT 256M MAXSIZE 32000M '
--		end
	else 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE ''/database/${DBNAME}01/oradata/'||SUBSTR(dbf.FILE_NAME,INSTR(dbf.FILE_NAME,'/',-1)+1)||'x'' SIZE '||to_char(dbf.BYTES)||
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
	when '01' then 'ALTER DATABASE TEMPFILE ''/database/'||lower(vdb.name)||'01/oradata'||substr(dtf.FILE_NAME,instr(dtf.FILE_NAME,'/',-1))||''' RESIZE '||dtf.BYTES||';'
	else 
		case
			when dtf.FILE_NAME like '/move/idwptmp/%' then 'ALTER TABLESPACE TEMP ADD TEMPFILE '''||'/database/'||lower(vdb.name)||'01/oradata'||substr(dtf.FILE_NAME,instr(dtf.FILE_NAME,'/',-1))||''' SIZE '||dtf.BYTES||';'
			else 'ALTER TABLESPACE TEMP ADD TEMPFILE '''||replace(dtf.FILE_NAME,'/move/','/database/')||''' SIZE '||dtf.BYTES||';'
			end
	end "STMT"
from DBA_TEMP_FILES dtf, V\$DATABASE vdb
where dtf.TABLESPACE_NAME='TEMP';

-- create additional temp tablespaces
select 'CREATE TEMPORARY TABLESPACE "'||tbs.TABLESPACE_NAME||'" TEMPFILE '''||replace(dbf.FILE_NAME,'/move/','/database/')||
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

select 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD TEMPFILE '''||replace(dbf.FILE_NAME,'/move/','/database/')||''' SIZE '||BYTES||';' "STMT"
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
select 'ALTER TABLESPACE "'||dts.TABLESPACE_NAME||'" TABLESPACE GROUP "'||tsg.GROUP_NAME||'";'
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
select dbms_metadata.get_ddl('SYNONYM',synonym_name,owner)||';' "STMT" from dba_synonyms
where table_owner NOT IN ($vExcludeUsers) or db_link is not null;
spool off;

PROMPT +++++++++++++++++ LOGON TRIGGERS +++++++++++++++++
spool $CREATELOGON
select DBMS_METADATA.GET_DDL('TABLE','LOGON_AUDIT_LOG','SYS')||';' "STMT" from dual;
select DBMS_METADATA.GET_DDL('TABLE','LOGON_AUDIT_LOG_ARCHIVE','SYS')||';' "STMT" from dual;
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
PROMPT *** GoldenGate Prep ***
-- set queue parameter
BEGIN
  FOR i IN
    (select 'ALTER SYSTEM SET ' || name || '=1 COMMENT=''original '||display_value||''' SCOPE=BOTH' as cmd
	 from v\$spparameter where name='aq_tm_processes' and (value='0' or value is NULL))
  LOOP
    execute immediate i.cmd;
  END LOOP;
END;
/

-- Create DP directory
create or replace DIRECTORY CNO_MIGRATE as '$vDPParDir';

column ddl format a2500 word_wrap
begin
   dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'SQLTERMINATOR', true);
   dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'PRETTY', true);
end;
/

EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',true);
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS',false);
spool off

PROMPT *** Add transaction data script ***
SPOOL $ADDTRANDATA
select 'dblogin userid GGS@${ORACLE_SID} password $GGSPWD' from dual;
select distinct 'ADD SCHEMATRANDATA "'||owner||'"' from dba_tables where owner not in ($vExcludeUsers) order by 1;
SPOOL OFF

--SPOOL $FLUSHSEQUENCES
--select distinct 'FLUSH SEQUENCE "'||sequence_owner||'".*'
--from dba_sequences 
--where sequence_owner not in ($vExcludeUsers)
--order by 1;
--SPOOL OFF

PROMPT *** Create data pump parameter file ***
SET ESCAPE OFF
SPOOL $vDPDataPar
DECLARE
  CURSOR c1 IS
	select '\\"'||username||'\\"' "STMT"
	from dba_users where username not in ($vExcludeUsers);
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

PROMPT *** Create Data Pump metadata param file ***
SPOOL $vDPMetaPar
select 'DIRECTORY=CNO_MIGRATE' from dual;
select 'DUMPFILE=${vDPDumpMeta}' from dual;
select 'LOGFILE=${vDPMetaLog}' from dual;
select 'CONTENT=METADATA_ONLY' from dual;
select 'METRICS=Y' from dual;
select 'FULL=Y' from dual;
SPOOL OFF

PROMPT *** Create GG extract parameter file ***
SPOOL $EPRMFILE
select '-- Extract Name' from dual;
select 'Extract $vExtName' from dual;
select ' ' from dual;
select '-- Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "${ORACLE_HOME}")' from dual;
select 'SETENV (NLS_LANG = "AMERICAN_AMERICA.'||value||'")' from nls_database_parameters where parameter='NLS_CHARACTERSET';
select ' ' from dual;
select '-- Database Login Information. ' from dual;
select 'USERID ggs@${ORACLE_SID}, PASSWORD $GGSPWD' from dual;
select ' ' from dual;
select '-- EXCLUDE USER GGS FROM BEING REPLICATING BACK OR CASCADING' from dual;
select 'TRANLOGOPTIONS EXCLUDEUSER GGS' from dual;
select 'TRANLOGOPTIONS INCLUDEREGIONID' from dual;
select ' ' from dual;
select 'DISCARDFILE ./dirrpt/$vExtName.dsc, APPEND, MEGABYTES 500' from dual;
select 'DISCARDROLLOVER AT 01:00 ON sunday' from dual;
select ' ' from dual;
select 'CACHEMGR CACHESIZE 8GB, CACHEDIRECTORY ${GGTMP} 200GB' from dual;
select ' ' from dual;
select 'ExtTrail $EXTTRAIL' from dual;
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
select 'WARNLONGTRANS 1h, CHECKINTERVAL 30m' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select distinct 'SEQUENCE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
-- Heartbeat Table
select 'TABLE gghb.GGS_HEARTBEAT,' from dual;
select 'TOKENS (' from dual;
select '         CAPGROUP = @GETENV ("GGENVIRONMENT", "GROUPNAME"),' from dual;
select '         CAPTIME =  @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '       );' from dual;
SPOOL OFF

PROMPT *** Create GG replicat parameter file ***
SPOOL $RPRMFILE
select 'REPLICAT $vRepName' from dual;
select ' ' from dual;
select '-- Oracle Environment Variables' from dual;
select 'SETENV (ORACLE_HOME = "${NEW_ORACLE_HOME}")' from dual;
select 'SETENV (NLS_LAG = "AMERICAN_AMERICA.$vCharSet")' from dual;
select ' ' from dual;
select '-- Use USERID to specify the type of database authentication for GoldenGate to use.' from dual;
select 'USERID ggs@${ORACLE_SID}, PASSWORD $GGSPWD' from dual;
select ' ' from dual;
select '-- Use DISCARDFILE to generate a discard file to which Extract or Replicat can log-- records that it cannot process. ' from dual;
select 'DISCARDFILE ./dirrpt/$vRepName.dsc, APPEND, MEGABYTES 500' from dual;
select ' ' from dual;
select '-- discard file rollover , weekly or daily' from dual;
select 'DISCARDROLLOVER AT 18:00' from dual;
select ' ' from dual;
select '-- Use REPORTCOUNT to generate a count of records that have been processed since the Extract or Replicat process started' from dual;
select 'reportcount every 5 MINUTES, rate' from dual;
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
--select 'MAPEXCLUDE "'||owner||'".'||MVIEW_NAME from dba_mviews where UPDATABLE='N' and owner not in ($vExcludeUsers) order by 1;
select 'MAPEXCLUDE "'||owner||'".'||MVIEW_NAME from dba_mviews where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select distinct 'MAP "'||owner||'".*, TARGET "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
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

exit;
RUNSQL

# check logs for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
for file in $SETPARAM $vOrigParams $REDOLOGS $CREATETS $TEMPSIZE $TSGROUPS $SYSOBJECTS $CREATEQUOTAS $CREATEROLES $CREATEGRANTS $CREATESYSPRIVS $REVOKESYSPRIVS $vProxyPrivs $DISABLETRIGGERS $ENABLETRIGGERS $CREATESYNS $CREATELOGON $vCreateExtTables $ADDTRANDATA $vDPDataPar $vDPMetaPar $EPRMFILE $RPRMFILE
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
-- create normal users with valid password
--select dbms_metadata.get_ddl('USER', u.username)||';' "STMT"
--from dba_users u,
--(select name, translate(password,'0123456789ABCDEF','----------------') password from user\$) d
--where u.username=d.name and d.password='----------------' and u.AUTHENTICATION_TYPE!='EXTERNAL'
--and u.username NOT IN ($vExcludeUsers);

-- create users with password invalid in 12c
--select 'CREATE USER "'||du.username||'" IDENTIFIED BY VALUES '||
--  '''S:0F9DDB9E51A96D66D8754952C4F1D987FE5E527F5E3BD9C7C5F08983B532;T:5BB9FF165DF9261D3D9B0A99BF37BD5985E8A0A59D42046185BFF0326950CB3A8FBF7E4A39EBDA3BF521F2D28D3C31AB27ABA24A19F43C3F1B5CD3BC0421A1DA0920DC6A88647656CAC1E87CC8937F0D;DE50D6C930ACAF6E'''
--  ||' DEFAULT TABLESPACE '||du.default_tablespace||
--  ' TEMPORARY TABLESPACE '||du.temporary_tablespace||
--  ' PROFILE '||du.profile||';' "STMT"
--from dba_users du,
--(select name, translate(password,'0123456789ABCDEF','----------------') password from user\$) d
--where du.username=d.name and d.password!='----------------' and du.password is null
--and du.AUTHENTICATION_TYPE!='EXTERNAL'
--and du.username NOT IN ($vExcludeUsers);

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
select 'ALTER TABLESPACE "'||tbs.TABLESPACE_NAME||'" ADD DATAFILE '''||replace(FILE_NAME,'/move/','/database/')||''' SIZE '||dbf.BYTES||';' "STMT"
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME
and tbs.TABLESPACE_NAME='UNDO'
order by 1;
SPOOL OFF

PROMPT *** Create GG pump parameter file ***
SPOOL $PPRMFILE
select '-- Use EXTRACT to specify a Pump group to send the information to the target' from dual;
select 'EXTRACT $vPushName' from dual;
select ' ' from dual;
select '-- Database Login Information.' from dual;
select 'USERID ggs@${ORACLE_SID}, PASSWORD $GGSPWD' from dual;
select ' ' from dual;
select '-- Use RMTHOST to identify a remote system and the TCP/IP port number on that system where the Manager process is running.' from dual;
select 'RMTHOST $GGHOST, MGRPORT 7819, TCPBUFSIZE 1000000, TCPFLUSHBYTES 1000000' from dual;
select ' ' from dual;
select '-- Use RMTTRAIL to specify a remote trail that was created with the ADD RMTTRAIL command in GGSCI.' from dual;
select 'RMTTRAIL $vRmtTrail' from dual;
select ' ' from dual;
select '-- Use WILDCARDRESOLVE to alter the rules for processing wildcard table' from dual;
select '-- specifications in a TABLE or MAP statement. WILDCARDRESOLVE must precede the' from dual;
select '-- associated TABLE or MAP statements in the parameter file.' from dual;
select 'WILDCARDRESOLVE DYNAMIC' from dual;
select ' ' from dual;
select 'ReportCount Every 5 Minutes, Rate' from dual;
select ' ' from dual;
select '--DDL' from dual;
select 'DDL INCLUDE ALL' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select distinct 'SEQUENCE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select ' ' from dual;
select '-- Heartbeat Table' from dual;
select 'table gghb.ggs_heartbeat,' from dual;
select '   TOKENS (' from dual;
select '            PMPGROUP = @GETENV ("GGENVIRONMENT","GROUPNAME"),' from dual;
select '            PMPTIME = @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '          );' from dual;
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
-- create users (no changes needed for passwords)
--select dbms_metadata.get_ddl('USER', u.username)||';' "STMT"
--from dba_users u
--where u.AUTHENTICATION_TYPE!='EXTERNAL' and u.username NOT IN ($vExcludeUsers);

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
and du.username NOT IN ($vExcludeUsers);
spool off;

PROMPT +++++++++++++++++ UNDO FILE SIZE +++++++++++++++++
SPOOL $UNDOSIZE
select case
	when SHORT_NAME='undo01.dbf' then
		case
			when BYTES > 209715200 then 'ALTER DATABASE DATAFILE '''||replace(FILE_NAME,'/move/','/database/')||''' RESIZE '||BYTES||';'
			else '-- undo01.dbf is less than 200 MB'
		end
	else 'ALTER TABLESPACE "'||TABLESPACE_NAME||'" ADD DATAFILE '''||replace(FILE_NAME,'/move/','/database/')||''' SIZE '||BYTES||';'
end "STMT"
from
	(select dbf.FILE_NAME, substr(dbf.FILE_NAME,instr(dbf.FILE_NAME,'/',-1)+1) "SHORT_NAME",
	 tbs.TABLESPACE_NAME, dbf.BYTES
	 from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
	 where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME
	 and tbs.TABLESPACE_NAME='UNDO')
order by 1;
SPOOL OFF

PROMPT *** Create GG pump parameter file ***
SPOOL $PPRMFILE
select '-- Use EXTRACT to specify a Pump group to send the information to the target' from dual;
select 'EXTRACT $vPushName' from dual;
select ' ' from dual;
select '-- Database Login Information.' from dual;
select 'USERID ggs@${ORACLE_SID}, PASSWORD $GGSPWD' from dual;
select ' ' from dual;
select '-- Use RMTHOST to identify a remote system and the TCP/IP port number on that system where the Manager process is running.' from dual;
select 'RMTHOST $GGHOST, MGRPORT 7919, TCPBUFSIZE 1000000, TCPFLUSHBYTES 1000000' from dual;
select ' ' from dual;
select '-- Use RMTTRAIL to specify a remote trail that was created with the ADD RMTTRAIL command in GGSCI.' from dual;
select 'RMTTRAIL $vRmtTrail' from dual;
select ' ' from dual;
select '-- Use WILDCARDRESOLVE to alter the rules for processing wildcard table' from dual;
select '-- specifications in a TABLE or MAP statement. WILDCARDRESOLVE must precede the' from dual;
select '-- associated TABLE or MAP statements in the parameter file.' from dual;
select 'WILDCARDRESOLVE DYNAMIC' from dual;
select ' ' from dual;
select 'ReportCount Every 5 Minutes, Rate' from dual;
select ' ' from dual;
select '--DDL' from dual;
select 'DDL INCLUDE ALL' from dual;
select ' ' from dual;
select '--tables' from dual;
select distinct 'TABLE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select distinct 'SEQUENCE "'||owner||'".*;' from dba_tables where owner not in ($vExcludeUsers) order by 1;
select ' ' from dual;
select ' ' from dual;
select '-- Heartbeat Table' from dual;
select 'table gghb.ggs_heartbeat,' from dual;
select '   TOKENS (' from dual;
select '            PMPGROUP = @GETENV ("GGENVIRONMENT","GROUPNAME"),' from dual;
select '            PMPTIME = @DATE ("YYYY-MM-DD HH:MI:SS.FFFFFF","JTS",@GETENV ("JULIANTIMESTAMP"))' from dual;
select '          );' from dual;
SPOOL OFF

PROMPT Create data pump import parameter file ***
SPOOL $vDPImpPar
--select 'DIRECTORY=CNO_MIGRATE' from dual;
--select 'DUMPFILE=${vDPDataDump}' from dual;
--select 'LOGFILE=impdp_${ORACLE_SID}.log' from dual;
--select 'table_exists_action=replace' from dual;
--select 'PARALLEL=8' from dual;
--select 'CLUSTER=Y' from dual;
--select 'METRICS=Y' from dual;

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
for file in $PPRMFILE $vDPImpPar $vCreateUsers $UNDOSIZE
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

############################ GoldenGate ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Create/start GG extract       *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

echo "" | tee -a $vOutputLog
echo "Starting GoldenGate process" | tee -a $vOutputLog

# Build script to create GG extract and pump
echo "delete extract $vExtName" > $CREATEEXTRACT
echo "delete extract $vPushName" >> $CREATEEXTRACT
echo "DBLOGIN USERID GGS@${DBCAPS} PASSWORD $GGSPWD" >> $CREATEEXTRACT
echo "add extract $vExtName, integrated tranlog, begin now" >> $CREATEEXTRACT
echo "add exttrail $EXTTRAIL, extract $vExtName, megabytes 1000" >> $CREATEEXTRACT
echo "add extract $vPushName, exttrailsource ${EXTTRAIL}" >> $CREATEEXTRACT
echo "add rmttrail $vRmtTrail, extract $vPushName, megabytes 1000" >> $CREATEEXTRACT
echo "register extract $vExtName database" >> $CREATEEXTRACT

# copy file for reverse replication
cp $ADDTRANDATA $vOutputDir

# Setup GG extracts
cd $GGATE
./ggsci > $vGGLog << EOF
obey $ADDTRANDATA
sh sleep 10

obey $CREATEEXTRACT
sh sleep 15

exit
EOF

# check for errors
cat $vGGLog >> $vOutputLog
vGGErrorCt=$(cat $vGGLog | grep OGG- | grep ERROR | wc -l)
if [[ $vGGErrorCt -gt 0 ]]
then
	echo "" | tee -a $vOutputLog
	echo "There was an error creating the GoldenGate services." | tee -a $vOutputLog
	cat $vGGLog | grep OGG- | grep ERROR | tee -a $vOutputLog
	exit 1
fi

# Build script to start GG extract and pump
echo "start extract $vExtName" > $STARTEXTRACT
echo "sh sleep 5" >> $STARTEXTRACT
echo "start extract $vPushName" >> $STARTEXTRACT
echo "sh sleep 5" >> $STARTEXTRACT

# start GG extracts
cd $GGATE
./ggsci >> $vOutputLog << EOF
obey $STARTEXTRACT

exit
EOF

# Check the GG extract status
GGRUNNING="TRUE"
gg_run_check_fnc $vExtName

# Check the GG pump status
gg_run_check_fnc $vPushName

# Check that GG pump is moving
if [[ $GGRUNNING = "TRUE" ]]
then
	gg_rba_check_fnc $vPushName
fi

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog
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
CURRENT_SCN=$( sqlplus -S ggs/${GGSPWD} <<EOF
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

# export metadata
expdp \"/ as sysdba\" parfile=$vDPMetaPar
cat ${vDPParDir}/${vDPMetaLog} >> $vOutputLog
error_check_fnc ${vDPParDir}/${vDPMetaLog} $vErrorLog $vCritLog

# get timing before copying scripts
vEndSec=$(date '+%s')

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


############################ Copy Scripts ############################

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Copy scripts to new host      *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# copy scripts for reverse replication to /tmp
cp $ADDTRANDATA /tmp
#cp $EPRMFILE /tmp
cp $RPRMFILE /tmp

# add all files to archive
cd $vOutputDir
tar -cvf $TARFILE *${ORACLE_SID}* *${DBShort}* $RPRMFILE

echo ""
# copy files to new host
if [[ AUTOMODE -eq 1 ]]
then
	echo "Copying archive file to $NEWHOST. You may be prompted for the password." | tee -a $vOutputLog
	scp ${TARFILE} oracle@${NEWHOST}:${vNewDir} | tee -a $vOutputLog
	if [ $? -ne 0 ]
	then
		echo "" | tee -a $vOutputLog
		echo "There was a problem copying $TARFILE to $NEWHOST. Please run this command manually:" | tee -a $vOutputLog
		echo "scp ${TARFILE} oracle@${NEWHOST}:${vNewDir}" | tee -a $vOutputLog
	fi
	# check if new DB host and GG host are different
	if [[ $NEWHOST != $GGHOST ]]
	then
		echo "Copying archive file to $GGHOST. You may be prompted for the password." | tee -a $vOutputLog
		scp ${TARFILE} oracle@${GGHOST}:${vNewDir} | tee -a $vOutputLog
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $vOutputLog
			echo "There was a problem copying $TARFILE to $GGHOST. Please run this command manually:" | tee -a $vOutputLog
			echo "scp ${TARFILE} oracle@${GGHOST}:${vNewDir}" | tee -a $vOutputLog
		fi
	fi
else
	echo "Cannot connect to $NEWHOST and/or $GGHOST. You will have to copy the archive file manually:" | tee -a $vOutputLog
	echo "${TARFILE}" | tee -a $vOutputLog
fi

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
echo "GoldenGate directories:" | tee -a $vOutputLog
echo "   Binaries:            $GGATE" | tee -a $vOutputLog
echo "   Export files:        ${DBTRAIL}" | tee -a $vOutputLog
echo "   Parameter files:     ${GGPRM}" | tee -a $vOutputLog
echo "   Report files:        ${GGATE}/dirrpt" | tee -a $vOutputLog
if [[ $GGRUNNING = "TRUE" ]]
then
	echo "GoldenGate Status:      Running" | tee -a $vOutputLog
else
	echo "GoldenGate Status:      Stopped/Abended" | tee -a $vOutputLog
	echo "  !!! Please check rpt files for errors !!!" | tee -a $vOutputLog
fi
echo "GoldenGate scripts:" | tee -a $vOutputLog
echo "   Add trans data:      $ADDTRANDATA" | tee -a $vOutputLog
echo "   Create extracts:     $CREATEEXTRACT" | tee -a $vOutputLog
echo "   Start extracts:      $STARTEXTRACT" | tee -a $vOutputLog
echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
echo "******************************************************************" | tee -a $vOutputLog
