#!/bin/ksh
#
#################################################################
#This script Verify the status of the following
#
# 1. Oracle Enterprise Manager Agent Service 
# 2. Oracle Listerner Service
# 3. Verify Number of Databases to be Running
# 3. List the Databases to be Running
# 4. Each Database connectivity & status is "OPEN"
#
#################################################################
# 
# ===============================================================
# Modification History
# ===============================================================
# 	Name		Date		Change
#	MRCB		12/22/2011	Created
#
# ===============================================================

ext=`uname -n`
ORATAB=/etc/oratab
DATESTAMP="`date '+%m%d%Y:%H:%M:%S'`"
LOG_DIR=/app/oracle/scripts/logs
#ORACLE_SCRIPT=/home/oracle/local/script
ORACLE_SCRIPT=/app/oracle/setenv
LOGFILE=$LOG_DIR/Oracle_DR_QUICK_Validation_${ext}_$DATESTAMP.log
ORATAB_SIDLIST=$LOG_DIR/oratab_sidlist.log
ORATAB_DBLIST=$LOG_DIR/oratab_dblist.log
PMON_SIDLIST=$LOG_DIR/pmon_sidlist.log
PMON_DBLIST=$LOG_DIR/pmon_dblist.log
rm -f $ORATAB_SIDLIST
rm -f $ORATAB_DBLIST
rm -f $PMON_SIDLIST
rm -f $PMON_DBLIST

echo "==================================================================================================="> ${LOGFILE}
echo "BEGIN ORACLE Validation on $ext - EMAGENT - LISTENER - DATABASES Status at `date`"		
echo "BEGIN ORACLE Validation on $ext - EMAGENT - LISTENER - DATABASES Status at `date`"	>> ${LOGFILE}
echo "===================================================================================================">> ${LOGFILE}

########################################################################################################
############################## Validate the EMAGENT STATUS ##################################
########################################################################################################

echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}
echo "BEGIN Validating the EMAGENT Status on $ext at `date`"
echo "BEGIN Validating the EMAGENT Status on $ext at `date`"			>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}

#EMAGENT_PROCESS=`ps -ef -o args | grep -v grep | grep /agent12c/core/12.1.0.3.0/jdk/bin/java | awk '{ print substr($1,19,length($1)) }'`
EMAGENT_PROCESS=`ps -ef | grep -v grep | grep /app/oracle/product/agent13c/agent_13.2.0.0.0/oracle_common/jdk/bin/java | awk '{ print $8 }'`

#EMPERL_PROCESS=`ps -ef -o args | grep -v grep | grep /agent12c/core/12.1.0.3.0/perl/bin/perl | awk '{ print substr($1,19,length($1)) }'`
EMPERL_PROCESS=`ps -ef | grep -v grep | grep /app/oracle/product/agent13c/agent_13.2.0.0.0/perl/bin/perl | awk '{ print $8 }'`

#if [[ ($EMAGENT_PROCESS = "/agent12c/core/12.1.0.3.0/jdk/bin/java") && ($EMPERL_PROCESS = "/agent12c/core/12.1.0.3.0/perl/bin/perl") ]] then
if [[ ($EMAGENT_PROCESS = "/app/oracle/product/agent13c/agent_13.2.0.0.0/oracle_common/jdk/bin/java") && ($EMPERL_PROCESS = "/app/oracle/product/agent13c/agent_13.2.0.0.0/perl/bin/perl") ]] then

echo "ORACLE EMAGENT STATUS on $ext at `date`  -->  EMAGENT IS UP"	
echo "ORACLE EMAGENT STATUS on $ext at `date`  -->  EMAGENT IS UP"			>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}

else if [[ ($EMAGENT_PROCESS = "") && ($EMPERL_PROCESS = "") ]] then

echo "ORACLE EMAGENT STATUS on $ext at `date`  -->  EMAGENT IS DOWN	& START THE EMAGENT"
echo "ORACLE EMAGENT STATUS on $ext at `date`  -->  EMAGENT IS DOWN	& START THE EMAGENT"	>> ${LOGFILE}
#echo "START EMAGENT --> "/nomove/app/oracle/agent12c/core/12.1.0.3.0/install/unix/scripts/agentstup start"" >> ${LOGFILE}
echo "START EMAGENT --> "/app/oracle/product/agent13c/agent_13.2.0.0.0/install/unix/scripts/agentstup start"" >> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}

	fi
fi

echo "END of EMAGENT Validation on $ext at `date`"	
echo "END of EMAGENT Validation on $ext at `date`"					>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}

########################################################################################################
################################### Validate the LISTENER STATUS #######################################
########################################################################################################

echo "BEGIN Validating the LISTENER Status on $ext at `date`"		
echo "====================================================================================">> ${LOGFILE}
echo "BEGIN Validating the LISTENER Status on $ext at `date`"					>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}

#. ${ORACLE_SCRIPT}/osetup.ksh -d 11ghome >> /dev/null ##>> ##$LOGFILE
. ${ORACLE_SCRIPT}/newdirosetup.sh -d LISTENER >> /dev/null

#LISTENER_HOME=`ps -ef -o args | grep -v grep | grep LISTENER | awk '{ print substr($1,1,length($1)) }'`
LISTENER_HOME=`ps -ef | grep -v grep | grep LISTENER | awk '{ print $8 }'`

#LISTENER_PROCESS=`ps -ef -o args | grep -v grep | grep LISTENER | awk '{ print substr($2,1,length($2)) }'`
LISTENER_PROCESS=`ps -ef | grep -v grep | grep LISTENER | awk '{ print $9 }'`

#if [[ ($LISTENER_HOME = "/nomove/app/oracle/db/11g/3/bin/tnslsnr") && ($LISTENER_PROCESS = "LISTENER") ]] then
if [[ ($LISTENER_HOME = "/app/oracle/product/db/12c/1/bin/tnslsnr") && ($LISTENER_PROCESS = "LISTENER") ]] then

#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/3 Home"
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/3 Home">> ${LOGFILE}
echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 12c/1 Home"
echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 12c/1 Home" >> ${LOGFILE}
echo "======================================================================================">> ${LOGFILE}

#else if [[ ($LISTENER_HOME = "/nomove/app/oracle/db/11g/4/bin/tnslsnr") && ($LISTENER_PROCESS = "LISTENER") ]] then
#
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/4 Home"	
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/4 Home">> ${LOGFILE}
#echo "======================================================================================">> ${LOGFILE}
#
#else if [[ ($LISTENER_HOME = "/nomove/app/oracle/db/11g/5/bin/tnslsnr") && ($LISTENER_PROCESS = "LISTENER") ]] then
#
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/5 Home"	
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 11g/5 Home">> ${LOGFILE}
#echo "======================================================================================">> ${LOGFILE}
#
#else if [[ ($LISTENER_HOME = "/nomove/app/oracle/db/10g/2/bin/tnslsnr") && ($LISTENER_PROCESS = "LISTENER") ]] then
#
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 10g Home"	
#echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS UP from 10g Home">> ${LOGFILE}
#echo "======================================================================================">> ${LOGFILE}

else if  [[ ($LISTENER_HOME = "") && ($LISTENER_PROCESS = "") ]] then

echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS DOWN"
echo "ORACLE LISTENER Status on $ext at `date`  -->  LISTENER IS DOWN"			 >> ${LOGFILE}
echo "SET ORACLE_HOME to 11g Home & START ORACLE LISTENER --> "lsnrctl start""
echo "SET ORACLE_HOME to 11g Home & START ORACLE LISTENER --> "lsnrctl start""		 >> ${LOGFILE}
echo "======================================================================================">> ${LOGFILE}

	fi

   	#fi

	#fi

   	#fi

fi

echo "END of LISTENER Validation on $ext at `date`"	
echo "END of LISTENER Validation on $ext at `date`"						>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}

########################################################################################################
################################### Validate DATABASE STATUS ###########################################
########################################################################################################

echo "====================================================================================" >> ${LOGFILE}
echo "BEGIN Validating the ORACLE DATABASES Status on $ext at `date`"            		 
echo "BEGIN Validating the ORACLE DATABASES Status on $ext at `date`"            		 >> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "Number of Databases Running on $ext : `ps -ef|grep pmon|grep -v grep|wc -l`"
echo "Number of Databases Running on $ext : `ps -ef|grep pmon|grep -v grep|wc -l`"	 	>> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}
#echo "`ps -ef -o args|grep -v grep|grep pmon|awk '{ print substr($1,10,length($1)) }'`"| sort
echo "`ps -ef | grep -v grep | grep pmon | awk '{ print substr($1,10,length($1)) }'`"| sort
ps -ef -o args|grep -v grep|grep pmon|awk '{ print substr($1,10,length($1)) }' | sort  >> ${LOGFILE}
ps -ef -o args|grep -v grep|grep pmon|awk '{ print substr($1,10,length($1)) }' | sort  > ${PMON_SIDLIST}
echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}
echo "List of Databases To be Running from ORATAB on $ext"							 
echo "List of Databases To be Running from ORATAB on $ext"					>> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}

cat ${ORATAB} | while read LINE
do
ORA_SID=`echo $LINE    | awk -F: '{print $1}' -`; export ORA_SID
AUTOSTART=`echo $LINE  | awk -F: '{print $3}' -`; export AUTOSTART
if [[ ${AUTOSTART} = "Y" ]] then
echo "$ORA_SID"
echo "$ORA_SID" >> ${LOGFILE}
echo "$ORA_SID" >> ${ORATAB_SIDLIST}

fi
done

echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "Databases To be Running from ORATAB on $ext : `cat $ORATAB_SIDLIST | wc -l`"
echo "Databases to be Running from oratab on $ext : `cat $ORATAB_SIDLIST | wc -l`">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}

echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "BEGIN Comparing the ORATAB & PMON Databases List"
echo "BEGIN Comparing the ORATAB & PMON Databases List"						>> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}

PMON_DB_COUNT="`cat $PMON_SIDLIST | sort | wc -l`"
ORATAB_DB_COUNT="`cat $ORATAB_SIDLIST | sort | wc -l`"

if [[ ${PMON_DB_COUNT} = ${ORATAB_DB_COUNT} ]] then

echo "====================================================================================	">> ${LOGFILE}
echo "Databases Running Count and ORATAB Database Count --> Matching"
echo "Databases Running Count and ORATAB Database Count --> Matching"			 	 >> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}

else

echo "====================================================================================	">> ${LOGFILE}
echo "Databses Running Count and ORATAB Database Count --> NOT Matching - Please Verify Missing Database(s)"
echo "Databses Running Count and ORATAB Database Count --> NOT Matching - Please Verify Missing Database(s)">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}
echo "Missing Databases List on $ext"								
echo "Missing Databases List on $ext"								>> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}

cat $PMON_SIDLIST | sort >> $PMON_DBLIST
cat $ORATAB_SIDLIST | sort >> $ORATAB_DBLIST
diff $PMON_DBLIST $ORATAB_DBLIST
diff $PMON_DBLIST $ORATAB_DBLIST									>> ${LOGFILE}

fi

echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}
echo "END Comparing the ORATAB & PMON Databases List"
echo "END Comparing the ORATAB & PMON Databases List"						>> ${LOGFILE}
echo "====================================================================================	">> ${LOGFILE}

cat ${ORATAB} | while read LINE
do

  ORA_SID=`echo $LINE    | awk -F: '{print $1}' -`; export ORA_SID
  ORA_HOME=`echo $LINE   | awk -F: '{print $2}' -`; export ORA_HOME
  AUTOSTART=`echo $LINE  | awk -F: '{print $3}' -`; export AUTOSTART

if [[ ${AUTOSTART} = "Y" ]] then

#. ${ORACLE_SCRIPT}/osetup.ksh -d ${ORA_SID} >> /dev/null
. ${ORACLE_SCRIPT}/newdirosetup.sh -d ${ORA_SID} >> /dev/null
echo "                                                                 		   	">> ${LOGFILE}
echo "====================================================================================" >> ${LOGFILE}
echo "Validating the Database ${ORACLE_SID} - ${ORACLE_HOME} at `date`"  			 >> ${LOGFILE}
echo "====================================================================================" >> ${LOGFILE}
DBSTATUS=`sqlplus -s /nolog <<EOF 
connect / as sysdba
set heading off
select status from v\\\$instance;
exit
EOF`
echo "Database ${ORACLE_SID} - ${ORACLE_HOME} STATUS at `date`" : $DBSTATUS
echo "Database ${ORACLE_SID} - ${ORACLE_HOME} STATUS at `date`" : $DBSTATUS  		 >> ${LOGFILE}
echo "====================================================================================" >> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}
fi
done

echo "====================================================================================" >> ${LOGFILE}
echo "END of Databases(s) Validation on $ext at `date`"	
echo "END of Databases(s) Validation on $ext at `date`"						>> ${LOGFILE}
echo "====================================================================================">> ${LOGFILE}
echo "                                                                 		   	">> ${LOGFILE}

echo "===================================================================================================">> ${LOGFILE}
echo "END of ORACLE Validation on $ext - EMAGENT - LISTENER - DATABASES Status at `date`"
echo "Check the Validation Status Details in the log file - $LOGFILE."
echo "END of ORACLE Validation on $ext - EMAGENT - LISTENER - DATABASES Status at `date`"	>> ${LOGFILE}
echo "Check the Validation Status Details in the log file - $LOGFILE."					>> ${LOGFILE}
echo "===================================================================================================">> ${LOGFILE}
