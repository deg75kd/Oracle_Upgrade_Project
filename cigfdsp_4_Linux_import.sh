#!/usr/bin/bash
#================================================================================================#
#  NAME
#    cigfdsp_4_Linux_import.sh
#
#  SPECS
#    uxp33
#    LXORAODSP04
#    11g
#    US7ASCII
#    Encrypted
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

# array of 11g databases
# List11g=(idevt cigfdsd cigfdst cigfdsm cigfdsp inf91d infgix8d infgix8t infgix8m infgix8p fdlzd fdlzt fdlzm trecscd trecsct trecscm trecscp obieed obieet obieem obieep obiee2d opsm opsp bpad bpat bpam bpap fnp8d fnp8t fnp8m fnp8p portalm c3appsd c3appst c3appsm c3appsp cpsmrtsm cpsmrtsp idmp p8legalp)

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts/12cupgrade"
vEnvScriptDir="/app/oracle/setenv"
vProfile="/home/oracle/.bash_profile"
vTNSScriptDir="/master_tnsnames/scripts"
vTNSMaster="/master_tnsnames/TNSNAMES/tnsnames.ora"
vTNSServer="/master_tnsnames/log/server.dat"
# vColdTemplate="${vScriptDir}/rman_coldfull_template.txt"
vPasswordFnc="${vScriptDir}/VERIFY_FUNCTION_CNO.fnc"
vMissingFiles="FALSE"
vHostName=$(hostname)

vExcludeUsers="'GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS\$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS\$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB\$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS'"
vExcludeRoles="'ADM_PARALLEL_EXECUTE_TASK','APEX_ADMINISTRATOR_ROLE','APEX_GRANTS_FOR_NEW_USERS_ROLE','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','AUTHENTICATEDUSER','CAPTURE_ADMIN','CDB_DBA','CONNECT','CSW_USR_ROLE','CTXAPP','DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','DBA','DBFS_ROLE','DELETE_CATALOG_ROLE','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_GOLDENGATE_ADMIN','DV_GOLDENGATE_REDO_ACCESS','DV_MONITOR','DV_OWNER','DV_PATCH_ADMIN','DV_PUBLIC','DV_REALM_OWNER','DV_REALM_RESOURCE','DV_SECANALYST','DV_STREAMS_ADMIN','DV_XSTREAM_ADMIN','EJBCLIENT','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','GATHER_SYSTEM_STATISTICS','GDS_CATALOG_SELECT','GLOBAL_AQ_USER_ROLE','GSMADMIN_ROLE','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE','JAVADEBUGPRIV','JAVAIDPRIV','JAVASYSPRIV','JAVAUSERPRIV','JAVA_ADMIN','JAVA_DEPLOY','JMXSERVER','LBAC_DBA','LOGSTDBY_ADMINISTRATOR','OEM_ADVISOR','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORDADMIN','PDB_DBA','PROVISIONER','RECOVERY_CATALOG_OWNER','RECOVERY_CATALOG_USER','RESOURCE','SCHEDULER_ADMIN','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_WFS_ADMIN','WFS_USR_ROLE','WM_ADMIN_ROLE','XDBADMIN','XDB_SET_INVOKER','XDB_WEBSERVICES','XDB_WEBSERVICES_OVER_HTTP','XDB_WEBSERVICES_WITH_PUBLIC','XS_CACHE_ADMIN','XS_NAMESPACE_ADMIN','XS_RESOURCE','XS_SESSION_ADMIN','PUBLIC','SECURITY_ADMIN_ROLE','SQLTUNE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','PROD_DBA_ROLE'"

NOWwSECs=$(date '+%Y%m%d%H%M%S')
vStartSec=$(date '+%s')

# AIX comparison tables
vRowTable="ggtest.row_count_aix"
vObjectTable="ggtest.object_count_aix"
vIndexTable="ggtest.index_count_aix"
vConstraintTable="ggtest.constraint_count_aix"
vPrivilegeTable="ggtest.priv_count_aix"
vColPrivTable="ggtest.col_priv_count_aix"
vRolesTable="ggtest.role_count_aix"
vQuotaTable="ggtest.quota_aix"
vProxyUsersTable="ggtest.proxy_users_aix"
vPubPrivTable="ggtest.pub_privs_aix"
vLobTable="ggtest.lob_aix"
vSysGenIndexTable="ggtest.sys_gen_index_aix"

# Linux comparison tables
vLinuxRowTable="ggtest.row_count_linux"
vLinuxObjectTable="ggtest.object_count_linux"
vLinuxIndexTable="ggtest.index_count_linux"
vLinuxConstraintTable="ggtest.constraint_count_linux"
vLinuxPrivilegeTable="ggtest.priv_count_linux"
vLinuxColPrivTable="ggtest.col_priv_count_linux"
vLinuxRolesTable="ggtest.role_count_linux"
vLinuxQuotaTable="ggtest.quota_linux"
vLinuxProxyUsersTable="ggtest.proxy_users_linux"
vLinuxPubPrivTable="ggtest.pub_privs_linux"
vLinuxLobTable="ggtest.lob_linux"
vLinuxSysGenIndexTable="ggtest.sys_gen_index_linux"

# users/profile checks
vLinuxUsersTable="ggtest.users_linux"
vLinuxUsersList="'AUTODDL','AUTODML','ECORA','ORA_QUALYS_DB','SQLTUNE','TNS_USER','UIMMONITOR'"
vLinuxProfilesTable="ggtest.profiles_linux"
vLinuxProfilesList="'APP_PROFILE','CNO_PROFILE','DEFAULT'"

############################ Version-specific Constants ############################
vHome12c="${ORACLE_BASE}/db/12c/1"
vHome11g="${ORACLE_BASE}/db/11g/1"
vInit11g="/app/oracle/scripts/init11g.ora"
vInit12c="/app/oracle/scripts/init12c.ora"
vGS11=gs11g
vGS12=cgs12c
vGSASCII=gsascii
vGSWE8=cbpad
vGS11ascii=gs11ascii
vGCpluggable=gs12c
vGS11gWE8=bpad

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	vOEMHost=lxoems02
	# vBkpLoc=/app/rman
	vBkpLoc=/oragg
	export GGMOUNT=/oragg
else
	vOEMHost=lxoemp01
	vBkpLoc=/nfs/oraexport/templates
	# export GGMOUNT=/oragg
	export GGMOUNT="/nfs/oraexport"
fi
# export RUNDIR=${GGATE}/dirsql

# array of acceptable Oracle errors
vErrIgnore+=(ORA-00604)         # error occurred at recursive SQL level 3
vErrIgnore+=(ORA-00959)         # tablespace 'XXX' does not exist
vErrIgnore+=(ORA-00911)         # invalid character
vErrIgnore+=(ORA-00942)         # table or view does not exist
vErrIgnore+=(ORA-00955)         # name is already used by an existing object
#vErrIgnore+=(ORA-00959)         # tablespace 'XXX' does not exist
vErrIgnore+=(ORA-00987)         # missing or invalid username(s) 
vErrIgnore+=(ORA-00990)         # missing or invalid privilege
vErrIgnore+=(ORA-01435)         # user does not exist
vErrIgnore+=(ORA-01507)         # database not mounted
vErrIgnore+=(ORA-01918)         # user 'XXX' does not exist
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
# list of users that may be expected to be duplicates during user creation
#vErrIgnore+=(ORA-01920)         # user name 'XXX' conflicts with another user or role name
vErrIgnore+=(SQLTUNE)
vErrIgnore+=(COGUGJ)
vErrIgnore+=(COGH4O)
vErrIgnore+=(CDPK2F)
vErrIgnore+=(COG71S)
vErrIgnore+=(CNOZK7)
vErrIgnore+=(COGVNU)
vErrIgnore+=(COGZX6)
vErrIgnore+=(CNOXGO)
vErrIgnore+=(COGLG1)
vErrIgnore+=(COGY0L)
vErrIgnore+=(COGOTA)
vErrIgnore+=(CDPTM2)
vErrIgnore+=(HPUCMDB)
vErrIgnore+=(TNS_USER)

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
			cat $vOutputLog >> $vFullLog
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
	vParamCt=4
	# check that all parameters passed
	if [[ $# -lt $vParamCt ]]
	then
		# exit script if not enough parameters passed
		echo "ERROR: This function requires $vParamCt parameter(s)!" | tee -a $1
		cat $1 >> $4
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
		#cat $3 | tee -a $1
		cat $3
		echo "Check $4 for the full details." | tee -a $1
		cat $1 >> $4
		#exit 1
		continue_fnc
	else
		echo " "
		echo "No errors to report." | tee -a $1
		cat $1 >> $4
	fi
	
	# delete section log
	rm $1
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
	
	# copy output of section to full log
	cat $1 >> $4
	rm $1
}

############################ Prompt Short Function ###########################
# PURPOSE:                                                                   #
# This function prompts the user for a few inputs.                           #
##############################################################################

function prompt_short_fnc {
	# Prompt for new DB name
	echo ""
	echo -e "Enter the new database name: \c"  
	while true
	do
		read vNewDB
		if [[ -n "$vNewDB" ]]
		then
			vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
			echo "The new database name is $vPDBName"
			break
		else
			echo -e "Enter a valid database name: \c"  
		fi
	done
	
	# set DB version
	export ORACLE_HOME=$vHome11g
	vDBVersion=11

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
	# vFileArray+=(${vRedoLogs})
	# vFileArray+=(${vSetParam})
	# vFileArray+=(${vCreateTbs})
	# vFileArray+=(${vUndoSize})
	# vFileArray+=(${vTempSize})
	# vFileArray+=(${vTSGroups})
	# vFileArray+=(${vCreateACL})
	# vFileArray+=(${vSysObjects})
	# vFileArray+=(${vProxyPrivs})
	# vFileArray+=(${vCreateUsers})
	# vFileArray+=(${CREATEQUOTAS})
	# vFileArray+=(${CREATEGRANTS})
	# vFileArray+=(${CREATESYSPRIVS})
	vFileArray+=(${REVOKESYSPRIVS})
	# vFileArray+=(${DISABLETRIGGERS})
	# vFileArray+=(${ENABLETRIGGERS})
	# vFileArray+=(${CREATESYNS})
	# vFileArray+=(${CREATEROLES})
	# vFileArray+=(${CREATELOGON})
	vFileArray+=(${vDPImpPar})

	# echo "" | tee -a $vOutputLog
	# echo "Removing scripts from previous run..." | tee -a $vOutputLog
	# for vCheckArray in ${vFileArray[@]}
	# do
		# echo "Checking for $vCheckArray" | tee -a $vOutputLog
		# remove file if it exists
		# if [[ -e $vCheckArray ]]
		# then
			# echo "Deleting $vCheckArray" | tee -a $vOutputLog
			# rm $vCheckArray
		# fi
	# done
	
	# echo "" | tee -a $vOutputLog
	# echo "Checking for scripts from existing AIX database..." | tee -a $vOutputLog
	
	# check for tar file
	# if [[ ! -e $TARFILE ]]
	# then
		# TARFILE="${vDBScripts}/Linux_setup_${vPDBName}.tar"
		# if [[ ! -e $TARFILE ]]
		# then
			# echo " " | tee -a $vOutputLog
			# echo "ERROR: That tar file of scripts from AIX is missing: $TARFILE" | tee -a $vOutputLog
			# echo "       This file is required to continue." | tee -a $vOutputLog
			# exit 1
		# fi
	# else
		# mv $TARFILE $vDBScripts
	# fi
	# unzip file
	# cd $vDBScripts
	# rm *.sql
	# rm *.out
	# rm *.par
	# rm *.oby
	# rm *.out
	
	# tar -xf Linux_setup_${vPDBName}.tar
	# if [ $? -ne 0 ]
	# then
		# echo " " | tee -a $vOutputLog
		# echo "ERROR: The tar file $TARFILE could not be unzipped." | tee -a $vOutputLog
		# echo "       This file must be unzipped to continue." | tee -a $vOutputLog
		# exit 1
	# else
		# echo "" | tee -a $vOutputLog
		# echo "The tar file $TARFILE was successfully unzipped." | tee -a $vOutputLog
	# fi
	# cd $vScriptDir

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
	# check of 12c-only script
	# if [[ ! -e $vCreateCommonUsers && $vDBVersion -eq 12 ]]
	# then
		# echo " " | tee -a $vOutputLog
		# echo "WARNING: The $vCreateCommonUsers file from the old DB does not exist." | tee -a $vOutputLog
		# continue_fnc
		# vMissingFiles="TRUE"
	# else
		# echo "${vCreateCommonUsers} is here" | tee -a $vOutputLog
	# fi
	
	# add slash to logon trigger script for PL/SQL block
	# echo "" | tee -a $vOutputLog
	# echo "Editing $CREATELOGON to add slashes (/)" | tee -a $vOutputLog
	# sed -i.$NOWwSECs "/END;/s/END;/END;\n\//" $CREATELOGON
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

############################ Import Data Function ############################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing AIX data            *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# set parameter for high undo usage
#	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
#spool $vOutputLog append
#Alter system set "_smu_debug_mode" = 33554432 scope=memory;
#EXIT;
#EOF

	# import data
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpPar}

	# reset parameter for high undo usage
	# $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
# spool $vOutputLog append
# Alter system reset "_smu_debug_mode";
# EXIT;
# EOF

	# check log for errors
	cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ Import FISERV_GTWY Data #########################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_fiserv_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing FISERV_GTWY data    *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create param file for ggtest import
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParFS
	echo "LOGFILE=${vDPDataLogFS}" >> $vDPImpParFS
	echo "DUMPFILE=${DPDataDumpFS}" >> $vDPImpParFS
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParFS
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParFS
	echo "CLUSTER=Y" >> $vDPImpParFS
	echo "METRICS=Y" >> $vDPImpParFS

	# import ggtest schema
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParFS}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogFS} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ Import BLC_EAPP_GTWY Data Function ##############
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_blc_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing BLC_EAPP_GTWY data  *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create param file for ggtest import
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParBLC
	echo "LOGFILE=${vDPDataLogBLC}" >> $vDPImpParBLC
	echo "DUMPFILE=${vDPDataDumpBLC}" >> $vDPImpParBLC
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParBLC
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParBLC
	echo "CLUSTER=Y" >> $vDPImpParBLC
	echo "METRICS=Y" >> $vDPImpParBLC

	# import ggtest schema
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParBLC}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogBLC} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ Import STG Data Function ########################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_stg_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing STG data            *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create param file for ggtest import
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParSTG
	echo "LOGFILE=${vDPDataLogSTG}" >> $vDPImpParSTG
	echo "DUMPFILE=${vDPDataDumpSTG}" >> $vDPImpParSTG
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParSTG
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParSTG
	echo "CLUSTER=Y" >> $vDPImpParSTG
	echo "METRICS=Y" >> $vDPImpParSTG

	# import ggtest schema
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParSTG}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogSTG} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ Import GGTEST Data Function #####################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function import_ggtest_data_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Importing GGTEST data         *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create param file for ggtest import
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParGG
	echo "LOGFILE=${vDPDataLogGG}" >> $vDPImpParGG
	echo "DUMPFILE=${vDPDataDumpGG}" >> $vDPImpParGG
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParGG
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParGG
	echo "CLUSTER=Y" >> $vDPImpParGG
	echo "METRICS=Y" >> $vDPImpParGG

	# import ggtest schema
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParGG}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogGG} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
}

############################ Cleanup Function ################################
# PURPOSE:                                                                   #
# This function imports data from AIX.                                       #
##############################################################################

function cleanup_fnc {
	# disable trigger, revoke privileges and check objects
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
spool $vOutputLog append
alter session set container=${vPDBName};
--@${DISABLETRIGGERS}
WHENEVER SQLERROR CONTINUE
@${REVOKESYSPRIVS}
@$ORACLE_HOME/rdbms/admin/utlrp.sql
spool off
exit;
EOF
	else
		$ORACLE_HOME/bin/sqlplus "/ as sysdba" << EOF
spool $vOutputLog append
--@${DISABLETRIGGERS}
WHENEVER SQLERROR CONTINUE
@${REVOKESYSPRIVS}
@$ORACLE_HOME/rdbms/admin/utlrp.sql
spool off
exit;
EOF
	fi

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
	#continue_fnc
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
	echo "Database Name:        $vPDBName" | tee -a $vOutputLog
	echo "Version:              $ORACLE_FULL_VERSION" | tee -a $vOutputLog
	echo "Data Pump Directory:  $vDPParDir" | tee -a $vOutputLog
	echo "Total Run Time:         $vTotalTime" | tee -a $vOutputLog
	echo "***************************************" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	echo "Run this in the PDB to gather stats:" | tee -a $vOutputLog
	echo "exec DBMS_STATS.GATHER_DATABASE_STATS (estimate_percent =>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>8, cascade=>true, no_invalidate=>false, gather_sys=>TRUE);" | tee -a $vOutputLog
	
	cat $vOutputLog >> $vFullLog
}

############################ Variable Function ###############################
# PURPOSE:                                                                   #
# This function sets variables.                                              #
##############################################################################

function variables_fnc {
	echo ""
	echo "**************************************************"
	echo "* Verify script variables                        *"
	echo "**************************************************"

	# reset array variables
	unset vDirArray
	
	# set output log names
	vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
	vLogDir="${vScriptDir}/logs"
	vFullLog="${vLogDir}/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
	vOutputLog="${vLogDir}/${vBaseName}_${vPDBName}_section.log"
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
	
	# remove log files if they exist
	if [[ -f $vOutputLog ]]
	then
		echo ""
		echo "Removing $vOutputLog"
		rm $vOutputLog
	fi
	if [[ -f $vErrorLog ]]
	then
		echo ""
		echo "Removing $vErrorLog"
		rm $vErrorLog
	fi
	if [[ -f $vCritLog ]]
	then
		echo ""
		echo "Removing $vCritLog"
		rm $vCritLog
	fi
	
	# Set script name for revoking system privs
	vDBScripts="/database/E${vPDBName}/${vPDBName}_admn01/scripts"
	REVOKESYSPRIVS="${vDBScripts}/revoke_sys_privs_${vPDBName}.sql"

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
	# DMPDIR="${GGMOUNT}/datapump"
	vDPParDir="${GGMOUNT}/${vPDBName}"
	vDPImpPar="${vDPParDir}/${vPDBName}_impdp_cutover.par"
	vDPDataLog="${vPDBName}_impdp_cutover.log"
	vDPDataDump="${vPDBName}_cutover_%U.dmp"
	
	vDPImpParFS="${vDBScripts}/${vPDBName}_impdp_cutover_fiserv.par"
	vDPDataLogFS="${vPDBName}_impdp_cutover_fiserv.log"
	DPDataDumpFS="${vPDBName}_cutover_fiserv_%U.dmp"

	vDPImpParBLC="${vDBScripts}/${vPDBName}_impdp_cutover_blc.par"
	vDPDataLogBLC="${vPDBName}_impdp_cutover_blc.log"
	vDPDataDumpBLC="${vPDBName}_cutover_blc_%U.dmp"
	
	vDPImpParSTG="${vDBScripts}/${vPDBName}_impdp_cutover_stg.par"
	vDPDataLogSTG="${vPDBName}_impdp_cutover_stg.log"
	vDPDataDumpSTG="${vPDBName}_cutover_stg_%U.dmp"

	vDPImpParGG="${vDBScripts}/${vPDBName}_impdp_cutover_ggtest.par"
	vDPDataLogGG="${vPDBName}_impdp_cutover_ggtest.log"
	vDPDataDumpGG="${vPDBName}_cutover_ggtest_%U.dmp"
	
	# check data pump directories
#	echo ""
#	echo "Checking Data Pump directory ${vDPParDir}" | tee -a $vOutputLog
#	if [[ ! -d ${vDPParDir} ]]
#	then
#		if [[ ! -d ${DMPDIR} ]]
#		then
#			mkdir ${DMPDIR}
#			if [[ $? -ne 0 ]]
#			then
#				echo "" | tee -a $vOutputLog
#				echo "There was a problem creating ${DMPDIR}" | tee -a $vOutputLog
#				exit 1
#			else
#				chmod 774 ${DMPDIR}
#				echo "Directory ${DMPDIR} has been created." | tee -a $vOutputLog
#			fi
#		fi
#		mkdir ${vDPParDir}
#		if [[ $? -ne 0 ]]
#		then
#			echo "" | tee -a $vOutputLog
#			echo "There was a problem creating ${vDPParDir}" | tee -a $vOutputLog
#			exit 1
#		else
#			chmod 774 ${vDPParDir}
#			echo "Directory ${vDPParDir} has been created." | tee -a $vOutputLog
#		fi
#	fi
}

############################ Confirmation Function ###########################
# PURPOSE:                                                                   #
# This function sets confirms variables.                                     #
##############################################################################

function confirmation_fnc {
	# Display user entries
	echo "" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	echo "Today is `date`"  | tee -a $vOutputLog
	echo "You have entered the following values:"
	echo "Database Name:        $vPDBName" | tee -a $vOutputLog
	echo "Oracle Version:       11g" | tee -a $vOutputLog
	echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
	echo "Datafiles:            /database/E${vPDBName}/${vPDBName}01/oradata" | tee -a $vOutputLog
	echo "Import parallelism:   $vParallelLevel" | tee -a $vOutputLog
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
	export ORACLE_SID=$vPDBName
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
	export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
	export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
	echo $ORACLE_SID
	
	############################ Array variables ############################
	
	# Set directory array
	unset vDirArray
	vDirArray+=($vScriptDir)
	vDirArray+=($GGMOUNT)
	vDirArray+=($vHome11g)
	vDirArray+=($vDBScripts)
	
	vDataDirs=$(df -h /database/E${vPDBName}/${vPDBName}0* | grep ${vPDBName} | awk '{ print $7}')
	for vDirName in ${vDataDirs[@]}
	do
		vDirArray+=($vDirName)
	done
	
	# Set file array
	unset vFileArray
	
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
WHENEVER SQLERROR CONTINUE
SPOOL $vOutputLog APPEND

SET DEFINE OFF
SET TIMING ON
WHENEVER SQLERROR EXIT

-- truncate tables
truncate table $vLinuxRowTable;
truncate table $vLinuxObjectTable;
truncate table $vLinuxIndexTable;
truncate table $vLinuxConstraintTable;
truncate table $vLinuxPrivilegeTable;
truncate table $vLinuxColPrivTable;
truncate table $vLinuxRolesTable;
truncate table $vLinuxQuotaTable;
truncate table $vLinuxProxyUsersTable;
truncate table $vLinuxPubPrivTable;
truncate table $vLinuxLobTable;
truncate table $vLinuxSysGenIndexTable;

-- insert Linux object info
insert into $vLinuxObjectTable
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null and generated='N'
and (owner, object_name, object_type) not in
(select owner, object_name, object_type from DBA_OBJECTS where owner='PUBLIC' and object_type='SYNONYM');
commit;

-- insert Linux index counts
insert into $vLinuxIndexTable
select ix.OWNER, ix.INDEX_NAME, ix.INDEX_TYPE, ix.TABLE_OWNER, ix.TABLE_NAME, ix.STATUS
from DBA_INDEXES ix, dba_objects ob
where ob.object_name=ix.index_name and ob.owner=ix.owner
and ob.object_type='INDEX' and ob.generated='N'
and (ix.TABLE_OWNER||'.'||ix.TABLE_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
and ix.owner not in ($vExcludeUsers);
commit;

-- insert Linux constraint counts
insert into $vLinuxConstraintTable
select owner, table_name, constraint_type, status, count(*) "CNSTR_CT"
from dba_constraints
where owner not in ($vExcludeUsers) and table_name not like 'BIN$%'
and (owner||'.'||table_name) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
group by owner, table_name, constraint_type, status;
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

-- insert Linux column privilege counts
insert into $vLinuxColPrivTable
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

-- insert Linux proxy user check
insert into $vLinuxProxyUsersTable
select PROXY, CLIENT, AUTHENTICATION, FLAGS
from proxy_users 
where client like 'APP%'
and proxy not in ($vExcludeUsers)
;
commit;

-- insert Linux privilege counts
insert into $vLinuxPubPrivTable
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
commit;

-- Populate table for lob comparison
insert into $vLinuxLobTable
select owner, table_name, column_name, tablespace_name
from dba_lobs
where owner not in ($vExcludeUsers)
and (owner||'.'||table_name) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
and owner!='GGTEST';
commit;

-- insert system-generated names
insert into $vLinuxSysGenIndexTable
select ic.table_owner, ic.table_name, ic.column_name, di.index_type, di.uniqueness, di.status, ic.descend 
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
join dba_objects ob
	on ob.object_name=di.index_name and ob.owner=di.owner
where ob.object_type='INDEX' and ob.generated='Y'
and di.TABLE_OWNER not in ($vExcludeUsers);
commit;

-- insert table counts
set serveroutput on
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
select 'There are '||count(*)||' column privileges.' "COLPRIVS" from $vLinuxColPrivTable;
select 'There are '||count(*)||' roles.' "ROLES" from $vLinuxRolesTable;
select 'There are '||count(*)||' quotas.' "QUOTAS" from $vLinuxQuotaTable;
select 'There are '||count(*)||' proxy users.' "PROXY_USERS" from $vLinuxProxyUsersTable;
select 'There are '||count(*)||' public privileges.' "PRIVILEGES" from $vLinuxPubPrivTable;
select 'There are '||count(*)||' indexes with system-generated names.' "SYSGEN" from ${vLinuxSysGenIndexTable};
select 'There are '||count(*)||' LOBs.' "LOBS" from ${vLinuxLobTable};

-- Table count comparison
col "TABLE" format a40
col "AIX" format 999,999,990
col "LINUX" format 999,999,990
col MVIEW format a5
select diff.OWNER||'.'||diff.TABLE_NAME "TABLE", diff."AIX", diff."LINUX", diff."DIFFERENCE", NVL2(mv.mview_name,'YES',NULL) "MVIEW"
from dba_mviews mv right outer join
	(select NVL(lx.OWNER,aix.OWNER) "OWNER", NVL(lx.TABLE_NAME,aix.TABLE_NAME) "TABLE_NAME", aix.RECORD_COUNT "AIX", lx.RECORD_COUNT "LINUX", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFFERENCE"
	 from $vLinuxRowTable lx full outer join $vRowTable aix
		on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
	 where (lx.RECORD_COUNT!=aix.RECORD_COUNT OR lx.RECORD_COUNT IS NULL OR aix.RECORD_COUNT IS NULL)
		and lx.owner not in ('GGS','GGTEST')
		and (lx.owner||'.'||lx.TABLE_NAME) not in
		('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
	) diff
	on mv.owner=diff.owner and mv.mview_name=diff."TABLE_NAME"
order by 1;

-- Table status comparison
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGS','GGTEST')
and (lx.owner||'.'||lx.TABLE_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
order by 1;

-- Index count comparison
col "AIX INDEX" format a50
col "LINUX INDEX" format a50
select aix.OWNER||'.'||aix.INDEX_NAME "AIX-INDEX", lx.OWNER||'.'||lx.INDEX_NAME "LX-INDEX"
from $vLinuxIndexTable lx full outer join $vIndexTable aix
  on aix.OWNER=lx.OWNER and aix.INDEX_NAME=lx.INDEX_NAME
where lx.INDEX_NAME is null and lx.owner not in ('GGS','GGTEST')
and (lx.owner||'.'||lx.TABLE_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
order by aix.OWNER, aix.INDEX_NAME, lx.OWNER, lx.INDEX_NAME;

-- Object status comparison
col "OBJECT_NAME" format a40
select aix.OBJECT_TYPE, aix.OWNER||'.'||aix.OBJECT_NAME "OBJECT_NAME", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxObjectTable lx full outer join $vObjectTable aix
  on aix.OWNER=lx.OWNER and aix.OBJECT_NAME=lx.OBJECT_NAME and aix.OBJECT_TYPE=lx.OBJECT_TYPE
where lx.STATUS!=aix.STATUS and lx.STATUS!='VALID' OR lx.STATUS is null
--and lx.owner not in ('GGTEST')
and (lx.owner||'.'||lx.OBJECT_NAME) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
order by aix.OBJECT_TYPE, aix.OWNER, aix.OBJECT_NAME;

-- Constraint comparison
select NVL(aix.owner,lx.owner) "OWNER", NVL(aix.table_name,lx.table_name) "TABLE_NAME", NVL(aix.constraint_type,lx.constraint_type) "CONSTRAINT_TYPE", NVL(aix.STATUS,lx.STATUS) "STATUS", aix.CNSTR_CT "AIX", lx.CNSTR_CT "LINUX"
from $vLinuxConstraintTable lx full outer join $vConstraintTable aix
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.constraint_type=lx.constraint_type and aix.STATUS=lx.STATUS
where NVL2(aix.CNSTR_CT,aix.CNSTR_CT,0)!=NVL2(lx.CNSTR_CT,lx.CNSTR_CT,0) and lx.owner!='GGTEST'
and (lx.owner||'.'||lx.table_name) not in
('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
order by 1,2,3,4;

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

-- Public privilege comparison
col "MISSING_PRIVILEGE" format a48
col object_type format a30
select NVL(sub.grantee,lx.grantee) "GRANTEE", 
	NVL2(sub.privilege,
		CASE sub.owner
		WHEN 'n/a' THEN sub.privilege
		ELSE sub.privilege||' on '||sub.owner||'.'||sub.table_name
	END
	,'-') "MISSING_PRIVILEGE", 
	sub.object_type
from $vLinuxPubPrivTable lx full outer join (
	select aix.grantee, aix.privilege, aix.owner, aix.table_name, obj.object_type
	from $vPubPrivTable aix left outer join dba_objects obj on aix.owner=obj.owner and aix.table_name=obj.object_name
	where aix.owner='n/a' or obj.object_name is not null) sub
	on sub.grantee=lx.grantee and sub.owner=lx.owner and sub.table_name=lx.table_name and sub.privilege=lx.privilege
where lx.grantee is null
order by 1,2,3;

-- Column privilege comparison
col "COLUMN" format a75
col "AIX_PRIV" format a15
col "LX_PRIV" format a12
select NVL(aix.grantee,lx.grantee) "GRANTEE",
	NVL2(aix.owner,aix.owner||'.'||aix.table_name||'.'||aix.column_name,lx.owner||'.'||lx.table_name||'.'||lx.column_name) "COLUMN",
	aix.privilege "AIX_PRIV", lx.privilege "LX_PRIV"
from $vColPrivTable aix full outer join $vLinuxColPrivTable lx
	on aix.grantee=lx.grantee and aix.owner=lx.owner and aix.table_name=lx.table_name and aix.privilege=lx.privilege and aix.column_name=lx.column_name
where lx.grantee is null or aix.grantee is null
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
and aix.tablespace_name in (select tablespace_name from dba_tablespaces)
order by 1,2;

-- Proxy user comparison
select NVL(aix.proxy,lx.proxy) "PROXY",
	NVL(aix.client,lx.client) "CLIENT",
	aix.flags "AIX_FLAGS", aix.authentication "AIX", 
	lx.flags "LX_FLAGS", lx.authentication "LX"
from $vProxyUsersTable aix full outer join $vLinuxProxyUsersTable lx
	on aix.proxy=lx.proxy and aix.client=lx.client
where lx.proxy is null or aix.proxy is null
	or aix.flags!=lx.flags or aix.authentication!=lx.authentication
order by 1,2;

-- LOB comparison
COL "OWNER" FORMAT A25
col column_name format a30
select NVL(aix.owner,lx.owner) "OWNER",
	NVL(aix.table_name,lx.table_name) "TABLE_NAME",
	NVL(aix.column_name,lx.column_name) "COLUMN_NAME",
	aix.tablespace_name "AIX_TS", lx.tablespace_name "LX_TS"
from $vLobTable aix full outer join $vLinuxLobTable lx
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.column_name=lx.column_name
where lx.column_name is null or aix.column_name is null or aix.tablespace_name!=lx.tablespace_name
order by 1,2,3;

-- system-generated name comparison
COL TABLE_OWNER FORMAT A25
COL INDEX_TYPE FORMAT A15
col "UNIQUE" format a15
select NVL(aix.table_owner,lx.table_owner) "OWNER",
	NVL(aix.table_name,lx.table_name) "TABLE_NAME",
	NVL(aix.column_name,lx.column_name) "COLUMN_NAME",
	NVL(aix.index_type,lx.index_type) "INDEX_TYPE",
	NVL(aix.uniqueness,lx.uniqueness) "UNIQUE",
	NVL(aix.descend,lx.descend) "DESC",
	aix.status "AIX_STATUS", lx.status "LX_STATUS"
from $vSysGenIndexTable aix full outer join $vLinuxSysGenIndexTable lx
	on aix.table_owner=lx.table_owner and aix.table_name=lx.table_name and aix.column_name=lx.column_name and aix.index_type=lx.index_type and aix.uniqueness=lx.uniqueness and aix.descend=lx.descend
where lx.column_name is null or aix.column_name is null
	or aix.status!=lx.status
order by 1,2,3;

SPOOL OFF

exit;
RUNSQL

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
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
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL
)

for linkname in ${vDBLinks[@]}
do
	# find owners of links with that name
	vLinkOwner=$($ORACLE_HOME/bin/sqlplus -S "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL
)

	for ownername in ${vLinkOwner[@]}
	do
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
					echo "" | tee -a $vOutputLog
					echo "Public link $linkname needs to be fixed!" | tee -a $vOutputLog
				else
					echo "" | tee -a $vOutputLog
					echo "Heterogeneous link $linkname needs to be fixed!" | tee -a $vOutputLog
				fi
				echo "$vLinkTest"
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
				echo "" | tee -a $vOutputLog
				echo "$linkname owned by $ownername needs to be fixed!" | tee -a $vOutputLog
				echo "$vLinkTest" | tee -a $vOutputLog
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

	# confirm db links
	echo ""
	echo "Please resolve all above discrepancies before cutover"
	if [[ -e ${vDBScripts}/create_db_links_${vPDBName}.log ]]
	then
		echo "The file ${vDBScripts}/create_db_links_${vPDBName}.log has the DDL for creating all DB links."
	fi
	continue_fnc
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
	echo -e "\t2) Import FISERV_GTWY data"
	echo -e "\t3) Import BLC_EAPP_GTWY data"
    echo -e "\t4) Import STG data"
	echo -e "\t5) Import GGTEST data"
	echo -e "\t6) Cleanup"
	echo -e "\t7) Verify data"
	echo -e "\tq) Quit"
    echo
    echo -e "\tEnter your selection: r\b\c"
    read selection
    if [[ -z "$selection" ]]
        then selection=r
    fi

    case $selection in
        1)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			import_data_fnc
			import_fiserv_data_fnc
			import_blc_data_fnc
			import_stg_data_fnc
			import_ggtest_data_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        2)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			import_fiserv_data_fnc
			import_blc_data_fnc
			import_stg_data_fnc
			import_ggtest_data_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        3)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			import_blc_data_fnc
			import_stg_data_fnc
			import_ggtest_data_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        4)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			import_stg_data_fnc
			import_ggtest_data_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        5)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			import_ggtest_data_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        6)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
			cleanup_fnc
			verify_data_fnc
			summary_fnc
			exit
            ;;
        7)  prompt_short_fnc
			variables_fnc
			confirmation_fnc
			check_vars_fnc
			pre_check_fnc
			aix_files_fnc
			missing_files_fnc
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

cat $vOutputLog >> $vFullLog