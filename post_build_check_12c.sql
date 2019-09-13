set head on
set echo off
set feedback on
set lines 150 pages 200
set trimspool on
spool ./logs/post_build_check_12c.log

-- 12c users
col username format a30
col profile format a20
select con_id, username, profile, common, ORACLE_MAINTAINED
from cdb_users where con_id=3 and username in 
('AUTODDL','AUTODML','ECORA','ORA_QUALYS_DB','SQLTUNE','TNS_USER','UIMMONITOR')
order by 1,2;

-- 12c profiles
col LIMIT format a20
col PROFILE format a12
col "C" format 90
set lines 150 pages 200
select CON_ID "C", PROFILE, RESOURCE_NAME, LIMIT, COMMON "CMN"
from cdb_profiles
where profile in ('DEFAULT','APP_PROFILE','CNO_PROFILE') and con_id=3 and limit!='UNLIMITED'
order by 1,2,3;

-- 12c roles
col con_id format 990
col role format a30
select con_id, role, common, oracle_maintained
from cdb_roles
where con_id=3 and role in ('AWR_REPORT_ROLE','AUTODDL_ADMIN','AUTODML_ADMIN','SECURITY_ADMIN','READONLY','READWRITE','EXECROLE',
	'APP_USER','APP_DBA','APP_DEVELOPER','PROD_DBA_ROLE','APP_DBA_ROLE','APP_DEVELOPER_ROLE','SECURITY_ADMIN_ROLE','QUALYS_ROLE')
order by 1,2;

-- 12c privileges
col con_id format 990
col grantee format a30
col granted_role format a30
select distinct con_id, grantee, granted_role, default_role
from cdb_role_privs
where con_id=3 and grantee in ('AUTODDL','AUTODML','ECORA','ORA_QUALYS_DB','SQLTUNE','TNS_USER','UIMMONITOR')
order by 1,2,3;

-- SQLTUNE objects
col con_id format 990
col owner format a30
col object_name format a30
select con_id, owner, object_name, oracle_maintained from cdb_objects where object_name like 'SQL_TUNE%' order by 1,2,3;

col table_name format a30
col tablespace_name format a30
select con_id, owner, table_name, tablespace_name from cdb_tables where table_name like 'SQL_TUNE%' order by 1,2,3;

-- SQLTUNE quotas
col "QUOTA" format a10
col tablespace_name format a30
select us.con_id, tq.tablespace_name, 
	case when tq.max_bytes is null then '0'
	when tq.max_bytes < 0 then 'UNLIMITED'
	else to_char(tq.max_bytes/1024/1024)
	end "QUOTA"
from cdb_users us left outer join cdb_ts_quotas tq
  on tq.username=us.username and tq.con_id=us.con_id
where us.username='SQLTUNE' and us.con_id=3
order by 1,2;

-- SQLTUNE privileges
col "PRIVILEGE" format a60
select con_id, privilege||' on '||owner||'.'||table_name "PRIVILEGE"
from cdb_tab_privs
where grantee='SQLTUNE' and con_id=3
order by con_id, owner, table_name, privilege;

select distinct con_id, privilege
from cdb_sys_privs where grantee='SQLTUNE' and con_id=3
order by 1,2;

select USERNAME, DEFAULT_ATTR, ALL_CONTAINERS from DBA_CONTAINER_DATA where username='SQLTUNE';

-- AWR retention policy
SELECT dhwc.dbid, extract(day from dhwc.snap_interval) *24*60+extract(hour from dhwc.snap_interval) *60+extract(minute from dhwc.snap_interval) snapshot_Interval,
	extract(day from dhwc.retention) *24*60+extract(hour from dhwc.retention) *60+extract(minute from dhwc.retention) retention_Interval
FROM dba_hist_wr_control dhwc, v$database db
WHERE dhwc.dbid=db.dbid;

-- logon audit objects
col owner format a30
col object_name format a30
col object_type format a30
select con_id, owner, object_name, object_type from cdb_objects where object_name like 'LOGON_AUDIT%' order by 1,2,3;

spool off
