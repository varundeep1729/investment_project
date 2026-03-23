-- ============================================================
-- INVESTMENT DOMAIN - SNOWFLAKE DATA PLATFORM
-- ============================================================
-- Phase 01: Account Administration
-- Script: 01_account_administration.sql
-- Version: 2.0.0
--
-- Change Reason: Configured for Investment/Finance domain
--               (Stocks, Mutual Funds, ETFs, Portfolio Management)
--               INV_GOVERNANCE_DB.SECURITY schema created as Phase 01
--               bootstrap prerequisite for security policy objects.
--               All remaining governance schemas (POLICIES, TAGS,
--               DATA_QUALITY, AUDIT) are created in Phase 04.
--
-- Description:
--   Configures account-level security settings for a SOX/SEC/FINRA
--   compliant financial services Snowflake environment. Creates
--   INV_GOVERNANCE_DB and INV_GOVERNANCE_DB.SECURITY as a bootstrap
--   step — these are required by Phase 01 to house security policy
--   objects before any other phase runs. Phase 04 completes the full
--   governance database structure.
--
-- Scope: Investment data across 4 domains (MARKET_DATA, PORTFOLIO,
--        REFERENCE, ANALYTICS) supporting Medallion Architecture
--
-- Prerequisites:
--   - Must be executed as ACCOUNTADMIN
--   - Snowflake Enterprise Edition or higher
--   - Appropriate compliance agreements in place
--
-- Execution Order:
--   Phase 01 (this file) → Phase 02 → Phase 03 → Phase 04 → Phase 05
--
-- !! WARNING !!
--   This script configures ACCOUNT-LEVEL settings affecting ALL users.
--   Network policy misconfiguration can lock out all users.
--   INV_GOVERNANCE_DB.SECURITY is created here as a bootstrap
--   prerequisite only. Do not add non-security objects to this schema.
--   All other governance schemas are managed exclusively by Phase 04.
--
-- Regulatory Framework:
--   - SOX (Sarbanes-Oxley Act) - Financial reporting controls
--   - SEC Rule 17a-4 - Records retention requirements
--   - FINRA Rules - Broker-dealer compliance
--   - PCI-DSS - Payment card data security (if applicable)
--
-- Author: Investment Domain Platform Team
-- Date: 2026-03-03
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: GOVERNANCE DATABASE BOOTSTRAP
-- ============================================================
-- INV_GOVERNANCE_DB and its SECURITY schema are created
-- here as a Phase 01 bootstrap prerequisite ONLY.
--
-- Reason: Password policies, session policies, and network rules
-- must live in a named schema. These objects are required by
-- Phase 01 and must exist before any other phase runs.
--
-- Phase 04 will create the remaining governance schemas:
--   INV_GOVERNANCE_DB.POLICIES
--   INV_GOVERNANCE_DB.TAGS
--   INV_GOVERNANCE_DB.DATA_QUALITY
--   INV_GOVERNANCE_DB.AUDIT
--   INV_GOVERNANCE_DB.MONITORING
--
-- Do NOT create any non-security objects in this schema.
-- Do NOT create any other schemas in INV_GOVERNANCE_DB here.
-- ============================================================

CREATE DATABASE IF NOT EXISTS INV_GOVERNANCE_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Central governance database for Investment Domain Platform. Houses security policies (Phase 01), data governance policies, tags, data quality rules, monitoring views, and audit logs (Phase 04). Supports SOX/SEC/FINRA compliance requirements for financial services.';

CREATE SCHEMA IF NOT EXISTS INV_GOVERNANCE_DB.SECURITY
    COMMENT = 'Bootstrap schema created in Phase 01. Houses account-level security objects: network rules, password policies, session policies. Created before all other phases as a prerequisite for policy application. Managed by ACCOUNTADMIN and INV_DATA_ADMIN.';

-- Verification
SHOW SCHEMAS IN DATABASE INV_GOVERNANCE_DB;

-- ============================================================
-- SECTION 2: NETWORK POLICY
-- ============================================================
-- Regulatory Reference: SOX Section 404 - Internal Controls
--                      FINRA Rule 4370 - Business Continuity
-- Restricts Snowflake access to approved IP ranges only.
-- All connections from outside approved ranges are rejected.
-- Critical for protecting sensitive financial data (PII, 
-- portfolio positions, trading data).
-- ============================================================

-- !! PLACEHOLDER IP - Replace before production !!
-- Production should include:
--   - Corporate office IPs (trading floor, operations)
--   - VPN gateway endpoints
--   - CI/CD runner IPs (GitHub Actions, Azure DevOps)
--   - Approved third-party vendor IPs (Bloomberg, Reuters feeds)
--   - Cloud service provider NAT gateways
ALTER ACCOUNT UNSET NETWORK_POLICY;
DROP NETWORK POLICY IF EXISTS INV_NETWORK_POLICY;

CREATE OR REPLACE NETWORK RULE INV_GOVERNANCE_DB.SECURITY.INV_ALLOWED_IPS
    TYPE = IPV4
    VALUE_LIST = ('0.0.0.0/0')
    MODE = INGRESS
    COMMENT = 'PLACEHOLDER - Replace with production IP ranges before go-live. Should include: corporate office IPs, VPN gateway IPs, trading floor network, market data vendor IPs, CI/CD runner IPs, cloud NAT gateway IPs.';

CREATE OR REPLACE NETWORK POLICY INV_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('INV_GOVERNANCE_DB.SECURITY.INV_ALLOWED_IPS')
    COMMENT = 'Primary account-level network policy per SOX Section 404 Internal Controls and FINRA cybersecurity requirements. Applied at account level — affects all users, service accounts, and API connections.';

-- Apply network policy at account level
ALTER ACCOUNT SET NETWORK_POLICY = INV_NETWORK_POLICY;

-- Verification
SHOW NETWORK POLICIES LIKE 'INV%';

-- ============================================================
-- SECTION 3: PASSWORD POLICY
-- ============================================================
-- Regulatory Reference: SOX Section 404 - Access Controls
--                      FINRA Rule 3110 - Supervision
--                      SEC Regulation S-P - Privacy of Consumer Info
-- Enforces strong password requirements for all human users.
-- Note: Service accounts (SVC_ETL_INVESTMENT, SVC_DATA_FEEDS)
-- should use key-pair authentication and bypass password policy.
-- ============================================================

ALTER ACCOUNT UNSET PASSWORD POLICY;

CREATE OR REPLACE PASSWORD POLICY INV_GOVERNANCE_DB.SECURITY.INV_PASSWORD_POLICY
    PASSWORD_MIN_LENGTH = 14
    PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2
    PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2
    PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1
    PASSWORD_MAX_AGE_DAYS = 90
    PASSWORD_MAX_RETRIES = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30
    PASSWORD_HISTORY = 12
    COMMENT = 'Financial services compliant password policy (SOX/FINRA): 14+ chars, mixed case required, numeric and special chars required, 90-day expiry, 12-password history, 30-min lockout after 5 failed attempts. Applied at account level. Exceeds industry baseline for investment platforms.';

-- Apply password policy at account level
ALTER ACCOUNT SET PASSWORD POLICY INV_GOVERNANCE_DB.SECURITY.INV_PASSWORD_POLICY;

-- Verification
DESCRIBE PASSWORD POLICY INV_GOVERNANCE_DB.SECURITY.INV_PASSWORD_POLICY;

-- ============================================================
-- SECTION 4: SESSION POLICY
-- ============================================================
-- Regulatory Reference: SOX Section 404 - Logical Access Controls
--                      SEC Cybersecurity Requirements
--                      FINRA Rule 4370 - BCP Requirements
-- Forces session termination after period of inactivity.
-- Prevents unauthorized access from unattended workstations.
-- Critical for trading floors and portfolio management systems.
-- ============================================================

ALTER ACCOUNT UNSET SESSION POLICY;

CREATE OR REPLACE SESSION POLICY INV_GOVERNANCE_DB.SECURITY.INV_SESSION_POLICY
    SESSION_IDLE_TIMEOUT_MINS = 30
    SESSION_UI_IDLE_TIMEOUT_MINS = 30
    COMMENT = '30-minute idle timeout per SOX/FINRA access control requirements. Shorter than typical due to sensitive financial data (portfolio positions, trading signals, client PII). Applies to all interactive sessions including Snowsight UI, BI tools, and programmatic connections.';

-- Apply session policy at account level
ALTER ACCOUNT SET SESSION POLICY INV_GOVERNANCE_DB.SECURITY.INV_SESSION_POLICY;

-- Verification
DESCRIBE SESSION POLICY INV_GOVERNANCE_DB.SECURITY.INV_SESSION_POLICY;

-- ============================================================
-- SECTION 5: ACCOUNT PARAMETERS
-- ============================================================
-- Account-level configuration for performance, security,
-- and compliance. These settings apply to all users,
-- warehouses, and workloads across the entire account.
-- Optimized for financial services workloads.
-- ============================================================

-- Timezone: Eastern Time (US financial markets standard)
-- NYSE/NASDAQ operate on ET, most trading systems use ET
ALTER ACCOUNT SET TIMEZONE = 'America/New_York';

-- Query execution limits: prevent runaway queries
-- Financial queries can be complex (portfolio analytics, risk calculations)
-- 1 hour max execution, 30 min queue timeout
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 3600;
ALTER ACCOUNT SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 1800;

-- Data retention defaults: 30-day account default, 14-day minimum
-- SEC Rule 17a-4 requires 3-7 year retention for certain records
-- Individual databases override this based on data classification:
--   INV_RAW_DB: 90 days | INV_TRANSFORM_DB: 30 days
--   INV_ANALYTICS_DB: 90 days | INV_AI_READY_DB: 30 days
ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 30;
ALTER ACCOUNT SET MIN_DATA_RETENTION_TIME_IN_DAYS = 14;

-- Storage integration requirement: prevents ad-hoc external stage creation
-- All external stages must use a governed storage integration object
-- Critical for controlling market data feeds and external data sources
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE;

-- Encryption: automatic periodic re-keying of all data at rest
-- SOX/SEC requirement for financial data protection
ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE;

-- OAuth security: blocks privileged roles from OAuth token escalation
-- Prevents unauthorized role elevation through OAuth flows
ALTER ACCOUNT SET OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE;
ALTER ACCOUNT SET EXTERNAL_OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE;

-- Login: enables username-first login flow for MFA compatibility
-- MFA is required for financial services compliance
ALTER ACCOUNT SET ENABLE_IDENTIFIER_FIRST_LOGIN = TRUE;

-- Verification
SELECT 'Account Parameters Configured' AS status;
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'DATA_RETENTION%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'PERIODIC_DATA_REKEYING' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE_INTEGRATION%' IN ACCOUNT;

-- ============================================================
-- SECTION 6: RESOURCE MONITORS (Cost Control)
-- ============================================================
-- Financial services require strict cost controls and budget
-- management. Resource monitors prevent runaway costs and
-- provide visibility into credit consumption.
-- ============================================================

-- Account-level resource monitor (overall budget ceiling)
CREATE OR REPLACE RESOURCE MONITOR INV_ACCOUNT_MONITOR
    WITH CREDIT_QUOTA = 10000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- Verification
SHOW RESOURCE MONITORS LIKE 'INV%';

-- ============================================================
-- SECTION 7: PHASE 01 VERIFICATION & SUMMARY
-- ============================================================

-- Final verification of all Phase 01 objects
SELECT '========== PHASE 01 VERIFICATION ==========' AS section;

-- Check database exists
SELECT 'DATABASE CHECK' AS check_type, 
       DATABASE_NAME, 
       CREATED,
       COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES 
WHERE DATABASE_NAME = 'INV_GOVERNANCE_DB' 
  AND DELETED IS NULL;

-- Check schema exists
SELECT 'SCHEMA CHECK' AS check_type,
       CATALOG_NAME AS database_name,
       SCHEMA_NAME,
       CREATED
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'INV_GOVERNANCE_DB'
  AND SCHEMA_NAME = 'SECURITY'
  AND DELETED IS NULL;

-- Check policies exist
SHOW PASSWORD POLICIES IN SCHEMA INV_GOVERNANCE_DB.SECURITY;
SHOW SESSION POLICIES IN SCHEMA INV_GOVERNANCE_DB.SECURITY;
SHOW NETWORK RULES IN SCHEMA INV_GOVERNANCE_DB.SECURITY;
SHOW NETWORK POLICIES LIKE 'INV%';
SHOW RESOURCE MONITORS LIKE 'INV%';

-- ============================================================
-- SECTION 8: PHASE 01 SUMMARY
-- ============================================================
--
-- BOOTSTRAP OBJECTS CREATED:
--   DATABASE : INV_GOVERNANCE_DB
--   SCHEMA   : INV_GOVERNANCE_DB.SECURITY
--
-- NOTE: Remaining INV_GOVERNANCE_DB schemas are created
--       in Phase 04 (POLICIES, TAGS, DATA_QUALITY, AUDIT, MONITORING).
--
-- SECURITY OBJECTS CREATED:
--   NETWORK RULE    : INV_GOVERNANCE_DB.SECURITY.INV_ALLOWED_IPS
--   NETWORK POLICY  : INV_NETWORK_POLICY (applied at account level)
--   PASSWORD POLICY : INV_GOVERNANCE_DB.SECURITY.INV_PASSWORD_POLICY (applied)
--   SESSION POLICY  : INV_GOVERNANCE_DB.SECURITY.INV_SESSION_POLICY (applied)
--   RESOURCE MONITOR: INV_ACCOUNT_MONITOR
--
-- ACCOUNT PARAMETERS CONFIGURED: 11
--   TIMEZONE                                         = America/New_York
--   STATEMENT_TIMEOUT_IN_SECONDS                     = 3600
--   STATEMENT_QUEUED_TIMEOUT_IN_SECONDS              = 1800
--   DATA_RETENTION_TIME_IN_DAYS                      = 30
--   MIN_DATA_RETENTION_TIME_IN_DAYS                  = 14
--   REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION  = TRUE
--   REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE
--   PERIODIC_DATA_REKEYING                           = TRUE
--   OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST       = TRUE
--   EXTERNAL_OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE
--   ENABLE_IDENTIFIER_FIRST_LOGIN                    = TRUE
--
-- REGULATORY COMPLIANCE:
--   - SOX Section 404: Internal controls, access management
--   - SEC Rule 17a-4: Records retention requirements
--   - SEC Regulation S-P: Privacy of consumer financial info
--   - FINRA Rule 3110: Supervision and compliance
--   - FINRA Rule 4370: Business continuity planning
--   - PCI-DSS: Payment card data security (if applicable)
--
-- PHASE 02 DEPENDENCIES:
--   - INV_GOVERNANCE_DB exists for role grant references
--   - INV_GOVERNANCE_DB.SECURITY exists for policy references
--   - INV_PASSWORD_POLICY exists for user account setup
--   - Network policy applied — ensure CI/CD runner IPs and
--     market data vendor IPs are whitelisted before executing
--     Phase 02 and beyond
--
-- ============================================================
-- ROLLBACK COMMANDS (run only if needed before Phase 02)
-- ============================================================
-- USE ROLE ACCOUNTADMIN;
--
-- ALTER ACCOUNT UNSET NETWORK_POLICY;
-- DROP NETWORK POLICY IF EXISTS INV_NETWORK_POLICY;
-- DROP NETWORK RULE IF EXISTS INV_GOVERNANCE_DB.SECURITY.INV_ALLOWED_IPS;
--
-- ALTER ACCOUNT UNSET PASSWORD POLICY;
-- DROP PASSWORD POLICY IF EXISTS INV_GOVERNANCE_DB.SECURITY.INV_PASSWORD_POLICY;
--
-- ALTER ACCOUNT UNSET SESSION POLICY;
-- DROP SESSION POLICY IF EXISTS INV_GOVERNANCE_DB.SECURITY.INV_SESSION_POLICY;
--
-- DROP RESOURCE MONITOR IF EXISTS INV_ACCOUNT_MONITOR;
--
-- DROP SCHEMA IF EXISTS INV_GOVERNANCE_DB.SECURITY;
-- DROP DATABASE IF EXISTS INV_GOVERNANCE_DB;
--
-- ALTER ACCOUNT SET TIMEZONE = 'America/Los_Angeles';
-- ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 1;
-- ALTER ACCOUNT SET MIN_DATA_RETENTION_TIME_IN_DAYS = 0;
-- ============================================================

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 01: ACCOUNT ADMINISTRATION COMPLETE'
UNION ALL
SELECT '  Investment Domain - Finance Platform'
UNION ALL
SELECT '  Proceed to Phase 02: RBAC Setup'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 01: ACCOUNT ADMINISTRATION
-- ============================================================
