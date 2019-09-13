#!/bin/bash
# install GG on source AIX

#initilaize varibles
NOWwSECs=$(date '+%Y%m%d%H%M%S')
export ORACLE_BASE="/nomove/app/oracle"
export ORACLE_HOME="${ORACLE_BASE}/db/11g/6"
ScriptDir="/nomove/app/oracle/scripts"
UpgradeDir="${ScriptDir}/12cupgrade"
ScriptBase=$(basename $0 | awk -F. '{ print ($1)}')
LogDir="${UpgradeDir}/logs"
OUTPUTLOG="${LogDir}/${ScriptBase}_${NOWwSECs}.log"

# GG variables
export GGATEBASE="${ORACLE_BASE}/ggate"
export GGATE="${GGATEBASE}/12c/1"
GGEXTDIR="/oragg/trail"
ResponseFile="${UpgradeDir}/oggcore.rsp"
DIRDAT="${GGATE}/dirdat"
MGRPRMTEMP="${UpgradeDir}/mgr.prm"
MGRPRM="${GGATE}/dirprm/mgr.prm"
GGMGROUT="${LogDir}/${ScriptBase}.out"
vGlobals="${GGATE}/GLOBALS"

# software variables
SoftwareMnt="/mnt/ora-sftwr-repo"
SoftwareLoc="${SoftwareMnt}/GoldenGate/AIX64"
SoftwareZip="${SoftwareLoc}/fbo_ggs_AIX_ppc_shiphome.zip"
Install_LOC=${GGATE}/fbo_ggs_AIX_ppc_shiphome/Disk1

# check directories
echo ""
echo "Checking required files and directories"

# check Oracle base directory
if [[ ! -d $ORACLE_BASE ]]
then
	echo "" | tee -a $OUTPUTLOG
	echo "ERROR: The required directory $ORACLE_BASE does not exit!" | tee -a $OUTPUTLOG
	exit 1
fi

# check script/log directories and create if missing
if [[ ! -d ${ScriptDir} ]]
then
	echo ""
	echo "Creating log directory $ScriptDir"
	mkdir $ScriptDir
fi
if [[ ! -d ${UpgradeDir} ]]
then
	echo ""
	echo "Creating log directory $UpgradeDir"
	mkdir $UpgradeDir
fi
if [[ ! -d ${LogDir} ]]
then
	echo ""
	echo "Creating log directory $LogDir"
	mkdir $LogDir
fi
rm $OUTPUTLOG

# check response file
if [[ ! -f $ResponseFile ]]
then
	echo "" | tee -a $OUTPUTLOG
	echo "ERROR: The response file $ResponseFile does not exit!" | tee -a $OUTPUTLOG
	exit 1
fi

# mount software NFS
if [[ ! -d $SoftwareMnt ]]
then
	sudo /usr/sbin/mount $SoftwareMnt
fi

# check directory
if [[ ! -d $SoftwareLoc ]]
then
	echo "" | tee -a $OUTPUTLOG
	echo "ERROR: The software directory $SoftwareLoc does not exit!" | tee -a $OUTPUTLOG
	exit 1
fi

# create direcoties
echo "" | tee -a $OUTPUTLOG
echo "Creating directories" | tee -a $OUTPUTLOG
mkdir $GGATEBASE
mkdir ${GGATEBASE}/12c
mkdir $GGATE

# unzip archive
echo "" | tee -a $OUTPUTLOG
echo "Unzipping binaries" | tee -a $OUTPUTLOG
cd $GGATE
unzip $SoftwareZip

# run silent installation
echo ""
echo "Running installation in silent mode"
cd $Install_LOC
./runInstaller -silent -responseFile $ResponseFile

sleep 120

# create links
echo ""
echo "Creating symbolic links"
cd $GGATE
ln -s $ORACLE_HOME/lib/libclntsh.so libclntsh.so
ln -s $ORACLE_HOME/lib/libnnz11.so libnnz11.so

# create manager parameter file
echo "" | tee -a $OUTPUTLOG
echo "Building manager parameter file" | tee -a $OUTPUTLOG
echo "-- Manager configuration file" > $MGRPRMTEMP
echo "--TCPIP port on which manager listens" >> $MGRPRMTEMP
echo "port 7819" >> $MGRPRMTEMP
echo "--Dynamic range of ports that Manager can allocate" >> $MGRPRMTEMP
echo "DYNAMICPORTLIST  7820-7920" >> $MGRPRMTEMP
echo "-- Use LAGINFOSECONDS, LAGINFOMINUTES, or LAGINFOHOURS to specify how often to report lag information to the error log." >> $MGRPRMTEMP
echo "LAGINFOHOURS 10" >> $MGRPRMTEMP
echo "-- Use LAGREPORTMINUTES and LAGREPORTHOURS to specify the interval at which Manager checks for Extract and Replicat lag." >> $MGRPRMTEMP
echo "LAGREPORTHOURS 1" >> $MGRPRMTEMP
echo "" >> $MGRPRMTEMP
echo "PURGEOLDEXTRACTS $DIRDAT/*, MINKEEPDAYS 30, USECHECKPOINTS" >> $MGRPRMTEMP
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
./ggsci > $OUTPUTLOG << EOF
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
	echo "The GoldenGate manager is $GGMGRSTATUS. Please fix before continuing." | tee -a $OUTPUTLOG
	exit 1
else
	echo "" | tee -a $OUTPUTLOG
	echo "The GoldenGate manager is $GGMGRSTATUS." | tee -a $OUTPUTLOG
fi

# change data directory to NFS mount
rm -r $DIRDAT
if [ $? -ne 0 ]
then
	echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
	echo "Could not remove $DIRDAT!" | tee -a $OUTPUTLOG
	echo "You have to create a symbolic link from $GGEXTDIR to $DIRDAT before you run the GG script against any databases." | tee -a $OUTPUTLOG
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
fi
ln -s -f $GGEXTDIR $DIRDAT
if [ $? -ne 0 ]
then
	echo "ERROR: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
	echo "Could not create the symbolic link from $GGEXTDIR to $DIRDAT" | tee -a $OUTPUTLOG
	echo "You have to create this link before you run the GG script against any databases." | tee -a $OUTPUTLOG
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $OUTPUTLOG
fi

echo "" | tee -a $OUTPUTLOG
echo "GoldenGate has been successfully installed." | tee -a $OUTPUTLOG
echo "End of $0" | tee -a $OUTPUTLOG
#End of GG silent installation
