#!/usr/bin/bash
#================================================================================================#
#  NAME
#    GG_0_autostart_extract.sh
#
#  DESCRIPTION
#    Tries to restart GG extract processes that are abended
#
#  NOTES
#    Run as oracle
#    
#  MODIFIED   (MM/DD/YY)
#  KDJ         03/25/17 - Created
#
#  STEPS
#    1. 


# set constants based on tier and OS
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`
vOSType=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, 0, 2 ) }'`
if [[ $vTier = 's' && $vOSType = 'ux' ]]
then
	GGATE11=/backup_uxs33/ggate/12.2
	GGATE12=/backup_uxs33/ggate/12.2
	vLogDir=/nomove/app/oracle/scripts/12cupgrade/logs
elif [[ $vTier = 's' && $vOSType = 'lx' ]]
then
	GGATE11=/app/oragg/12.2_11g
	GGATE12=/oragg/12.2
	vLogDir=/app/oracle/scripts/12cupgrade/logs
elif [[ $vOSType = 'ux' ]]
then
	GGATE11=/nomove/app/oracle/ggate/12c/1
	GGATE12=/nomove/app/oracle/ggate/12c/1
	vLogDir=/nomove/app/oracle/scripts/12cupgrade/logs
else
	GGATE11=/app/oracle/product/ggate/11g/1
	GGATE12=/app/oracle/product/ggate/12c/1
	vLogDir=/app/oracle/scripts/12cupgrade/logs
fi

vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputLog="${vLogDir}/${vBaseName}.log"
rm $vOutputLog

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
	cat $vGGStatusOut | grep ERROR | tee -a $vOutputLog
}

############################ GoldenGate Manager Check ########################
# PURPOSE:                                                                   #
# This function checks the status of the GG Manager.                         #
##############################################################################

function restart_mgr_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Checking manager              *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog

	# set variables
	vExtStatus="${GGATE}/dirout/extract_status.out"
	rm $vExtStatus
	
	# put proc statuses into file
	cd $GGATE
	./ggsci > $vExtStatus << EOF
info all
exit
EOF

	# check if manager is running
	vExtProcs=$(cat $vExtStatus | grep MANAGER | grep -E "STOPPED|ABENDED" | wc -l)
	
	# try to restart processes
	if [[ $vExtProcs -gt 0 ]]
	then
		# Check that GG extract is running
		./ggsci >> $vOutputLog << EOF
start mgr
exit
EOF

		sleep 15
		echo "" | tee -a $vOutputLog
		echo "Checking the status of the manager" | tee -a $vOutputLog
		while true
		do
			# Check the GG status
			./ggsci > $vExtStatus << EOF
info all
exit
EOF

			vGGStatus=$(cat $vExtStatus | grep MANAGER | awk '{ print $2}')
			if [[ $vGGStatus = "ABENDED" || $vGGStatus = "STOPPED" ]]
			then
				echo "" | tee -a $vOutputLog
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
				echo "The GG manger could not be started" | tee -a $vOutputLog
				echo "Please start this manually before continuing" | tee -a $vOutputLog
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
				exit 1
			elif [[ $vGGStatus = "RUNNING" ]]
			then
				echo "SUCCESS: The GG manager is running." | tee -a $vOutputLog
				break
			fi
			echo "Waiting 30 seconds..." | tee -a $vOutputLog
			sleep 30
		done
	else
		echo "" | tee -a $vOutputLog
		echo "The GG manager is running." | tee -a $vOutputLog
	fi
}

############################ GoldenGate Process Check ########################
# PURPOSE:                                                                   #
# This function checks the status of a GG process.                           #
##############################################################################

function restart_fnc {
	echo "" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	echo "* Checking abended processes    *" | tee -a $vOutputLog
	echo "*********************************" | tee -a $vOutputLog
	
	# set variables
	vExtStatus="${GGATE}/dirout/extract_status.out"
	vGGStatusOut="${GGATE}/dirout/GGExtractStatus_All.out"
	rm $vExtStatus
	rm $vGGStatusOut
	
	# put proc statuses into file
	cd $GGATE
	./ggsci > $vExtStatus << EOF
info all
exit
EOF

	# check for abended processes
	vExtProcs=$(cat $vExtStatus | grep EXTRACT | grep -E "ABENDED" | awk '{ print $3}')
	
	# try to restart processes
	for procname in ${vExtProcs[@]}
	do
		# Check that GG extract is running
		./ggsci >> $vOutputLog << EOF
start extract $procname
exit
EOF

		echo "" | tee -a $vOutputLog
		echo "Checking the status of $procname" | tee -a $vOutputLog
	
		sleep 15
		while true
		do
			# Check the GG status
			./ggsci > $vGGStatusOut << EOF
info all
exit
EOF

			vGGStatus=$(cat $vGGStatusOut | grep $procname | awk '{ print $2}')
			if [[ $vGGStatus = "ABENDED" ]]
			then
				echo "" | tee -a $vOutputLog
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  | tee -a $vOutputLog
				echo "The GG process $procname is $vGGStatus."  | tee -a $vOutputLog
				view_report_fnc $procname
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vOutputLog
				break
			elif [[ $vGGStatus = "RUNNING" ]]
			then
				echo "SUCCESS: The GG process $procname is $vGGStatus."| tee -a $vOutputLog
				break
			fi
			echo "Waiting 30 seconds..." | tee -a $vOutputLog
			sleep 30
		done
	done
}

#####################################################################
# PURPOSE:                                                          #
# MAIN PROGRAM EXECUTION BEGINS HERE.                               #
#####################################################################

# set goldengate home
if [[ -d $GGATE11 ]]
then
	export GGATE=$GGATE11
	echo "" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	echo "Setting GoldenGate Home: $GGATE" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	
	# make sure manager is running
	restart_mgr_fnc
	# run restart function
	restart_fnc
fi

# run for 12c home if different
if [[ $GGATE12 != $GGATE11 ]]
then
	export GGATE=$GGATE12
	echo "" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	echo "Setting GoldenGate Home: $GGATE" | tee -a $vOutputLog
	echo "*******************************************************" | tee -a $vOutputLog
	# make sure manager is running
	restart_mgr_fnc
	# run restart function
	restart_fnc
fi
