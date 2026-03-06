-- ============================================================
-- INVESTMENT DOMAIN — PHASE 09: AUDIT & COMPLIANCE
-- ============================================================
-- Script:      09_audit_compliance.sql
-- Version:     1.0.0
-- Environment: Enterprise Snowflake (SOX/SEC-regulated)
-- Purpose:     Implement centralized enterprise audit and
--              compliance monitoring framework for investment.
--
-- AUDIT FRAMEWORK OVERVIEW:
-- -------------------------
-- This phase implements comprehensive audit capabilities:
--   - Security event monitoring (logins, grants, escalations)
--   - PII data access tracking
--   - Governance change auditing (tags, policies)
--   - Compliance monitoring (SOX, SEC, FINRA)
--   - Risk scoring per user
--
-- DATA SOURCES:
-- -------------
-- All views source from SNOWFLAKE.ACCOUNT_USAGE which has:
--   - Up to 45 minutes latency for query data
--   - Up to 2-3 hours latency for some metadata
--   - 365 days retention for most views
--
-- REGULATORY COMPLIANCE:
-- ----------------------
-- These audit views support requirements for:
--   - SOX Section 404: Internal controls audit
--   - SEC Regulation S-P: Client privacy monitoring
--   - SEC Rule 17a-4: Records retention tracking
--   - FINRA Rule 3110: Supervision audit trails
--
-- Prerequisites:
--   - Phase 01-08 completed
--   - INV_GOVERNANCE_DB.AUDIT schema exists
--   - Tags and policies deployed (Phase 08)
--
-- Execution: Run as ACCOUNTADMIN
-- ============================================================


-- ============================================================
-- SECTION 1: AUDIT SCHEMA SETUP
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE INV_GOVERNANCE_DB;
USE WAREHOUSE COMPUTE_WH;

CREATE SCHEMA IF NOT EXISTS INV_GOVERNANCE_DB.AUDIT
    COMMENT = 'Audit and compliance monitoring views for SOX/SEC/FINRA compliance';

USE SCHEMA INV_GOVERNANCE_DB.AUDIT;


-- ============================================================
-- SECTION 2: SECURITY EVENT AUDIT VIEWS
-- ============================================================
-- Monitor authentication, authorization, and security events.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_LOGIN_HISTORY
-- ------------------------------------------------------------
-- Tracks all authentication attempts including successes and
-- failures. Critical for detecting brute force attacks and
-- unauthorized access attempts.
--
-- Data Latency: Up to 2 hours from ACCOUNT_USAGE.LOGIN_HISTORY
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_LOGIN_HISTORY
    COMMENT = 'Authentication audit log tracking login successes and failures. Includes IP, client type, and error details. Data latency: up to 2 hours. Retention: 90 days.'
AS
SELECT
    EVENT_ID                                                AS EVENT_ID,
    EVENT_TIMESTAMP                                         AS LOGIN_TIMESTAMP,
    USER_NAME                                               AS USER_NAME,
    CLIENT_IP                                               AS CLIENT_IP,
    REPORTED_CLIENT_TYPE                                    AS CLIENT_TYPE,
    REPORTED_CLIENT_VERSION                                 AS CLIENT_VERSION,
    FIRST_AUTHENTICATION_FACTOR                             AS AUTH_METHOD,
    SECOND_AUTHENTICATION_FACTOR                            AS MFA_METHOD,
    IS_SUCCESS                                              AS LOGIN_SUCCESS,
    ERROR_CODE                                              AS ERROR_CODE,
    ERROR_MESSAGE                                           AS ERROR_MESSAGE,
    CASE 
        WHEN IS_SUCCESS = 'NO' THEN 'FAILED'
        WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 'SUCCESS_MFA'
        ELSE 'SUCCESS'
    END                                                     AS LOGIN_STATUS,
    CASE
        WHEN IS_SUCCESS = 'NO' THEN 'HIGH'
        WHEN CLIENT_IP NOT LIKE '10.%' 
             AND CLIENT_IP NOT LIKE '192.168.%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
ORDER BY EVENT_TIMESTAMP DESC;


-- ------------------------------------------------------------
-- VIEW: V_ROLE_GRANT_HISTORY
-- ------------------------------------------------------------
-- Tracks role grants to users and role-to-role inheritance.
-- Essential for detecting unauthorized privilege expansion.
--
-- Data Latency: Up to 3 hours from ACCOUNT_USAGE
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_ROLE_GRANT_HISTORY
    COMMENT = 'Role grant audit tracking grants to users and role hierarchy changes. Data latency: up to 3 hours. Retention: 180 days.'
AS
SELECT
    CREATED_ON                                              AS GRANT_TIMESTAMP,
    'USER_GRANT'                                            AS GRANT_TYPE,
    ROLE                                                    AS GRANTED_ROLE,
    GRANTEE_NAME                                            AS GRANTEE_NAME,
    'USER'                                                  AS GRANTEE_TYPE,
    GRANTED_BY                                              AS GRANTED_BY,
    CASE
        WHEN ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN')
        THEN 'CRITICAL'
        WHEN ROLE LIKE '%ADMIN%' THEN 'HIGH'
        WHEN ROLE LIKE '%COMPLIANCE%' THEN 'HIGH'
        ELSE 'NORMAL'
    END                                                     AS SENSITIVITY_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND DELETED_ON IS NULL

UNION ALL

SELECT
    CREATED_ON                                              AS GRANT_TIMESTAMP,
    'ROLE_GRANT'                                            AS GRANT_TYPE,
    NAME                                                    AS GRANTED_ROLE,
    GRANTEE_NAME                                            AS GRANTEE_NAME,
    'ROLE'                                                  AS GRANTEE_TYPE,
    GRANTED_BY                                              AS GRANTED_BY,
    CASE
        WHEN NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN')
        THEN 'CRITICAL'
        WHEN NAME LIKE '%ADMIN%' THEN 'HIGH'
        WHEN NAME LIKE '%COMPLIANCE%' THEN 'HIGH'
        ELSE 'NORMAL'
    END                                                     AS SENSITIVITY_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTED_ON = 'ROLE'
  AND PRIVILEGE = 'USAGE'
  AND CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND DELETED_ON IS NULL

ORDER BY GRANT_TIMESTAMP DESC;


-- ------------------------------------------------------------
-- VIEW: V_PRIVILEGE_ESCALATION_EVENTS
-- ------------------------------------------------------------
-- Detects high-risk privilege grants that could indicate
-- privilege escalation attacks or policy violations.
--
-- Monitored privileges:
--   - OWNERSHIP grants
--   - ACCOUNTADMIN/SECURITYADMIN grants
--   - APPLY MASKING POLICY / ROW ACCESS POLICY grants
--
-- Data Latency: Up to 3 hours
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_PRIVILEGE_ESCALATION_EVENTS
    COMMENT = 'High-risk privilege escalation detection. Monitors OWNERSHIP, admin role grants, and policy application privileges. Data latency: up to 3 hours. Retention: 180 days.'
AS
SELECT
    CREATED_ON                                              AS EVENT_TIMESTAMP,
    PRIVILEGE                                               AS PRIVILEGE_GRANTED,
    GRANTED_ON                                              AS OBJECT_TYPE,
    NAME                                                    AS OBJECT_NAME,
    GRANTEE_NAME                                            AS GRANTEE,
    GRANTED_BY                                              AS GRANTED_BY,
    'HIGH_RISK'                                             AS RISK_FLAG,
    CASE
        WHEN PRIVILEGE = 'OWNERSHIP' THEN 'OWNERSHIP_TRANSFER'
        WHEN PRIVILEGE IN ('APPLY MASKING POLICY', 'APPLY ROW ACCESS POLICY', 'APPLY TAG') 
        THEN 'GOVERNANCE_PRIVILEGE'
        WHEN NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN') 
        THEN 'ADMIN_ROLE_GRANT'
        ELSE 'OTHER_ESCALATION'
    END                                                     AS ESCALATION_TYPE,
    CASE
        WHEN NAME IN ('ACCOUNTADMIN', 'ORGADMIN') THEN 'CRITICAL'
        WHEN PRIVILEGE = 'OWNERSHIP' THEN 'CRITICAL'
        WHEN NAME = 'SECURITYADMIN' THEN 'HIGH'
        WHEN PRIVILEGE LIKE 'APPLY%' THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                     AS SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE (
    PRIVILEGE = 'OWNERSHIP'
    OR PRIVILEGE IN ('APPLY MASKING POLICY', 'APPLY ROW ACCESS POLICY', 'APPLY TAG')
    OR (GRANTED_ON = 'ROLE' AND NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN'))
)
AND CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
AND DELETED_ON IS NULL
ORDER BY CREATED_ON DESC;


-- ============================================================
-- SECTION 3: DATA ACCESS AUDIT
-- ============================================================
-- Track access to sensitive data, particularly PII and
-- financial data protected under SOX/SEC regulations.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_PII_DATA_ACCESS
-- ------------------------------------------------------------
-- Tracks queries that accessed PII-tagged columns.
-- Joins query history with tag references to identify
-- access to DIRECT_PII and FINANCIAL data.
--
-- IMPORTANT: This view may have significant latency as it
-- depends on TAG_REFERENCES which updates asynchronously.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_PII_DATA_ACCESS
    COMMENT = 'PII data access audit tracking queries to columns tagged as DIRECT_PII or FINANCIAL. Critical for SEC Reg S-P compliance. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    qh.DATABASE_NAME                                        AS DATABASE_ACCESSED,
    qh.SCHEMA_NAME                                          AS SCHEMA_ACCESSED,
    COALESCE(tr.OBJECT_NAME, 'UNKNOWN')                     AS TABLE_ACCESSED,
    COALESCE(tr.COLUMN_NAME, 'UNKNOWN')                     AS COLUMN_ACCESSED,
    tr.TAG_VALUE                                            AS PII_CLASSIFICATION,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    qh.TOTAL_ELAPSED_TIME / 1000                            AS EXECUTION_SECONDS,
    CASE
        WHEN tr.TAG_VALUE = 'DIRECT_PII' THEN 'CRITICAL'
        WHEN tr.TAG_VALUE = 'FINANCIAL' THEN 'HIGH'
        WHEN tr.TAG_VALUE = 'QUASI_PII' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS SENSITIVITY_LEVEL,
    CASE
        WHEN qh.ROLE_NAME NOT IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
             AND tr.TAG_VALUE = 'DIRECT_PII'
        THEN 'POTENTIAL_VIOLATION'
        ELSE 'AUTHORIZED'
    END                                                     AS ACCESS_ASSESSMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
    AND tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
    AND tr.TAG_SCHEMA = 'TAGS'
    AND tr.TAG_NAME = 'PII_CLASSIFICATION'
    AND tr.TAG_VALUE IN ('DIRECT_PII', 'QUASI_PII', 'FINANCIAL')
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND qh.WAREHOUSE_NAME LIKE 'INV_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH'
  AND qh.QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'MERGE', 'DELETE')
  AND tr.TAG_VALUE IS NOT NULL
ORDER BY qh.START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_MASKING_POLICY_USAGE
-- ------------------------------------------------------------
-- Tracks tables and columns with masking policies applied.
-- Shows where data masking is actively protecting data.
--
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_MASKING_POLICY_USAGE
    COMMENT = 'Masking policy application audit showing which columns are protected by masking policies. Data latency: up to 3 hours.'
AS
SELECT
    pr.POLICY_NAME                                          AS MASKING_POLICY_NAME,
    pr.POLICY_DB                                            AS POLICY_DATABASE,
    pr.POLICY_SCHEMA                                        AS POLICY_SCHEMA,
    pr.REF_DATABASE_NAME                                    AS PROTECTED_DATABASE,
    pr.REF_SCHEMA_NAME                                      AS PROTECTED_SCHEMA,
    pr.REF_ENTITY_NAME                                      AS PROTECTED_TABLE,
    pr.REF_COLUMN_NAME                                      AS PROTECTED_COLUMN,
    pr.REF_ENTITY_DOMAIN                                    AS OBJECT_TYPE,
    mp.POLICY_OWNER                                         AS POLICY_OWNER,
    mp.CREATED                                              AS POLICY_CREATED,
    CASE
        WHEN pr.POLICY_NAME LIKE '%CLIENT_PII%' THEN 'CRITICAL'
        WHEN pr.POLICY_NAME LIKE '%ACCOUNT%' THEN 'HIGH'
        WHEN pr.POLICY_NAME LIKE '%FINANCIAL%' THEN 'HIGH'
        ELSE 'STANDARD'
    END                                                     AS PROTECTION_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
JOIN SNOWFLAKE.ACCOUNT_USAGE.MASKING_POLICIES mp
    ON pr.POLICY_NAME = mp.POLICY_NAME
    AND pr.POLICY_DB = mp.POLICY_CATALOG
    AND pr.POLICY_SCHEMA = mp.POLICY_SCHEMA
WHERE pr.POLICY_KIND = 'MASKING_POLICY'
  AND pr.REF_DATABASE_NAME LIKE 'INV_%'
  AND mp.DELETED IS NULL
ORDER BY pr.POLICY_NAME, pr.REF_DATABASE_NAME, pr.REF_SCHEMA_NAME;


-- ------------------------------------------------------------
-- VIEW: V_ROW_ACCESS_POLICY_USAGE
-- ------------------------------------------------------------
-- Tracks tables with row access policies applied.
-- Shows row-level security enforcement patterns.
--
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_ROW_ACCESS_POLICY_USAGE
    COMMENT = 'Row access policy application audit showing which tables have row-level security. Data latency: up to 3 hours.'
AS
SELECT
    pr.POLICY_NAME                                          AS ROW_ACCESS_POLICY_NAME,
    pr.POLICY_DB                                            AS POLICY_DATABASE,
    pr.POLICY_SCHEMA                                        AS POLICY_SCHEMA,
    pr.REF_DATABASE_NAME                                    AS PROTECTED_DATABASE,
    pr.REF_SCHEMA_NAME                                      AS PROTECTED_SCHEMA,
    pr.REF_ENTITY_NAME                                      AS PROTECTED_TABLE,
    pr.REF_ENTITY_DOMAIN                                    AS OBJECT_TYPE,
    rap.POLICY_OWNER                                        AS POLICY_OWNER,
    rap.CREATED                                             AS POLICY_CREATED,
    CASE
        WHEN pr.POLICY_NAME LIKE '%CLIENT_TIER%' THEN 'HIGH'
        WHEN pr.POLICY_NAME LIKE '%DATA_QUALITY%' THEN 'MEDIUM'
        ELSE 'STANDARD'
    END                                                     AS PROTECTION_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
JOIN SNOWFLAKE.ACCOUNT_USAGE.ROW_ACCESS_POLICIES rap
    ON pr.POLICY_NAME = rap.POLICY_NAME
    AND pr.POLICY_DB = rap.POLICY_CATALOG
    AND pr.POLICY_SCHEMA = rap.POLICY_SCHEMA
WHERE pr.POLICY_KIND = 'ROW_ACCESS_POLICY'
  AND pr.REF_DATABASE_NAME LIKE 'INV_%'
  AND rap.DELETED IS NULL
ORDER BY pr.POLICY_NAME, pr.REF_DATABASE_NAME, pr.REF_SCHEMA_NAME;


-- ============================================================
-- SECTION 4: GOVERNANCE CHANGE AUDIT
-- ============================================================
-- Track changes to governance objects including tags and
-- data protection policies.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_TAG_CHANGE_HISTORY
-- ------------------------------------------------------------
-- Tracks tag-related DDL operations including:
--   - CREATE/ALTER/DROP TAG
--   - SET TAG / UNSET TAG on objects
--
-- Data Latency: Up to 45 minutes
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_TAG_CHANGE_HISTORY
    COMMENT = 'Tag governance change audit tracking CREATE/ALTER/DROP TAG and SET/UNSET TAG operations. Data latency: up to 45 minutes. Retention: 180 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS CHANGE_TIMESTAMP,
    USER_NAME                                               AS CHANGED_BY,
    ROLE_NAME                                               AS ROLE_USED,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    LEFT(QUERY_TEXT, 1000)                                  AS DDL_STATEMENT,
    EXECUTION_STATUS                                        AS STATUS,
    ERROR_CODE                                              AS ERROR_CODE,
    ERROR_MESSAGE                                           AS ERROR_MESSAGE,
    CASE
        WHEN QUERY_TEXT ILIKE '%DROP TAG%' THEN 'CRITICAL'
        WHEN QUERY_TEXT ILIKE '%UNSET TAG%' THEN 'HIGH'
        WHEN QUERY_TEXT ILIKE '%ALTER TAG%' THEN 'MEDIUM'
        WHEN QUERY_TEXT ILIKE '%SET TAG%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS CHANGE_SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND (
    QUERY_TEXT ILIKE '%CREATE TAG%'
    OR QUERY_TEXT ILIKE '%ALTER TAG%'
    OR QUERY_TEXT ILIKE '%DROP TAG%'
    OR QUERY_TEXT ILIKE '%SET TAG%'
    OR QUERY_TEXT ILIKE '%UNSET TAG%'
  )
  AND QUERY_TYPE IN ('CREATE', 'ALTER', 'DROP', 'ALTER_TABLE', 'ALTER_TABLE_MODIFY_COLUMN')
ORDER BY START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_POLICY_CHANGE_HISTORY
-- ------------------------------------------------------------
-- Tracks policy-related DDL operations including:
--   - CREATE/ALTER/DROP MASKING POLICY
--   - CREATE/ALTER/DROP ROW ACCESS POLICY
--
-- Data Latency: Up to 45 minutes
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_POLICY_CHANGE_HISTORY
    COMMENT = 'Policy governance change audit tracking CREATE/ALTER/DROP for masking and row access policies. Data latency: up to 45 minutes. Retention: 180 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS CHANGE_TIMESTAMP,
    USER_NAME                                               AS CHANGED_BY,
    ROLE_NAME                                               AS ROLE_USED,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    LEFT(QUERY_TEXT, 1000)                                  AS DDL_STATEMENT,
    EXECUTION_STATUS                                        AS STATUS,
    ERROR_CODE                                              AS ERROR_CODE,
    ERROR_MESSAGE                                           AS ERROR_MESSAGE,
    CASE
        WHEN QUERY_TEXT ILIKE '%MASKING POLICY%' THEN 'MASKING_POLICY'
        WHEN QUERY_TEXT ILIKE '%ROW ACCESS POLICY%' THEN 'ROW_ACCESS_POLICY'
        ELSE 'OTHER_POLICY'
    END                                                     AS POLICY_TYPE,
    CASE
        WHEN QUERY_TEXT ILIKE '%DROP%POLICY%' THEN 'CRITICAL'
        WHEN QUERY_TEXT ILIKE '%ALTER%POLICY%' THEN 'HIGH'
        WHEN QUERY_TEXT ILIKE '%CREATE%POLICY%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS CHANGE_SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND (
    QUERY_TEXT ILIKE '%MASKING POLICY%'
    OR QUERY_TEXT ILIKE '%ROW ACCESS POLICY%'
  )
  AND QUERY_TYPE IN ('CREATE_MASKING_POLICY', 'CREATE_ROW_ACCESS_POLICY', 
                     'ALTER_MASKING_POLICY', 'ALTER_ROW_ACCESS_POLICY',
                     'DROP_MASKING_POLICY', 'DROP_ROW_ACCESS_POLICY',
                     'CREATE', 'ALTER', 'DROP')
ORDER BY START_TIME DESC;


-- ============================================================
-- SECTION 5: DATA QUALITY & COMPLIANCE MONITORING
-- ============================================================
-- Monitor access attempts to quarantined data and
-- highly confidential financial information.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_QUARANTINED_DATA_ACCESS_ATTEMPTS
-- ------------------------------------------------------------
-- Detects queries attempting to access data tagged as
-- QUARANTINED. This data has failed quality checks and
-- should not be used in production analytics.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_QUARANTINED_DATA_ACCESS_ATTEMPTS
    COMMENT = 'Data quality compliance monitoring detecting access attempts to QUARANTINED data. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    tr.OBJECT_DATABASE                                      AS DATABASE_ACCESSED,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_ACCESSED,
    tr.OBJECT_NAME                                          AS TABLE_ACCESSED,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    'QUARANTINED_ACCESS'                                    AS VIOLATION_TYPE,
    'HIGH'                                                  AS SEVERITY,
    CASE
        WHEN qh.ROLE_NAME IN ('INV_DATA_ENGINEER', 'INV_DATA_ADMIN', 'ACCOUNTADMIN')
        THEN 'REMEDIATION_ACCESS'
        ELSE 'POTENTIAL_VIOLATION'
    END                                                     AS ACCESS_ASSESSMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND (qh.WAREHOUSE_NAME LIKE 'INV_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH')
  AND tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'TAGS'
  AND tr.TAG_NAME = 'DATA_QUALITY_STATUS'
  AND tr.TAG_VALUE = 'QUARANTINED'
ORDER BY qh.START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_RETAIL_CLIENT_DATA_ACCESS
-- ------------------------------------------------------------
-- Monitors all access attempts to retail client data protected
-- under SEC Regulation S-P (client privacy).
--
-- SEC Regulation S-P requires:
--   - Protection of client nonpublic personal information
--   - Strict access controls
--   - Audit trails of all access
--
-- Flags access by roles other than DATA_ADMIN and ANALYST.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_RETAIL_CLIENT_DATA_ACCESS
    COMMENT = 'SEC Reg S-P compliance monitoring tracking all access to retail client data. Flags unauthorized access. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    tr.OBJECT_DATABASE                                      AS DATABASE_ACCESSED,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_ACCESSED,
    tr.OBJECT_NAME                                          AS TABLE_ACCESSED,
    tr.COLUMN_NAME                                          AS COLUMN_ACCESSED,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    'SEC_REG_SP_ACCESS'                                     AS REGULATORY_CATEGORY,
    CASE
        WHEN qh.ROLE_NAME IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
        THEN 'AUTHORIZED'
        ELSE 'REQUIRES_REVIEW'
    END                                                     AS ACCESS_AUTHORIZATION,
    CASE
        WHEN qh.ROLE_NAME NOT IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
        THEN 'CRITICAL'
        ELSE 'LOGGED'
    END                                                     AS SEVERITY,
    CASE
        WHEN qh.ROLE_NAME NOT IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
        THEN 'Verify business need for retail client PII access'
        ELSE 'Authorized client data access'
    END                                                     AS COMPLIANCE_NOTE
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND (qh.WAREHOUSE_NAME LIKE 'INV_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH')
  AND tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'TAGS'
  AND tr.TAG_NAME = 'PII_CLASSIFICATION'
  AND tr.TAG_VALUE = 'DIRECT_PII'
  AND qh.QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'MERGE', 'DELETE')
ORDER BY qh.START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_HIGHLY_CONFIDENTIAL_DATA_ACCESS
-- ------------------------------------------------------------
-- Monitors all access to HIGHLY_CONFIDENTIAL data including:
--   - Proprietary trading strategies
--   - Client wealth information
--   - Unreleased financial reports
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_HIGHLY_CONFIDENTIAL_DATA_ACCESS
    COMMENT = 'Highly confidential data access monitoring for proprietary strategies and sensitive financial data. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    tr.OBJECT_DATABASE                                      AS DATABASE_ACCESSED,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_ACCESSED,
    tr.OBJECT_NAME                                          AS TABLE_ACCESSED,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    'HIGHLY_CONFIDENTIAL_ACCESS'                            AS ACCESS_CATEGORY,
    CASE
        WHEN qh.ROLE_NAME IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'INV_ML_ADMIN', 'ACCOUNTADMIN')
        THEN 'AUTHORIZED'
        ELSE 'REQUIRES_REVIEW'
    END                                                     AS ACCESS_AUTHORIZATION,
    CASE
        WHEN qh.ROLE_NAME NOT IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'INV_ML_ADMIN', 'ACCOUNTADMIN')
        THEN 'HIGH'
        ELSE 'LOGGED'
    END                                                     AS SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND (qh.WAREHOUSE_NAME LIKE 'INV_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH')
  AND tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'TAGS'
  AND tr.TAG_NAME = 'DATA_SENSITIVITY'
  AND tr.TAG_VALUE = 'HIGHLY_CONFIDENTIAL'
  AND qh.QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'MERGE', 'DELETE')
ORDER BY qh.START_TIME DESC;


-- ============================================================
-- SECTION 6: TRADING & TRANSACTION AUDIT
-- ============================================================
-- Track access to trading and transaction data for
-- FINRA Rule 3110 supervision compliance.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_TRADING_DATA_ACCESS
-- ------------------------------------------------------------
-- Monitors access to transaction and trading data.
-- Supports FINRA Rule 3110 supervision requirements.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_TRADING_DATA_ACCESS
    COMMENT = 'Trading data access audit for FINRA Rule 3110 supervision compliance. Tracks all access to transaction-related data. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    tr.OBJECT_DATABASE                                      AS DATABASE_ACCESSED,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_ACCESSED,
    tr.OBJECT_NAME                                          AS TABLE_ACCESSED,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    qh.ROWS_PRODUCED                                        AS ROWS_RETURNED,
    'FINRA_3110_SUPERVISION'                                AS REGULATORY_CATEGORY,
    CASE
        WHEN qh.QUERY_TEXT ILIKE '%DELETE%' OR qh.QUERY_TEXT ILIKE '%UPDATE%'
        THEN 'HIGH'
        WHEN qh.ROWS_PRODUCED > 10000 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND (qh.WAREHOUSE_NAME LIKE 'INV_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH')
  AND tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'TAGS'
  AND tr.TAG_NAME = 'DATA_DOMAIN'
  AND tr.TAG_VALUE = 'TRANSACTIONS'
  AND qh.QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'MERGE', 'DELETE')
ORDER BY qh.START_TIME DESC;


-- ============================================================
-- SECTION 7: WAREHOUSE & SESSION AUDIT
-- ============================================================
-- Track session activity and administrative operations.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_SESSION_HISTORY
-- ------------------------------------------------------------
-- Comprehensive session tracking including client details,
-- authentication method, and session duration.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_SESSION_HISTORY
    COMMENT = 'Session audit log tracking user sessions including client app, IP, and duration. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    SESSION_ID                                              AS SESSION_ID,
    USER_NAME                                               AS USER_NAME,
    CREATED_ON                                              AS LOGIN_TIME,
    DESTROYED_ON                                            AS LOGOUT_TIME,
    DATEDIFF(MINUTE, CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))
                                                            AS SESSION_DURATION_MINUTES,
    CLIENT_APPLICATION_ID                                   AS CLIENT_APPLICATION,
    CLIENT_APPLICATION_VERSION                              AS CLIENT_VERSION,
    CLIENT_ENVIRONMENT                                      AS CLIENT_ENVIRONMENT,
    AUTHENTICATION_METHOD                                   AS AUTH_METHOD,
    CASE
        WHEN DATEDIFF(HOUR, CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP())) > 8
        THEN 'EXTENDED_SESSION'
        WHEN AUTHENTICATION_METHOD NOT LIKE '%MFA%' AND AUTHENTICATION_METHOD NOT LIKE '%MULTI%'
        THEN 'NO_MFA'
        ELSE 'NORMAL'
    END                                                     AS SESSION_FLAG
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE CREATED_ON >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC;


-- ------------------------------------------------------------
-- VIEW: V_ADMIN_ACTIVITY
-- ------------------------------------------------------------
-- Tracks all activity performed using administrative roles:
--   - ACCOUNTADMIN
--   - SECURITYADMIN
--   - SYSADMIN
--
-- Critical for SOX separation of duties compliance.
--
-- Data Latency: Up to 45 minutes
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_ADMIN_ACTIVITY
    COMMENT = 'Administrative activity audit tracking all operations performed as ACCOUNTADMIN, SECURITYADMIN, or SYSADMIN. SOX compliance requirement. Data latency: up to 45 minutes. Retention: 90 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS ACTIVITY_TIMESTAMP,
    USER_NAME                                               AS USER_NAME,
    ROLE_NAME                                               AS ADMIN_ROLE,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    WAREHOUSE_NAME                                          AS WAREHOUSE_NAME,
    LEFT(QUERY_TEXT, 500)                                   AS QUERY_TEXT_PREVIEW,
    EXECUTION_STATUS                                        AS STATUS,
    TOTAL_ELAPSED_TIME / 1000                               AS EXECUTION_SECONDS,
    ROWS_PRODUCED                                           AS ROWS_AFFECTED,
    CASE
        WHEN ROLE_NAME = 'ACCOUNTADMIN' THEN 'CRITICAL'
        WHEN ROLE_NAME = 'SECURITYADMIN' THEN 'HIGH'
        WHEN ROLE_NAME = 'SYSADMIN' THEN 'MEDIUM'
        ELSE 'OTHER'
    END                                                     AS PRIVILEGE_LEVEL,
    CASE
        WHEN QUERY_TYPE IN ('GRANT', 'REVOKE') THEN 'PRIVILEGE_CHANGE'
        WHEN QUERY_TYPE IN ('CREATE_USER', 'ALTER_USER', 'DROP_USER') THEN 'USER_MANAGEMENT'
        WHEN QUERY_TYPE IN ('CREATE_ROLE', 'DROP_ROLE') THEN 'ROLE_MANAGEMENT'
        WHEN QUERY_TYPE LIKE 'CREATE%' OR QUERY_TYPE LIKE 'DROP%' THEN 'DDL_OPERATION'
        ELSE 'OTHER_OPERATION'
    END                                                     AS ACTIVITY_CATEGORY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND ROLE_NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN')
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC;


-- ============================================================
-- SECTION 8: SEC 17a-4 RETENTION COMPLIANCE
-- ============================================================
-- Monitor data retention compliance for SEC requirements.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_RETENTION_COMPLIANCE_STATUS
-- ------------------------------------------------------------
-- Tracks data retention status against SEC 17a-4 requirements.
-- Shows which objects have retention tags and their status.
--
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_RETENTION_COMPLIANCE_STATUS
    COMMENT = 'SEC 17a-4 retention compliance status showing data retention policy adherence. Data latency: up to 3 hours.'
AS
SELECT
    tr.OBJECT_DATABASE                                      AS DATABASE_NAME,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_NAME,
    tr.OBJECT_NAME                                          AS TABLE_NAME,
    tr.TAG_VALUE                                            AS RETENTION_POLICY,
    t.CREATED                                               AS TABLE_CREATED,
    t.ROW_COUNT                                             AS ROW_COUNT,
    t.BYTES / (1024*1024*1024)                              AS SIZE_GB,
    CASE
        WHEN tr.TAG_VALUE = '7_YEARS' THEN DATEADD(YEAR, 7, t.CREATED)
        WHEN tr.TAG_VALUE = '10_YEARS' THEN DATEADD(YEAR, 10, t.CREATED)
        WHEN tr.TAG_VALUE = 'PERMANENT' THEN NULL
        WHEN tr.TAG_VALUE = '1_YEAR' THEN DATEADD(YEAR, 1, t.CREATED)
        ELSE NULL
    END                                                     AS EARLIEST_DELETION_DATE,
    CASE
        WHEN tr.TAG_VALUE = 'PERMANENT' THEN 'NEVER_DELETE'
        WHEN tr.TAG_VALUE IS NULL THEN 'UNTAGGED_REVIEW_REQUIRED'
        ELSE 'RETENTION_ACTIVE'
    END                                                     AS RETENTION_STATUS,
    '17a-4'                                                 AS REGULATORY_REFERENCE
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
JOIN SNOWFLAKE.ACCOUNT_USAGE.TABLES t
    ON tr.OBJECT_DATABASE = t.TABLE_CATALOG
    AND tr.OBJECT_SCHEMA = t.TABLE_SCHEMA
    AND tr.OBJECT_NAME = t.TABLE_NAME
WHERE tr.TAG_DATABASE = 'INV_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'TAGS'
  AND tr.TAG_NAME = 'RETENTION_POLICY'
  AND tr.OBJECT_DATABASE LIKE 'INV_%'
  AND t.DELETED IS NULL
ORDER BY tr.OBJECT_DATABASE, tr.OBJECT_SCHEMA, tr.OBJECT_NAME;


-- ============================================================
-- SECTION 9: RISK SCORING VIEW
-- ============================================================
-- Aggregate risk metrics per user for security monitoring.
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_SECURITY_RISK_SCORE
-- ------------------------------------------------------------
-- Computes a security risk score for each user based on:
--   +50  ACCOUNTADMIN usage
--   +30  Privilege escalation grants
--   +25  Access to DIRECT_PII data
--   +40  Access to HIGHLY_CONFIDENTIAL data
--   +20  Multiple failed logins
--
-- Risk Levels:
--   0-25   LOW
--   26-50  MEDIUM
--   51-100 HIGH
--   101+   CRITICAL
--
-- Data Latency: Depends on source views (up to 3 hours)
-- Retention: Based on 90-day query history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW INV_GOVERNANCE_DB.AUDIT.V_SECURITY_RISK_SCORE
    COMMENT = 'User security risk scoring based on admin usage, privilege escalations, PII access, and failed logins. Risk levels: LOW (0-25), MEDIUM (26-50), HIGH (51-100), CRITICAL (101+).'
AS
WITH admin_usage AS (
    SELECT 
        USER_NAME,
        COUNT(*) AS admin_query_count,
        50 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE ROLE_NAME = 'ACCOUNTADMIN'
      AND START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND EXECUTION_STATUS = 'SUCCESS'
    GROUP BY USER_NAME
),
privilege_escalations AS (
    SELECT
        GRANTED_BY AS USER_NAME,
        COUNT(*) AS escalation_count,
        30 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
    WHERE (
        PRIVILEGE = 'OWNERSHIP'
        OR NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN')
    )
    AND CREATED_ON >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
    AND DELETED_ON IS NULL
    GROUP BY GRANTED_BY
),
direct_pii_access AS (
    SELECT
        qh.USER_NAME,
        COUNT(*) AS pii_access_count,
        25 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
        ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND tr.TAG_NAME = 'PII_CLASSIFICATION'
      AND tr.TAG_VALUE = 'DIRECT_PII'
    GROUP BY qh.USER_NAME
),
confidential_access AS (
    SELECT
        qh.USER_NAME,
        COUNT(*) AS confidential_access_count,
        40 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
        ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND tr.TAG_NAME = 'DATA_SENSITIVITY'
      AND tr.TAG_VALUE = 'HIGHLY_CONFIDENTIAL'
      AND qh.ROLE_NAME NOT IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
    GROUP BY qh.USER_NAME
),
failed_logins AS (
    SELECT
        USER_NAME,
        COUNT(*) AS failed_login_count,
        20 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE IS_SUCCESS = 'NO'
      AND EVENT_TIMESTAMP >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
    GROUP BY USER_NAME
    HAVING COUNT(*) >= 3
),
all_users AS (
    SELECT DISTINCT USER_NAME 
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY 
    WHERE START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
)
SELECT
    u.USER_NAME                                             AS USER_NAME,
    COALESCE(au.admin_query_count, 0)                       AS ACCOUNTADMIN_QUERIES,
    COALESCE(pe.escalation_count, 0)                        AS PRIVILEGE_ESCALATIONS,
    COALESCE(dpa.pii_access_count, 0)                       AS PII_ACCESS_COUNT,
    COALESCE(ca.confidential_access_count, 0)               AS CONFIDENTIAL_ACCESS_COUNT,
    COALESCE(fl.failed_login_count, 0)                      AS FAILED_LOGINS,
    (
        CASE WHEN au.USER_NAME IS NOT NULL THEN au.risk_points ELSE 0 END +
        CASE WHEN pe.USER_NAME IS NOT NULL THEN pe.risk_points ELSE 0 END +
        CASE WHEN dpa.USER_NAME IS NOT NULL THEN dpa.risk_points ELSE 0 END +
        CASE WHEN ca.USER_NAME IS NOT NULL THEN ca.risk_points ELSE 0 END +
        CASE WHEN fl.USER_NAME IS NOT NULL THEN fl.risk_points ELSE 0 END
    )                                                       AS RISK_SCORE,
    CASE
        WHEN (
            CASE WHEN au.USER_NAME IS NOT NULL THEN au.risk_points ELSE 0 END +
            CASE WHEN pe.USER_NAME IS NOT NULL THEN pe.risk_points ELSE 0 END +
            CASE WHEN dpa.USER_NAME IS NOT NULL THEN dpa.risk_points ELSE 0 END +
            CASE WHEN ca.USER_NAME IS NOT NULL THEN ca.risk_points ELSE 0 END +
            CASE WHEN fl.USER_NAME IS NOT NULL THEN fl.risk_points ELSE 0 END
        ) >= 101 THEN 'CRITICAL'
        WHEN (
            CASE WHEN au.USER_NAME IS NOT NULL THEN au.risk_points ELSE 0 END +
            CASE WHEN pe.USER_NAME IS NOT NULL THEN pe.risk_points ELSE 0 END +
            CASE WHEN dpa.USER_NAME IS NOT NULL THEN dpa.risk_points ELSE 0 END +
            CASE WHEN ca.USER_NAME IS NOT NULL THEN ca.risk_points ELSE 0 END +
            CASE WHEN fl.USER_NAME IS NOT NULL THEN fl.risk_points ELSE 0 END
        ) >= 51 THEN 'HIGH'
        WHEN (
            CASE WHEN au.USER_NAME IS NOT NULL THEN au.risk_points ELSE 0 END +
            CASE WHEN pe.USER_NAME IS NOT NULL THEN pe.risk_points ELSE 0 END +
            CASE WHEN dpa.USER_NAME IS NOT NULL THEN dpa.risk_points ELSE 0 END +
            CASE WHEN ca.USER_NAME IS NOT NULL THEN ca.risk_points ELSE 0 END +
            CASE WHEN fl.USER_NAME IS NOT NULL THEN fl.risk_points ELSE 0 END
        ) >= 26 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL,
    CURRENT_TIMESTAMP()                                     AS SCORE_CALCULATED_AT
FROM all_users u
LEFT JOIN admin_usage au ON u.USER_NAME = au.USER_NAME
LEFT JOIN privilege_escalations pe ON u.USER_NAME = pe.USER_NAME
LEFT JOIN direct_pii_access dpa ON u.USER_NAME = dpa.USER_NAME
LEFT JOIN confidential_access ca ON u.USER_NAME = ca.USER_NAME
LEFT JOIN failed_logins fl ON u.USER_NAME = fl.USER_NAME
ORDER BY RISK_SCORE DESC;


-- ============================================================
-- SECTION 10: SECURITY GRANTS
-- ============================================================
-- Grant access to audit views for compliance and platform
-- administration. Restrict from analyst and readonly roles.
-- ============================================================

GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.AUDIT
    TO ROLE INV_DATA_ADMIN;

GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.AUDIT
    TO ROLE INV_ML_ADMIN;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.AUDIT
    TO ROLE INV_DATA_ADMIN;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.AUDIT
    TO ROLE INV_ML_ADMIN;


-- ============================================================
-- SECTION 11: VERIFICATION QUERIES
-- ============================================================
-- Verify successful deployment of audit views.
-- ============================================================

SHOW VIEWS IN SCHEMA INV_GOVERNANCE_DB.AUDIT;

SHOW GRANTS TO ROLE INV_DATA_ADMIN;


-- ============================================================
-- PHASE 09 COMPLETE
-- ============================================================
-- Enterprise Audit & Compliance Framework deployed with:
--
-- SECURITY EVENT VIEWS (3):
--   - V_LOGIN_HISTORY
--   - V_ROLE_GRANT_HISTORY
--   - V_PRIVILEGE_ESCALATION_EVENTS
--
-- DATA ACCESS VIEWS (3):
--   - V_PII_DATA_ACCESS
--   - V_MASKING_POLICY_USAGE
--   - V_ROW_ACCESS_POLICY_USAGE
--
-- GOVERNANCE CHANGE VIEWS (2):
--   - V_TAG_CHANGE_HISTORY
--   - V_POLICY_CHANGE_HISTORY
--
-- COMPLIANCE MONITORING VIEWS (4):
--   - V_QUARANTINED_DATA_ACCESS_ATTEMPTS
--   - V_RETAIL_CLIENT_DATA_ACCESS
--   - V_HIGHLY_CONFIDENTIAL_DATA_ACCESS
--   - V_TRADING_DATA_ACCESS
--
-- RETENTION COMPLIANCE (1):
--   - V_RETENTION_COMPLIANCE_STATUS
--
-- SESSION & ADMIN VIEWS (2):
--   - V_SESSION_HISTORY
--   - V_ADMIN_ACTIVITY
--
-- RISK SCORING (1):
--   - V_SECURITY_RISK_SCORE
--
-- TOTAL VIEWS: 16
--
-- ACCESS GRANTED TO:
--   - INV_DATA_ADMIN
--   - INV_ML_ADMIN
--
-- REGULATORY COMPLIANCE ADDRESSED:
--   - SOX Section 404: Internal controls audit
--   - SEC Regulation S-P: Client privacy monitoring
--   - SEC Rule 17a-4: Records retention tracking
--   - FINRA Rule 3110: Trading supervision
--
-- NEXT STEPS:
--   1. Configure alerting on high-risk events
--   2. Set up scheduled reports for compliance review
--   3. Integrate with SIEM if applicable
--   4. Create dashboards for security monitoring
--   5. Schedule quarterly compliance reviews
-- ============================================================
