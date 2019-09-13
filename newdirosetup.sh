#!/bin/ksh

#############################################################
# Author :  Kevin Shidler                                   #
# Date   :  July 7th, 2007                                  #
# Purpose:  Sets up the environment for Oracle.             #
#############################################################
# Version History                                           #
# ---------------                                           #
# 1.  Modified by: Kevin Shidler                            #
#     Date       : July 7th, 2007                           #
#     Version    : 1.0.0                                    #
#     Purpose    : Created                                  #
# 2.  Modified by: Kevin Shidler                            #
#     Date       : July 20th, 2007                          #
#     Version    : 1.0.1                                    #
#     Purpose    : Removed the export for SQLPATH.          #
# 3.  Modified by: Kevin Shidler                            #
#     Date       : August 7th, 2007                         #
#     Version    : 1.0.3                                    #
#     Purpose    : Implemented enhancement 1.0.3#e4         #
#       (see README.txt).                                   #
# 4.  Modified by: Kevin Shidler                            #
#     Date       : September 11th, 2007                     #
#     Version    : 1.0.4                                    #
#     Purpose    : Implemented enhancement 1.0.3#e5         #
#       (see README.txt).                                   #
# 5.  Modified by: Kevin Shidler                            #
#     Date       : September 13th, 2007                     #
#     Version    : 1.0.5                                    #
#     Purpose    : Fixed bug 1.0.5#b1                       #
#       (see README.txt).                                   #
# 6.  Modified by: Kevin DeJesus                            #
#     Date       : January 10th, 2017                       #
#     Version    : 2.0.0                                    #
#     Purpose    : Adjusted for Oracle 12c on Linux         #
# 7.  Modified by: Kevin DeJesus                            #
#     Date       : January 25th, 2017                       #
#     Version    : 2.0.1                                    #
#     Purpose    : Rewritten for bash                       #
#############################################################

###########################################################
# The below ${-} tells us what settings are in effect     #
# for this Korn shell session.  A setting which has       #
# caused grief in the past in the "set -u" which says,    #
# "If an unitialized variable is used, raise an error     #
# and exit the shell".  This is actually a good setting,  #
# but we encountered errors executing our scripts, so     #
# we will store all "set"tings, change the ones we need   #
# to change, and set the other ones back.                 #
###########################################################
typeset CallerScriptMinusSettings=${-}
if [[ ${CallerScriptMinusSettings} = *u* ]]
then
  set +u
fi

#####################################################################
# List of main variables.                                           #
#####################################################################
#typeset  __ProgramName="`basename $0`"
#typeset  __ProgramNameWArgs="${__ProgramName} $*"
typeset  __Zero="$0"
typeset    SERVERNAME=`uname -n`
typeset    OSTYPE=`uname -s`
typeset    NOWwSECs=$(date '+%Y%m%d%H%M%S')
typeset    NOWwSECsFormat=$(date '+%m/%d/%Y %H:%M:%S')
typeset -i gFAILURE=999
typeset -i gSUCCESS=0
typeset -i END=2
typeset -i TRUE=gSUCCESS
typeset -i FALSE=gFAILURE
typeset    USAGEFILE=${ORACLE_SCRIPT}/osetup.ksh.USAGE
typeset    gORATABFILE=/etc/oratab
typeset -i gDatabaseMode=1
typeset -i gHomeMode=2
typeset -i gProgramMode=${gDatabaseMode}
typeset -i OPTIND=1
typeset    vCDBPrefix="c"

#####################################################################
# Restore settings if <Control>-C is entered while program is       #
# executing.                                                        #
# Also restoring the "set -u/+u" variable.                          #
#####################################################################
trap '
if [[ ${CallerScriptMinusSettings} = *u* ]]
then
  set -u
fi
' EXIT 

#####################################################################
# PURPOSE:                                                          #
# This function prints out how to run the program.                  #
#####################################################################
function PrintUsage
{
  clear
  more ${USAGEFILE} 
}

#####################################################################
# PURPOSE:                                                          #
# This function reads the synopsis section of the USAGE file, to    #
# give a quick look at the options and how to use this tool,        #
# without duplicating documentation.                                #
#####################################################################
function SYNOPSIS
{
  cat ${USAGEFILE} | sed '/SYNOPSIS/,/OPTIONS/!d' | sed -e 's/OPTIONS//'
}

################################################
# PURPOSE:                                     #
# Used to raise and errors, print out an       #
# error, plus exit.  Arguments are:            #
# 1.  Message                                  #
# 2.  Return Error Number.                     #
################################################
function raiseError
{
  typeset message="$1"
  typeset retval=$2

  echo -e "\nERROR:\n-------\n$message\n"
#  SYNOPSIS
  return $retval
}

#####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function PrintParameters {
  echo ""
  echo "Your Oracle Environment Settings:"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "ORACLE_SID            = ${ORACLE_SID}"
  echo "ORACLE_HOME           = ${ORACLE_HOME}"
  echo "ORACLE_VERSION        = ${ORACLE_FULL_VERSION}"
  echo "TNS_ADMIN             = ${TNS_ADMIN}"
  echo "LD_LIBRARY_PATH       = ${LD_LIBRARY_PATH}"
  echo "DBHOME                = ${DBHOME}"
  echo ""
}

#####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function RaiseInvalidSwitchException {
  typeset lSwitch=${1}

  # Do not raise the exception for the "-t" switch.
  if [[ "${lSwitch}" != "t" ]]
  then
    raiseError "Invalid switch argument for \"-${1}\"." ${gFAILURE}
    return $?
  fi
}

#####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function SetConsecoStandard {
  # check if parameter passed
  if [[ $# -lt 2 ]]
  then
    raiseError "Two parameters must be passed to the $0 function." ${gFAILURE}
    return $?
  else
    lCDBName=$1
    lHasCDB=$2
  fi

  unset TNS_ADMIN LD_LIBRARY_PATH NLS_LANG ORACLE_NLS DBHOME PFILE ALERT TNS DBHOME 
  unset ARCHDIR BACKUPDIR EXPDIR INITFILE LOGDIR SHLIB_PATH SPFILE

  # set DBHOME according to whether CDB exists
  if [[ $lHasCDB = 1 ]]
  then
    export DBHOME=/database/${lCDBName}_admn01
    export ALERT=${DBHOME}/admin/diag/rdbms/${lCDBName}/${lCDBName}/trace/alert_${lCDBName}.log
  else
    export DBHOME=/database/${ORACLE_SID}_admn01
    export ALERT=${DBHOME}/admin/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
  fi

  export PFILE=${DBHOME}/admin/pfile/init${ORACLE_SID}.ora
  export SPFILE=${DBHOME}/admin/pfile/spfile${ORACLE_SID}.ora
  export TNS_ADMIN=/app/oracle/tns_admin
  export LD_LIBRARY_PATH=${ORACLE_HOME}/lib

  #export ARCHDIR=/ora${TIER}backup/${ORACLE_SID}/dumparch
  #export BACKUPDIR=/ora${TIER}backup/${ORACLE_SID}/dumpdata
  #export EXPDIR=/ora${TIER}backup/${ORACLE_SID}/dumpexp
  #export LOGDIR=/ora${TIER}backup/${ORACLE_SID}/log
}

#####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function GetOracleDetails {
  typeset    lText
 
  unset ORACLE_FULL_VERSION
  
  # First, let's see if SQL*Plus is even available.
  lText=`which sqlplus`
  if [[ ${lText} != which:* ]]
  then  
    ORACLE_FULL_VERSION=`sqlplus -v 2>&1 | awk -F" " '{print $3}' | grep -v ^$`
  fi
}

####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function SetConsecoVariable {
  typeset lOldPath=${PATH}
  typeset lModPath=""
  typeset lOldOracleHome=${ORACLE_HOME}
  typeset tmpIFS=${IFS}
  typeset lCount=0
  typeset lCounter=0
  # only set database name if a variable was passed
  if [[ -n $2 ]] 
  then
    typeset lDatabaseName="$2"
  else
    unset lDatabaseName
  fi

  unset ORACLE_HOME ORACLE_SID PATH

  if [[ -z ${lOldOracleHome} ]];
  then
    lOldOracleHome="/just/a/default/path/has/no/meaning"
  fi
 
  IFS=':'
  PathItemsArray=${lOldPath}
  for PathItem in ${PathItemsArray[*]}
  do
    if [[ ${PathItem} != ${lOldOracleHome}* ]] || [[ "${PathItem}" == "" ]]
    then
      lModPath=${PathItem}:${lModPath}
    fi
  done
  IFS=${tmpIFS}

export ORACLE_SID=$lDatabaseName
export ORACLE_HOME=$1
export PATH=${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${lModPath}
}

#####################################################################
# PURPOSE:                                                          #
#                                                                   #
#####################################################################
function SetEnvironment {
  typeset -i lDatabaseMode=1
  typeset -i lHomeMode=2
  typeset -i lProgramMode=${lDatabaseMode}
  
  typeset lOracleHomePath
  typeset lOracleDatabaseName
  typeset lOracleCDBName
  typeset lOracleFullVersion

  typeset -i lCDBExists=0
  typeset -i lExists=0
  typeset -i OPTIND=1

  while getopts :o:d:t: SetEnvironmentArgs
  do
    case ${SetEnvironmentArgs} in
      o)  lProgramMode=${lHomeMode}
          lOracleHomePath=${OPTARG};;
      :)  RaiseInvalidSwitchException ${OPTARG};;
      d)  lProgramMode=${lDatabaseMode}
          lOracleDatabaseName=${OPTARG};;
      :)  RaiseInvalidSwitchException ${OPTARG};;
      t)  gORATABFILE=${OPTARG:-gORATABFILE};;
      #:)  ;;
      /?) RaiseInvalidSwitchException ${OPTARG};;
    esac
  done
    
  # Set CDB name
  if [[ $lOracleDatabaseName = ${vCDBPrefix}* ]]
  then
      lOracleCDBName=$lOracleDatabaseName
  else
      lOracleCDBName="${vCDBPrefix}${lOracleDatabaseName}"
  fi

  if [[ ${lProgramMode} -eq ${lDatabaseMode} ]]
  then
    if [[ ! -f ${gORATABFILE} || ! -r ${gORATABFILE} ]]
    then
      raiseError "Specified oratab file does not exist - \"${gORATABFILE}\"." ${gFAILURE}
      return $?
    fi
    # Validate existence of the CDB name in an "/etc/oratab"-like file.
    lCDBExists=`grep ^${lOracleCDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | wc -l`
    lExists=`grep ^${lOracleDatabaseName} ${gORATABFILE} | grep -v ^# | grep -v ^* | wc -l`
    if [[ ${lCDBExists} -eq 1 ]]
    then
      lOracleHomePath=`grep ^${lOracleCDBName} ${gORATABFILE} | grep -v ^# | grep -v ^* | cut -d: -f2`
    elif [[ ${lExists} -eq 1 ]]
    then
      lOracleHomePath=`grep ^${lOracleDatabaseName} ${gORATABFILE} | grep -v ^# | grep -v ^* | cut -d: -f2`
    else
      raiseError "Found ${lCDBExists} occurrence(s) of \"${lOracleCDBName}\" and ${lExists} occurrence(s) of \"${lOracleDatabaseName}\" in \"${gORATABFILE}\".\nPlease modify this file so that only 1 entry of the appropriate database exists." ${gFAILURE}
      return $?
    fi
    if [[ -z $lOracleHomePath ]]
    then
      raiseError "Could not determine Oracle home of ${lOracleCDBName} from ${gORATABFILE}. Ensure the entry follows the following format \"<CDB_Name>:<Oracle_Home>:<Y|N>\". " ${gFAILURE}
      return $?
    fi
  elif [[ ${lProgramMode} -eq ${lHomeMode} ]]
  then
    unset lOracleDatabaseName
    unset lOracleCDBName
  fi

  SetConsecoVariable ${lOracleHomePath} ${lOracleDatabaseName}
  SetConsecoStandard ${lOracleCDBName} ${lCDBExists}
  GetOracleDetails

  if [[ ! -z ${ORACLE_SID} ]];
  then

    if [[ -f ${ORACLE_SCRIPT}/init${ORACLE_SID}.ksh && -x ${ORACLE_SCRIPT}/init${ORACLE_SID}.ksh ]];
    then
      . ${ORACLE_SCRIPT}/init${ORACLE_SID}.ksh
    fi

  fi

}

function Main {
  typeset OracleDatabaseParameter
  typeset OracleHomeParameter
  typeset -i lReturn=0

  if [[ ${#} -eq 0 ]]
  then
    raiseError "Invalid # of arguments was passed into the program." ${gFAILURE}
    return $?
  fi

  while getopts :o:d:t:h CommandLineArgs
  do
    case $CommandLineArgs in
      o)  OracleHomesParameter=$OPTARG
          gProgramMode=${gHomeMode};;
      d)  OracleDatabaseParameter=$OPTARG
          gProgramMode=${gDatabaseMode};;
      t)  gORATAB=${OPTARG:-gORATAB};;
      h)  PrintUsage
          return ${END};; 
      :)  RaiseInvalidSwitchException ${OPTARG}
          return $?;;
      \?) RaiseInvalidSwitchException ${OPTARG};;
    esac
  done

  if [[ ${gProgramMode} -eq ${gDatabaseMode} ]]
  then
    if [[ -z ${OracleDatabaseParameter} ]]
    then
      raiseError "No database name was specified.  Please supply a valid database name." ${gFAILURE}
      return $?
    fi
    SetEnvironment -d ${OracleDatabaseParameter} -t ${gORATAB}
    lReturn=$?
    if [[ ${lReturn} -ne 0 ]]
    then
      return ${lReturn}
    fi
  elif [[ ${gProgramMode} -eq ${gHomeMode} ]]
  then
    SetEnvironment -o ${OracleHomesParameter}
    lReturn=$?
    if [[ ${lReturn} -ne 0 ]]
    then
      return ${lReturn}
    fi
  fi

}

Main $*
lReturn=$?
if [[ ${lReturn} -ne 0 ]]
then
  return ${lReturn}
fi
PrintParameters
return ${gSUCCESS}



