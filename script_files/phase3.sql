-- ============================================================
-- INVESTMENT DOMAIN - WAREHOUSE MANAGEMENT
-- ============================================================
-- Phase 03: Warehouse Management (Simplified)
-- Script: 03_warehouse_management.sql
-- Version: 1.0.0
--
-- Description:
--   Creates 4 workload-specific warehouses for Investment
--   Analysis Platform. Aligned with 7-role RBAC from Phase 02.
--
-- Warehouses: 4 (Only what's needed)
--   1. INV_INGEST_WH    - Data loading (market data feeds)
--   2. INV_TRANSFORM_WH - ETL transformations
--   3. INV_ANALYTICS_WH - BI, dashboards, reports
--   4. INV_ML_WH        - Machine learning workloads
--
-- Dependencies:
--   - Phase 01 completed
--   - Phase 02 completed (7 roles exist)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: CREATE 4 WAREHOUSES
-- ============================================================

-- ------------------------------------------------------------
-- WAREHOUSE 1: INV_INGEST_WH
-- Purpose: Data loading (market data feeds, portfolio imports)
-- Users: INV_DATA_ENGINEER, INV_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS INV_INGEST_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    COMMENT = 'Data ingestion warehouse for market data feeds, portfolio imports. Small size - data loading is I/O bound. 1-min auto-suspend for cost savings.';

-- ------------------------------------------------------------
-- WAREHOUSE 2: INV_TRANSFORM_WH
-- Purpose: ETL transformations, dbt, data pipelines
-- Users: INV_DATA_ENGINEER, INV_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS INV_TRANSFORM_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'ETL transformation warehouse for data pipelines. Medium size for compute-intensive transformations. 2-min auto-suspend.';

-- ------------------------------------------------------------
-- WAREHOUSE 3: INV_ANALYTICS_WH
-- Purpose: BI queries, dashboards, reports, Streamlit
-- Users: INV_READONLY, INV_ANALYST, INV_APP_ADMIN, INV_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS INV_ANALYTICS_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 4
    SCALING_POLICY = 'STANDARD'
    ENABLE_QUERY_ACCELERATION = TRUE
    QUERY_ACCELERATION_MAX_SCALE_FACTOR = 4
    COMMENT = 'Analytics warehouse for BI, dashboards, Streamlit apps. Large size for fast query response. Query acceleration enabled.';

-- ------------------------------------------------------------
-- WAREHOUSE 4: INV_ML_WH
-- Purpose: ML model training, feature engineering, predictions
-- Users: INV_ML_ENGINEER, INV_ML_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS INV_ML_WH
    WAREHOUSE_SIZE = 'XLARGE'
    AUTO_SUSPEND = 600
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    ENABLE_QUERY_ACCELERATION = TRUE
    QUERY_ACCELERATION_MAX_SCALE_FACTOR = 8
    COMMENT = 'ML warehouse for model training, feature engineering. X-Large for compute-intensive ML. 10-min auto-suspend for iterative work.';

-- VERIFICATION
SHOW WAREHOUSES LIKE 'INV_%';


-- ============================================================
-- SECTION 2: RESOURCE MONITORS (Per-Warehouse)
-- ============================================================

-- Account-level monitor (created in Phase 01)
-- INV_ACCOUNT_MONITOR already exists

-- Per-warehouse monitors
CREATE OR REPLACE RESOURCE MONITOR INV_INGEST_MONITOR
    WITH CREDIT_QUOTA = 500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR INV_TRANSFORM_MONITOR
    WITH CREDIT_QUOTA = 1500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR INV_ANALYTICS_MONITOR
    WITH CREDIT_QUOTA = 2000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR INV_ML_MONITOR
    WITH CREDIT_QUOTA = 1000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

-- Assign monitors to warehouses
ALTER WAREHOUSE INV_INGEST_WH SET RESOURCE_MONITOR = INV_INGEST_MONITOR;
ALTER WAREHOUSE INV_TRANSFORM_WH SET RESOURCE_MONITOR = INV_TRANSFORM_MONITOR;
ALTER WAREHOUSE INV_ANALYTICS_WH SET RESOURCE_MONITOR = INV_ANALYTICS_MONITOR;
ALTER WAREHOUSE INV_ML_WH SET RESOURCE_MONITOR = INV_ML_MONITOR;

-- VERIFICATION
SHOW RESOURCE MONITORS LIKE 'INV_%';


-- ============================================================
-- SECTION 3: WAREHOUSE GRANTS TO 7 ROLES
-- ============================================================

-- ------------------------------------------------------------
-- INV_INGEST_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE INV_INGEST_WH TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_INGEST_WH TO ROLE INV_DATA_ADMIN;

-- ------------------------------------------------------------
-- INV_TRANSFORM_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE INV_TRANSFORM_WH TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_TRANSFORM_WH TO ROLE INV_DATA_ADMIN;

-- ------------------------------------------------------------
-- INV_ANALYTICS_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_READONLY;
GRANT USAGE, OPERATE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_ANALYST;
GRANT USAGE, OPERATE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_APP_ADMIN;
GRANT USAGE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_ANALYTICS_WH TO ROLE INV_DATA_ADMIN;

-- ------------------------------------------------------------
-- INV_ML_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE INV_ML_WH TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON WAREHOUSE INV_ML_WH TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE INV_ML_WH TO ROLE INV_ML_ADMIN;


-- ============================================================
-- SECTION 4: VERIFICATION
-- ============================================================

-- Verify warehouses
SHOW WAREHOUSES LIKE 'INV_%';

-- Verify grants
SHOW GRANTS ON WAREHOUSE INV_INGEST_WH;
SHOW GRANTS ON WAREHOUSE INV_TRANSFORM_WH;
SHOW GRANTS ON WAREHOUSE INV_ANALYTICS_WH;
SHOW GRANTS ON WAREHOUSE INV_ML_WH;

-- Verify resource monitors
SHOW RESOURCE MONITORS LIKE 'INV_%';


-- ============================================================
-- SECTION 5: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 03: WAREHOUSE MANAGEMENT - SUMMARY
================================================================================

WAREHOUSES CREATED: 4
┌───────────────────┬─────────┬──────────────┬───────────────────────────────┐
│ Warehouse         │ Size    │ Auto-Suspend │ Purpose                       │
├───────────────────┼─────────┼──────────────┼───────────────────────────────┤
│ INV_INGEST_WH     │ SMALL   │ 60 sec       │ Data loading, market feeds    │
│ INV_TRANSFORM_WH  │ MEDIUM  │ 120 sec      │ ETL, dbt, transformations     │
│ INV_ANALYTICS_WH  │ LARGE   │ 300 sec      │ BI, dashboards, Streamlit     │
│ INV_ML_WH         │ XLARGE  │ 600 sec      │ ML training, predictions      │
└───────────────────┴─────────┴──────────────┴───────────────────────────────┘

RESOURCE MONITORS: 4
┌───────────────────────┬───────────────┬─────────────────────────────────────┐
│ Monitor               │ Credit Quota  │ Assigned To                         │
├───────────────────────┼───────────────┼─────────────────────────────────────┤
│ INV_INGEST_MONITOR    │ 500/month     │ INV_INGEST_WH                       │
│ INV_TRANSFORM_MONITOR │ 1500/month    │ INV_TRANSFORM_WH                    │
│ INV_ANALYTICS_MONITOR │ 2000/month    │ INV_ANALYTICS_WH                    │
│ INV_ML_MONITOR        │ 1000/month    │ INV_ML_WH                           │
└───────────────────────┴───────────────┴─────────────────────────────────────┘

WAREHOUSE GRANTS BY ROLE:
┌───────────────────┬───────────────────────────────────────────────────────┐
│ Role              │ Warehouse Access                                      │
├───────────────────┼───────────────────────────────────────────────────────┤
│ INV_READONLY      │ ANALYTICS_WH (usage)                                  │
│ INV_ANALYST       │ ANALYTICS_WH (usage, operate)                         │
│ INV_DATA_ENGINEER │ INGEST, TRANSFORM (usage, operate), ANALYTICS, ML    │
│ INV_ML_ENGINEER   │ ML_WH (usage, operate), ANALYTICS_WH (usage)         │
│ INV_DATA_ADMIN    │ INGEST, TRANSFORM, ANALYTICS (all privileges)        │
│ INV_ML_ADMIN      │ ML_WH (all privileges)                               │
│ INV_APP_ADMIN     │ ANALYTICS_WH (usage, operate)                        │
└───────────────────┴───────────────────────────────────────────────────────┘

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 03: WAREHOUSE MANAGEMENT COMPLETE'
UNION ALL
SELECT '  4 Warehouses + 4 Resource Monitors'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 03: WAREHOUSE MANAGEMENT
-- ============================================================
