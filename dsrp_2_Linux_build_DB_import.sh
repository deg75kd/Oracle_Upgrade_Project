#!/usr/bin/bash
#================================================================================================#
#  NAME
#    dsrp_2_Linux_build_DB_noGG_netapp.sh
#
#  SPECS
#    uxorap01
#    LXORAODSP03
#    12c
#    AL32UTF8
#    Encrypted
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

# array of 11g databases
List11g=(idevt cigfdsd cigfdst cigfdsm cigfdsp inf91d infgix8d infgix8t infgix8m infgix8p fdlzd fdlzt fdlzm trecscd trecsct trecscm trecscp obieed obieet obieem obieep obiee2d opsm opsp bpad bpat bpam bpap fnp8d fnp8t fnp8m fnp8p portalm c3appsd c3appst c3appsm c3appsp cpsmrtsm cpsmrtsp idmp p8legalp)

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
vSysGenIndexTable="ggtest.sys_gen_index_aix"
vLobTable="ggtest.lob_aix"

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
vLinuxSysGenIndexTable="ggtest.sys_gen_index_linux"
vLinuxLobTable="ggtest.lob_linux"

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
	vBkpLoc=/oragg
	export GGMOUNT=/oragg
else
	vOEMHost=lxoemp01
	# vBkpLoc=/oragg
	vBkpLoc=/nfs/oraexport/templates
	export GGMOUNT=/nfs/oraexport
fi

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
vErrIgnore+=(ECORA)
vErrIgnore+=(IDMUNX)

# array of acceptable errors for data pump only
vErrPumpIgnore+=(ORA-00604)     # error occurred at recursive SQL level 3
vErrPumpIgnore+=(ORA-01110)     # data file XX: '/database/XXX/oradata/XXX.dbf'
vErrPumpIgnore+=(ORA-01116)     # error in opening database file 12
vErrPumpIgnore+=(ORA-04052)     # error occurred when looking up remote object XXX@XXX
vErrPumpIgnore+=(ORA-12154)     # TNS:could not resolve the connect identifier specified
vErrPumpIgnore+=(ORA-27041)     # unable to open file
vErrPumpIgnore+=(ORA-39166)     # Object XXX was not found or could not be exported or imported.

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
	# echo -e "Do you wish to continue? (Y) or (N) \c"
	# while true
	# do
		# read vConfirm
		# if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
		# then
			# echo "Continuing..."  | tee -a $vOutputLog
			# break
		# elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
		# then
			# echo " "
			# echo "Exiting at user's request..."  | tee -a $vOutputLog
			# cat $vOutputLog >> $vFullLog
			# exit 2
		# else
			# echo -e "Please enter (Y) or (N).\c"  
		# fi
	# done
	echo ""
	echo "Please check the above for errors."
	echo "Continuing in 2 minutes."
	sleep 120
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

############################ RMAN 12c Duplicate Function #####################
# PURPOSE:                                                                   #
# This function runs the RMAN duplicate command for a 12c database.          #
##############################################################################

#  DUPLICATE DATABASE TO $vCDBName
#  SKIP PLUGGABLE DATABASE $vGCpluggable
# CONNECT CATALOG '$vRMANUser/$vRmanPwd@$vRMANSid'

function duplicate_12c_fnc {
	echo "" | tee -a $vOutputLog
	echo "Duplicating a 12c AL32UTF8 database" | tee -a $vOutputLog
	
	# connect to RMAN
	$ORACLE_HOME/bin/rman >> ${vOutputLog} << RUNRMAN
CONNECT AUXILIARY /
RUN
{
  ALLOCATE AUXILIARY CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL c3 DEVICE TYPE DISK;
  SET NEWNAME FOR DATAFILE 1  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/system01.dbf'; 
  SET NEWNAME FOR DATAFILE 3  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/sysaux01.dbf';
  SET NEWNAME FOR DATAFILE 6  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/users01.dbf';
  SET NEWNAME FOR DATAFILE 5  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/undo.dbf';
  SET NEWNAME FOR DATAFILE 8  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/tools01.dbf';
  SET NEWNAME FOR DATAFILE 13 TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/LOGON_AUDIT_DATA_01.dbf';
  SET NEWNAME FOR TEMPFILE 1  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/temp01.dbf'; 
  SET NEWNAME FOR DATAFILE 2  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed/system01.dbf';
  SET NEWNAME FOR DATAFILE 4  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed/sysaux01.dbf';
  SET NEWNAME FOR DATAFILE 7  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed/users01.dbf';
  SET NEWNAME FOR DATAFILE 12 TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed/tools01.dbf';
  SET NEWNAME FOR TEMPFILE 2  TO '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed/temp01.dbf'; 
  DUPLICATE DATABASE $vGCSID TO $vCDBName
  BACKUP LOCATION '${vBkpLoc}/${vGCSID}'
    LOGFILE
      GROUP 1 ('/database/E${vCDBFull}/${vCDBFull}_redo01/oralog/redo101.log', 
               '/database/E${vCDBFull}/${vCDBFull}_redo02/oralog/redo102.log') SIZE $vRedoSize REUSE, 
      GROUP 2 ('/database/E${vCDBFull}/${vCDBFull}_redo01/oralog/redo201.log', 
               '/database/E${vCDBFull}/${vCDBFull}_redo02/oralog/redo202.log') SIZE $vRedoSize REUSE,
      GROUP 3 ('/database/E${vCDBFull}/${vCDBFull}_redo01/oralog/redo301.log', 
               '/database/E${vCDBFull}/${vCDBFull}_redo02/oralog/redo302.log') SIZE $vRedoSize REUSE
  SPFILE
    set audit_file_dest='/database/E${vCDBFull}/${vCDBFull}_admn01/admin/audit/'
    set control_files='/database/E${vCDBFull}/${vCDBFull}_redo02/oractl/control02.ctl','/database/E${vCDBFull}/${vCDBFull}_redo01/oractl/control01.ctl'
    set diagnostic_dest='/database/E${vCDBFull}/${vCDBFull}_admn01/admin/'
    set log_archive_dest_1='LOCATION=/database/E${vCDBFull}/${vCDBFull}_arch01/arch'
    set utl_file_dir='/database/E${vCDBFull}/${vCDBFull}_admn01/admin/utldump/'
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
	if [[ $vDBVersion -eq 12 && $vCharSet = AL32UTF8 ]]
	then
		vGCSID=$vGS12
		duplicate_12c_fnc
	else
		echo "" | tee -a $vOutputLog
		echo "The version ($vDBVersion) and character set ($vCharSet) are wrong for this script. " | tee -a $vOutputLog
		exit 1
	fi
	
	# change SYSTEM password and set AWR retention policy
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
ALTER USER SYSTEM IDENTIFIED BY $vSystemPwd;
exit	
RUNSQL
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Prompt Short Function ###########################
# PURPOSE:                                                                   #
# This function prompts the user for a few inputs.                           #
##############################################################################

function prompt_short_fnc {
	# Prompt for new DB name
	echo ""
	# echo -e "Enter the new database name: \c"  
	# while true
	# do
		# read vNewDB
		# if [[ -n "$vNewDB" ]]
		# then
			vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
			# vDBCaps=`echo $vNewDB | tr 'a-z' 'A-Z'`
			echo "The new database name is $vPDBName"
			# break
		# else
			# echo -e "Enter a valid database name: \c"  
		# fi
	# done
	
	# Prompt for DB version
	# echo ""
	# echo -e "Select the Oracle version for this database: (a) 12c (b) 11g \c"
	# while true
	# do
		# read vReadVersion
		# if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
		# then
			## set Oracle home
			# export ORACLE_HOME=$vHome12c
			# vDBVersion=12
			# echo "You have selected Oracle version 12c"
			# echo "The Oracle Home has been set to $vHome12c"
			# break
		# elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
		# then
			## set Oracle home
			# export ORACLE_HOME=$vHome11g
			# vDBVersion=11
			# echo "You have selected Oracle version 11g"
			# echo "The Oracle Home has been set to $vHome11g"
			# break
		# else
			# echo -e "Select a valid database version: \c"  
		# fi
	# done
	
	# set DB version
	export ORACLE_HOME=$vHome12c
	vDBVersion=12
	# for dblist in ${List11g[@]}
	# do
		# if [[ $dblist = $vPDBName ]]
		# then
			# export ORACLE_HOME=$vHome11g
			# vDBVersion=11
			# break
		# fi
	# done
	
	# Prompt for character set
	# echo ""
	# echo "Please choose the character set for this DB:"
	# echo "   (a) AL32UTF8"
	# echo "   (b) US7ASCII"
	# echo "   (c) WE8ISO8859P1"
	# echo -e "Choose AL32UTF8 unless you have confirmed there are data loss issues. \c"
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
	
	# Prompt for the SYS password
	# while true
	# do
		# echo ""
		# echo -e "Enter the SYS password:"
		# stty -echo
		# read vSysPwd
		# echo -e "Verify the SYS password:"
		# read vSysPwdVerf
		# if [[ $vSysPwd != $vSysPwdVerf ]]
		# then
			# echo -e "The passwords do not match\n"
		# elif [[ -n "$vSysPwd" ]]
		# then
			# break
		# else
			# echo -e "You must enter a password\n"
		# fi
	# done
	# stty echo

	# Prompt for the SYSTEM password
	# while true
	# do
		# echo ""
		# echo -e "Enter the SYSTEM password:"
		# stty -echo
		# read vSystemPwd
		# if [[ -n "$vSystemPwd" ]]
		# then
			# break
		# else
			# echo -e "You must enter a password\n"
		# fi
	# done
	# stty echo

	# Prompt for parallelism
	# re='^[1-8]+$'
	# echo ""
	# echo "How much parallelism do you want for the import?"  
	# echo "   (a) 2"
	# echo "   (b) 4"
	# echo "   (c) 10"
	# echo "   (d) 16"
	# echo "   (e) 20"
	# while true
	# do
		# read vParallelOption
		# if [[ "$vParallelOption" == "A" || "$vParallelOption" == "a" ]]
		# then
			# vParallelLevel=2
			# break
		# elif [[ "$vParallelOption" == "B" || "$vParallelOption" == "b" ]]
		# then
			# vParallelLevel=4
			# break
		# elif [[ "$vParallelOption" == "C" || "$vParallelOption" == "c" ]]
		# then
			# vParallelLevel=10
			# break
		# elif [[ "$vParallelOption" == "D" || "$vParallelOption" == "d" ]]
		# then
			# vParallelLevel=16
			# break
		# elif [[ "$vParallelOption" == "E" || "$vParallelOption" == "e" ]]
		# then
			# vParallelLevel=20
			# break
		# else
			# echo "Choose a valid option. \c"  
		# fi
	# done
	# echo "You have entered parallelism $vParallelLevel"
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
	
	# Check connection to RMAN recovery catalog
	# echo "" | tee -a $vOutputLog
	# echo "Checking connection to RMAN database..." | tee -a $vOutputLog
	# $ORACLE_HOME/bin/sqlplus -s "$vRMANUser/$vRmanPwd@$vRMANSid" >> ${vRMANCheck} << RUNSQL
# set head off
# set pages 0
# set feedback off
# select '1' from dual;
# RUNSQL
	
	# while IFS= read -r line
	# do
		# if [[ $line == *ORA-* || $line == *SP2-* ]]
		# then
			# echo "ERROR: Cannot connect to the RMAN database $vRMANSid"
			# echo $line
			# exit 1
		# fi
	# done < $vRMANCheck
	# if [ -f $vRMANCheck ]
	# then
		# rm $vRMANCheck
	# fi
	
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
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin/adump | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin/adump)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin/audit | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin/audit)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin/bct | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin/bct)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin/pfile | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin/pfile)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/admin/utldump | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/admin/utldump)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/scripts | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/scripts)
	mkdir /database/E${vCDBFull}/${vCDBFull}_admn01/scripts/cron | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01/scripts/cron)
	mkdir /database/E${vCDBFull}/${vCDBFull}_redo01/oralog | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo01/oralog)
	mkdir /database/E${vCDBFull}/${vCDBFull}_redo01/oractl | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo01/oractl)
	mkdir /database/E${vCDBFull}/${vCDBFull}_redo02/oralog | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo02/oralog)
	mkdir /database/E${vCDBFull}/${vCDBFull}_redo02/oractl | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo02/oractl)
	mkdir /database/E${vCDBFull}/${vCDBFull}_arch01/arch | tee -a $vOutputLog
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_arch01/arch)

	# Create oradata directory on every data mount point
	echo "" | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		# create data directory for CDB
		echo "Creating data directories for ${vCDBName}..." | tee -a $vOutputLog
		mkdir /database/E${vCDBFull}/${vCDBFull}01/oradata
		if [ $? -eq 0 ]
		then
			echo "Directory /database/E${vCDBFull}/${vCDBFull}01/oradata created successfully" | tee -a $vOutputLog
		fi
		vDirArray+=(/database/E${vCDBFull}/${vCDBFull}01/oradata)
		mkdir /database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed
		if [ $? -eq 0 ]
		then
			echo "Directory /database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed created successfully" | tee -a $vOutputLog
		fi
		vDirArray+=(/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed)
		
		# create data directories for PDB
		echo "" | tee -a $vOutputLog
		echo "Creating data directories for ${vPDBName}..." | tee -a $vOutputLog
		vDataDirs=$(ls /database/E${vPDBName} | grep ${vPDBName}0 | grep -v ${vCDBFull}01)
		for vDirName in ${vDataDirs[@]}
		do
			df -h /database/E${vPDBName}/${vDirName}
			if [ $? -eq 0 ]
			then
				echo "Creating directory /database/E${vPDBName}/${vDirName}/oradata" | tee -a $vOutputLog
				mkdir /database/E${vPDBName}/${vDirName}/oradata
				vDirArray+=(/database/E${vPDBName}/${vDirName}/oradata)
			else
				echo "ERROR: /database/E${vPDBName}/${vDirName} is not a mount point!" | tee -a $vOutputLog
				exit 1
			fi
		done
	else
		# create data directories for 11g DB
		echo "" | tee -a $vOutputLog
		echo "Creating data directories for ${vPDBName}..." | tee -a $vOutputLog
		vDataDirs=$(ls /database/E${vPDBName} | grep ${vPDBName}0)
		for vDirName in ${vDataDirs[@]}
		do
			df -h /database/E${vPDBName}/${vDirName}	#mountpoint -q ${vDirName}
			if [ $? -eq 0 ]
			then
				echo "Creating directory /database/E${vPDBName}/${vDirName}/oradata" | tee -a $vOutputLog
				mkdir /database/E${vPDBName}/${vDirName}/oradata
				vDirArray+=(/database/E${vPDBName}/${vDirName}/oradata)
			else
				echo "ERROR: /database/E${vPDBName}/${vDirName} is not a mount point!" | tee -a $vOutputLog
				exit 1
			fi
		done
	fi

	# Create backup directories
	# echo "" | tee -a $vOutputLog
	# echo "Creating RMAN backup directories..." | tee -a $vOutputLog
	# mkdir ${vRMANDir} | tee -a $vOutputLog
	# vDirArray+=(${vRMANDir})
	# mkdir ${vRMANDir}/dumpexp | tee -a $vOutputLog
	# vDirArray+=(${vRMANDir}/dumpexp)
	# mkdir ${vRMANDir}/log | tee -a $vOutputLog
	# vDirArray+=(${vRMANDir}/log)
	# mkdir ${vRMANDir}/rman | tee -a $vOutputLog
	# vDirArray+=(${vRMANDir}/rman)
	
	# Create GG and data pump directories


	# if [[ ! -d $DBDAT ]]
	# then
		# mkdir $DBDAT | tee -a $vOutputLog
	# fi
	# vDirArray+=($DBDAT)
	
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
	vFileArray+=(${CREATESYNS})
	vFileArray+=(${CREATEROLES})
	vFileArray+=(${CREATELOGON})
	vFileArray+=(${CURRENTSCN})
	vFileArray+=(${vDPImpPar})

#	echo "" | tee -a $vOutputLog
#	echo "Removing scripts from previous run..." | tee -a $vOutputLog
#	for vCheckArray in ${vFileArray[@]}
#	do
#		# remove file if it exists
#		if [[ -e $vCheckArray ]]
#		then
#			echo "Deleting $vCheckArray" | tee -a $vOutputLog
#			rm $vCheckArray
#		fi
#	done
#	# 12c-only script
#	if [[ -e $vCreateCommonUsers ]]
#	then
#		echo "Deleting $vCreateCommonUsers" | tee -a $vOutputLog
#		rm $vCreateCommonUsers
#	fi
	
	echo "" | tee -a $vOutputLog
	echo "Checking for scripts from existing AIX database..." | tee -a $vOutputLog
	
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
	# check of 12c-only script
	if [[ ! -e $vCreateCommonUsers && $vDBVersion -eq 12 ]]
	then
		echo " " | tee -a $vOutputLog
		echo "WARNING: The $vCreateCommonUsers file from the old DB does not exist." | tee -a $vOutputLog
		continue_fnc
		vMissingFiles="TRUE"
	else
		echo "${vCreateCommonUsers} is here" | tee -a $vOutputLog
	fi
	
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
	
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
}

############################ Pluggable Function ##############################
# PURPOSE:                                                                   #
# This function creates the pluggable database.                              #
##############################################################################

function plug_db_fnc {
	export ORACLE_SID=$vCDBName
	echo $ORACLE_SID
	
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "*******************************" | tee -a $vOutputLog
		echo "* Creating pluggable database *"  | tee -a $vOutputLog
		echo "*******************************" | tee -a $vOutputLog
	
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET LINES 150
SET PAGES 200
WHENEVER SQLERROR EXIT
SPOOL $vOutputLog APPEND

/*--- start CDB ---*/
startup force;

/*--- connect to CDB ---*/
alter session set container=cdb\$root;
-- set initialization parameters
WHENEVER SQLERROR CONTINUE
@$vSetParam
ALTER SYSTEM SET filesystemio_options='SETALL' SCOPE=SPFILE;
alter system set "_optimizer_gather_stats_on_load"=FALSE scope=spfile;
shutdown immediate
startup

WHENEVER SQLERROR EXIT
-- create system objects
@$vSysObjects
-- add undo space
@$vUndoSize

WHENEVER SQLERROR CONTINUE
ALTER TABLESPACE "UNDO" RETENTION NOGUARANTEE;
WHENEVER SQLERROR EXIT

col file_id format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id "ID", file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from dba_data_files where tablespace_name like 'UNDO%' order by file_name;

/*--- create PDB ---*/
CREATE PLUGGABLE DATABASE $vPDBName
ADMIN USER PDBADMIN IDENTIFIED BY oracle ROLES=(CONNECT)  
  file_name_convert=(
    '/database/E${vCDBFull}/${vCDBFull}01/oradata/pdbseed',
    '/database/E${vPDBName}/${vPDBName}01/oradata'
  );
alter pluggable database $vPDBName open;
alter system register;
alter pluggable database $vPDBName save state;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;

-- update UIM user (wrong role in some templates)
ALTER USER UIMMONITOR DEFAULT ROLE all CONTAINER=ALL;

-- disable auto optimizer stats collection
exec DBMS_AUTO_TASK_ADMIN.DISABLE('AUTO OPTIMIZER STATS COLLECTION', NULL, NULL);

col client_name format a40
select client_name, status from DBA_AUTOTASK_CLIENT order by client_name;

-- move into PDB
alter session set container=${vPDBName};

-- create password verify function
@${vPasswordFnc}

-- set DEFAULT profile limits
ALTER PROFILE DEFAULT LIMIT COMPOSITE_LIMIT UNLIMITED;
ALTER PROFILE DEFAULT LIMIT CONNECT_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT CPU_PER_CALL UNLIMITED;
ALTER PROFILE DEFAULT LIMIT CPU_PER_SESSION UNLIMITED;
ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED;
ALTER PROFILE DEFAULT LIMIT IDLE_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT LOGICAL_READS_PER_CALL UNLIMITED;
ALTER PROFILE DEFAULT LIMIT LOGICAL_READS_PER_SESSION UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LOCK_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_VERIFY_FUNCTION VERIFY_FUNCTION_CNO;
ALTER PROFILE DEFAULT LIMIT PRIVATE_SGA UNLIMITED;
ALTER PROFILE DEFAULT LIMIT SESSIONS_PER_USER UNLIMITED;

-- create tuning table in PDB
CREATE TABLE "SQLTUNE"."SQL_TUNE_STAGING"
   (    "RECORDED_DATE" DATE,
        "TIER" VARCHAR2(4),
        "SERVER" VARCHAR2(64),
        "DB_NAME" VARCHAR2(9),
        "USERNAME" VARCHAR2(30),
        "SQL_ID" VARCHAR2(13),
        "PLAN_HASH_VALUE" NUMBER,
        "SQL_PROFILE" VARCHAR2(64),
        "SQL_COMMAND" VARCHAR2(64),
        "OPTIMIZER_COST" NUMBER,
        "CPU_SEC" NUMBER,
        "READS" NUMBER,
        "WRITES" NUMBER,
        "ELAPSED_SEC" NUMBER,
        "CURSOR_KB" NUMBER,
        "BUFFER_GETS" NUMBER,
        "EXECUTIONS" NUMBER,
        "RECOMMENDATION" VARCHAR2(64),
        "MESSAGE" VARCHAR2(4000),
        "NEW_PLAN_HASH" VARCHAR2(30),
        "BENEFIT" NUMBER,
        "SQL_TEXT" VARCHAR2(4000),
        "TUNING_TASK" VARCHAR2(30),
        "TUNE_WINDOW_START" DATE,
        "TUNE_WINDOW_END" DATE
) TABLESPACE USERS;
  
CREATE TABLE "SQLTUNE"."SQL_TUNE_TASK_STAGING"
   (    "DB_NAME" VARCHAR2(9),
        "TUNE_PERIOD" VARCHAR2(9),
        "START_TUNE" DATE,
        "RECOMMEND_CT" NUMBER,
        "SQL_COUNT" NUMBER,
        "MIN_BENEFIT_PCT" NUMBER,
        "JOB_HOST" VARCHAR2(20)
) TABLESPACE USERS;

exit
RUNSQL
	fi
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
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
	
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
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

-- create tablespaces
@$vCreateTbs
-- add temp tablespace files
@$vTempSize

-- add tablespace groups
@$vTSGroups

-- create logon trigger tablespace
CREATE TABLESPACE LOGON_AUDIT_DATA 
DATAFILE '/database/E${vPDBName}/${vPDBName}01/oradata/LOGON_AUDIT_DATA_01.dbf' 
SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 32000M 
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1048576 
SEGMENT SPACE MANAGEMENT AUTO;

/*--- shutdown DB ---*/
--alter session set container=cdb\$root;
--shutdown immediate;
exit
EOF

	else
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
ALTER SYSTEM SET filesystemio_options='SETALL' SCOPE=SPFILE;
alter system set "_optimizer_gather_stats_on_load"=FALSE scope=spfile;
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

	fi

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
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
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
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
		# echo -e "Type (Y) and Enter when you're ready to continue? \c"
		echo "Continuing in 2 minutes."
		sleep 120
		
		# while true
		# do
			# read vConfirm
			# if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
			# then
				# echo "Continuing..."  | tee -a $vOutputLog
				# break
			# else
				# echo -e "Still waiting...\c"  
			# fi
		# done
	fi
}

############################ DB Setup Function ###############################
# PURPOSE:                                                                   #
# This function sets up the DB.                                              #
##############################################################################

function db_prep_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Create objects for GG setup   *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Set location for data file
	DATAFILE_LOC="/database/E${vPDBName}/${vPDBName}01/oradata"
	
	# Create required objects in PDB
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
SET ECHO OFF
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

-- CDB tasks
WHENEVER SQLERROR EXIT

--create user ggs identified by $vGGSPwd
--default tablespace TOOLS
--temporary tablespace TEMP
--container=all;

--ALTER USER ggs QUOTA UNLIMITED ON TOOLS container=all;
--grant connect, resource, DBA to GGS container=all;
--grant connect,resource,unlimited tablespace to ggs container=all;
--grant execute on utl_file to ggs container=all;
--grant select any table to ggs container=all;
--grant select any dictionary to ggs container=all;

--on 12c Multitenant
--grant DBA to ggs container=all;
--grant Create Session to ggs container=all;
--grant SYSDBA to ggs container=all;
--grant Exempt Access Policy to ggs container=all;
--grant Restricted Session to ggs container=all;
--grant execute on dbms_metadata to ggs container=all;

SPOOL OFF
exit;
EOF

else
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
SET ECHO OFF
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

WHENEVER SQLERROR CONTINUE
--drop user ggs cascade;
drop tablespace GGS including contents and datafiles;
WHENEVER SQLERROR EXIT

--cr_tablespaces.sql
--ASM, edit ASM dg group name accordingly
CREATE TABLESPACE GGS DATAFILE '$DATAFILE_LOC/ggs01.dbf' SIZE 500M
AUTOEXTEND ON
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 4194304
SEGMENT SPACE MANAGEMENT AUTO;
select * from v\$instance;

--create user ggs identified by $vGGSPwd
--default tablespace GGS
--temporary tablespace TEMP;
--ALTER USER ggs QUOTA UNLIMITED ON GGS;

--grant connect, resource, DBA to GGS;
--grant connect,resource,unlimited tablespace to ggs;
--grant execute on utl_file to ggs;
--grant select any table to ggs;
--grant select any dictionary to ggs;

--on 12c Multitenant
--grant DBA to ggs;
--grant Create Session to ggs;
--grant SYSDBA to ggs;
--grant Exempt Access Policy to ggs;
--grant Restricted Session to ggs;
--grant execute on dbms_metadata to ggs;

SPOOL OFF
exit;
EOF

fi

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	echo "COMPLETE" | tee -a $vOutputLog
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

	# create DIRECTORY
	echo "" | tee -a $vOutputLog
	echo "Creating database directories..." | tee -a $vOutputLog
	$ORACLE_HOME/bin/sqlplus "system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))" << EOF
SET ECHO OFF
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

spool $vOutputLog append
create or replace DIRECTORY CNO_MIGRATE as '$vDPParDir';
spool off
exit;
EOF

	# Recreate OS authenticated users for 12c DBs
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "" | tee -a $vOutputLog
		echo "Creating OS autheticated users..." | tee -a $vOutputLog
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
spool $vOutputLog append
@${vCreateCommonUsers}
spool off
exit;
EOF
	fi
	
	# Recreate objects from AIX
	echo "" | tee -a $vOutputLog
	echo "Creating users, roles, synonyms and logon triggers..." | tee -a $vOutputLog
	$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
spool $vOutputLog append
@${vCreateUsers}
@${CREATEQUOTAS}
@${CREATEROLES}
@${CREATEGRANTS}
@${CREATESYSPRIVS}
@${CREATESYNS}
@${CREATELOGON}
@${vProxyPrivs}
@${vCreateACL}
spool off
exit;
EOF

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
	# import metadata and db links
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpMeta}
	
	# check log for errors
	cat ${vDPParDir}/${vDPMetaLog} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
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
	
	# Create param files for CURE_CORE imports
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParCCcomp
	echo "DUMPFILE=${vDPDataDumpCC}" >> $vDPImpParCCcomp
	echo "LOGFILE=${vDPDataLogCCcomp}" >> $vDPImpParCCcomp
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParCCcomp
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParCCcomp
	echo "CLUSTER=Y" >> $vDPImpParCCcomp
	echo "METRICS=Y" >> $vDPImpParCCcomp
	echo "TRANSFORM=TABLE_COMPRESSION_CLAUSE:\"ROW STORE COMPRESS ADVANCED\"" >> $vDPImpParCCcomp
	#echo "TABLES=JIRA.QRTZ_TRIGGER_LISTENERS,JIRA.QRTZ_TRIGGERS,JIRA.REMEMBERMETOKEN,JIRA.CWD_APPLICATION_ADDRESS,JIRA.RESOLUTION,JIRA.SCHEMEISSUESECURITIES,JIRA.SCHEMEISSUESECURITYLEVELS,JIRA.SCHEMEPERMISSIONS,JIRA.SEARCHREQUEST,JIRA.SEQUENCE_VALUE_ITEM,JIRA.SERVICECONFIG,JIRA.SHAREPERMISSIONS,JIRA.ISSUESTATUS,JIRA.TRACKBACK_PING,JIRA.TRUSTEDAPP,JIRA.UPGRADEHISTORY,JIRA.UPGRADEVERSIONHISTORY,JIRA.CWD_USER,JIRA.USERASSOCIATION,JIRA.CWD_USER_ATTRIBUTES,JIRA.USERHISTORYITEM,JIRA.PROJECTVERSION,JIRA.VERSIONCONTROL,JIRA.VOTEHISTORY,JIRA.JIRAWORKFLOWS,JIRA.WORKFLOWSCHEME,JIRA.WORKFLOWSCHEMEENTITY,JIRA.WORKLOG,JIRA.AO_60DB71_COLUMN,JIRA.AO_60DB71_COLUMNSTATUS,JIRA.AO_60DB71_QUICKFILTER,JIRA.AO_60DB71_RANK_ISSUE_LINK,JIRA.AO_60DB71_RAPIDVIEW,JIRA.AO_60DB71_STATSFIELD,JIRA.AO_60DB71_SWIMLANE,JIRA.AO_60DB71_SUBQUERY,JIRA.AO_60DB71_ISSUERANKING,JIRA.AO_60DB71_SPRINT,JIRA.AO_60DB71_ISSUERANKINGLOG,JIRA.REMOTELINK,JIRA.AO_563AEE_MEDIA_LINK_ENTITY,JIRA.AO_563AEE_ACTOR_ENTITY,JIRA.AO_563AEE_TARGET_ENTITY,JIRA.AO_563AEE_OBJECT_ENTITY,JIRA.AO_563AEE_ACTIVITY_ENTITY,JIRA.JIRAACTION,JIRA.CWD_APPLICATION,JIRA.AVATAR,JIRA.CHANGEGROUP,JIRA.CHANGEITEM,JIRA.COLUMNLAYOUT,JIRA.COLUMNLAYOUTITEM,JIRA.COMPONENT,JIRA.CONFIGURATIONCONTEXT,JIRA.CUSTOMFIELD,JIRA.CUSTOMFIELDOPTION,JIRA.CUSTOMFIELDVALUE,JIRA.CWD_DIRECTORY,JIRA.CWD_DIRECTORY_ATTRIBUTE,JIRA.CWD_DIRECTORY_OPERATION,JIRA.JIRADRAFTWORKFLOWS,JIRA.JIRAEVENTTYPE,JIRA.EXTERNAL_ENTITIES,JIRA.EXTERNALGADGET,JIRA.FAVOURITEASSOCIATIONS,JIRA.FIELDCONFIGSCHEME,JIRA.FIELDCONFIGSCHEMEISSUETYPE,JIRA.FIELDCONFIGURATION,JIRA.FIELDLAYOUT,JIRA.FIELDLAYOUTITEM,JIRA.FIELDLAYOUTSCHEME,JIRA.FIELDLAYOUTSCHEMEASSOCIATION,JIRA.FIELDLAYOUTSCHEMEENTITY,JIRA.FIELDSCREEN,JIRA.FIELDSCREENLAYOUTITEM,JIRA.FIELDSCREENSCHEME,JIRA.FIELDSCREENSCHEMEITEM,JIRA.FIELDSCREENTAB,JIRA.FILEATTACHMENT,JIRA.FILTERSUBSCRIPTION,JIRA.GADGETUSERPREFERENCE,JIRA.GENERICCONFIGURATION,JIRA.CWD_GROUP,JIRA.CWD_GROUP_ATTRIBUTES,JIRA.JIRAISSUE,JIRA.ISSUELINK,JIRA.ISSUELINKTYPE,JIRA.ISSUESECURITYSCHEME,JIRA.ISSUETYPE,JIRA.ISSUETYPESCREENSCHEME,JIRA.ISSUETYPESCREENSCHEMEENTITY,JIRA.LABEL,JIRA.LISTENERCONFIG,JIRA.MAILSERVER,JIRA.CWD_MEMBERSHIP,JIRA.NODEASSOCIATION,JIRA.NOTIFICATION,JIRA.NOTIFICATIONINSTANCE,JIRA.NOTIFICATIONSCHEME,JIRA.OAUTHCONSUMER,JIRA.OAUTHCONSUMERTOKEN,JIRA.OAUTHSPCONSUMER,JIRA.OAUTHSPTOKEN,JIRA.OS_CURRENTSTEP,JIRA.OS_CURRENTSTEP_PREV,JIRA.GROUPBASE,JIRA.OS_HISTORYSTEP,JIRA.OS_HISTORYSTEP_PREV,JIRA.MEMBERSHIPBASE,JIRA.PROPERTYDATA,JIRA.PROPERTYDATE,JIRA.PROPERTYDECIMAL,JIRA.PROPERTYENTRY,JIRA.PROPERTYNUMBER,JIRA.PROPERTYSTRING,JIRA.PROPERTYTEXT,JIRA.USERBASE,JIRA.OS_WFENTRY,JIRA.OPTIONCONFIGURATION,JIRA.JIRAPERMS,JIRA.PERMISSIONSCHEME,JIRA.PLUGINVERSION,JIRA.PORTALPAGE,JIRA.PORTLETCONFIGURATION,JIRA.PRIORITY,JIRA.PROJECT,JIRA.PROJECTCATEGORY,JIRA.PROJECTROLE,JIRA.PROJECTROLEACTOR,JIRA.QRTZ_CALENDARS,JIRA.QRTZ_CRON_TRIGGERS,JIRA.QRTZ_FIRED_TRIGGERS,JIRA.QRTZ_JOB_DETAILS,JIRA.QRTZ_JOB_LISTENERS,JIRA.QRTZ_SIMPLE_TRIGGERS,JIRA.AO_60DB71_ESTIMATESTATISTIC,JIRA.AO_60DB71_TRACKINGSTATISTIC,JIRA.AO_60DB71_CARDCOLOR,JIRA.AO_60DB71_RANKABLEOBJECT,JIRA.AO_60DB71_SPRINTMARKER,JIRA.APP_USER,JIRA.DRAFTWORKFLOWSCHEME,JIRA.DRAFTWORKFLOWSCHEMEENTITY,JIRA.CLUSTERMESSAGE,JIRA.CLUSTERNODE,JIRA.ENTITY_PROPERTY,JIRA.MOVED_ISSUE_KEY,JIRA.NODEINDEXCOUNTER,JIRA.PLUGINSTATE,JIRA.PROJECT_KEY,JIRA.REPLICATEDINDEXOPERATION,JIRA.AO_21D670_WHITELIST_RULES,JIRA.AO_E8B6CC_PROJECT_MAPPING,JIRA.AO_E8B6CC_ISSUE_MAPPING,JIRA.AO_E8B6CC_PROJECT_MAPPING_V2,JIRA.AO_E8B6CC_ISSUE_MAPPING_V2,JIRA.AO_E8B6CC_CHANGESET_MAPPING,JIRA.AO_E8B6CC_ORGANIZATION_MAPPING,JIRA.AO_E8B6CC_REPOSITORY_MAPPING,JIRA.AO_E8B6CC_REPO_TO_CHANGESET,JIRA.AO_E8B6CC_ISSUE_TO_CHANGESET,JIRA.AO_E8B6CC_BRANCH_HEAD_MAPPING,JIRA.AO_38321B_CUSTOM_CONTENT_LINK,JIRA.AO_60DB71_AUDITENTRY,JIRA.AO_60DB71_BOARDADMINS,JIRA.AO_B9A0F0_APPLIED_TEMPLATE,JIRA.AO_60DB71_DETAILVIEWFIELD,JIRA.MANAGEDCONFIGURATIONITEM,JIRA.AO_4AEACD_WEBHOOK_DAO,JIRA.AO_60DB71_VERSION,JIRA.AO_60DB71_WORKINGDAYS,JIRA.AO_60DB71_NONWORKINGDAY" >> $vDPImpParCCcomp
	#### echo "TABLES=CURE_CORE.AGT_OBJ_ATTR_VAL,CURE_CORE.APP_OBJ_ATTR_VAL,CURE_CORE.CLM_OBJ_ATTR,CURE_CORE.CLM_OBJ_ATTR_VAL,CURE_CORE.CLNT_OBJ_ATTR_VAL,CURE_CORE.COVRG_OBJ_ATTR_VAL,CURE_CORE.EVNT_OBJ,CURE_CORE.EVNT_OBJ_ATTR,CURE_CORE.EVNT_OBJ_ATTR_VAL,CURE_CORE.EVNT_OBJ_XREF,CURE_CORE.MV_DATA_POINT_TM_SERIS,CURE_CORE.MV_RLTSHP_LIST,CURE_CORE.MV_SUBJ_AREA_ATTR_LIST,CURE_CORE.POC_OBJ_ATTR,CURE_CORE.POC_OBJ_ATTR_VAL,CURE_CORE.POLCY_OBJ_ATTR_VAL,CURE_CORE.POL_PTY_POC,CURE_CORE.POL_PTY_POC_ATTR,CURE_CORE.POL_PTY_POC_KVP,CURE_CORE.PTY_OBJ_ATTR_VAL,CURE_CORE.RLTSHP_APP_CVG_ATTR,CURE_CORE.RLTSHP_APP_CVG_ATTR_VAL" >> $vDPImpParCCcomp
	echo "TABLES=CURE_CORE.AGT_OBJ_ATTR_VAL,CURE_CORE.APP_OBJ_ATTR_VAL,CURE_CORE.CLM_OBJ_ATTR,CURE_CORE.CLM_OBJ_ATTR_VAL,CURE_CORE.CLNT_OBJ_ATTR_VAL,CURE_CORE.COVRG_OBJ_ATTR_VAL,CURE_CORE.EVNT_OBJ,CURE_CORE.EVNT_OBJ_ATTR,CURE_CORE.EVNT_OBJ_ATTR_VAL,CURE_CORE.EVNT_OBJ_XREF,CURE_CORE.MV_DATA_POINT_TM_SERIS,CURE_CORE.MV_SUBJ_AREA_ATTR_LIST,CURE_CORE.POC_OBJ_ATTR,CURE_CORE.POC_OBJ_ATTR_VAL,CURE_CORE.POLCY_OBJ_ATTR_VAL,CURE_CORE.PTY_OBJ_ATTR_VAL" >> $vDPImpParCCcomp
	echo "LOGTIME=ALL" >> $vDPImpParCCcomp
	
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParCCnc
	echo "DUMPFILE=${vDPDataDumpCC}" >> $vDPImpParCCnc
	echo "LOGFILE=${vDPDataLogCCnc}" >> $vDPImpParCCnc
	echo "TABLE_EXISTS_ACTION=SKIP" >> $vDPImpParCCnc
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParCCnc
	echo "CLUSTER=Y" >> $vDPImpParCCnc
	echo "METRICS=Y" >> $vDPImpParCCnc
	echo "TRANSFORM=TABLE_COMPRESSION_CLAUSE:"NOCOMPRESS"" >> $vDPImpParCCnc
	echo "LOGTIME=ALL" >> $vDPImpParCCnc

	# Create param files for CURE_QUEUE imports
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParCQcomp
	echo "DUMPFILE=${vDPDataDumpCQ}" >> $vDPImpParCQcomp
	echo "LOGFILE=${vDPDataLogCQcomp}" >> $vDPImpParCQcomp
	echo "TABLE_EXISTS_ACTION=REPLACE" >> $vDPImpParCQcomp
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParCQcomp
	echo "CLUSTER=Y" >> $vDPImpParCQcomp
	echo "METRICS=Y" >> $vDPImpParCQcomp
	echo "TRANSFORM=TABLE_COMPRESSION_CLAUSE:\"ROW STORE COMPRESS ADVANCED\"" >> $vDPImpParCQcomp
	#echo "TABLES=GGTEST.COL_PRIV_COUNT_AIX,GGTEST.COL_PRIV_COUNT_LINUX,GGTEST.CONSTRAINT_COUNT_AIX,GGTEST.CONSTRAINT_COUNT_LINUX,GGTEST.INDEX_COUNT_AIX,GGTEST.INDEX_COUNT_LINUX,GGTEST.LOB_AIX,GGTEST.LOB_LINUX" >> $vDPImpParCQcomp
	#### echo "TABLES=CURE_QUEUE.CCF_CIL_APP_AGT,CURE_QUEUE.CCF_CIL_APP_CVG,CURE_QUEUE.CCF_CIL_APP_POC,CURE_QUEUE.CCF_CIL_APP_POL,CURE_QUEUE.CCF_CIL_APP_PTY,CURE_QUEUE.CCF_CIL_APP_PTY_APP_CVG,CURE_QUEUE.CCF_CLIENT_MDM_POC,CURE_QUEUE.CCF_EPS_EID,CURE_QUEUE.CCF_EPS_EID_PTY,CURE_QUEUE.CCF_EPS_POC,CURE_QUEUE.CCF_QSR_L_POC,CURE_QUEUE.CCF_QSR_L_POL,CURE_QUEUE.CCF_QSR_L_POL_CVG,CURE_QUEUE.CCF_QSR_L_POL_PTY,CURE_QUEUE.CCF_QSR_L_POL_PTY_POC,CURE_QUEUE.CCF_QSR_L_PTY,CURE_QUEUE.CCF_QSR_L_PTY_POC,CURE_QUEUE.CCF_QSR_POL,CURE_QUEUE.CCF_QSR_POL_CVG,CURE_QUEUE.CCF_QSR_POL_PTY,CURE_QUEUE.CCF_QSR_POL_PTY_POC,CURE_QUEUE.CURE_QUEUE,CURE_QUEUE.PEL_ATS_EVT,CURE_QUEUE.PEL_ATS_POC,CURE_QUEUE.PEL_ATS_PTY,CURE_QUEUE.PEL_AWD_EVNT,CURE_QUEUE.PEL_BICPS_BLC_CLM,CURE_QUEUE.PEL_BICPS_BLC_EVT,CURE_QUEUE.PEL_BICPS_BLC_POL,CURE_QUEUE.PEL_BICPS_BLC_PTY,CURE_QUEUE.PEL_BICPS_WN_CLM,CURE_QUEUE.PEL_BICPS_WN_EVT,CURE_QUEUE.PEL_BICPS_WN_POL,CURE_QUEUE.PEL_BICPS_WN_PTY,CURE_QUEUE.PEL_BLCP_POL,CURE_QUEUE.PEL_BLC_ISSUE_APPLICATION,CURE_QUEUE.PEL_BLC_ISSUE_PARTY,CURE_QUEUE.PEL_BLC_ISSUE_POC,CURE_QUEUE.PEL_C3_APP,CURE_QUEUE.PEL_C3_POC,CURE_QUEUE.PEL_C3_PTY,CURE_QUEUE.PEL_CIB_EVT,CURE_QUEUE.PEL_CIL_POC,CURE_QUEUE.PEL_CIL_POL,CURE_QUEUE.PEL_CIL_PTY,CURE_QUEUE.PEL_CIT_POC,CURE_QUEUE.PEL_CIT_POL,CURE_QUEUE.PEL_CIT_PTY,CURE_QUEUE.PEL_CLIENT_MDM_CLIENT,CURE_QUEUE.PEL_CLIENT_MDM_POC,CURE_QUEUE.PEL_CTS2_CLM,CURE_QUEUE.PEL_CTS2_EVT,CURE_QUEUE.PEL_CTS2_POL,CURE_QUEUE.PEL_CTS2_PTY,CURE_QUEUE.PEL_DSS_C_AGT,CURE_QUEUE.PEL_DSS_C_POC,CURE_QUEUE.PEL_DSS_C_PTY,CURE_QUEUE.PEL_DSS_F_AGT,CURE_QUEUE.PEL_DSS_F_POC,CURE_QUEUE.PEL_DSS_F_PTY,CURE_QUEUE.PEL_DSS_S_AGT,CURE_QUEUE.PEL_DSS_S_POC,CURE_QUEUE.PEL_DSS_S_PTY,CURE_QUEUE.PEL_EAPP_PARTY,CURE_QUEUE.PEL_EAPP_POC,CURE_QUEUE.PEL_ERL_CVG,CURE_QUEUE.PEL_EZAPP_PARTY,CURE_QUEUE.PEL_EZAPP_POC,CURE_QUEUE.PEL_FDLZ_POLCY,CURE_QUEUE.PEL_LIFEPRO_CIK_EVNT,CURE_QUEUE.PEL_LIFEPRO_CIK_PARTY,CURE_QUEUE.PEL_LIFEPRO_CIK_POC,CURE_QUEUE.PEL_LIFEPRO_CIK_POLICY,CURE_QUEUE.PEL_LPK_APP,CURE_QUEUE.PEL_LPK_CLM,CURE_QUEUE.PEL_LTG_CLM,CURE_QUEUE.PEL_LTG_EVT,CURE_QUEUE.PEL_LTG_POC,CURE_QUEUE.PEL_LTG_POL,CURE_QUEUE.PEL_LTG_PTY,CURE_QUEUE.PEL_PAL_AGT,CURE_QUEUE.PEL_PAL_POC,CURE_QUEUE.PEL_PAL_PTY,CURE_QUEUE.PEL_PPLUS_AGT,CURE_QUEUE.PEL_PPLUS_POC,CURE_QUEUE.PEL_PPLUS_PTY,CURE_QUEUE.PEL_QSEARCH_PARTY,CURE_QUEUE.PEL_QSEARCH_POC,CURE_QUEUE.PEL_RPS_POLCY,CURE_QUEUE.PEL_SELERIX_APPLICATION,CURE_QUEUE.PEL_SHARP_WN_PARTY,CURE_QUEUE.PEL_SHARP_WN_POC,CURE_QUEUE.PEL_V1T_AGT,CURE_QUEUE.PEL_V1T_APP,CURE_QUEUE.PEL_V1T_CVG,CURE_QUEUE.PEL_V1T_POC,CURE_QUEUE.PEL_V1T_POL,CURE_QUEUE.PEL_V1T_PTY,CURE_QUEUE.PEL_WN_COVRG_MSTR_COVRG,CURE_QUEUE.PEL_WN_ISSUE_APPLICATION,CURE_QUEUE.PEL_WN_ISSUE_PARTY,CURE_QUEUE.PEL_WN_ISSUE_POC,CURE_QUEUE.QSRCH_SLCTN" >> $vDPImpParCQcomp
	echo "TABLES=CURE_QUEUE.CCF_CLIENT_MDM_POC,CURE_QUEUE.CURE_QUEUE,CURE_QUEUE.PEL_ATS_EVT,CURE_QUEUE.PEL_ATS_POC,CURE_QUEUE.PEL_ATS_PTY,CURE_QUEUE.PEL_AWD_EVNT,CURE_QUEUE.PEL_BLCP_POL,CURE_QUEUE.PEL_BLC_ISSUE_APPLICATION,CURE_QUEUE.PEL_BLC_ISSUE_PARTY,CURE_QUEUE.PEL_BLC_ISSUE_POC,CURE_QUEUE.PEL_C3_APP,CURE_QUEUE.PEL_C3_POC,CURE_QUEUE.PEL_C3_PTY,CURE_QUEUE.PEL_CIB_EVT,CURE_QUEUE.PEL_CIL_POC,CURE_QUEUE.PEL_CIL_POL,CURE_QUEUE.PEL_CIL_PTY,CURE_QUEUE.PEL_CIT_POC,CURE_QUEUE.PEL_CIT_POL,CURE_QUEUE.PEL_CIT_PTY,CURE_QUEUE.PEL_CLIENT_MDM_CLIENT,CURE_QUEUE.PEL_CLIENT_MDM_POC,CURE_QUEUE.PEL_CTS2_CLM,CURE_QUEUE.PEL_CTS2_EVT,CURE_QUEUE.PEL_CTS2_PTY,CURE_QUEUE.PEL_DSS_C_AGT,CURE_QUEUE.PEL_DSS_C_POC,CURE_QUEUE.PEL_DSS_C_PTY,CURE_QUEUE.PEL_DSS_F_AGT,CURE_QUEUE.PEL_DSS_F_POC,CURE_QUEUE.PEL_DSS_F_PTY,CURE_QUEUE.PEL_DSS_S_AGT,CURE_QUEUE.PEL_DSS_S_POC,CURE_QUEUE.PEL_DSS_S_PTY,CURE_QUEUE.PEL_EAPP_PARTY,CURE_QUEUE.PEL_EAPP_POC,CURE_QUEUE.PEL_ERL_CVG,CURE_QUEUE.PEL_EZAPP_PARTY,CURE_QUEUE.PEL_EZAPP_POC,CURE_QUEUE.PEL_FDLZ_POLCY,CURE_QUEUE.PEL_LIFEPRO_CIK_EVNT,CURE_QUEUE.PEL_LIFEPRO_CIK_PARTY,CURE_QUEUE.PEL_LIFEPRO_CIK_POC,CURE_QUEUE.PEL_LIFEPRO_CIK_POLICY,CURE_QUEUE.PEL_LPK_APP,CURE_QUEUE.PEL_LPK_CLM,CURE_QUEUE.PEL_PAL_AGT,CURE_QUEUE.PEL_PAL_POC,CURE_QUEUE.PEL_PAL_PTY,CURE_QUEUE.PEL_PPLUS_AGT,CURE_QUEUE.PEL_PPLUS_POC,CURE_QUEUE.PEL_PPLUS_PTY,CURE_QUEUE.PEL_QSEARCH_PARTY,CURE_QUEUE.PEL_QSEARCH_POC,CURE_QUEUE.PEL_RPS_POLCY,CURE_QUEUE.PEL_SELERIX_APPLICATION,CURE_QUEUE.PEL_SHARP_WN_PARTY,CURE_QUEUE.PEL_SHARP_WN_POC,CURE_QUEUE.PEL_V1T_AGT,CURE_QUEUE.PEL_V1T_APP,CURE_QUEUE.PEL_V1T_CVG,CURE_QUEUE.PEL_V1T_POC,CURE_QUEUE.PEL_V1T_POL,CURE_QUEUE.PEL_V1T_PTY,CURE_QUEUE.PEL_WN_COVRG_MSTR_COVRG,CURE_QUEUE.PEL_WN_ISSUE_APPLICATION,CURE_QUEUE.PEL_WN_ISSUE_PARTY,CURE_QUEUE.PEL_WN_ISSUE_POC" >> $vDPImpParCQcomp
	echo "LOGTIME=ALL" >> $vDPImpParCQcomp
	
	echo "DIRECTORY=CNO_MIGRATE" > $vDPImpParCQnc
	echo "DUMPFILE=${vDPDataDumpCQ}" >> $vDPImpParCQnc
	echo "LOGFILE=${vDPDataLogCQnc}" >> $vDPImpParCQnc
	echo "TABLE_EXISTS_ACTION=SKIP" >> $vDPImpParCQnc
	echo "PARALLEL=${vParallelLevel}" >> $vDPImpParCQnc
	echo "CLUSTER=Y" >> $vDPImpParCQnc
	echo "METRICS=Y" >> $vDPImpParCQnc
	echo "TRANSFORM=TABLE_COMPRESSION_CLAUSE:"NOCOMPRESS"" >> $vDPImpParCQnc
	echo "LOGTIME=ALL" >> $vDPImpParCQnc
	
	# set parameter for high undo usage
#	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
#spool $vOutputLog append
#Alter system set "_smu_debug_mode" = 33554432 scope=memory;
#EXIT;
#EOF

	# import data
	#vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	#$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpPar}
	
	# check log for errors
	#cat ${vDPParDir}/${vDPDataLog} >> $vOutputLog
	#dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
	# import CURE_CORE data - compressed
	#vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	#$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParCCcomp}
	
	# check log for errors
	#cat ${vDPParDir}/${vDPDataLogCCcomp} >> $vOutputLog
	#dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
	# import CURE_CORE data - uncompressed
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParCCnc}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogCCnc} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
	# import CURE_QUEUE data - compressed
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParCQcomp}
	
	# check log for errors
	cat ${vDPParDir}/${vDPDataLogCQcomp} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
	
	# import CURE_QUEUE data - compressed
	vConnect="system/${vSystemPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName})))"
	$ORACLE_HOME/bin/impdp \"$vConnect\" parfile=${vDPImpParCQnc}

	# check log for errors
	cat ${vDPParDir}/${vDPDataLogCQnc} >> $vOutputLog
	dp_error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog

	# reset parameter for high undo usage
	# $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
# spool $vOutputLog append
# Alter system reset "_smu_debug_mode";
# EXIT;
# EOF

	# revoke privileges and check objects
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${vHostName}.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${vPDBName}))) as sysdba" << EOF
spool $vOutputLog append
alter session set container=${vPDBName};
WHENEVER SQLERROR CONTINUE
@${REVOKESYSPRIVS}
@$ORACLE_HOME/rdbms/admin/utlrp.sql
spool off
exit;
EOF
	else
		$ORACLE_HOME/bin/sqlplus "/ as sysdba" << EOF
spool $vOutputLog append
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
	
	# copy to full log
	cat $vOutputLog >> $vFullLog
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
	# echo -e "Do you want to delete the data pump dump files? (Y) or (N) \c"
	# while true
	# do
		# read vConfirm
		# if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
		# then
			# echo "Deleteing dump files from $vDPParDir"  | tee -a $vOutputLog
			# rm ${vDPParDir}/*.dmp
			# break
		# elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
		# then
			# echo " "
			# echo "Dump files will NOT be deleted"  | tee -a $vOutputLog
			# break
		# else
			# echo -e "Please enter (Y) or (N).\c"  
		# fi
	# done
	
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
	echo "" | tee -a $vOutputLog
	echo "Run this in the PDB to gather stats:" | tee -a $vOutputLog
	echo "exec DBMS_STATS.GATHER_DATABASE_STATS (estimate_percent =>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>4, cascade=>true, no_invalidate=>false, gather_sys=>TRUE);" | tee -a $vOutputLog
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

	# set CDB variable based on DB version
	if [[ $vDBVersion -eq 12 ]]
	then
		# set CDB name
		vCDBName="${vCDBPrefix}${vPDBName}"
		vCDBFull=$vCDBName
		# check length of CDB name (max 8 char)
		vCDBLength=$(echo -n $vCDBName | wc -c)
		if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
		then
			# first5_last1
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

	# check length of CDB name
	vNameLength=$(echo -n $vCDBName | wc -c)
	if [[ $vNameLength -gt $MAXNAMELENGTH ]]
	then
			echo "ERROR: The CDB name, $vCDBName, is too long! The max length is $MAXNAMELENGTH."
			exit 1
	fi

	# set environment variables
	vPfileLoc="/database/E${vCDBFull}/${vCDBFull}_admn01/admin/pfile"
	vEnvScriptPDB="${vEnvScriptDir}/set${vPDBName}.sh"
	vEnvScriptCDB="${vEnvScriptDir}/set${vCDBName}.sh"
	vDirArray+=($vPfileLoc)

	# Files from AIX host
	vDBScripts="/database/E${vCDBFull}/${vCDBFull}_admn01/scripts"
	TARFILE="/tmp/Linux_setup_${vPDBName}.tar"
	vRedoLogs="${vDBScripts}/redologs_${vPDBName}.out"
	vSetParam="${vDBScripts}/setparam_${vPDBName}.sql"
	vCreateTbs="${vDBScripts}/createts_${vPDBName}.sql"
	vUndoSize="${vDBScripts}/undosize_${vPDBName}.sql"
	vTempSize="${vDBScripts}/tempsize_${vPDBName}.sql"
	vTSGroups="${vDBScripts}/tsgroups_${vPDBName}.sql"
	vCreateACL="${vDBScripts}/create_acls_${vPDBName}.sql"
	vSysObjects="${vDBScripts}/sysobjects_${vPDBName}.sql"
	vProxyPrivs="${vDBScripts}/grant_proxy_privs_${vPDBName}.sql"
	vCreateUsers="${vDBScripts}/3_create_users_${vPDBName}.sql"
	vCreateCommonUsers="${vDBScripts}/create_common_users_${vPDBName}.sql"
	CREATEQUOTAS="${vDBScripts}/4_create_quotas_${vPDBName}.sql"
	CREATEGRANTS="${vDBScripts}/6_create_grants_${vPDBName}.sql"
	CREATESYSPRIVS="${vDBScripts}/7_create_sys_privs_tousers_${vPDBName}.sql"
	REVOKESYSPRIVS="${vDBScripts}/revoke_sys_privs_${vPDBName}.sql"
	CREATESYNS="${vDBScripts}/10_create_synonyms_${vPDBName}.sql"
	CREATEROLES="${vDBScripts}/5_create_roles_metadata_${vPDBName}.sql"
	CREATELOGON="${vDBScripts}/12_create_logon_triggers_${vPDBName}.sql"
	CURRENTSCN="${vDBScripts}/current_scn_AIX_${vPDBName}.out"
	vDefaultDates="${vDBScripts}/default_dates_${vPDBName}.log"
	vRefreshGroups="${vDBScripts}/create_refresh_groups_${vPDBName}.sql"
	vDirArray+=($vDBScripts)

	# set RMAN variables
	vRMANSid="rman12${vTier}"
	vRMANCheck="${vLogDir}/rmancheck_${vPDBName}.log"
	# construct name of RMAN mount point
	vTeam=`hostname | awk '{ print substr( $0, length($0) - 5, length($0) ) }' | tr 'A-Z' 'a-z' | cut -c 1-3`
	# vRMANDir="/nfs/ora${vTier}${vTeam}bkp001/DR/${vCDBFull}"
	# RMANLOGDIR=${vRMANDir}/log
	# Backupdir=${vRMANDir}/rman
	#vDirArray+=($vRMANDir)
	#vDirArray+=($RMANLOGDIR)
	#vDirArray+=($Backupdir)

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
	#DMPDIR="${GGMOUNT}/datapump"
	vDPParDir="${GGMOUNT}/${vPDBName}"
	vDPDataDump="${vPDBName}_%U.dmp"
	vDPDataLog="impdp_${vPDBName}.log"
	vDPImpPar="${vDBScripts}/impdp_${vPDBName}.par"
	
	vDPDataDumpCC="${vPDBName}_cure_core_%U.dmp"
	vDPDataLogCCcomp="impdp_${vPDBName}_cure_core_compress.log"
	vDPImpParCCcomp="${vDBScripts}/impdp_${vPDBName}_cure_core_compress.par"
	vDPDataLogCCnc="impdp_${vPDBName}_cure_core_nocompress.log"
	vDPImpParCCnc="${vDBScripts}/impdp_${vPDBName}_cure_core_nocompress.par"
	
	vDPDataDumpCQ="${vPDBName}_cure_queue_%U.dmp"
	vDPDataLogCQcomp="impdp_${vPDBName}_cure_queue_compress.log"
	vDPImpParCQcomp="${vDBScripts}/impdp_${vPDBName}_cure_queue_compress.par"
	vDPDataLogCQnc="impdp_${vPDBName}_cure_queue_nocompress.log"
	vDPImpParCQnc="${vDBScripts}/impdp_${vPDBName}_cure_queue_nocompress.par"
	
	vDPMetaDump="${vPDBName}_metadata_%U.dmp"
	vDPMetaLog="impdp_metadata_db_link_${vPDBName}.log"
	vDPImpMeta="${vDBScripts}/impdp_metadata_db_link_${vPDBName}.par"

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
	if [ -f $vOutputLog ]
	then
		rm $vOutputLog | tee -a $vOutputLog
	fi
	sleep 10
	echo "" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	echo "Today is `date`"  | tee -a $vOutputLog
	echo "You have entered the following values:"
	echo "Database Name:        $vPDBName" | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "CDB Name:             $vCDBName" | tee -a $vOutputLog
		if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
		then
			echo "  (This was changed due to length)" | tee -a $vOutputLog
		fi
		echo "Oracle Version:       12c" | tee -a $vOutputLog
	else
		echo "Oracle Version:       11g" | tee -a $vOutputLog
	fi
	echo "Character Set:        $vCharSet" | tee -a $vOutputLog
	echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
	echo "Datafiles:            /database/E${vCDBFull}/${vCDBFull}01/oradata" | tee -a $vOutputLog
	echo "Data Pump Directory:  $vDPParDir" | tee -a $vOutputLog
	echo "Parallelism:          $vParallelLevel" | tee -a $vOutputLog
	echo "Encrypted:            YES" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog

	# Confirmation
	echo ""
	echo "Are these values correct?"
	echo "Waiting for 1 minute"
	sleep 60
	# echo -e "Are these values correct? (Y) or (N) \c"
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
			# echo -e "Please enter (Y) or (N).\c"  
		# fi
	# done
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
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_admn01) 
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo01) 
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_redo02) 
	vDirArray+=(/database/E${vCDBFull}/${vCDBFull}_arch01) 
	vDirArray+=($vScriptDir)
	vDirArray+=($vEnvScriptDir)
	vDirArray+=($GGMOUNT)

	# Add Oracle Home and data mount points to array based on DB version
	if [[ $vDBVersion -eq 12 ]]
	then
		vDirArray+=($vHome12c)
		vDirArray+=(/database/E${vCDBFull}/${vCDBFull}01)
	else
		vDirArray+=($vHome11g)
	fi
	vDataDirs=$(df -h /database/E${vPDBName}/${vPDBName}0* | grep ${vPDBName} | awk '{ print $7}')
	for vDirName in ${vDataDirs[@]}
	do
		vDirArray+=($vDirName)
	done
	
	# Set file array
	unset vFileArray
	vFileArray+=(${vEnvScriptDir}/setnewdb.sh)
	# vFileArray+=($vColdTemplate)
	# vFileArray+=(${vTNSScriptDir}/tns_update_auto.sh)
	# vFileArray+=(${vTNSScriptDir}/tns_template.ora)
	# vFileArray+=($vTNSMaster)
	# vFileArray+=($vTNSServer)
	vFileArray+=($ORATAB)
	vFileArray+=($vPasswordFnc)
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
truncate table $vLinuxSysGenIndexTable;
truncate table $vLinuxLobTable;

-- insert Linux object info
insert into $vLinuxObjectTable
select owner, object_name, object_type, status
from DBA_OBJECTS
where object_type not like '%PARTITION%' and owner not in ($vExcludeUsers)
and SUBOBJECT_NAME is null and GENERATED='N'
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

-- insert Linux lob data
insert into $vLinuxLobTable
select owner, table_name, column_name, tablespace_name
from dba_lobs
where owner not in ($vExcludeUsers);
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

-- insert Linux system-generated names
insert into $vLinuxSysGenIndexTable
select ic.table_owner, ic.table_name, ic.column_name, di.index_type, di.uniqueness, di.status, ic.descend 
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
join dba_objects ob
	on ob.object_name=di.index_name and ob.owner=di.owner
where ob.object_type='INDEX' and ob.generated='Y'
  and ic.table_owner not in ($vExcludeUsers);
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
		and lx.owner not in ('GGTEST')) diff
	on mv.owner=diff.owner and mv.mview_name=diff."TABLE_NAME"
order by 1;

-- Table status comparison
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGTEST')
order by 1;

-- Index count comparison
col "AIX INDEX" format a50
col "LINUX INDEX" format a50
select aix.OWNER||'.'||aix.INDEX_NAME "AIX-INDEX", lx.OWNER||'.'||lx.INDEX_NAME "LX-INDEX"
from $vLinuxIndexTable lx full outer join $vIndexTable aix
  on aix.OWNER=lx.OWNER and aix.INDEX_NAME=lx.INDEX_NAME
where lx.INDEX_NAME is null and lx.owner not in ('GGTEST')
order by aix.OWNER, aix.INDEX_NAME, lx.OWNER, lx.INDEX_NAME;

-- Object status comparison
col "OBJECT_NAME" format a40
select aix.OBJECT_TYPE, aix.OWNER||'.'||aix.OBJECT_NAME "OBJECT_NAME", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxObjectTable lx full outer join $vObjectTable aix
  on aix.OWNER=lx.OWNER and aix.OBJECT_NAME=lx.OBJECT_NAME and aix.OBJECT_TYPE=lx.OBJECT_TYPE
where lx.STATUS!=aix.STATUS and lx.STATUS!='VALID' OR lx.STATUS is null
--and lx.owner not in ('GGTEST')
order by aix.OBJECT_TYPE, aix.OWNER, aix.OBJECT_NAME;

-- Constraint comparison
select lx.owner, lx.table_name, lx.constraint_name, lx.constraint_type, aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxConstraintTable lx full outer join $vConstraintTable aix
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.constraint_name=lx.constraint_name
where lx.STATUS!=aix.STATUS and lx.owner not in ('GGTEST')
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
	echo "* Verify users/profiles in $vPDBName              *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	
	if [[ $vDBVersion -eq 12 ]]
	then
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

-- drop tables
DROP TABLE $vLinuxUsersTable;
DROP TABLE $vLinuxProfilesTable;

WHENEVER SQLERROR EXIT

-- create users table
CREATE TABLE $vLinuxUsersTable AS
select username, profile, common
from dba_users
where 1=0;

-- populate users table
insert into $vLinuxUsersTable values ('AUTODDL','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('AUTODML','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('ECORA','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('ORA_QUALYS_DB','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('SQLTUNE','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('TNS_USER','APP_PROFILE','YES');
insert into $vLinuxUsersTable values ('UIMMONITOR','APP_PROFILE','YES');
commit;

-- create profiles table
CREATE TABLE $vLinuxProfilesTable AS
select PROFILE, RESOURCE_NAME, LIMIT, COMMON
from dba_profiles
where 1=0;

-- populate profiles table
insert into $vLinuxProfilesTable values ('APP_PROFILE','COMPOSITE_LIMIT','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','CONNECT_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','CPU_PER_CALL','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','CPU_PER_SESSION','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','FAILED_LOGIN_ATTEMPTS','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','IDLE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','LOGICAL_READS_PER_CALL','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','LOGICAL_READS_PER_SESSION','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_GRACE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_LIFE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_LOCK_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_REUSE_MAX','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_REUSE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PASSWORD_VERIFY_FUNCTION','FROM ROOT','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','PRIVATE_SGA','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('APP_PROFILE','SESSIONS_PER_USER','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','COMPOSITE_LIMIT','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','CONNECT_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','CPU_PER_SESSION','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','CPU_PER_CALL','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','FAILED_LOGIN_ATTEMPTS','3','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','IDLE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','LOGICAL_READS_PER_CALL','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','LOGICAL_READS_PER_SESSION','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_GRACE_TIME','0','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_LIFE_TIME','90','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_LOCK_TIME','1','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_REUSE_MAX','3','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_REUSE_TIME','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PASSWORD_VERIFY_FUNCTION','FROM ROOT','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','PRIVATE_SGA','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('CNO_PROFILE','SESSIONS_PER_USER','UNLIMITED','YES');
insert into $vLinuxProfilesTable values ('DEFAULT','COMPOSITE_LIMIT','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','CONNECT_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','CPU_PER_CALL','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','CPU_PER_SESSION','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','FAILED_LOGIN_ATTEMPTS','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','IDLE_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','LOGICAL_READS_PER_CALL','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','LOGICAL_READS_PER_SESSION','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_GRACE_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_LIFE_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_LOCK_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_REUSE_MAX','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_REUSE_TIME','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PASSWORD_VERIFY_FUNCTION','VERIFY_FUNCTION_CNO','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','PRIVATE_SGA','UNLIMITED','NO');
insert into $vLinuxProfilesTable values ('DEFAULT','SESSIONS_PER_USER','UNLIMITED','NO');
commit;

PROMPT Setting all standard users to APP_PROFILE profile
BEGIN
  FOR i IN
    (select 'ALTER USER '||du.username||' PROFILE APP_PROFILE' cmd
	 from dba_users du join ggtest.users_linux std on du.username=std.username
	 where (std.profile!=du.profile or du.username is null))
  LOOP
    dbms_output.put_line(i.cmd);
    execute immediate i.cmd;
  END LOOP;
END;
/

PROMPT Setting profiles to gold standard settings
BEGIN
  FOR i IN
    (select 'ALTER PROFILE '||dp.PROFILE||' LIMIT '||std.RESOURCE_NAME||' '||std.LIMIT cmd
	 from dba_profiles dp join ggtest.profiles_linux std on dp.PROFILE=std.PROFILE and dp.RESOURCE_NAME=std.RESOURCE_NAME
	 where (std.LIMIT!=dp.LIMIT or dp.PROFILE is null))
  LOOP
    dbms_output.put_line(i.cmd);
    execute immediate i.cmd;
  END LOOP;
END;
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

-- compare standard users to actual
col username format a30
col "STD_PROFILE" format a20
col "ACT_PROFILE" format a20
col "STD" format a3
col "ACT" format a3
select NVL(du.username,std.username||' ***') "USERNAME", 
	std.profile "STD_PROFILE", NVL(du.profile,'***') "ACT_PROFILE", 
	std.common "STD", NVL(du.common,'***') "ACT"
from dba_users du full outer join $vLinuxUsersTable std on du.username=std.username
where (std.profile!=du.profile or std.common!=du.common or du.username is null)
order by 1;

-- compare standard profiles to actual
col profile format a20
col RESOURCE_NAME format a40
col "STD_LIMIT" format a30
col "ACT_LIMIT" format a30
select NVL(dp.PROFILE,std.PROFILE) "PROFILE", NVL(dp.RESOURCE_NAME,std.RESOURCE_NAME) "RESOURCE_NAME", std.LIMIT "STD_LIMIT", dp.LIMIT "ACT_LIMIT", std.common "STD", dp.common "ACT"
from dba_profiles dp full outer join $vLinuxProfilesTable std on dp.PROFILE=std.PROFILE and dp.RESOURCE_NAME=std.RESOURCE_NAME
where (std.LIMIT!=dp.LIMIT or std.common!=dp.common or dp.PROFILE is null)
--dp.PROFILE in ($vLinuxProfilesList) and
order by 1,2;

EXIT;
RUNSQL

fi

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
	
		echo "" | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "* Verify UAT settings                            *"  | tee -a $vOutputLog
	echo "**************************************************" | tee -a $vOutputLog
	echo "" | tee -a $vOutputLog
	
	# run post-build checks
	if [[ $vDBVersion -eq 12 ]]
	then
		$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
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
WHENEVER SQLERROR EXIT
SPOOL $vOutputLog APPEND

-- set AWR retention policy
exec DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(132480,60);

-- enable block change tracking
WHENEVER SQLERROR CONTINUE
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/database/E${vCDBFull}/${vCDBFull}_admn01/admin/bct/bct.bt';
WHENEVER SQLERROR EXIT

-- AWR retention policy
SELECT dhwc.dbid, extract(day from dhwc.snap_interval) *24*60+extract(hour from dhwc.snap_interval) *60+extract(minute from dhwc.snap_interval) snapshot_Interval,
	extract(day from dhwc.retention) *24*60+extract(hour from dhwc.retention) *60+extract(minute from dhwc.retention) retention_Interval
FROM dba_hist_wr_control dhwc, V\$DATABASE db
WHERE dhwc.dbid=db.dbid;

-- jobs
col client_name format a40
select client_name, status from DBA_AUTOTASK_CLIENT order by client_name;

-- block change tracking
col filename format a60
select * from v\$block_change_tracking;

-- hidden parameter
col Parameter format a50
col Session_Value format a20
col Instance_Value format a20
SELECT a.ksppinm "Parameter",
       b.ksppstvl "Session_Value",
       c.ksppstvl "Instance_Value"
FROM   x\$ksppi a,
       x\$ksppcv b,
       x\$ksppsv c
WHERE  a.indx = b.indx
AND    a.indx = c.indx
AND    a.ksppinm LIKE '/_%' escape '/'
AND    a.ksppinm LIKE '_optimizer_gather_stats_on_load'
ORDER BY 1;

-- filesystemio_options parameter
col name format a30
col value format a10
select name, value from v\$spparameter where name='filesystemio_options';
select name, value from v\$parameter where name='filesystemio_options';

spool off
EXIT
RUNSQL

	fi
	
	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog

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

-- load UAT compressed table list
CREATE TABLE GGTEST.COMP_TABLES_UAT (
	OWNER			VARCHAR2(30),
	TABLE_NAME		VARCHAR2(30),
	COMPRESS_FOR	VARCHAR2(30)
);
------------------------------------------------------------------------------------------
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('AIM_RM','POLICY_SUMMARY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','AGT_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','APP_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','CLM_OBJ_ATTR','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','CLM_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','CLNT_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','COVRG_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','EVNT_OBJ','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','EVNT_OBJ_ATTR','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','EVNT_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','EVNT_OBJ_XREF','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','MV_DATA_POINT_TM_SERIS','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','MV_RLTSHP_LIST','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','MV_SUBJ_AREA_ATTR_LIST','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POC_OBJ_ATTR','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POC_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POLCY_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POL_PTY_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POL_PTY_POC_ATTR','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','POL_PTY_POC_KVP','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','PTY_OBJ_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','RLTSHP_APP_CVG_ATTR','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_CORE','RLTSHP_APP_CVG_ATTR_VAL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CIL_APP_PTY_APP_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_CLIENT_MDM_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_EPS_EID','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_EPS_EID_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_EPS_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_POL_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_POL_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_POL_PTY_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_L_PTY_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_POL_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_POL_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CCF_QSR_POL_PTY_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','CURE_QUEUE','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_ATS_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_ATS_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_ATS_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_AWD_EVNT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_BLC_CLM','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_BLC_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_BLC_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_BLC_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_WN_CLM','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_WN_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_WN_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BICPS_WN_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BLCP_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BLC_ISSUE_APPLICATION','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BLC_ISSUE_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_BLC_ISSUE_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_C3_APP','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_C3_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_C3_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIB_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIL_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIL_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIL_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIT_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIT_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CIT_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CLIENT_MDM_CLIENT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CLIENT_MDM_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CTS2_CLM','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CTS2_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CTS2_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_CTS2_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_C_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_C_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_C_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_F_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_F_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_F_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_S_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_S_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_DSS_S_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_EAPP_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_EAPP_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_ERL_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_EZAPP_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_EZAPP_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_FDLZ_POLCY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LIFEPRO_CIK_EVNT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LIFEPRO_CIK_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LIFEPRO_CIK_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LIFEPRO_CIK_POLICY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LPK_APP','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LPK_CLM','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LTG_CLM','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LTG_EVT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LTG_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LTG_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_LTG_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PAL_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PAL_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PAL_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PPLUS_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PPLUS_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_PPLUS_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_QSEARCH_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_QSEARCH_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_RPS_POLCY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_SELERIX_APPLICATION','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_SHARP_WN_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_SHARP_WN_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_AGT','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_APP','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_CVG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_POL','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_V1T_PTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_WN_COVRG_MSTR_COVRG','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_WN_ISSUE_APPLICATION','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_WN_ISSUE_PARTY','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','PEL_WN_ISSUE_POC','ADVANCED');
INSERT INTO GGTEST.COMP_TABLES_UAT VALUES ('CURE_QUEUE','QSRCH_SLCTN','ADVANCED');
COMMIT;

-- compare compression settings to UAT
col "OWNER" format a30
col "TABLE_NAME" format a30
col "UAT" format a12
col "PROD" format a12
select NVL(prd.OWNER,uat.OWNER) "OWNER", NVL(prd.TABLE_NAME,uat.TABLE_NAME) "TABLE_NAME",
	uat.COMPRESS_FOR "UAT", prd.COMPRESS_FOR "PROD"
from GGTEST.COMP_TABLES_UAT uat join (
	select distinct owner, table_name, COMPRESS_FOR from dba_tables where COMPRESSION='ENABLED'
	union
	select distinct table_owner, table_name, COMPRESS_FOR from dba_tab_subpartitions where COMPRESSION='ENABLED'
	union
	select distinct table_owner, table_name, COMPRESS_FOR from dba_tab_partitions where COMPRESSION='ENABLED') prd
on uat.owner=prd.owner and uat.table_name=prd.table_name
order by 1,2;

spool off
EXIT
RUNSQL

	# check log for errors
	error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
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

# while :
# do
	# echo ""
    # echo -e "\tWhere would you like to start/continue this script?"
    # echo -e "\t---------------------------------------------"
    # echo -e "\t1) Beginning"
    # echo -e "\t2) Create the Database"
	# echo -e "\t3) Create pluggable database (12c only)"
	# echo -e "\t4) Create DB Objects"
    # echo -e "\t5) Turn on Archive Log Mode"
	# echo -e "\t6) Add DB to tnsnames file"
	# echo -e "\t7) Take a backup"
	# echo -e "\t8) Prep Database for GG"
	# echo -e "\t9) Import AIX data and metadata"
	# echo -e "\t10) Import AIX data only"
	# echo -e "\t11) Add DB to OEM"
	# echo -e "\t12) Verify data"
	# echo -e "\tq) Quit"
    # echo
    # echo -e "\tEnter your selection: r\b\c"
    # read selection
    # if [[ -z "$selection" ]]
        # then selection=r
    # fi

    # case $selection in
        # 1)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# pre_check_fnc
			# create_dirs_fnc
			# aix_files_fnc
			# create_files_fnc
			# dup_db_fnc
			# update_param_fnc
			# plug_db_fnc
			# create_ts_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
        # 2)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# shutdown_db_fnc
			# dup_db_fnc
			# update_param_fnc
			# plug_db_fnc
			# create_ts_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
		# 3)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# plug_db_fnc
			# create_ts_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
			# ;;
		# 4)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# create_ts_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
			# ;;
		# 5)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
			# ;;
		# 6)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
			# ;;
		# 7)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
			# ;;
        # 8)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# missing_files_fnc
			# db_prep_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
		# 9)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# import_meta_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
		# 10)  prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# import_data_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
		# 11) prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
		# 12) prompt_short_fnc
			# variables_fnc
			# confirmation_fnc
			# check_vars_fnc
			# verify_data_fnc
			# summary_fnc
			# exit
            # ;;
      # q|Q)  echo "You have chosen to quit"
            # exit
            # ;;
        # *)  echo -e "\n Invalid selection"
            # sleep 1
            # ;;
    # esac
# done

# call parameter file
source dsrp_2_Linux_build_DB.param

prompt_short_fnc
variables_fnc
confirmation_fnc
check_vars_fnc
#pre_check_fnc
#create_dirs_fnc
#aix_files_fnc
#create_files_fnc
#dup_db_fnc
#update_param_fnc
#plug_db_fnc
#create_ts_fnc
# archive_fnc
#missing_files_fnc
#db_prep_fnc
#import_meta_fnc
import_data_fnc
verify_data_fnc
summary_fnc
			
cat $vOutputLog >> $vFullLog
