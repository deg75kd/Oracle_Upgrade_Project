#!/usr/bin/bash

vPDBName=bpam
vCDBName=cbpam
vSysPwd=oracle
vOutputLog=gg_setup.log
vGGSPwd=Oracle1
ORACLE_HOME=/app/oracle/product/db/12c/1

# Set location for data file
DATAFILE_LOC="/database/${vPDBName}01/oradata"

# Create required objects in PDB
$ORACLE_HOME/bin/sqlplus "sys/${vSysPwd}@${vCDBName} as sysdba" << EOF
SET ECHO ON
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

WHENEVER SQLERROR EXIT
alter system set enable_goldengate_replication=TRUE scope=both;
alter session set container=${vPDBName};

WHENEVER SQLERROR CONTINUE
drop user ggs cascade;
drop user GGTEST cascade;
drop tablespace GGS including contents and datafiles;
WHENEVER SQLERROR EXIT

--cr_tablespaces.sql
--ASM, edit ASM dg group name accordingly
CREATE TABLESPACE GGS DATAFILE '$DATAFILE_LOC/ggs01.dbf' SIZE 500M
AUTOEXTEND ON
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 4194304
SEGMENT SPACE MANAGEMENT AUTO;
select * from v\$instance;

create user ggs identified by $vGGSPwd
default tablespace GGS
temporary tablespace TEMP
container=current;

grant connect, resource, DBA to GGS;
grant connect,resource,unlimited tablespace to ggs;
grant execute on utl_file to ggs;
grant select any table to ggs;
grant select any dictionary to ggs;

--on 12c Multitenant
grant DBA to ggs;
grant Create Session to ggs;
grant SYSDBA to ggs;
grant Exempt Access Policy to ggs;
grant Restricted Session to ggs;
grant execute on dbms_metadata to ggs;

--11.2.0.2 or above
exec dbms_goldengate_auth.grant_admin_privilege('GGS');
--grant permission to user can issue  add schematrandata
exec dbms_streams_auth.grant_admin_privilege('GGS');

--or --for both capture and apply
--11.2.0.3
exec dbms_goldengate_auth.grant_admin_privilege('GGS',grant_select_privileges=>true);   

--enable_goldengate_replication
--run below command in CDB
--alter system set enable_goldengate_replication=TRUE scope=both;

create user GGTEST identified by gg#te#st01
default tablespace GGS
temporary tablespace TEMP;

grant connect, resource to GGTEST;

SPOOL OFF
exit;
EOF
