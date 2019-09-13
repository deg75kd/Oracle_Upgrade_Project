#!/usr/bin/ksh

# variables to set now
HOST=`hostname`
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vOutputDir=/nomove/app/oracle/scripts/12cupgrade/logs
OUTPUTLOG="${vOutputDir}/${vBaseName}.log"
DBLIST="${vOutputDir}/dblist_${HOST}.log"
vCharSetLog="${vOutputDir}/${vBaseName}_charset.log"
vDLRLog="${vOutputDir}/${vBaseName}_dataloss.log"

# delete old DB list
rm $OUTPUTLOG
rm $DBLIST

# list current databases on server
ps -eo args | grep ora_pmon_ | sed 's/ora_pmon_//' | grep -Ev "grep|sed" | sort > $DBLIST

# read DB list into array variable
set -A SIDLIST $(cat $DBLIST)
# uxd33
#set -A SIDLIST agtdmd awdd blcdwsd cigfdsd idwd portd62 prodd trmpd
# uxd34
#set -A SIDLIST abcinfod blctdmd cigtdmd nbdmtdmd vasd blcfdsd blcnavc blcnavd blcnavg cdsinfod custsvcd idmd lbilld opsd pbizd

# check space for each DB
for dbname in ${SIDLIST[@]}
do
	# set environment variables
	unset LIBPATH
	export ORACLE_SID=$dbname
	export ORAENV_ASK=NO
	export PATH=/usr/local/bin:$PATH
	. /usr/local/bin/oraenv
	export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
	export LIBPATH=$ORACLE_HOME/lib
	echo "================================" | tee -a $OUTPUTLOG
	print -- "Your Oracle Environment Settings:" | tee -a $OUTPUTLOG
  	print -- "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a $OUTPUTLOG
  	print -- "ORACLE_SID            = ${ORACLE_SID}" | tee -a $OUTPUTLOG
  	print -- "ORACLE_HOME           = ${ORACLE_HOME}" | tee -a $OUTPUTLOG
  	print -- "TNS_ADMIN             = ${TNS_ADMIN}" | tee -a $OUTPUTLOG
  	print -- "LD_LIBRARY_PATH       = ${LD_LIBRARY_PATH}" | tee -a $OUTPUTLOG
	print -- ""
	
	# get current scn
	sqlplus -S / as sysdba > $vCharSetLog <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select value from nls_database_parameters where parameter='NLS_CHARACTERSET';
exit;
EOF

	vCharSet=$(cat $vCharSetLog)
	echo "" | tee -a $OUTPUTLOG
	echo "Character set is $vCharSet" | tee -a $OUTPUTLOG
	
	# Run scripts in database
	if [[ $vCharSet != AL32UTF8 ]]
	then
		echo "" | tee -a $OUTPUTLOG
		echo "$ORACLE_SID is using $vCharSet" | tee -a $OUTPUTLOG
		$ORACLE_HOME/bin/sqlplus -s / as sysdba <<RUNSQL
SET SERVEROUTPUT ON SIZE 1000000
SET LINES 2500
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
spool $OUTPUTLOG append
drop user csmig cascade;
@?/rdbms/admin/csminst.sql
spool off
RUNSQL

		# run character set scan
		vCSScanLog="${vOutputDir}/csscan_${ORACLE_SID}"
		$ORACLE_HOME/bin/csscan \"/ as sysdba\" FULL=Y TOCHAR=AL32UTF8 LOG=$vCSScanLog CAPTURE=N ARRAY=1000000 PROCESS=4 | tee -a $OUTPUTLOG
		echo "" | tee -a $OUTPUTLOG
		echo "Logs written to $vCSScanLog" | tee -a $OUTPUTLOG
		
		# check for data loss
		sqlplus -S / as sysdba > $vDLRLog <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from csmig.csmv\$columns where DATA_LOSS_ROWS>0;
exit;
EOF

		vDataLossRows=$(cat $vDLRLog)
		echo "" | tee -a $OUTPUTLOG
		echo "There were $vDataLossRows rows or reported data loss." | tee -a $OUTPUTLOG
		# re-run csscan if data loss
		if [[ $vDataLossRows -gt 0 ]]
		then
			vCSScanLog="${vOutputDir}/csscan_${ORACLE_SID}_${vCharSet}"
			$ORACLE_HOME/bin/csscan \"/ as sysdba\" FULL=Y TOCHAR=$vCharSet LOG=$vCSScanLog CAPTURE=N ARRAY=1000000 PROCESS=4 | tee -a $OUTPUTLOG
			
			# check for data loss
			sqlplus -S / as sysdba > $vDLRLog <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select count(*) from csmig.csmv\$columns where DATA_LOSS_ROWS>0;
exit;
EOF

			vDataLossRows=$(cat $vDLRLog)
			if [[ $vDataLossRows -gt 0 ]]
			then
				echo "" | tee -a $OUTPUTLOG
				echo "Data loss still found for $ORACLE_SID using $vCharSet" | tee -a $OUTPUTLOG
				echo "Logs written to $vCSScanLog" | tee -a $OUTPUTLOG
			else
				echo "" | tee -a $OUTPUTLOG
				echo "Columns in $ORACLE_SID can be extended to accomodate conversion" | tee -a $OUTPUTLOG
			fi
		else
			echo "" | tee -a $OUTPUTLOG
			echo "No data loss found for $ORACLE_SID" | tee -a $OUTPUTLOG
		fi
	else
		echo "" | tee -a $OUTPUTLOG
		echo "Skipping $ORACLE_SID: using $vCharSet" | tee -a $OUTPUTLOG
	fi
done

echo ""
echo "See $OUTPUTLOG for log"

