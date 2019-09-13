#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GGRR_4_start_replicat_LXOGG.sh
#
#  DESCRIPTION
#    Start extract for reverse replication on GoldenGate host
#
#  NOTES
#    Run as oracle
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         03/19/17 - Created
#
# PREREQUISITES
#
#  STEPS
#    1. 
#    2. 
#    3. 
#
#================================================================================================#

vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')

############################ Oracle Constants ############################
export ORACLE_HOME="/app/oracle/product/db/11g/1"

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts"
vUpgradeDir="${vScriptDir}/12cupgrade"
vLogDir="${vUpgradeDir}/logs"
vLockExclude="'GGS','SYS','SYSTEM','DBSNMP'"
GGRUNNING="TRUE"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	export GGATE=/app/oragg/12.2_11g
	export TNS_ADMIN=/app/oracle/product/db/11g/1/network/admin
else
	export GGATE=/app/oracle/product/ggate/11g/1
	export TNS_ADMIN="/app/oracle/tns_admin"
fi

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
		exit 1
	else
		echo " " | tee -a $vOutputLog
		echo "No errors to report." | tee -a $vOutputLog
	fi
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

	$ORACLE_HOME/bin/sqlplus -s "sys/${vSysPwd}@${ORACLE_SID} as sysdba" << EOF
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
WHENEVER SQLERROR CONTINUE

SPOOL $vLockUsers
select 'ALTER USER '||username||' ACCOUNT LOCK;'
from dba_users
where ACCOUNT_STATUS in ('OPEN','EXPIRED') and USERNAME not in ($vLockExclude)
order by 1;
SPOOL OFF

SPOOL $vUnlockUsers
select 'ALTER USER '||username||' ACCOUNT '||account_status||';'
from dba_users
where ACCOUNT_STATUS in ('OPEN','EXPIRED') and USERNAME not in ($vLockExclude)
order by 1;
SPOOL OFF

REM Locking user accounts
SPOOL $vOutputLog APPEND
@$vLockUsers
SPOOL OFF
EOF

# check for errors
error_check_fnc $vLockUsers $vErrorLog
error_check_fnc $vUnlockUsers $vErrorLog
error_check_fnc $vOutputLog $vErrorLog
}

############################ GoldenGate View Report ##########################
# PURPOSE:                                                                   #
# This function views the errors in a GG process report.                     #
##############################################################################

function view_report_fnc {
	cd $GGATE
	# Check report file
	./ggsci > $vGGStatusOut << EOF
view report $1
exit
EOF

	# display errors
	echo "" | tee -a $vOutputLog
	echo "Report errors for $1:" | tee -a $vOutputLog
	cat $vGGStatusOut | grep ERROR | tee -a $vOutputLog
}

############################ GoldenGate Fail Check ###########################
# PURPOSE:                                                                   #
# This function makes sure GG process is running.                            #
##############################################################################

function gg_run_check_fnc {
	echo "" | tee -a $vOutputLog
	echo "Check the status of $1" | tee -a $vOutputLog
	cd $GGATE
	while true
	do
		# Check the GG status
		./ggsci > $vGGStatusOut << EOF
info all
exit
EOF
		echo "Waiting 30 seconds..." | tee -a $vOutputLog
		sleep 30
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
			view_report_fnc $1
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

############################ Start Rep Function ##############################
# PURPOSE:                                                                   #
# This function starts the GG replicat.                                      #
##############################################################################

function gg_start_rep_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Starting GG replicat process  *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Create GG script
	echo "DBLOGIN USERID ggs@${vDBName} PASSWORD $vGGSPwd" > $vProcessOby
	echo "delete replicat $vRepName" >> $vProcessOby
	echo "add replicat $vRepName, INTEGRATED , exttrail $vRepTrail" >> $vProcessOby
	
	# Get Linux SCN
	SOURCE_CURRENT_SCN=`cat $vLinuxStartSCN`
	echo "" | tee -a $vOutputLog
	echo "Starting replicat at SCN $SOURCE_CURRENT_SCN" | tee -a $vOutputLog
	
	# start replicat process
	cd $GGATE
./ggsci >> $vOutputLog << EOF
obey $vProcessOby
sh sleep 10

start replicat $vRepName
sh sleep 10
exit
EOF
#start replicat $vRepName aftercsn $SOURCE_CURRENT_SCN

	sleep 5
	
	# Check the GG extract status
	#vRepStatus="unknown"
	#vRepStatus=$(gg_run_check_fnc $vRepName)
	gg_run_check_fnc $vRepName
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

############################ Prompt Function #################################
# PURPOSE:                                                                   #
# This function prompts the user for input.                                  #
##############################################################################

function prompt_fnc {
	# Prompt for DB name
	echo ""
	echo -e "Enter the database to replicate (use the 11g name): \c"  
	while true
	do
		read vNewDB
		if [[ -n "$vNewDB" ]]
		then
			vDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
			DBCAPS=`echo $vNewDB | tr 'a-z' 'A-Z'`
			export ORACLE_SID=$vDBName
			break
		else
			echo -e "Enter a valid database name: \c"  
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
		echo "Enter the password for the GGS user :"
		stty -echo
		read vGGSPwd
		if [[ -n "$vGGSPwd" ]]
		then
			break
		else
			echo "You must enter a password\n"
		fi
	done
	stty echo
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

############################ Set host variables ############################
export EDITOR=vim
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`

############################ User prompts ############################

prompt_fnc

############################ Oracle Variables ############################
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
export TNS_ADMIN="${ORACLE_BASE}/tns_admin"

############################ Script Variables ############################

# set output log names
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${vLogDir}/${vBaseName}_${vDBName}_${NOWwSECs}.log"
vErrorLog="${vLogDir}/${vBaseName}_${vPDBName}_err.log"
vGGStatusOut="${vLogDir}/GGStatus_${vDBName}.out"
vTNSLog="${vLogDir}/TNS-Check_${vDBName}.log"

# Remove existing logs
if [[ -f $vOutputLog ]]
then
	rm $vOutputLog
fi
if [[ -f $vErrorLog ]]
then
	rm $vErrorLog
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
	echo "" | tee -a $OUTPUTLOG
	echo "ERROR: The extract name $vRepName is too long. Max is 8 characters." | tee -a $OUTPUTLOG
	exit 1
else
	echo "" | tee -a $OUTPUTLOG
	echo "The replicat name is set to $vRepName." | tee -a $OUTPUTLOG
fi

# GG directories and files
DIRPRM="${GGATE}/dirprm"
DIROUT="${GGATE}/dirout"
DIRDAT="${GGATE}/dirdat"
DBDAT="${DIRDAT}/${vDBName}"
vGGRevDir="${DBDAT}/RR"
vSQLDir="${GGATE}/dirsql"

# set directory array
unset vDirArray
vDirArray+=($DIRPRM)
vDirArray+=($DIRDAT)
vDirArray+=($DBDAT)
vDirArray+=($vGGRevDir)
vDirArray+=($vSQLDir)

# GG files
vRepTrail="${vGGRevDir}/ra"
vProcessOby="${DIRPRM}/${vDBName}_AIX_replicat.oby"
if [[ -f $vProcessOby ]]
then
	rm $vProcessOby
fi

# Files from other scripts
TARFILE_RR="Linux_RR_${vDBName}.tar"
RPRMFILE="${vRepName}.prm"
vLinuxStartSCN="RR_replicat_${vDBName}_start_scn.out"

# set array of files to check
unset vFileArray
vFileArray+=(${DIRPRM}/${RPRMFILE})
vFileArray+=(${DIROUT}/${vLinuxStartSCN})

# scripts to create
# vLockUsers="${vSQLDir}/LockUsers_${vDBName}.sql"
# vUnlockUsers="${vSQLDir}/RestoreUsers_${vDBName}.sql"

############################ Pre-checks ############################

echo ""  | tee -a $vOutputLog
echo "*********************************"  | tee -a $vOutputLog
echo "* Checking GG manager           *"  | tee -a $vOutputLog
echo "*********************************"  | tee -a $vOutputLog

# Check that GG manager is running
cd $GGATE
./ggsci > $vGGStatusOut << EOF
info mgr
exit
EOF

sleep 5
vGGStatus=$(cat $vGGStatusOut | grep "Manager" | awk '{ print $3}')
if [[ $vGGStatus != "running" ]]
then
	echo ""  | tee -a $vOutputLog
	echo "The GoldenGate manager is $vGGStatus. Please fix before continuing."  | tee -a $vOutputLog
	exit 1
else
	echo ""  | tee -a $vOutputLog
	echo "The GoldenGate manager is $vGGStatus."  | tee -a $vOutputLog
	echo "COMPLETE"  | tee -a $vOutputLog
fi

echo "" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog
echo "* Performing pre-install checks *" | tee -a $vOutputLog
echo "*********************************" | tee -a $vOutputLog

# check for tar file
if [[ ! -e ${DIROUT}/${TARFILE_RR} ]]
then
	# check alternative location
	if [[ ! -e /tmp/${TARFILE_RR} ]]
	then
		echo " " | tee -a $vOutputLog
		echo "ERROR: The tar file of scripts from AIX is missing: $TARFILE_RR" | tee -a $vOutputLog
		echo "       Check the Linux VM in /database/<CDBName>_admn01/scripts/RR" | tee -a $vOutputLog
		echo "       Copy it to $DIROUT before continuing." | tee -a $vOutputLog
		exit 1
	else
		echo " " | tee -a $vOutputLog
		echo "$TARFILE_RR found in /tmp" | tee -a $vOutputLog
		cd /tmp
		tar -xf $TARFILE_RR
	fi
else
	echo " " | tee -a $vOutputLog
	echo "$TARFILE_RR found in $DIROUT" | tee -a $vOutputLog
	cd $DIROUT
	tar -xf $TARFILE_RR
fi

# move files
mv $RPRMFILE $DIRPRM
mv $vLinuxStartSCN $DIROUT

# Check for required directories
echo "" | tee -a $vOutputLog
echo "Checking for required directories..." | tee -a $vOutputLog
for vCheckArray in ${vDirArray[@]}
do
	if [[ ! -d $vCheckArray ]]
	then
		mkdir $vCheckArray
		if [[ $? -ne 0 ]]
		then
			echo "ERROR: Could not create directory $vCheckArray" | tee -a $vOutputLog
			exit 1
		else
			echo "$vCheckArray created" | tee -a $vOutputLog
		fi
	fi
done

# Check for required files
echo "" | tee -a $vOutputLog
echo "Checking for required files..." | tee -a $vOutputLog
for vCheckArray in ${vFileArray[@]}
do
	if [[ ! -e $vCheckArray ]]
	then
		echo ""  | tee -a $vOutputLog
		echo "ERROR: $vCheckArray does not exist!" | tee -a $vOutputLog
		exit 1
	fi
done

############################ Database Variables ############################

# Display user entries
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
echo "Database Name:    $vDBName" | tee -a $vOutputLog
#echo "Oracle Version:   $vDBVersion" | tee -a $vOutputLog
echo "Oracle Home:      $ORACLE_HOME" | tee -a $vOutputLog
echo "GoldenGate Home:  $GGATE" | tee -a $vOutputLog
echo "GG Replicat Name: $vRepName" | tee -a $vOutputLog
echo "Output Log:       $vOutputLog" | tee -a $vOutputLog
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
		echo -e "Please enter (Y) or (N) \c"
	fi
done

############################ Verify tns entry ############################

echo ""  | tee -a $vOutputLog
echo "Checking tnsnames.ora"  | tee -a $vOutputLog

tnsping $vDBName > $vTNSLog
vTNSCheck=$(cat $vTNSLog | grep HOST | awk '{print $17}' | tr 'a-z' 'A-Z' | cut -c 1-2)
if [[ $vTNSCheck = 'UX' ]]
then
	echo ""  | tee -a $vOutputLog
	echo "SUCCESS: Able to ping $vDBName"  | tee -a $vOutputLog
elif [[ $vTNSCheck = '' ]]
then
	echo ""  | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	echo "ERROR"  | tee -a $vOutputLog
	echo "The tnsnames.ora file cannot find $vDBName."  | tee -a $vOutputLog
	echo "Confirm the connection before continuing."  | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	exit 1
else
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	echo "ERROR"  | tee -a $vOutputLog
	echo "The tnsnames.ora file is not pointing to an AIX server."  | tee -a $vOutputLog
	echo "You must correct this before continuing."  | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	exit 1
fi

############################ Run Subroutines ############################

# lock unnecessary user accounts
# lock_users_fnc

# Start GG replicat process
gg_start_rep_fnc
# sleep 30

# Check if replicat is processing data
gg_rba_check_fnc $vRepName

############################ Summary ################################

# Report Timing of Script
vEndSec=$(date '+%s')
vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:         $vDBName" | tee -a $vOutputLog
# if [[ $vDBVersion -eq 12 ]]
# then
	# echo "Version:               12c" | tee -a $vOutputLog
# else
	# echo "Version:               11g" | tee -a $vOutputLog
# fi
echo "GoldenGate Home:       $GGATE" | tee -a $vOutputLog
if [[ $GGRUNNING = "TRUE" ]]
then
	echo "GG Status:             Running" | tee -a $vOutputLog
else
	echo "GG Status:             Stopped/Abended" | tee -a $vOutputLog
	echo "  !!! Please check rpt files for errors !!!" | tee -a $vOutputLog
fi
echo "Unlock Users Script:   $vUnlockUsers" | tee -a $vOutputLog
echo "Total Run Time:        $vTotalTime" | tee -a $vOutputLog
echo "Output log:            $vOutputLog" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
