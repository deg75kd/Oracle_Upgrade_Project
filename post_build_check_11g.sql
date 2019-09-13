set head on
set echo off
set feedback on
set lines 150 pages 200
set trimspool on

column filename new_val filename
select '/app/oracle/scripts/12cupgrade/logs/post_build_check_11g_'||name||'.log' filename from v$database; 
spool &filename

-- users
col username format a30
col profile format a20
select username, profile
from dba_users where username in 
('AUTODDL','AUTODML','ECORA','ORA_QUALYS_DB','SQLTUNE','TNS_USER','UIMMONITOR')
order by 1,2;

-- profiles
col LIMIT format a20
col PROFILE format a12
select PROFILE, RESOURCE_NAME, LIMIT
from dba_profiles
where profile in ('DEFAULT','APP_PROFILE','CNO_PROFILE') and limit!='UNLIMITED'
order by 1,2;

-- roles
col role format a30
select role from dba_roles
where role in ('AWR_REPORT_ROLE','AUTODDL_ADMIN','AUTODML_ADMIN','SECURITY_ADMIN','READONLY','READWRITE','EXECROLE',
	'APP_USER','APP_DBA','APP_DEVELOPER','PROD_DBA_ROLE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','SECURITY_ADMIN_ROLE','QUALYS_ROLE')
order by 1;

-- privileges
col grantee format a30
col granted_role format a30
select grantee, granted_role, default_role
from dba_role_privs
where grantee in ('AUTODDL','AUTODML','ECORA','ORA_QUALYS_DB','SQLTUNE','TNS_USER','UIMMONITOR')
order by 1,2,3;

-- SQLTUNE objects
col table_name format a30
col tablespace_name format a30
select owner, table_name, tablespace_name from dba_tables where table_name like 'SQL_TUNE%' order by 1,2,3;

-- SQLTUNE quotas
col "QUOTA" format a10
col tablespace_name format a30
select tq.tablespace_name, 
	case when tq.max_bytes is null then '0'
	when tq.max_bytes < 0 then 'UNLIMITED'
	else to_char(tq.max_bytes/1024/1024)
	end "QUOTA"
from dba_users us left outer join dba_ts_quotas tq
  on tq.username=us.username
where us.username='SQLTUNE'
order by 1,2;

-- SQLTUNE privileges
col "PRIVILEGE" format a60
select privilege||' on '||owner||'.'||table_name "PRIVILEGE"
from dba_tab_privs
where grantee='SQLTUNE'
order by owner, table_name, privilege;

select privilege
from dba_sys_privs where grantee='SQLTUNE'
order by 1;

-- AWR retention policy
SELECT dhwc.dbid, extract(day from dhwc.snap_interval) *24*60+extract(hour from dhwc.snap_interval) *60+extract(minute from dhwc.snap_interval) snapshot_Interval,
	extract(day from dhwc.retention) *24*60+extract(hour from dhwc.retention) *60+extract(minute from dhwc.retention) retention_Interval
FROM dba_hist_wr_control dhwc, v$database db
WHERE dhwc.dbid=db.dbid;

-- logon audit objects
col owner format a30
col object_name format a30
col object_type format a30
select owner, object_name, object_type from dba_objects where object_name like 'LOGON_AUDIT%' order by 1,2,3;

spool off
