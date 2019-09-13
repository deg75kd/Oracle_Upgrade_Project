#!/bin/bash
# install GG on source Linux

#initilaize varibles
NOWwSECs=$(date '+%Y%m%d%H%M%S')
export ORACLE_BASE="/app/oracle/product"
vHome12c="${ORACLE_BASE}/db/12c/1"
vHome11g="${ORACLE_BASE}/db/11g/1"
ScriptDir="/app/oracle/scripts"
UpgradeDir="${ScriptDir}/12cupgrade"
ScriptBase=$(basename $0 | awk -F. '{ print ($1)}')
LogDir="${UpgradeDir}/logs"
OUTPUTLOG="${LogDir}/${ScriptBase}_${NOWwSECs}.log"
HOST=`hostname | tr 'A-Z' 'a-z'`

# GG variables
export GGATEBASE="${ORACLE_BASE}/ggate"
vGG12c="${GGATEBASE}/12c/1"
vGG11g="${GGATEBASE}/11g/1"
MGRPRMTEMP="${UpgradeDir}/mgr.prm"
GGMGROUT="${LogDir}/${ScriptBase}.out"
GGEXTDIR="/oragg/trail"
GGHOSTEXTDIR="/oraggrep/trail"

# software variables
SoftwareMnt="/mnt/ora-sftwr-repo"
SoftwareLoc="${SoftwareMnt}/GoldenGate/LINUX64/fbo_ggs_Linux_x64_shiphome"
#SoftwareLoc="/tmp/fbo_ggs_Linux_x64_shiphome"
#SoftwareZip="${SoftwareLoc}/fbo_ggs_AIX_ppc_shiphome.zip"
Install_LOC="${SoftwareLoc}/Disk1"

############################ Trap Function ###################################
# PURPOSE:                                                                   #
# This function writes appropirate message based on how script exits.        #
##############################################################################

function trap_fnc {
	if [[ $vExitCode -eq 0 ]]
	then
		echo "COMPLETE" | tee -a $OUTPUTLOG
	elif [[ $vExitCode -eq 2 ]]
	then
		echo "Exiting at user's request" | tee -a $OUTPUTLOG
	else
		vBgProcCt=$(jobs | wc -l)
		if [[ $vBgProcCt -gt 0 ]]
		then
			kill $(jobs -p)
		fi
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $OUTPUTLOG
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
	fi
}

############################ Pre-Check Function ##############################
# PURPOSE:                                                                   #
# This function checks for prerequisites.                                    #
##############################################################################

function precheck_fnc {
	# check directories
	echo "" | tee -a $OUTPUTLOG
	echo "Checking required files and directories" | tee -a $OUTPUTLOG
	
	# check Oracle base directory
	if [[ ! -d $ORACLE_BASE ]]
	then
		echo "ERROR: The required directory $ORACLE_BASE does not exit!" | tee -a $OUTPUTLOG
		exit 1
	else
		echo "The directory $ORACLE_BASE is here." | tee -a $OUTPUTLOG
	fi
	
	# check script/log directories and create if missing
	if [[ ! -d ${ScriptDir} ]]
	then
		echo "Creating log directory $ScriptDir" | tee -a $OUTPUTLOG
		mkdir $ScriptDir
		if [[ $? -eq 0 ]]
		then
			echo "Directory $ScriptDir was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory $ScriptDir" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo "Directory $ScriptDir is here." | tee -a $OUTPUTLOG
	fi
	if [[ ! -d ${UpgradeDir} ]]
	then
		echo "Creating directory $UpgradeDir" | tee -a $OUTPUTLOG
		mkdir $UpgradeDir
		if [[ $? -eq 0 ]]
		then
			echo "Directory $UpgradeDir was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory $UpgradeDir" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo "Directory $UpgradeDir is here." | tee -a $OUTPUTLOG
	fi
	if [[ ! -d ${LogDir} ]]
	then
		echo "Creating directory $LogDir" | tee -a $OUTPUTLOG
		mkdir $LogDir
		if [[ $? -eq 0 ]]
		then
			echo "Directory $LogDir was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory $LogDir" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo "Directory $LogDir is here." | tee -a $OUTPUTLOG
	fi

	# check response file
	if [[ ! -f $ResponseFile ]]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "ERROR: The response file $ResponseFile does not exit!" | tee -a $OUTPUTLOG
		exit 1
	else
		echo "" | tee -a $OUTPUTLOG
		echo "The response file $ResponseFile is here." | tee -a $OUTPUTLOG
	fi
	
#	# mount software NFS
	if [[ ! -d $SoftwareMnt ]]
	then
		echo ""  | tee -a $OUTPUTLOG
		echo "Mounting the software location $SoftwareMnt" | tee -a $OUTPUTLOG
		sudo mount $SoftwareMnt
		if [[ $? -ne 0 ]]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "ERROR: Could not mount $SoftwareMnt!" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo ""  | tee -a $OUTPUTLOG
		echo "The software mount $SoftwareMnt is available." | tee -a $OUTPUTLOG
	fi
	
	# check directory
	if [[ ! -d $SoftwareLoc ]]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "ERROR: The software directory $SoftwareLoc does not exit!" | tee -a $OUTPUTLOG
		exit 1
	else
		echo "The software directory $SoftwareLoc is here." | tee -a $OUTPUTLOG
	fi
	
	# create direcoties
	echo "" | tee -a $OUTPUTLOG
	echo "Creating directories" | tee -a $OUTPUTLOG
	if [[ ! -d ${GGATEBASE} ]]
	then
		mkdir $GGATEBASE
		if [[ $? -eq 0 ]]
		then
			echo "Directory $GGATEBASE was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory $GGATEBASE" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo "Directory $GGATEBASE is here." | tee -a $OUTPUTLOG
	fi
	if [[ $vDBVersion = 12c && ! -d ${GGATEBASE}/12c ]]
	then
		mkdir ${GGATEBASE}/12c
		if [[ $? -eq 0 ]]
		then
			echo "Directory ${GGATEBASE}/12c was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory ${GGATEBASE}/12c" | tee -a $OUTPUTLOG
			exit 1
		fi
	elif [[ $vDBVersion = 11g && ! -d ${GGATEBASE}/11g ]]
	then
		mkdir ${GGATEBASE}/11g
		if [[ $? -eq 0 ]]
		then
			echo "Directory ${GGATEBASE}/11g was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory ${GGATEBASE}/11g" | tee -a $OUTPUTLOG
			exit 1
		fi
	fi
	if [[ ! -d ${GGATE} ]]
	then
		mkdir $GGATE
		if [[ $? -eq 0 ]]
		then
			echo "Directory $GGATE was created." | tee -a $OUTPUTLOG
		else
			echo "ERROR: Not able to create directory $GGATE" | tee -a $OUTPUTLOG
			exit 1
		fi
	else
		echo "Directory $GGATE is here." | tee -a $OUTPUTLOG
	fi
}

############################ Install Function ################################
# PURPOSE:                                                                   #
# This function installs GoldenGate.                                         #
##############################################################################

function install_fnc {
	# unzip archive
	#echo "" | tee -a $OUTPUTLOG
	#echo "Unzipping binaries" | tee -a $OUTPUTLOG
	#cd $GGATE
	#unzip ${SoftwareLoc}/fbo_ggs_AIX_ppc_shiphome.zip
	
	# run silent installation
	echo "" | tee -a $OUTPUTLOG
	echo "Running GoldenGate installation in silent mode" | tee -a $OUTPUTLOG
	cd $Install_LOC
	./runInstaller -silent -responseFile $ResponseFile >> $OUTPUTLOG
	if [ $? -ne 0 ]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "ERROR:" | tee -a $OUTPUTLOG
		echo "Failed to install GoldenGate." | tee -a $OUTPUTLOG
		exit 1
	fi
	sleep 120

	# create links
	if [[ $vDBVersion = 11g ]]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "Creating symbolic links" | tee -a $OUTPUTLOG
		cd $GGATE
		ln -s $ORACLE_HOME/lib/libclntsh.so libclntsh.so
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "WARNING:" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link for libclntsh.so" | tee -a $OUTPUTLOG
			echo "GoldenGate may not function properly. Please check the Oracle installation in $ORACLE_HOME." | tee -a $OUTPUTLOG
		fi
		ln -s $ORACLE_HOME/lib/libclntsh.so.11.1 libclntsh.so.11.1
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "WARNING:" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link for libclntsh.so.11.1" | tee -a $OUTPUTLOG
			echo "GoldenGate may not function properly. Please check the Oracle installation in $ORACLE_HOME." | tee -a $OUTPUTLOG
		fi
		ln -s $ORACLE_HOME/lib/libnnz11.so libnnz11.so
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "WARNING:" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link for libnnz11.so" | tee -a $OUTPUTLOG
			echo "GoldenGate may not function properly. Please check the Oracle installation in $ORACLE_HOME." | tee -a $OUTPUTLOG
		fi
	else
		echo "" | tee -a $OUTPUTLOG
		echo "Creating symbolic links" | tee -a $OUTPUTLOG
		cd $GGATE
		ln -s ${ORACLE_BASE}/client/12c/1/lib/libclntsh.so.12.1 libclntsh.so.12.1
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "WARNING:" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link for libclntsh.so.12.1" | tee -a $OUTPUTLOG
			echo "GoldenGate may not function properly. Please check the Oracle installation in ${ORACLE_BASE}/client/12c/1." | tee -a $OUTPUTLOG
		fi
		ln -s ${ORACLE_BASE}/client/12c/1/lib/libnnz12.so libnnz12.so
		if [ $? -ne 0 ]
		then
			echo "" | tee -a $OUTPUTLOG
			echo "WARNING:" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link for libnnz12.so" | tee -a $OUTPUTLOG
			echo "GoldenGate may not function properly. Please check the Oracle installation in ${ORACLE_BASE}/client/12c/1." | tee -a $OUTPUTLOG
		fi
	fi
	
	# create manager parameter file
	echo "" | tee -a $OUTPUTLOG
	echo "Building manager parameter file" | tee -a $OUTPUTLOG
	echo "-- Manager configuration file" > $MGRPRMTEMP
	echo "--TCPIP port on which manager listens" >> $MGRPRMTEMP
	if [[ $vDBVersion = 12c ]]
	then
		echo "port 7819" >> $MGRPRMTEMP
		echo "--Dynamic range of ports that Manager can allocate" >> $MGRPRMTEMP
		echo "DYNAMICPORTLIST  7820-7870" >> $MGRPRMTEMP
	else
		echo "port 7919" >> $MGRPRMTEMP
		echo "--Dynamic range of ports that Manager can allocate" >> $MGRPRMTEMP
		echo "DYNAMICPORTLIST  7871-7920" >> $MGRPRMTEMP
	fi
	echo "-- Use LAGINFOSECONDS, LAGINFOMINUTES, or LAGINFOHOURS to specify how often to report lag information to the error log." >> $MGRPRMTEMP
	echo "LAGINFOHOURS 10" >> $MGRPRMTEMP
	echo "-- Use LAGREPORTMINUTES and LAGREPORTHOURS to specify the interval at which Manager checks for Extract and Replicat lag." >> $MGRPRMTEMP
	echo "LAGREPORTHOURS 1" >> $MGRPRMTEMP
	echo "" >> $MGRPRMTEMP
	echo "PURGEOLDEXTRACTS ${DIRDAT}/*, MINKEEPDAYS 30, USECHECKPOINTS" >> $MGRPRMTEMP
	echo "" >> $MGRPRMTEMP
	# echo "AUTOSTART EXTRACT E*" >> $MGRPRMTEMP
	# echo "AUTOSTART EXTRACT P*" >> $MGRPRMTEMP
	# echo "AUTOSTART EXTRACT R*" >> $MGRPRMTEMP
	echo "" >> $MGRPRMTEMP
	echo "AUTORESTART EXTRACT E* , RETRIES 6, WAITMINUTES 5, RESETMINUTES 60" >> $MGRPRMTEMP
	echo "AUTORESTART EXTRACT P* , RETRIES 6, WAITMINUTES 5, RESETMINUTES 60" >> $MGRPRMTEMP
	echo "AUTORESTART EXTRACT R* , RETRIES 6, WAITMINUTES 5, RESETMINUTES 60" >> $MGRPRMTEMP

	# create globals parameter file
	echo "GGSCHEMA ggs" > $vGlobals

	# start GG manager
	echo "" | tee -a $OUTPUTLOG
	echo "Starting GoldenGate Manager" | tee -a $OUTPUTLOG
	cd $GGATE
	./ggsci >> $OUTPUTLOG << EOF
CREATE SUBDIRS
sh mv $MGRPRMTEMP $MGRPRM
START MANAGER
exit
EOF

	sleep 30
	
	# Check that GG manager is running
	echo "" | tee -a $OUTPUTLOG
	echo "Checking that GG is running" | tee -a $OUTPUTLOG
	./ggsci > $GGMGROUT << EOF
info mgr
exit
EOF

	#sleep 10
	
	GGMGRSTATUS=$(cat $GGMGROUT | grep "Manager" | awk '{ print $3}')
	if [[ $GGMGRSTATUS != "running" ]]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "The $vDBVersion GoldenGate manager is $GGMGRSTATUS. Please fix before continuing." | tee -a $OUTPUTLOG
		exit 1
	else
		echo "" | tee -a $OUTPUTLOG
		echo "The $vDBVersion GoldenGate manager is $GGMGRSTATUS." | tee -a $OUTPUTLOG
	fi
	
	#sleep 10

	# change data directory to NFS mount if installing on lxogg host
	if [[ $HOST = lxoggm01 || $HOST = lxoggp01 ]]
	then
		rm -r $DIRDAT
		if [ $? -ne 0 ]
		then
			echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
			echo "Could not remove $DIRDAT!" | tee -a $OUTPUTLOG
			echo "You have to create a symbolic link from $DIRDAT to $GGHOSTEXTDIR before you run the GG script against any databases." | tee -a $OUTPUTLOG
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
		fi
		ln -s -f $GGHOSTEXTDIR $DIRDAT
		if [ $? -ne 0 ]
		then
			echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link from $DIRDAT to $GGHOSTEXTDIR" | tee -a $OUTPUTLOG
			echo "You have to create this link before you run the GG script against any databases." | tee -a $OUTPUTLOG
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
		fi
	else
		rm -r $DIRDAT
		if [ $? -ne 0 ]
		then
			echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
			echo "Could not remove $DIRDAT!" | tee -a $OUTPUTLOG
			echo "You have to create a symbolic link from $DIRDAT to $GGEXTDIR before you run the GG script against any databases." | tee -a $OUTPUTLOG
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
		fi
		ln -s -f $GGEXTDIR $DIRDAT
		if [ $? -ne 0 ]
		then
			echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
			echo "Could not create the symbolic link from $DIRDAT to $GGEXTDIR" | tee -a $OUTPUTLOG
			echo "You have to create this link before you run the GG script against any databases." | tee -a $OUTPUTLOG
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
		fi
	fi
}

############################ Prompt Function #################################
# PURPOSE:                                                                   #
# This function prompts the user for input.                                  #
##############################################################################

function prompt_fnc {
	# Prompt for version
	echo ""
	echo "Select the database version you wish to install:"
	echo "  (a) 12c"
	echo "  (b) 11g"
	echo "  (c) Both"
	while true
	do
		read vReadVersion
		if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
		then
			# set Oracle home
			export ORACLE_HOME=$vHome12c
			export GGATE=$vGG12c
			ResponseFile="${UpgradeDir}/oggcore.rsp"
			vGlobals="${GGATE}/GLOBALS"
			MGRPRM="${GGATE}/dirprm/mgr.prm"
			DIRDAT="${GGATE}/dirdat"
			vDBVersion=12c
			echo "You have selected Oracle version 12c" | tee -a $OUTPUTLOG
			echo "The Oracle Home has been set to $ORACLE_HOME" | tee -a $OUTPUTLOG
			echo "The GoldenGate Home has been set to $GGATE" | tee -a $OUTPUTLOG
			precheck_fnc
			install_fnc
			break
		elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
		then
			# set Oracle home
			export ORACLE_HOME=$vHome11g
			export GGATE=$vGG11g
			ResponseFile="${UpgradeDir}/oggcore_11g.rsp"
			vGlobals="${GGATE}/GLOBALS"
			MGRPRM="${GGATE}/dirprm/mgr.prm"
			DIRDAT="${GGATE}/dirdat"
			vDBVersion=11g
			echo "You have selected Oracle version 11g" | tee -a $OUTPUTLOG
			echo "The Oracle Home has been set to $ORACLE_HOME" | tee -a $OUTPUTLOG
			echo "The GoldenGate Home has been set to $GGATE" | tee -a $OUTPUTLOG
			precheck_fnc
			install_fnc
			break
		elif [[ "$vReadVersion" == "C" || "$vReadVersion" == "c" ]]
		then
			# Install 12c version
			export ORACLE_HOME=$vHome12c
			export GGATE=$vGG12c
			ResponseFile="${UpgradeDir}/oggcore.rsp"
			vGlobals="${GGATE}/GLOBALS"
			MGRPRM="${GGATE}/dirprm/mgr.prm"
			DIRDAT="${GGATE}/dirdat"
			vDBVersion=12c
			echo "You have selected Oracle versions 11g and 12c" | tee -a $OUTPUTLOG
			echo "The Oracle Home has been set to $ORACLE_HOME" | tee -a $OUTPUTLOG
			echo "The GoldenGate Home has been set to $GGATE" | tee -a $OUTPUTLOG
			precheck_fnc
			install_fnc
			
			# Install 11g version
			export ORACLE_HOME=$vHome11g
			export GGATE=$vGG11g
			ResponseFile="${UpgradeDir}/oggcore_11g.rsp"
			vGlobals="${GGATE}/GLOBALS"
			MGRPRM="${GGATE}/dirprm/mgr.prm"
			DIRDAT="${GGATE}/dirdat"
			vDBVersion=11g
			# echo "You have selected Oracle version 11g" | tee -a $OUTPUTLOG
			echo "The Oracle Home has been set to $ORACLE_HOME" | tee -a $OUTPUTLOG
			echo "The GoldenGate Home has been set to $GGATE" | tee -a $OUTPUTLOG
			precheck_fnc
			install_fnc
			break
		else
			echo -e "Select a valid database version: \c"  
		fi
	done
	
}

#####################################################################
# PURPOSE:                                                          #
# MAIN PROGRAM EXECUTION BEGINS HERE.                               #
#####################################################################

# When this exits, exit all background process also.
trap 'vExitCode=$?; trap_fnc' EXIT

# call prompt function
prompt_fnc

echo "" | tee -a $OUTPUTLOG
echo "End of $0" | tee -a $OUTPUTLOG
#End of GG silent installation
