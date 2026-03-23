-- ============================================================
-- INVESTMENT DOMAIN - SIMPLIFIED RBAC SETUP
-- ============================================================
-- Phase 02: RBAC Setup (Simplified)
-- Script: 02_rbac_setup.sql
-- Version: 1.0.0
--
-- Description:
--   Simplified RBAC for Investment Analysis Platform.
--   Only 7 essential roles for stocks, mutual funds, ETFs analysis.
--
-- Role Count: 7 (NOT 18)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: CREATE ONLY 7 ESSENTIAL ROLES
-- ============================================================
/*
ROLE HIERARCHY:

                    SYSADMIN
         ┌────────────┼────────────┐
    INV_DATA_ADMIN  INV_ML_ADMIN  INV_APP_ADMIN
         │              │              │
   INV_DATA_ENGINEER  INV_ML_ENGINEER INV_ANALYST
         └──────────────┼──────────────┘
                   INV_READONLY

WHY THESE 7 ROLES?
1. INV_READONLY     - View investment reports (auditors, stakeholders)
2. INV_ANALYST      - Create reports, analyze performance
3. INV_DATA_ENGINEER- Build ETL pipelines, manage data
4. INV_ML_ENGINEER  - Build ML models for predictions
5. INV_DATA_ADMIN   - Admin for RAW/TRANSFORM/ANALYTICS databases
6. INV_ML_ADMIN     - Admin for AI_READY database
7. INV_APP_ADMIN    - Manage Streamlit dashboards
*/

-- ------------------------------------------------------------
-- ROLE 1: INV_READONLY (Base Read-Only Access)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_READONLY
    COMMENT = 'Read-only access to investment analytics. For viewing reports, dashboards, KPIs. Persona: Stakeholders, auditors, viewers.';

-- ------------------------------------------------------------
-- ROLE 2: INV_ANALYST (Business Analyst)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_ANALYST
    COMMENT = 'Investment analysts - analyze portfolio performance, create reports. Can read all data, create views in reporting schema. Persona: Portfolio analysts, research analysts.';

-- ------------------------------------------------------------
-- ROLE 3: INV_DATA_ENGINEER (Data Pipeline Developer)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_DATA_ENGINEER
    COMMENT = 'Data engineers - build ETL pipelines, manage data transformations. Full access to RAW and TRANSFORM databases. Persona: Data engineers, ETL developers.';

-- ------------------------------------------------------------
-- ROLE 4: INV_ML_ENGINEER (Machine Learning Engineer)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_ML_ENGINEER
    COMMENT = 'ML engineers - build predictive models, feature engineering. Full access to AI_READY database. Persona: Data scientists, quant researchers.';

-- ------------------------------------------------------------
-- ROLE 5: INV_DATA_ADMIN (Data Platform Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_DATA_ADMIN
    COMMENT = 'Data administrator - manage RAW, TRANSFORM, ANALYTICS databases. Senior data engineers, data platform team.';

-- ------------------------------------------------------------
-- ROLE 6: INV_ML_ADMIN (ML Platform Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_ML_ADMIN
    COMMENT = 'ML administrator - manage AI_READY database, model registry. Senior data scientists, ML platform team.';

-- ------------------------------------------------------------
-- ROLE 7: INV_APP_ADMIN (Application Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS INV_APP_ADMIN
    COMMENT = 'Application administrator - manage Streamlit dashboards, APIs. Application developers, DevOps team.';

-- VERIFICATION: 7 roles created
SHOW ROLES LIKE 'INV_%';


-- ============================================================
-- SECTION 2: ROLE HIERARCHY
-- ============================================================
-- Child roles granted TO parent roles (inheritance flows UP)

USE ROLE SECURITYADMIN;

-- Base layer: INV_READONLY is foundation
-- Layer 2: Functional roles inherit from READONLY
GRANT ROLE INV_READONLY TO ROLE INV_ANALYST;
GRANT ROLE INV_READONLY TO ROLE INV_DATA_ENGINEER;
GRANT ROLE INV_READONLY TO ROLE INV_ML_ENGINEER;

-- Layer 3: Admin roles inherit from functional roles
GRANT ROLE INV_ANALYST TO ROLE INV_APP_ADMIN;
GRANT ROLE INV_DATA_ENGINEER TO ROLE INV_DATA_ADMIN;
GRANT ROLE INV_ML_ENGINEER TO ROLE INV_ML_ADMIN;

-- Layer 4: Admin roles to SYSADMIN
GRANT ROLE INV_DATA_ADMIN TO ROLE SYSADMIN;
GRANT ROLE INV_ML_ADMIN TO ROLE SYSADMIN;
GRANT ROLE INV_APP_ADMIN TO ROLE SYSADMIN;

-- VERIFICATION
SHOW GRANTS OF ROLE INV_READONLY;
SHOW GRANTS TO ROLE SYSADMIN;


-- ============================================================
-- SECTION 3: WAREHOUSE GRANTS
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- INV_INGEST_WH: Data loading
GRANT USAGE, OPERATE ON WAREHOUSE INV_INGEST_WH TO ROLE INV_DATA_ENGINEER;
GRANT USAGE, OPERATE ON WAREHOUSE INV_INGEST_WH TO ROLE INV_DATA_ADMIN;

-- INV_TRANSFORM_WH: ETL processing
GRANT USAGE, OPERATE ON WAREHOUSE INV_TRANSFORM_WH TO ROLE INV_DATA_ENGINEER;
GRANT USAGE, OPERATE ON WAREHOUSE INV_TRANSFORM_WH TO ROLE INV_DATA_ADMIN;

-- INV_ANALYTICS_WH: BI and reporting
GRANT USAGE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_READONLY;
GRANT OPERATE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_ANALYST;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_DATA_ADMIN;
GRANT USAGE, OPERATE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_APP_ADMIN;

-- INV_ML_WH: Machine learning
GRANT USAGE, OPERATE ON WAREHOUSE INV_ML_WH TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_ML_WH TO ROLE INV_ML_ADMIN;


-- ============================================================
-- SECTION 4: DATABASE GRANTS - INV_RAW_DB (2 schemas: MARKET_DATA, REFERENCE)
-- ============================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS INV_RAW_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Raw ingestion layer for investment data. Two schemas: MARKET_DATA (stocks, ETFs, mutual funds prices/volumes) and REFERENCE (instrument metadata, exchange info).';

CREATE SCHEMA IF NOT EXISTS INV_RAW_DB.MARKET_DATA
    COMMENT = 'Raw market data: stock prices, ETF NAVs, mutual fund returns, trading volumes.';
CREATE SCHEMA IF NOT EXISTS INV_RAW_DB.REFERENCE
    COMMENT = 'Reference/master data: instrument metadata, exchange info, sector classifications.';

GRANT USAGE ON DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON DATABASE INV_RAW_DB TO ROLE INV_DATA_ADMIN;

GRANT USAGE ON SCHEMA INV_RAW_DB.MARKET_DATA TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON SCHEMA INV_RAW_DB.REFERENCE TO ROLE INV_DATA_ENGINEER;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_RAW_DB.MARKET_DATA TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_RAW_DB.MARKET_DATA TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_RAW_DB.REFERENCE TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_RAW_DB.REFERENCE TO ROLE INV_DATA_ENGINEER;

GRANT CREATE TABLE ON SCHEMA INV_RAW_DB.MARKET_DATA TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE ON SCHEMA INV_RAW_DB.REFERENCE TO ROLE INV_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE INV_RAW_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 5: DATABASE GRANTS - INV_TRANSFORM_DB (2 schemas: STAGING, CLEANED)
-- ============================================================

CREATE DATABASE IF NOT EXISTS INV_TRANSFORM_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Transformation layer. Two schemas: STAGING (intermediate/work-in-progress) and CLEANED (validated, deduplicated, conformed data).';

CREATE SCHEMA IF NOT EXISTS INV_TRANSFORM_DB.STAGING
    COMMENT = 'Intermediate staging area for ETL work-in-progress transformations.';
CREATE SCHEMA IF NOT EXISTS INV_TRANSFORM_DB.CLEANED
    COMMENT = 'Validated, deduplicated, conformed data ready for analytics or ML.';

GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_ANALYST;
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ADMIN;

GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.STAGING TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ANALYST;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.STAGING TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.STAGING TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE ON SCHEMA INV_TRANSFORM_DB.STAGING TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE ON SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_DATA_ENGINEER;

GRANT SELECT ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ML_ENGINEER;

GRANT SELECT ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_TRANSFORM_DB.CLEANED TO ROLE INV_ANALYST;

GRANT OWNERSHIP ON DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 6: DATABASE GRANTS - INV_ANALYTICS_DB (2 schemas: CORE, REPORTING)
-- ============================================================

CREATE DATABASE IF NOT EXISTS INV_ANALYTICS_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Analytics/consumption layer. Two schemas: CORE (fact/dim tables from ETL) and REPORTING (analyst-created views, dashboards, Streamlit apps).';

CREATE SCHEMA IF NOT EXISTS INV_ANALYTICS_DB.CORE
    COMMENT = 'Curated fact and dimension tables produced by data engineering pipelines.';
CREATE SCHEMA IF NOT EXISTS INV_ANALYTICS_DB.REPORTING
    COMMENT = 'Analyst-created reports, views, KPIs, and Streamlit dashboards.';

GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_ANALYST;
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_APP_ADMIN;
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ADMIN;

GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_READONLY;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_READONLY;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_ANALYST;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_ANALYST;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_APP_ADMIN;

GRANT SELECT ON ALL TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_READONLY;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_READONLY;
GRANT SELECT ON ALL TABLES IN SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_READONLY;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_READONLY;

GRANT CREATE TABLE ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_ANALYST;
GRANT CREATE VIEW ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_ANALYST;

GRANT CREATE TABLE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;

GRANT CREATE STREAMLIT ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_APP_ADMIN;

GRANT OWNERSHIP ON DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 7: DATABASE GRANTS - INV_AI_READY_DB (2 schemas: FEATURES, MODELS)
-- ============================================================

CREATE DATABASE IF NOT EXISTS INV_AI_READY_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'ML-ready data layer. Two schemas: FEATURES (feature store for ML pipelines) and MODELS (model artifacts, predictions, experiment tracking).';

CREATE SCHEMA IF NOT EXISTS INV_AI_READY_DB.FEATURES
    COMMENT = 'Feature store: engineered features for ML model training and inference.';
CREATE SCHEMA IF NOT EXISTS INV_AI_READY_DB.MODELS
    COMMENT = 'Model artifacts, predictions, scoring outputs, experiment tracking.';

GRANT USAGE ON DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON DATABASE INV_AI_READY_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON DATABASE INV_AI_READY_DB TO ROLE INV_ML_ADMIN;

GRANT USAGE ON SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON SCHEMA INV_AI_READY_DB.MODELS TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_DATA_ENGINEER;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_AI_READY_DB.MODELS TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_AI_READY_DB.MODELS TO ROLE INV_ML_ENGINEER;
GRANT CREATE TABLE ON SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_ML_ENGINEER;
GRANT CREATE TABLE ON SCHEMA INV_AI_READY_DB.MODELS TO ROLE INV_ML_ENGINEER;

GRANT SELECT ON ALL TABLES IN SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE INV_AI_READY_DB TO ROLE INV_ML_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 8: DATABASE GRANTS - INV_GOVERNANCE_DB (2 schemas: SECURITY, MONITORING)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS INV_GOVERNANCE_DB.MONITORING
    COMMENT = 'Operational monitoring views: cost tracking, query performance, data quality dashboards.';

GRANT USAGE ON DATABASE INV_GOVERNANCE_DB TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON DATABASE INV_GOVERNANCE_DB TO ROLE INV_READONLY;

GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.SECURITY TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;


-- ============================================================
-- SECTION 9: VERIFICATION
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Verify 7 roles exist
SELECT 
    'Role Count Check' AS test_name,
    COUNT(*) AS role_count,
    CASE WHEN COUNT(*) = 7 THEN '✅ PASS: 7 roles created' 
         ELSE '❌ CHECK: Expected 7 roles' END AS status
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES
WHERE NAME LIKE 'INV_%'
  AND DELETED_ON IS NULL;

-- List all roles
SHOW ROLES LIKE 'INV_%';

-- Verify hierarchy
SHOW GRANTS OF ROLE INV_READONLY;
SHOW GRANTS TO ROLE INV_DATA_ADMIN;
SHOW GRANTS TO ROLE SYSADMIN;


-- ============================================================
-- SECTION 10: SUMMARY
-- ============================================================
/*
================================================================================
SIMPLIFIED RBAC - 7 ROLES ONLY
================================================================================

ROLES CREATED:
┌─────────────────────┬───────────────────────────────────────────────────────┐
│ Role                │ Purpose                                               │
├─────────────────────┼───────────────────────────────────────────────────────┤
│ INV_READONLY        │ View reports, dashboards (stakeholders, auditors)     │
│ INV_ANALYST         │ Create reports, analyze portfolio performance         │
│ INV_DATA_ENGINEER   │ Build ETL pipelines, manage data                      │
│ INV_ML_ENGINEER     │ Build ML models, feature engineering                  │
│ INV_DATA_ADMIN      │ Admin for RAW/TRANSFORM/ANALYTICS databases           │
│ INV_ML_ADMIN        │ Admin for AI_READY database                           │
│ INV_APP_ADMIN       │ Manage Streamlit dashboards                           │
└─────────────────────┴───────────────────────────────────────────────────────┘

ROLE HIERARCHY:
                         SYSADMIN
              ┌─────────────┼─────────────┐
         INV_DATA_ADMIN INV_ML_ADMIN  INV_APP_ADMIN
              │              │              │
        INV_DATA_ENGINEER INV_ML_ENGINEER INV_ANALYST
              └──────────────┼──────────────┘
                        INV_READONLY

WAREHOUSE ACCESS:
┌──────────────────────┬────────────────────────────────────────────────────┐
│ Warehouse            │ Roles                                              │
├──────────────────────┼────────────────────────────────────────────────────┤
│ INV_INGEST_WH        │ DATA_ENGINEER, DATA_ADMIN                          │
│ INV_TRANSFORM_WH     │ DATA_ENGINEER, DATA_ADMIN                          │
│ INV_ANALYTICS_WH     │ READONLY, ANALYST, DATA_ADMIN, APP_ADMIN           │
│ INV_ML_WH            │ ML_ENGINEER, ML_ADMIN                              │
└──────────────────────┴────────────────────────────────────────────────────┘

DATABASE ACCESS (2 SCHEMAS EACH):
┌──────────────────────┬──────────────────┬────────────────────────────────┐
│ Database             │ Schemas          │ Roles                          │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ INV_RAW_DB           │ MARKET_DATA      │ DATA_ENGINEER (full)           │
│                      │ REFERENCE        │ DATA_ADMIN (owner)             │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ INV_TRANSFORM_DB     │ STAGING          │ DATA_ENGINEER (full)           │
│                      │ CLEANED          │ ML_ENGINEER/ANALYST (read)     │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ INV_ANALYTICS_DB     │ CORE             │ DATA_ENGINEER (write)          │
│                      │ REPORTING        │ ANALYST (create), APP_ADMIN    │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ INV_AI_READY_DB      │ FEATURES         │ ML_ENGINEER (full)             │
│                      │ MODELS           │ DATA_ENGINEER (read FEATURES)  │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ INV_GOVERNANCE_DB    │ SECURITY         │ DATA_ADMIN                     │
│                      │ MONITORING       │ READONLY (monitoring)          │
└──────────────────────┴──────────────────┴────────────────────────────────┘

NO COMPLIANCE_OFFICER - Not needed for investment analysis
NO PLATFORM_ADMIN - DATA_ADMIN handles platform management
================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 02: RBAC SETUP COMPLETE'
UNION ALL
SELECT '  7 Roles Created (Simplified)'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 02: SIMPLIFIED RBAC SETUP
-- ============================================================
