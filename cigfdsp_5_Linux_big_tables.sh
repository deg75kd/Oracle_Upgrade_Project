#!/usr/bin/bash
#================================================================================================#
#  NAME
#    cigfdsp_5_Linux_big_tables.sh
#
#  SPECS
#    uxp33
#    LXORAODSP04
#    11g
#    US7ASCII
#    Encrypted
#================================================================================================#

############################ Oracle Constants ############################
export ORACLE_BASE="/app/oracle/product"
export TNS_ADMIN=/app/oracle/tns_admin
vHome11g=/app/oracle/product/db/11g/1
export ORACLE_HOME=$vHome11g

############################ Script Constants ############################
vScriptDir="/app/oracle/scripts/12cupgrade"
vEnvScriptDir="/app/oracle/setenv"
vProfile="/home/oracle/.bash_profile"
vHostName=$(hostname)

NOWwSECs=$(date '+%Y%m%d%H%M%S')
vStartSec=$(date '+%s')

# AIX database link name
vAIXlink="CIGFDSP_AIX"

# big table comparison tables
vRowTable="ggtest.big_row_count_aix@${vAIXlink}"
vLinuxRowTable="ggtest.big_row_count_linux"

### add constraint check ###
vConstraintTable="ggtest.constraint_count_aix"
vLinuxConstraintTable="ggtest.constraint_count_linux"

# array of acceptable Oracle errors
vErrIgnore+=(ORA-02011)         # ORA-02011: duplicate database link name
vErrIgnore+=(ORA-02275)         # ORA-02275: such a referential constraint already exists in the table


############################ Trap Function ###################################
# PURPOSE:                                                                   #
# This function writes appropirate message based on how script exits.        #
##############################################################################

function trap_fnc {
	if [[ $vExitCode -eq 0 ]]
	then
		echo "COMPLETE" | tee -a $vFullLog
	elif [[ $vExitCode -eq 2 ]]
	then
		echo "Exiting at user's request" | tee -a $vFullLog
	else
		vBgProcCt=$(jobs | wc -l)
		if [[ $vBgProcCt -gt 0 ]]
		then
			kill $(jobs -p)
		fi
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vFullLog
		echo "!!!!!!CRITICAL ERROR!!!!!!" | tee -a $vFullLog
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a $vFullLog
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

	# copy Oracle and bash errors from log file to error log
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

#####################################################################
# PURPOSE:                                                          #
# MAIN PROGRAM EXECUTION BEGINS HERE.                               #
#####################################################################

# When this exits, exit all background process also.
trap 'vExitCode=$?; trap_fnc' EXIT
unset TWO_TASK

############################ Prompts ############################

# call parameter file
source cigfdsp_5_Linux_big_tables.param

# Prompt for new DB name
# echo ""
# echo -e "Enter the new database name: \c"  
# while true
# do
	# read vNewDB
	# if [[ -n "$vNewDB" ]]
	# then
		vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
		# echo "The new database name is $vPDBName"
		# break
	# else
		# echo -e "Enter a valid database name: \c"  
	# fi
# done

# Prompt for AIX host
# echo ""
# echo -e "Enter the AIX host of the source database: \c"  
# while true
# do
	# read vAIXHost
	# if [[ -n "$vAIXHost" ]]
	# then
		# echo "The AIX host is $vAIXHost"
		# break
	# else
		# echo -e "Enter a valid host name: \c"  
	# fi
# done

# Prompt for the SYSTEM password
# while true
# do
	# echo ""
	# echo -e "Enter the SYSTEM password for the AIX version of this database:"
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

############################ Set log names ############################

# set output log names
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
vLogDir="${vScriptDir}/logs"
vFullLog="${vLogDir}/${vBaseName}_${vPDBName}_${NOWwSECs}.log"
vOutputLog="${vLogDir}/${vBaseName}_${vPDBName}_section.log"
vErrorLog="${vLogDir}/${vBaseName}_${vPDBName}_err.log"
vCritLog="${vLogDir}/${vBaseName}_${vPDBName}_crit.log"

# removing existing logs
if [ -f $vFullLog ]
then
	rm $vFullLog
fi
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
touch $vFullLog
touch $vOutputLog
touch $vErrorLog
touch $vCritLog

# set trigger script names
vEnableTrigger="${vLogDir}/${vPDBName}_enable_trigger.sql"
vDisableTrigger="${vLogDir}/${vPDBName}_disable_trigger.sql"

# Create log directory if they do not exist
if [ ! -d $vLogDir ]
then
	echo "Making directory $vLogDir"
	mkdir $vLogDir
	if [ $? -ne 0 ]
	then
		echo "ERROR: There was an error creating $vLogDir!"
		exit 1
	fi
fi

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
vGawkCmd="$vGawkCmd/' $vErrorLog > $vCritLog"
# echo $vGawkCmd | tee -a $vOutputLog

############################ Confirmation ############################

# Display user entries
sleep 10
echo "" | tee -a $vOutputLog
echo "*******************************************************" | tee -a $vOutputLog
echo "Today is `date`"  | tee -a $vOutputLog
echo "You have entered the following values:"
echo "Database Name:        $vPDBName" | tee -a $vOutputLog
echo "AIX Host:             $vAIXHost" | tee -a $vOutputLog
echo "Oracle Home:          $ORACLE_HOME" | tee -a $vOutputLog
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
		# echo "Proceeding with the script..." | tee -a $vOutputLog
		# break
	# elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	# then
		# exit 2
	# else
		# echo -e "Please enter (Y) or (N).\c"  
	# fi
# done
cat $vOutputLog >> $vFullLog
rm $vOutputLog

############################ Set host variables ############################
export ORACLE_SID=$vPDBName
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
vDBVersion=11
echo $ORACLE_SID

echo "" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog
echo "* Loading big tables               *" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET TIMING OFF
SET ECHO ON
SET DEFINE ON
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET LINES 200
SET PAGES 0
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SET HEAD OFF
SET FEEDBACK OFF
PROMPT +++++++++++++++++ DISABLE TRIGGERS +++++++++++++++++
SPOOL $vEnableTrigger
SELECT 'ALTER TRIGGER '||dt.owner||'.'||dt.trigger_name||' ENABLE;'
FROM dba_triggers dt
WHERE dt.owner in ('BLC_EAPP_GTWY','FISERV_GTWY','STG');
SPOOL OFF

SPOOL $vDisableTrigger
SELECT 'ALTER TRIGGER '||dt.owner||'.'||dt.trigger_name||' DISABLE;'
FROM dba_triggers dt
WHERE dt.owner in ('BLC_EAPP_GTWY','FISERV_GTWY','STG');
SPOOL OFF

SPOOL $vOutputLog APPEND
@$vDisableTrigger

SET PAGES 1000
SET TIMING ON
SET HEAD ON
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
-- *** Set up database link ***
CREATE PUBLIC DATABASE LINK ${vAIXlink} 
CONNECT TO system IDENTIFIED BY $vSystemPwd
USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = ${vAIXHost}.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SID = cigfdsp)))';

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
PROMPT *** Loading BLC_EAPP_GTWY.APP_EMP_DTL_FORM ***
-- populate updates to BLC_EAPP_GTWY.APP_EMP_DTL_FORM
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'BLC_EAPP_GTWY.APP_EMP_DTL_FORM'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(APP_EMP_DTL_FORM_ID)
    INTO
        V_ID
    FROM
        BLC_EAPP_GTWY.APP_EMP_DTL_FORM;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;

    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            BLC_EAPP_GTWY.APP_EMP_DTL_FORM
        WHERE
            APP_EMP_DTL_FORM_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO BLC_EAPP_GTWY.APP_EMP_DTL_FORM
        (
            APP_EMP_DTL_FORM_ID
          , APP_FORM_ID
          , APP_EMP_DTL_ID
          , FORM
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , DOC_ID
          , APP_FILE_TYP_ID
        )
        SELECT
            APP_EMP_DTL_FORM_ID
          , APP_FORM_ID
          , APP_EMP_DTL_ID
          , FORM
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , DOC_ID
          , APP_FILE_TYP_ID
        FROM
            BLC_EAPP_GTWY.APP_EMP_DTL_FORM@${vAIXlink}
        WHERE
            APP_EMP_DTL_FORM_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO BLC_EAPP_GTWY.APP_EMP_DTL_FORM
    (
        APP_EMP_DTL_FORM_ID
      , APP_FORM_ID
      , APP_EMP_DTL_ID
      , FORM
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , DOC_ID
      , APP_FILE_TYP_ID
    )
    SELECT
        APP_EMP_DTL_FORM_ID
      , APP_FORM_ID
      , APP_EMP_DTL_ID
      , FORM
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , DOC_ID
      , APP_FILE_TYP_ID
    FROM
        BLC_EAPP_GTWY.APP_EMP_DTL_FORM@${vAIXlink}
    WHERE
        APP_EMP_DTL_FORM_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('BLC_EAPP_GTWY.APP_EMP_DTL_FORM is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading BLC_EAPP_GTWY.APP_PAYLD ***
-- populate updates to BLC_EAPP_GTWY.APP_PAYLD
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'BLC_EAPP_GTWY.APP_PAYLD'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(APP_PAYLD_ID)
    INTO
        V_ID
    FROM
        BLC_EAPP_GTWY.APP_PAYLD;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            BLC_EAPP_GTWY.APP_PAYLD
        WHERE
            APP_PAYLD_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO BLC_EAPP_GTWY.APP_PAYLD
        (
            APP_PAYLD_ID
          , PAYLD
          , APP_EMP_DTL_ID
          , APP_GRP_STAT_ID
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        )
        SELECT
            APP_PAYLD_ID
          , PAYLD
          , APP_EMP_DTL_ID
          , APP_GRP_STAT_ID
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        FROM
            BLC_EAPP_GTWY.APP_PAYLD@${vAIXlink}
        WHERE
            APP_PAYLD_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO BLC_EAPP_GTWY.APP_PAYLD
    (
        APP_PAYLD_ID
      , PAYLD
      , APP_EMP_DTL_ID
      , APP_GRP_STAT_ID
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    )
    SELECT
        APP_PAYLD_ID
      , PAYLD
      , APP_EMP_DTL_ID
      , APP_GRP_STAT_ID
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    FROM
        BLC_EAPP_GTWY.APP_PAYLD@${vAIXlink}
    WHERE
        APP_PAYLD_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('BLC_EAPP_GTWY.APP_PAYLD is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading FISERV_GTWY.APP_EMP_DTL_FORM ***
-- populate updates to FISERV_GTWY.APP_EMP_DTL_FORM
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'FISERV_GTWY.APP_EMP_DTL_FORM'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(APP_EMP_DTL_FORM_ID)
    INTO
        V_ID
    FROM
        FISERV_GTWY.APP_EMP_DTL_FORM;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            FISERV_GTWY.APP_EMP_DTL_FORM
        WHERE
            APP_EMP_DTL_FORM_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO FISERV_GTWY.APP_EMP_DTL_FORM
        (
            APP_EMP_DTL_FORM_ID
          , APP_FORM_ID
          , APP_EMP_DTL_ID
          , FORM
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , DOC_ID
          , APP_FILE_TYP_ID
        )
        SELECT
            APP_EMP_DTL_FORM_ID
          , APP_FORM_ID
          , APP_EMP_DTL_ID
          , FORM
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , DOC_ID
          , APP_FILE_TYP_ID
        FROM
            FISERV_GTWY.APP_EMP_DTL_FORM@${vAIXlink}
        WHERE
            APP_EMP_DTL_FORM_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO FISERV_GTWY.APP_EMP_DTL_FORM
    (
        APP_EMP_DTL_FORM_ID
      , APP_FORM_ID
      , APP_EMP_DTL_ID
      , FORM
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , DOC_ID
      , APP_FILE_TYP_ID
    )
    SELECT
        APP_EMP_DTL_FORM_ID
      , APP_FORM_ID
      , APP_EMP_DTL_ID
      , FORM
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , DOC_ID
      , APP_FILE_TYP_ID
    FROM
        FISERV_GTWY.APP_EMP_DTL_FORM@${vAIXlink}
    WHERE
        APP_EMP_DTL_FORM_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('FISERV_GTWY.APP_EMP_DTL_FORM is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading FISERV_GTWY.APP_PAYLD ***
-- populate updates to FISERV_GTWY.APP_PAYLD
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'FISERV_GTWY.APP_PAYLD'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(APP_PAYLD_ID)
    INTO
        V_ID
    FROM
        FISERV_GTWY.APP_PAYLD;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            FISERV_GTWY.APP_PAYLD
        WHERE
            APP_PAYLD_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO FISERV_GTWY.APP_PAYLD
        (
            APP_PAYLD_ID
          , PAYLD
          , APP_EMP_DTL_ID
          , APP_GRP_STAT_ID
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        )
        SELECT
            APP_PAYLD_ID
          , PAYLD
          , APP_EMP_DTL_ID
          , APP_GRP_STAT_ID
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        FROM
            FISERV_GTWY.APP_PAYLD@${vAIXlink}
        WHERE
            APP_PAYLD_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO FISERV_GTWY.APP_PAYLD
    (
        APP_PAYLD_ID
      , PAYLD
      , APP_EMP_DTL_ID
      , APP_GRP_STAT_ID
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    )
    SELECT
        APP_PAYLD_ID
      , PAYLD
      , APP_EMP_DTL_ID
      , APP_GRP_STAT_ID
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    FROM
        FISERV_GTWY.APP_PAYLD@${vAIXlink}
    WHERE
        APP_PAYLD_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('FISERV_GTWY.APP_PAYLD is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading FISERV_GTWY.APP_TRANSMISSION ***
-- populate updates to FISERV_GTWY.APP_TRANSMISSION
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'FISERV_GTWY.APP_TRANSMISSION'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(TRANSMISSION_ID)
    INTO
        V_ID
    FROM
        FISERV_GTWY.APP_TRANSMISSION;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            FISERV_GTWY.APP_TRANSMISSION
        WHERE
            TRANSMISSION_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO FISERV_GTWY.APP_TRANSMISSION
        (
            TRANSMISSION_ID
          , TRANSMITTAL_ID
          , APP_SRC_SYS_ID
          , PAYLD
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , HEALTH_CHECK
        )
        SELECT
            TRANSMISSION_ID
          , TRANSMITTAL_ID
          , APP_SRC_SYS_ID
          , PAYLD
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
          , HEALTH_CHECK
        FROM
            FISERV_GTWY.APP_TRANSMISSION@${vAIXlink}
        WHERE
            TRANSMISSION_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO FISERV_GTWY.APP_TRANSMISSION
    (
        TRANSMISSION_ID
      , TRANSMITTAL_ID
      , APP_SRC_SYS_ID
      , PAYLD
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , HEALTH_CHECK
    )
    SELECT
        TRANSMISSION_ID
      , TRANSMITTAL_ID
      , APP_SRC_SYS_ID
      , PAYLD
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
      , HEALTH_CHECK
    FROM
        FISERV_GTWY.APP_TRANSMISSION@${vAIXlink}
    WHERE
        TRANSMISSION_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('FISERV_GTWY.APP_TRANSMISSION is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading FISERV_GTWY.WS_TRXN_LOG ***
-- populate updates to FISERV_GTWY.WS_TRXN_LOG
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'FISERV_GTWY.WS_TRXN_LOG'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(WS_TRXN_LOG_ID)
    INTO
        V_ID
    FROM
        FISERV_GTWY.WS_TRXN_LOG;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            FISERV_GTWY.WS_TRXN_LOG
        WHERE
            WS_TRXN_LOG_ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new version of the record
        INSERT INTO FISERV_GTWY.WS_TRXN_LOG
        (
            WS_TRXN_LOG_ID
          , WS_TRXN_GRP
          , OPERATION_NM
          , SRC_SYS_ID
          , USER_ID
          , WS_TRXN_TYP_ID
          , WS_TRXN_TIME
          , PAYLD
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        )
        SELECT
            WS_TRXN_LOG_ID
          , WS_TRXN_GRP
          , OPERATION_NM
          , SRC_SYS_ID
          , USER_ID
          , WS_TRXN_TYP_ID
          , WS_TRXN_TIME
          , PAYLD
          , CRTD_BY
          , CRTD_DT
          , LAST_UPDT_BY
          , LAST_UPDT_DT
        FROM
            FISERV_GTWY.WS_TRXN_LOG@${vAIXlink}
        WHERE
            WS_TRXN_LOG_ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO FISERV_GTWY.WS_TRXN_LOG
    (
        WS_TRXN_LOG_ID
      , WS_TRXN_GRP
      , OPERATION_NM
      , SRC_SYS_ID
      , USER_ID
      , WS_TRXN_TYP_ID
      , WS_TRXN_TIME
      , PAYLD
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    )
    SELECT
        WS_TRXN_LOG_ID
      , WS_TRXN_GRP
      , OPERATION_NM
      , SRC_SYS_ID
      , USER_ID
      , WS_TRXN_TYP_ID
      , WS_TRXN_TIME
      , PAYLD
      , CRTD_BY
      , CRTD_DT
      , LAST_UPDT_BY
      , LAST_UPDT_DT
    FROM
        FISERV_GTWY.WS_TRXN_LOG@${vAIXlink}
    WHERE
        WS_TRXN_LOG_ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('FISERV_GTWY.WS_TRXN_LOG is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

PROMPT *** Loading STG.S1_XML_ACORD ***
-- populate updates to STG.S1_XML_ACORD
DECLARE
    V_ID      NUMBER;
	vError    VARCHAR2(500);

    CURSOR C_UPDATE_LIST   
    (
        P_ID      NUMBER
    )
    IS
        SELECT
            ID
          , ERR_TIMESTAMP
          , PACK_NM
          , PROC_NM
        FROM
            UTIL.FDS_ERR_LOG@${vAIXlink}
        WHERE
            PACK_NM = 'AIX CUTOVER'
            AND PROC_NM = 'STG.S1_XML_ACORD'
            AND ID <= P_ID;
BEGIN

    -- Get the current max ID value
    SELECT 
        MAX(ID)
    INTO
        V_ID
    FROM
        STG.S1_XML_ACORD;
    IF (V_ID IS NULL) THEN
        -- Error out?
        NULL;
    END IF;
    
    -- Handle updated records
    FOR R_UPDATE IN C_UPDATE_LIST (V_ID)
    LOOP
        DELETE
        FROM
            STG.S1_XML_ACORD
        WHERE
            ID = R_UPDATE.ID;
		COMMIT;

        -- Pull in the new records from the other server
        INSERT INTO STG.S1_XML_ACORD
        (
            ID
          , ACORD_XML
          , SOAP_MSG_ID
          , PRCSS_FLAG
          , CREAT_DATE
        )
        SELECT
            ID
          , ACORD_XML
          , SOAP_MSG_ID
          , PRCSS_FLAG
          , CREAT_DATE
        FROM
            STG.S1_XML_ACORD@${vAIXlink}
        WHERE
            ID = R_UPDATE.ID;

    END LOOP;
	COMMIT;
    
    -- Pull in the new records from the other server
    INSERT INTO STG.S1_XML_ACORD
    (
        ID
      , ACORD_XML
      , SOAP_MSG_ID
      , PRCSS_FLAG
      , CREAT_DATE
    )
    SELECT
        ID
      , ACORD_XML
      , SOAP_MSG_ID
      , PRCSS_FLAG
      , CREAT_DATE
    FROM
        STG.S1_XML_ACORD@${vAIXlink}
    WHERE
        ID > V_ID;
        
    COMMIT;
	DBMS_OUTPUT.PUT_LINE('STG.S1_XML_ACORD is loaded');
EXCEPTION
  WHEN OTHERS THEN
    vError:= SUBSTR(SQLERRM, 1, 500);
	DBMS_OUTPUT.PUT_LINE(vError);
END;
/

exit
RUNSQL

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
echo "COMPLETE" | tee -a $vFullLog

echo "" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog
echo "* Create missed FK constraints     *" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET TIMING ON
SET ECHO ON
SET DEFINE ON
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET LINES 200
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR CONTINUE
SPOOL $vOutputLog APPEND

ALTER TABLE "BLC_EAPP_GTWY"."APP_PAYLD" ADD CONSTRAINT "FK_APP_GRP_STAT_AP" FOREIGN KEY ("APP_GRP_STAT_ID") REFERENCES "BLC_EAPP_GTWY"."APP_GRP_STAT" ("APP_GRP_STAT_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "BLC_EAPP_GTWY"."APP_PAYLD" ADD CONSTRAINT "FK_APP_EMP_DTL_AP" FOREIGN KEY ("APP_EMP_DTL_ID") REFERENCES "BLC_EAPP_GTWY"."APP_EMP_DTL" ("APP_EMP_DTL_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "BLC_EAPP_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_FILE_TYP" FOREIGN KEY ("APP_FILE_TYP_ID") REFERENCES "BLC_EAPP_GTWY"."APP_FILE_TYP" ("APP_FILE_TYP_ID") ENABLE;
ALTER TABLE "BLC_EAPP_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_EMP_DTL_AEDF" FOREIGN KEY ("APP_EMP_DTL_ID") REFERENCES "BLC_EAPP_GTWY"."APP_EMP_DTL" ("APP_EMP_DTL_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "BLC_EAPP_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_FORM_AEDF" FOREIGN KEY ("APP_FORM_ID") REFERENCES "BLC_EAPP_GTWY"."APP_FORM" ("APP_FORM_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_TRANSMISSION" ADD CONSTRAINT "FK_APP_SRC_SYS_ID" FOREIGN KEY ("APP_SRC_SYS_ID") REFERENCES "FISERV_GTWY"."APP_SRC_SYS" ("APP_SRC_SYS_ID") ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_PAYLD" ADD CONSTRAINT "FK_APP_GRP_STAT_AP" FOREIGN KEY ("APP_GRP_STAT_ID") REFERENCES "FISERV_GTWY"."APP_GRP_STAT" ("APP_GRP_STAT_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_PAYLD" ADD CONSTRAINT "FK_APP_EMP_DTL_AP" FOREIGN KEY ("APP_EMP_DTL_ID") REFERENCES "FISERV_GTWY"."APP_EMP_DTL" ("APP_EMP_DTL_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_FILE_TYP" FOREIGN KEY ("APP_FILE_TYP_ID") REFERENCES "FISERV_GTWY"."APP_FILE_TYP" ("APP_FILE_TYP_ID") ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_EMP_DTL_AEDF" FOREIGN KEY ("APP_EMP_DTL_ID") REFERENCES "FISERV_GTWY"."APP_EMP_DTL" ("APP_EMP_DTL_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "FISERV_GTWY"."APP_EMP_DTL_FORM" ADD CONSTRAINT "FK_APP_FORM_AEDF" FOREIGN KEY ("APP_FORM_ID") REFERENCES "FISERV_GTWY"."APP_FORM" ("APP_FORM_ID") ON DELETE CASCADE ENABLE;
ALTER TABLE "FISERV_GTWY"."WS_TRXN_LOG" ADD CONSTRAINT "FK_WS_TRXN_TYP" FOREIGN KEY ("WS_TRXN_TYP_ID") REFERENCES "FISERV_GTWY"."WS_TRXN_TYP" ("WS_TRXN_TYP_ID") ENABLE;

exit
RUNSQL

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
echo "COMPLETE" | tee -a $vFullLog

echo "" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog
echo "* Validate big table counts        *" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET TIMING ON
SET ECHO ON
SET DEFINE ON
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET LINES 200
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL $vOutputLog APPEND

-- truncate tables
truncate table $vLinuxRowTable;

-- insert table counts
set serveroutput on
declare
  cursor cf is
    select db.name, ins.host_name,
	  tb.owner, tb.table_name, tb.status
	from DBA_TABLES tb, v\$instance ins, v\$database db
	where tb.IOT_TYPE is null
	and (tb.owner||'.'||tb.table_name) in
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

select 'There are '||count(*)||' big tables.' "TABLES" from ${vLinuxRowTable};

-- Table count comparison
col "TABLE" format a30
col "AIX" format 999,999,990
col "LINUX" format 999,999,990
col "DIFF" format 999,999,990
select NVL(lx.OWNER,aix.OWNER) "OWNER", NVL(lx.TABLE_NAME,aix.TABLE_NAME) "TABLE_NAME", 
	aix.RECORD_COUNT "AIX", lx.RECORD_COUNT "LINUX", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFF"
from $vLinuxRowTable lx full outer join $vRowTable aix
	on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.owner not in ('GGS','GGTEST')
order by 1;

-- Table status comparison
select lx.OWNER||'.'||lx.TABLE_NAME "TABLE", aix.STATUS "AIX", lx.STATUS "LINUX"
from $vLinuxRowTable lx full outer join $vRowTable aix
  on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME
where lx.owner not in ('GGS','GGTEST')
order by 1;

-- constraint comparison
with aix as (
	select owner, table_name, constraint_type, status, count(*) "CNSTR_CT"
	from dba_constraints@${vAIXlink}
	where table_name not like 'BIN$%'
	and (owner||'.'||table_name) in
	('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
	group by owner, table_name, constraint_type, status
), lx as (
	select owner, table_name, constraint_type, status, count(*) "CNSTR_CT"
	from dba_constraints
	where table_name not like 'BIN$%'
	and (owner||'.'||table_name) in
	('FISERV_GTWY.WS_TRXN_LOG','FISERV_GTWY.APP_TRANSMISSION','FISERV_GTWY.APP_PAYLD','FISERV_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_EMP_DTL_FORM','BLC_EAPP_GTWY.APP_PAYLD','STG.S1_XML_ACORD','JIRA.PROPERTYSTRING','SONAR.ISSUE_FILTER_FAVOURITES')
	group by owner, table_name, constraint_type, status
)
select NVL(aix.owner,lx.owner) "OWNER", NVL(aix.table_name,lx.table_name) "TABLE_NAME", 
	NVL(aix.constraint_type,lx.constraint_type) "CONSTRAINT_TYPE", NVL(aix.STATUS,lx.STATUS) "STATUS", 
	aix.CNSTR_CT "AIX", lx.CNSTR_CT "LINUX", lx.CNSTR_CT-aix.CNSTR_CT "DIFF"
from lx full outer join aix
	on aix.owner=lx.owner and aix.table_name=lx.table_name and aix.constraint_type=lx.constraint_type and aix.STATUS=lx.STATUS
--where NVL2(aix.CNSTR_CT,aix.CNSTR_CT,0)!=NVL2(lx.CNSTR_CT,lx.CNSTR_CT,0)
order by 1,2,3,4;

exit
RUNSQL

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
echo "COMPLETE" | tee -a $vFullLog

echo "" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog
echo "* Dropping DB link to AIX database *" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
SET TIMING ON
SET ECHO ON
SET DEFINE ON
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET LINES 200
SET PAGES 1000
SET TRIMSPOOL ON
SET LONG 10000
SET NUMFORMAT 999999999999999990
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL $vOutputLog APPEND

PROMPT +++++++++++++++++ DROP DB LINK TO AIX +++++++++++++++++
DROP PUBLIC DATABASE LINK ${vAIXlink};

PROMPT +++++++++++++++++ RE-ENABLE TRIGGERS +++++++++++++++++
@$vEnableTrigger

col "TRIGGER" format a40
col status format a12
SELECT dt.owner||'.'||dt.trigger_name "TRIGGER", TRIGGER_TYPE, dt.status
FROM dba_triggers dt
WHERE dt.owner in ('BLC_EAPP_GTWY','FISERV_GTWY','STG')
order by 1;

exit
RUNSQL

# check log for errors
error_check_fnc $vOutputLog $vErrorLog $vCritLog $vFullLog
echo "COMPLETE" | tee -a $vFullLog

echo "" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog
echo "* Summary                          *" | tee -a $vOutputLog
echo "************************************" | tee -a $vOutputLog

# Report Timing of Script
vEndSec=$(date '+%s')
vRunSec=$(echo "scale=2; ($vEndSec-$vStartSec)" | bc)
show_time $vRunSec

echo "" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
echo "$0 is now complete." | tee -a $vOutputLog
echo "Database Name:        $vPDBName" | tee -a $vOutputLog
echo "Total Run Time:       $vTotalTime" | tee -a $vOutputLog
echo "***************************************" | tee -a $vOutputLog
echo "" | tee -a $vOutputLog
cat $vOutputLog >> $vFullLog