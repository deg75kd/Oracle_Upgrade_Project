SET SERVEROUTPUT ON
SET VERIFY OFF
SET ECHO OFF
SET DEFINE ON
SET TRIMSPOOL ON
SET LINES 200
SET PAGES 0

WHENEVER SQLERROR CONTINUE

column filename new_val filename
select 'db_link_check_'||name filename from v$database; 
SPOOL &filename..log

DECLARE
	CURSOR c1 IS
		SELECT db_link FROM dba_db_links WHERE owner='PUBLIC';
	v_link	c1%ROWTYPE;
	v_query	VARCHAR2(100);
	v_date	DATE;
	v_error	VARCHAR2(500);
BEGIN
	OPEN c1;
	LOOP
		FETCH c1 INTO v_link;
		EXIT WHEN c1%NOTFOUND;
		v_query := 'SELECT sysdate FROM dual@'||v_link.db_link;
		
		-- use separate block with exception handling
		BEGIN
			EXECUTE IMMEDIATE v_query INTO v_date;
			DBMS_OUTPUT.PUT_LINE(v_link.db_link||' -OK-');
				
		EXCEPTION
			WHEN OTHERS THEN
				v_error:= SUBSTR(SQLERRM, 1, 500);
				DBMS_OUTPUT.PUT_LINE('************ Error connecting with '||v_link.db_link||' ************');
				DBMS_OUTPUT.PUT_LINE(v_error);
		END;
		ROLLBACK;
		--EXECUTE IMMEDIATE 'ALTER SESSION CLOSE DATABASE LINK '||v_link.db_link;
	END LOOP;
	CLOSE c1;
	
	EXCEPTION
		WHEN OTHERS THEN
			v_error:= SUBSTR(SQLERRM, 1, 500);
			DBMS_OUTPUT.PUT_LINE(v_error);
END;
/

SPOOL OFF

