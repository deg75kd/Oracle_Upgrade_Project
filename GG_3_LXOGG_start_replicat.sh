#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GG_Linux_start_replicat.sh
#
#  DESCRIPTION
#    Start GG replicat from intermediary server
#
#  NOTES
#    Run as oracle
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         03/13/17 - Created
#
# PREREQUISITES
#    Parameter file built from AIX script
#    GoldenGate installed and manager running
#    Extract for the DB being pushed to this host
#    /oraggrep mounted
#
#  STEPS
#    1. Set variables (including prompting user for some)
#    2. Perform pre-install checks
#    3. Create directories
#    4. 
#    5. 
#    6. 
#    7. 
#    8. 
#    9. 
#    10. 
#    11. 
#    12. 
#    13. 
#    14. 
#
#================================================================================================#

vStartSec=$(date '+%s')
NOWwSECs=$(date '+%Y%m%d%H%M%S')

############################ Oracle Constants ############################
export ORACLE_BASE="/app/oracle"
export TNS_ADMIN=/app/oracle/tns_admin
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHome11g="${ORACLE_BASE}/product/db/11g/1"
vOraTab="/etc/oratab"
vCDBPrefix="c"
MAXNAMELENGTH=8

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts"
vUpgradeDir="${vScriptDir}/12cupgrade"
vLogDir="${vUpgradeDir}/logs"

# set tier-specific constants
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
if [[ $vTier = 's' ]]
then
	GGATE12=/oragg/12.2
	GGATE11=/app/oragg/12.2_11g
else
	GGATE12=/app/oracle/product/ggate/12c/1
	GGATE11=/app/oracle/product/ggate/11g/1
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

############################ GoldenGate Manager Check ########################
# PURPOSE:                                                                   #
# This function makes sure GG manager is running.                            #
##############################################################################

function gg_mgr_check_fnc {
	echo ""  | tee -a $vOutputLog
	echo "*********************************"  | tee -a $vOutputLog
	echo "* Checking GG manager           *"  | tee -a $vOutputLog
	echo "*********************************"  | tee -a $vOutputLog
	
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
		echo ""  | tee -a $vOutputLog
		echo "The GoldenGate manager is $GGMGRSTATUS. Please fix before continuing."  | tee -a $vOutputLog
		exit 1
	else
		echo ""  | tee -a $vOutputLog
		echo "The GoldenGate manager is $GGMGRSTATUS."  | tee -a $vOutputLog
		echo "COMPLETE"  | tee -a $vOutputLog
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
		sleep 5
		cat $GGALLOUT | tee -a $vOutputLog
		GGALLSTATUS=$(cat $GGALLOUT | grep "$1" | awk '{ print $2}')
		if [[ $GGALLSTATUS = "STOPPED" || $GGALLSTATUS = "ABENDED" ]]
		then
			GGRUNNING="FALSE"
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			echo "WARNING"  | tee -a $vOutputLog
			echo "The GG process $1 is $GGALLSTATUS."  | tee -a $vOutputLog
			echo "Please make sure this is running before continuing." | tee -a $vOutputLog
			echo "The command for the initial start is:" | tee -a $vOutputLog
			echo "  start replicat $vRepName aftercsn $SOURCE_CURRENT_SCN" | tee -a $vOutputLog
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
			break
			#exit 1
		elif [[ $GGALLSTATUS = "RUNNING" ]]
		then
			echo "SUCCESS: The GG process $1 is $GGALLSTATUS."
			break
		else
			sleep 10
		fi
	done
}

############################ GoldenGate Process Check ########################
# PURPOSE:                                                                   #
# This function checks if this GG process is already running.                #
##############################################################################

function gg_pre_check_fnc {
	# Check the GG status
	cd $GGATE
	./ggsci > $GGALLOUT << EOF
info all
exit
EOF

	sleep 5
	cat $GGALLOUT | tee -a $vOutputLog
	GGCOUNT=$(cat $GGALLOUT | grep "$1" | wc -l)
	if [[ $GGCOUNT -ne 0 ]]
	then
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
		echo "ERROR"  | tee -a $vOutputLog
		echo "The GG process $1 is already running here."  | tee -a $vOutputLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
		exit 1
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
	vProcessOby="$DIRPRM/${vDBName}_LINUX_rep.oby"
	if [[ -f $vProcessOby ]]
	then
		rm $vProcessOby
	fi
	echo "DBLOGIN USERID ggs@${vDBName} PASSWORD $vGGSPwd" > $vProcessOby
	echo "delete replicat $vRepName" >> $vProcessOby
	echo "add replicat $vRepName, INTEGRATED , exttrail $REPDIR" >> $vProcessOby
	
	# Get AIX SCN
	SOURCE_CURRENT_SCN=`cat $SCNFILE | awk '{print $2}'`
	echo $SOURCE_CURRENT_SCN > $REPSCN
	
	# start replicat process
	cd $GGATE
./ggsci >> $vOutputLog << EOF
obey $vProcessOby
sh sleep 10

start replicat $vRepName aftercsn $SOURCE_CURRENT_SCN
sh sleep 10
exit
EOF

	sleep 5
	
}

############################ Prompt Function #################################
# PURPOSE:                                                                   #
# This function prompts the user for input.                                  #
##############################################################################

function prompt_fnc {
	# List running databases
	# echo ""
	# /app/oracle/scripts/pmonn.pm

	# Prompt for DB name
	echo ""
	echo -e "Enter the database to replicate. Use the pluggable database name. \c"  
	while true
	do
		read vNewDB
		if [[ -n "$vNewDB" ]]
		then
			vDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
			DBCAPS=`echo $vNewDB | tr 'a-z' 'A-Z'`
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
			# set Oracle home
			export ORACLE_HOME=$vHome12c
			export GGATE=$GGATE12
			vDBVersion=12
			echo "You have selected Oracle version 12c"
			echo "The Oracle Home has been set to $vHome12c"
			break
		elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
		then
			# set Oracle home
			export ORACLE_HOME=$vHome11g
			export GGATE=$GGATE11
			vDBVersion=11
			echo "You have selected Oracle version 11g"
			echo "The Oracle Home has been set to $vHome11g"
			break
		else
			echo -e "Select a valid database version: \c"  
		fi
	done

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

############################ Pre-Check Function ##############################
# PURPOSE:                                                                   #
# This function checks script prerequisites.                                 #
##############################################################################

function pre_check_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Performing pre-install checks *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# Check if GG manager is running
	gg_mgr_check_fnc
	
	# Checking directories that can be created
	echo "" | tee -a $vOutputLog
	echo "Checking optional directories..." | tee -a $vOutputLog

	# Set array of optional directories
	unset vDirArray
	vDirArray+=($vUpgradeDir)
	vDirArray+=($vLogDir)
	vDirArray+=($vScriptDir)
	vDirArray+=($GGATE)
	vDirArray+=($DIRPRM)
	vDirArray+=($DIRDAT)
	vDirArray+=($DBDAT)

	# Create directories if they do not exist
	echo "" | tee -a $vOutputLog
	echo "Confirming that all directories created successfully..." | tee -a $vOutputLog
	for vCheckArray in ${vDirArray[@]}
	do
		df -h $vCheckArray
		if [ $? -ne 0 ]
		then
			# try to create it if not there
			echo "Trying again to create $vCheckArray..." | tee -a $vOutputLog
			mkdir $vCheckArray
			df -h $vCheckArray
			if [ $? -ne 0 ]
			then
				echo "ERROR: Unable to create $vCheckArray!" | tee -a $vOutputLog
				exit 1
			fi
		fi
	done
	
	# Set array of required directories
	vDirArray+=($GGATE)
	#vDirArray+=($GGATE11)
	vDirArray+=($ORACLE_BASE)
	vDirArray+=($vHome12c)
	#vDirArray+=($vHome11g)

	# Check for required directories
	echo "" | tee -a $vOutputLog
	echo "Confirming that all directories created successfully..." | tee -a $vOutputLog
	for vCheckArray in ${vDirArray[@]%:}
	do
		df -h $vCheckArray
		if [ $? -ne 0 ]
		then
			echo "ERROR: The directory $vCheckArray is missing!" | tee -a $vOutputLog
			exit 1
		fi
	done
	
	# check for tar file
	if [[ ! -e /tmp/${TARFILE} ]]
	then
		# check alternative location
#		TARFILE="${DIROUT}/Linux_setup_${vDBName}.tar"
		if [[ ! -e ${DIROUT}/${TARFILE} ]]
		then
			echo " " | tee -a $vOutputLog
			echo "ERROR: The tar file of scripts from AIX is missing: $TARFILE" | tee -a $vOutputLog
			echo "       This file is required to continue." | tee -a $vOutputLog
			exit 1 | tee -a $vOutputLog
		fi
	else
		mv /tmp/${TARFILE} $DIROUT
	fi
	# unzip file
	cd $DIROUT
	tar -xf $TARFILE
	cd $vUpgradeDir

	# Check for required files
	unset vFileArray
	vFileArray+=(${RPRMFILE})
	vFileArray+=(${SCNFILE})

	for vCheckArray in ${vFileArray[@]}
	do
		ls -l $vCheckArray
		if [ $? -ne 0 ]
		then
			echo ""  | tee -a $vOutputLog
			echo "ERROR: $vCheckArray does not exist!" | tee -a $vOutputLog
			exit 1
		fi
	done
	# Move param file from AIX
	mv $RPRMFILE $DIRPRM
	RPRMFILE="${DIRPRM}/${vRepName}.prm"
	
	# Check that database with this name not already running
	gg_pre_check_fnc $vRepName
}

############################ Summary Function ################################
# PURPOSE:                                                                   #
# This function displays summary.                                            #
##############################################################################

function summary_fnc {
	# Get Runtime of Script
	vEndSec=$(date '+%s')
	vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
	show_time $vRunSec

	echo "" | tee -a $vOutputLog
	echo "***************************************" | tee -a $vOutputLog
	echo "$0 is now complete." | tee -a $vOutputLog
	echo "Database Name:    $vDBName" | tee -a $vOutputLog
	if [[ $vDBVersion -eq 12 ]]
	then
		echo "Version:          12c" | tee -a $vOutputLog
	else
		echo "Version:          11g" | tee -a $vOutputLog
	fi
	echo "GoldenGate Home:  $GGATE" | tee -a $vOutputLog
	if [[ $GGRUNNING = "TRUE" ]]
	then
		echo "GG Status:        Running" | tee -a $vOutputLog
	else
		echo "GG Status:        Stopped/Abended" | tee -a $vOutputLog
		echo "  !!! Please check rpt files for errors !!!" | tee -a $vOutputLog
	fi
	echo "Total Run Time:   $vTotalTime" | tee -a $vOutputLog
	echo "***************************************" | tee -a $vOutputLog
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

# set CDB name
#vCDBName="${vCDBPrefix}${vDBName}"
#vCDBLength=$(echo -n $vCDBName | wc -c)
#if [[ $vCDBLength -gt $MAXNAMELENGTH ]]
#then
#	vCDBName1=$(echo -n $vCDBName | awk '{ print substr( $0, 1, 6 ) }')
#	vCDBName2=$(echo -n $vCDBName | awk '{ print substr( $0, length($0), length($0) ) }')
#	vCDBName="${vCDBName1}_${vCDBName2}"
#fi
#export ORACLE_SID=$vCDBName

# set output log names
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${vLogDir}/${vBaseName}_${vDBName}_${NOWwSECs}.log"
vErrorLog="${vLogDir}/${vBaseName}_${vDBName}_err.log"
vCritLog="${vLogDir}/${vBaseName}_${vDBName}_crit.log"
GGMGROUT="${vLogDir}/GGManagerStatus_${vDBName}.log"
GGALLOUT="${vLogDir}/GGAllStatus_${vDBName}.log"
GGRBAOUT="${vLogDir}/GGRBAStatus_${vDBName}.log"
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
if [[ -f $vCritLog ]]
then
	rm $vCritLog
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
vRepName="R${DBShort}1"
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
DIROUT="${GGATE}/dirout"
DIRDAT="${GGATE}/dirdat"
DIRPRM="${GGATE}/dirprm"
DBDAT="${DIRDAT}/${vDBName}"
REPDIR="${DBDAT}/ra"

# Files from AIX script
TARFILE="Linux_setup_${vDBName}.tar"
RPRMFILE="${DIROUT}/${vRepName}.prm"
SCNFILE="${DIROUT}/current_scn_AIX_${vDBName}.out"
REPSCN="${vLogDir}/replicat_${vDBName}_start_scn.out"

############################ Pre-checks ############################

pre_check_fnc

############################ Database Variables ############################

# Display user entries
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
echo "Database Name:    $vDBName" | tee -a $vOutputLog
#if [[ $vDBVersion -eq 12 ]]
#then
#	echo "  CDB Name:       $vCDBName" | tee -a $vOutputLog
#fi
echo "Oracle Home:      $ORACLE_HOME" | tee -a $vOutputLog
echo "GoldenGate Home:  $GGATE" | tee -a $vOutputLog
if [[ $vDBVersion -eq 12 ]]
then
	echo "Oracle Version:   12c" | tee -a $vOutputLog
else
	echo "Oracle Version:   11g" | tee -a $vOutputLog
fi
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
if [[ $vTNSCheck = 'LX' ]]
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
	echo "The tnsnames.ora file is not pointing to a Linux server."  | tee -a $vOutputLog
	echo "You must correct this before continuing."  | tee -a $vOutputLog
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
	exit 1
fi

############################ Run Subroutines ############################

# Start GG replicat process
gg_start_rep_fnc

# Check the GG extract status
GGRUNNING="TRUE"
gg_run_check_fnc $vRepName

# Check if replicat is processing data
gg_rba_check_fnc $vRepName

# Print script summary
summary_fnc
