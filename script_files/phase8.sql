-- ============================================================
-- INVESTMENT DOMAIN - DATA GOVERNANCE
-- ============================================================
-- Phase 08: Data Governance
-- Script: 08_data_governance.sql
-- Version: 1.0.0
--
-- Description:
--   Data governance layer for Investment Analysis Platform.
--   Implements tags, masking policies, and access controls
--   for SOX/SEC compliance.
--
-- Regulatory Framework:
--   - SOX Section 404: Internal controls
--   - SEC Regulation S-P: Client privacy
--   - FINRA Rule 3110: Supervision
--
-- Components:
--   - Tags: 8 classification tags
--   - Masking Policies: 4 policies
--   - Row Access Policies: 2 policies
--
-- Dependencies:
--   - Phase 04: INV_GOVERNANCE_DB exists
--   - Phase 02: 7 roles exist
-- ============================================================


-- ============================================================
-- DETAILED EXPLANATION: WHAT IS DATA GOVERNANCE?
-- ============================================================
/*
DATA GOVERNANCE is a framework of policies, processes, and standards
that ensures data is:
  1. ACCURATE    - Data represents reality correctly
  2. ACCESSIBLE  - Right people can access right data
  3. CONSISTENT  - Same data means same thing everywhere
  4. SECURE      - Protected from unauthorized access
  5. COMPLIANT   - Meets regulatory requirements

WHY DATA GOVERNANCE FOR INVESTMENT PLATFORM?
────────────────────────────────────────────
Financial services are heavily regulated. We must:
  - Protect client personal information (PII)
  - Maintain audit trails for SEC/FINRA
  - Ensure data quality for accurate reporting
  - Track data lineage for compliance

SNOWFLAKE GOVERNANCE OBJECTS:
────────────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Object Type         │ Purpose                                                │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ TAGS                │ Classify and label data (metadata)                     │
│ MASKING POLICIES    │ Hide/transform sensitive data based on role            │
│ ROW ACCESS POLICIES │ Filter rows based on user role/attributes              │
│ ACCESS HISTORY      │ Track who accessed what data (audit)                   │
└─────────────────────┴────────────────────────────────────────────────────────┘

REGULATORY COMPLIANCE CONTEXT:
──────────────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Regulation          │ What It Requires                                       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ SOX Section 404     │ Internal controls over financial reporting             │
│                     │ - Data must be accurate and auditable                  │
│                     │ - Access controls must be documented                   │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ SEC Regulation S-P  │ Privacy of consumer financial information              │
│                     │ - Protect client PII (names, SSN, accounts)            │
│                     │ - Limit sharing of nonpublic personal info             │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ SEC Rule 17a-4      │ Records retention requirements                         │
│                     │ - Most records: 6-7 years                              │
│                     │ - Some records: permanent                              │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ FINRA Rule 3110     │ Supervision of registered representatives              │
│                     │ - Monitor trading activity                             │
│                     │ - Maintain supervisory procedures                      │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE INV_GOVERNANCE_DB;
USE WAREHOUSE COMPUTE_WH;


-- ============================================================
-- SECTION 1: CREATE TAGS
-- ============================================================
/*
WHAT ARE TAGS?
──────────────
Tags are metadata labels that you attach to Snowflake objects
(databases, schemas, tables, columns) to classify them.

WHY USE TAGS?
─────────────
1. CLASSIFICATION: Identify sensitive data automatically
2. DISCOVERY: Find all PII columns across the platform
3. AUTOMATION: Drive policies based on tag values
4. COMPLIANCE: Document data for auditors
5. LINEAGE: Track data origin and purpose

HOW TAGS WORK:
──────────────
┌─────────────────────────────────────────────────────────────────┐
│                        TAG HIERARCHY                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   TAG: PII_CLASSIFICATION                                       │
│        │                                                        │
│        ├── Value: 'DIRECT_PII'    → Apply MASK_CLIENT_PII       │
│        ├── Value: 'QUASI_PII'     → Apply partial masking       │
│        ├── Value: 'FINANCIAL'     → Apply MASK_FINANCIAL_AMOUNT │
│        └── Value: 'NON_PII'       → No masking needed           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

TAG INHERITANCE:
────────────────
Tags can be inherited from parent to child objects:
  DATABASE tag → inherited by all SCHEMAS
  SCHEMA tag   → inherited by all TABLES
  TABLE tag    → inherited by all COLUMNS (unless overridden)

Example:
  SET TAG DATA_DOMAIN = 'CLIENT' on INV_ANALYTICS_DB.CORE
  All tables in CORE schema inherit DATA_DOMAIN = 'CLIENT'
*/

USE SCHEMA INV_GOVERNANCE_DB.TAGS;

-- ------------------------------------------------------------
-- TAG 1: PII_CLASSIFICATION
-- ------------------------------------------------------------
/*
PURPOSE: Classify client personal information for privacy protection

WHAT IS PII (Personally Identifiable Information)?
──────────────────────────────────────────────────
PII is any data that can identify a specific individual:
  - DIRECT PII: Uniquely identifies (SSN, name, account number)
  - QUASI PII: Can identify when combined (ZIP code, birth year)

VALUES AND THEIR MEANING:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Examples & Treatment                                   │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ DIRECT_PII          │ Client name, SSN, account number, email                │
│                     │ Treatment: Full masking for unauthorized roles         │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ QUASI_PII           │ Address, phone, date of birth, ZIP code                │
│                     │ Treatment: Partial masking (show last 4, truncate)     │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ FINANCIAL           │ Account balances, transaction amounts, holdings        │
│                     │ Treatment: NULL for readonly roles                     │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ NON_PII             │ Market data, ticker symbols, dates                     │
│                     │ Treatment: No masking required                         │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG PII_CLASSIFICATION
    COMMENT = 'Client PII classification. Values: DIRECT_PII (name, SSN, account), QUASI_PII (address, phone), FINANCIAL (balances, transactions), NON_PII (no protection)';

-- ------------------------------------------------------------
-- TAG 2: DATA_SENSITIVITY
-- ------------------------------------------------------------
/*
PURPOSE: Overall sensitivity level for access control decisions

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Description & Access Level                             │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ HIGHLY_CONFIDENTIAL │ Client PII, trading strategies, proprietary models    │
│                     │ Access: DATA_ADMIN, ANALYST only                       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CONFIDENTIAL        │ Portfolio holdings, transaction history                │
│                     │ Access: All functional roles                           │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INTERNAL            │ Internal reports, aggregated metrics                   │
│                     │ Access: All authenticated users                        │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ PUBLIC              │ Market data, public filings, published reports         │
│                     │ Access: Anyone (no restrictions)                       │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_SENSITIVITY
    COMMENT = 'Data sensitivity level. Values: HIGHLY_CONFIDENTIAL, CONFIDENTIAL, INTERNAL, PUBLIC';

-- ------------------------------------------------------------
-- TAG 3: DATA_DOMAIN
-- ------------------------------------------------------------
/*
PURPOSE: Business domain classification for organization and discovery

WHY DATA DOMAINS?
─────────────────
  - Organize data by business function
  - Apply domain-specific governance rules
  - Enable domain-based access control
  - Simplify data discovery and cataloging

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Description                                            │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ MARKET_DATA         │ Prices, quotes, indices, corporate actions             │
│ PORTFOLIO           │ Holdings, positions, NAV, allocations                  │
│ TRANSACTIONS        │ Trades, settlements, cash movements                    │
│ CLIENT              │ Client profiles, accounts, contacts                    │
│ RISK                │ VaR, exposure, Greeks, stress tests                    │
│ REFERENCE           │ Securities master, benchmarks, calendars               │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_DOMAIN
    COMMENT = 'Business domain. Values: MARKET_DATA, PORTFOLIO, TRANSACTIONS, CLIENT, RISK, REFERENCE';

-- ------------------------------------------------------------
-- TAG 4: MEDALLION_LAYER
-- ------------------------------------------------------------
/*
PURPOSE: Identify data position in the medallion architecture

MEDALLION ARCHITECTURE EXPLAINED:
─────────────────────────────────
┌─────────────────────────────────────────────────────────────────┐
│                     DATA FLOW DIRECTION →                       │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   BRONZE    │   SILVER    │    GOLD     │      PLATINUM        │
│  (RAW_DB)   │(TRANSFORM_DB│(ANALYTICS_DB│   (AI_READY_DB)      │
├─────────────┼─────────────┼─────────────┼──────────────────────┤
│ Raw data    │ Cleansed    │ Business    │ ML-ready             │
│ as-is from  │ validated   │ aggregated  │ Feature store        │
│ sources     │ conformed   │ KPIs ready  │ Training data        │
├─────────────┼─────────────┼─────────────┼──────────────────────┤
│ Quality:LOW │ Quality:MED │ Quality:HIGH│ Quality:HIGH         │
│ Trusted:NO  │ Trusted:YES │ Trusted:YES │ Trusted:YES          │
└─────────────┴─────────────┴─────────────┴──────────────────────┘

WHY TAG BY LAYER?
─────────────────
  - BRONZE: May contain duplicates, errors - use with caution
  - SILVER: Safe for analysis but needs joins
  - GOLD: Ready for dashboards and reports
  - PLATINUM: Ready for ML model training
*/
CREATE OR REPLACE TAG MEDALLION_LAYER
    COMMENT = 'Medallion layer. Values: BRONZE (raw), SILVER (cleansed), GOLD (analytics), PLATINUM (ML)';

-- ------------------------------------------------------------
-- TAG 5: DATA_QUALITY_STATUS
-- ------------------------------------------------------------
/*
PURPOSE: Track data quality certification status

WHY DATA QUALITY TAGS?
──────────────────────
  - Prevent use of bad data in production analytics
  - Enable data stewardship workflows
  - Support data quality SLAs
  - Track remediation progress

VALUES AND WORKFLOW:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Meaning & Allowed Actions                              │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CERTIFIED           │ Passed all DQ checks - safe for production use         │
│                     │ Allowed: All roles can query                           │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ UNDER_REVIEW        │ Pending validation - use with caution                  │
│                     │ Allowed: Engineers + Admins only                       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ QUARANTINED         │ Failed DQ checks - do NOT use                          │
│                     │ Allowed: Engineers only (for fixing)                   │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ DEPRECATED          │ Scheduled for removal - migrate away                   │
│                     │ Allowed: Engineers only (for cleanup)                  │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_QUALITY_STATUS
    COMMENT = 'Data quality status. Values: CERTIFIED, UNDER_REVIEW, QUARANTINED, DEPRECATED';

-- ------------------------------------------------------------
-- TAG 6: SOURCE_SYSTEM
-- ------------------------------------------------------------
/*
PURPOSE: Track data origin for lineage and troubleshooting

WHY TRACK SOURCE SYSTEM?
────────────────────────
  - Data lineage: Where did this data come from?
  - Troubleshooting: Which source caused the issue?
  - SLA tracking: Is source system delivering on time?
  - Impact analysis: What happens if source goes down?

COMMON INVESTMENT DATA SOURCES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Source              │ Data Provided                                          │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ BLOOMBERG           │ Market data, prices, corporate actions, analytics      │
│ REUTERS             │ News, prices, reference data                           │
│ CUSTODIAN           │ Holdings, settlements, corporate actions               │
│ TRADING_SYSTEM      │ Orders, executions, fills                              │
│ PORTFOLIO_SYSTEM    │ Positions, NAV, allocations                            │
│ MANUAL              │ Manually entered data (spreadsheets, adjustments)      │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG SOURCE_SYSTEM
    COMMENT = 'Source system. Values: BLOOMBERG, REUTERS, CUSTODIAN, TRADING_SYSTEM, PORTFOLIO_SYSTEM, MANUAL';

-- ------------------------------------------------------------
-- TAG 7: REFRESH_FREQUENCY
-- ------------------------------------------------------------
/*
PURPOSE: Document data refresh cadence for SLA monitoring

WHY TRACK REFRESH FREQUENCY?
────────────────────────────
  - Set user expectations on data freshness
  - Monitor SLA compliance
  - Plan capacity for refresh jobs
  - Identify stale data

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Description                                            │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ REAL_TIME           │ Streaming or near-real-time (< 1 minute latency)       │
│ HOURLY              │ Refreshed every hour                                   │
│ DAILY               │ Refreshed once per day (typically overnight)           │
│ WEEKLY              │ Refreshed once per week                                │
│ MONTHLY             │ Refreshed once per month                               │
│ ON_DEMAND           │ Manual or event-triggered refresh                      │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG REFRESH_FREQUENCY
    COMMENT = 'Refresh frequency. Values: REAL_TIME, HOURLY, DAILY, WEEKLY, MONTHLY, ON_DEMAND';

-- ------------------------------------------------------------
-- TAG 8: RETENTION_POLICY
-- ------------------------------------------------------------
/*
PURPOSE: SEC 17a-4 compliance for records retention

SEC RULE 17a-4 EXPLAINED:
─────────────────────────
SEC Rule 17a-4 requires broker-dealers to retain certain records:
  - Trade confirmations: 6 years
  - Account statements: 6 years  
  - Order tickets: 3 years
  - Communications: 3 years
  - Customer complaints: 4 years

WHY RETENTION TAGS?
───────────────────
  - Automate data lifecycle management
  - Ensure compliance with SEC requirements
  - Enable legal hold for investigations
  - Control storage costs

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Use Case                                               │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ 7_YEARS             │ Standard financial records (SEC 17a-4 requirement)     │
│ 10_YEARS            │ Extended retention for audit trails                    │
│ PERMANENT           │ Never delete (master data, legal holds)                │
│ 1_YEAR              │ Temporary/operational data                             │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG RETENTION_POLICY
    COMMENT = 'Retention period per SEC 17a-4. Values: 7_YEARS (standard), 10_YEARS (extended), PERMANENT, 1_YEAR';

-- VERIFICATION
SHOW TAGS IN SCHEMA INV_GOVERNANCE_DB.TAGS;


-- ============================================================
-- SECTION 2: CREATE MASKING POLICIES
-- ============================================================
/*
WHAT ARE MASKING POLICIES?
──────────────────────────
Masking policies dynamically transform column values at query time
based on the role of the user executing the query.

HOW MASKING WORKS:
──────────────────
┌─────────────────────────────────────────────────────────────────┐
│                     MASKING FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   User Query                                                    │
│       │                                                         │
│       ▼                                                         │
│   SELECT CLIENT_NAME FROM CLIENTS                               │
│       │                                                         │
│       ▼                                                         │
│   Snowflake checks: Does CLIENT_NAME have masking policy?       │
│       │                                                         │
│       ▼ YES                                                     │
│   Evaluate policy: CASE WHEN CURRENT_ROLE() IN (...) THEN ...   │
│       │                                                         │
│       ├── ANALYST role → Return actual value: "John Smith"      │
│       │                                                         │
│       └── READONLY role → Return masked value: "***MASKED***"   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

KEY CONCEPTS:
─────────────
1. COLUMN-LEVEL: Policies attach to specific columns
2. DYNAMIC: Evaluated at query time (not stored)
3. ROLE-BASED: Different output based on CURRENT_ROLE()
4. TRANSPARENT: Users don't know data is masked
5. AUDITABLE: All access is logged

MASKING POLICY SYNTAX:
──────────────────────
CREATE MASKING POLICY policy_name
    AS (val DATA_TYPE)           -- Input: column value
    RETURNS DATA_TYPE            -- Output: same data type
    -> CASE                      -- Logic to mask or return
         WHEN condition THEN ...
         ELSE ...
       END;
*/

USE SCHEMA INV_GOVERNANCE_DB.POLICIES;

-- ------------------------------------------------------------
-- POLICY 1: MASK_CLIENT_PII
-- ------------------------------------------------------------
/*
PURPOSE: Protect client personal identifiable information

WHAT THIS POLICY DOES:
──────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Role                │ What They See                                          │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_DATA_ADMIN      │ Full value: "John Smith"                               │
│ INV_ML_ADMIN        │ Full value: "John Smith"                               │
│ INV_ANALYST         │ Full value: "John Smith"                               │
│ ACCOUNTADMIN        │ Full value: "John Smith"                               │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_DATA_ENGINEER   │ Partial mask: "*****mith" (last 4 chars)              │
│ INV_ML_ENGINEER     │ Partial mask: "*****mith" (last 4 chars)              │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_READONLY        │ Full mask: "***MASKED***"                              │
│ INV_APP_ADMIN       │ Full mask: "***MASKED***"                              │
│ Any other role      │ Full mask: "***MASKED***"                              │
└─────────────────────┴────────────────────────────────────────────────────────┘

WHY PARTIAL MASKING FOR ENGINEERS?
──────────────────────────────────
Engineers need some visibility for:
  - Data quality troubleshooting
  - ETL debugging
  - Data validation
But they don't need full PII access for their work.
*/
CREATE OR REPLACE MASKING POLICY MASK_CLIENT_PII
    AS (val STRING)
    RETURNS STRING
    COMMENT = 'Masks client PII. Full: DATA_ADMIN, ML_ADMIN, ANALYST. Masked: others.'
    ->
    CASE
        -- Full access: Admin and Analyst roles
        WHEN CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ML_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN') THEN val
        -- Partial access: Engineers see last 4 characters
        WHEN CURRENT_ROLE() IN ('INV_DATA_ENGINEER', 'INV_ML_ENGINEER') THEN 
            CASE 
                WHEN LENGTH(val) > 4 THEN CONCAT(REPEAT('*', LENGTH(val) - 4), RIGHT(val, 4))
                ELSE REPEAT('*', LENGTH(val))
            END
        -- No access: Everyone else sees masked value
        ELSE '***MASKED***'
    END;

-- ------------------------------------------------------------
-- POLICY 2: MASK_ACCOUNT_NUMBER
-- ------------------------------------------------------------
/*
PURPOSE: Protect financial account numbers

ACCOUNT NUMBER MASKING STRATEGY:
────────────────────────────────
Account numbers are highly sensitive - if exposed, could enable:
  - Identity theft
  - Unauthorized account access
  - Wire fraud

We show last 4 digits only (like credit card statements):
  "123456789012" → "****-****-9012"

This allows:
  - Verification: "Is this the account ending in 9012?"
  - Troubleshooting: "We see an issue with account ...9012"
  - Compliance: PII is protected while enabling support
*/
CREATE OR REPLACE MASKING POLICY MASK_ACCOUNT_NUMBER
    AS (val STRING)
    RETURNS STRING
    COMMENT = 'Masks account numbers. Shows last 4 digits only.'
    ->
    CASE
        -- Full access: Admin and Analyst only
        WHEN CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN') THEN val
        -- Partial access: Show last 4 digits
        WHEN LENGTH(val) > 4 THEN CONCAT('****-****-', RIGHT(val, 4))
        -- Fallback for short values
        ELSE '****'
    END;

-- ------------------------------------------------------------
-- POLICY 3: MASK_FINANCIAL_AMOUNT
-- ------------------------------------------------------------
/*
PURPOSE: Hide financial amounts from unauthorized roles

WHY MASK FINANCIAL AMOUNTS?
───────────────────────────
Financial amounts reveal:
  - Client wealth (portfolio values, balances)
  - Trading activity (transaction amounts)
  - Business metrics (AUM, revenue)

This information is:
  - Competitively sensitive
  - Privacy-protected (client wealth)
  - Potentially insider information

MASKING STRATEGY:
─────────────────
For unauthorized roles, return NULL instead of fake numbers.
Why NULL instead of 0 or fake value?
  - NULL is honest: "You can't see this"
  - 0 would be misleading: "Account has zero balance?"
  - Fake values could cause incorrect analysis
*/
CREATE OR REPLACE MASKING POLICY MASK_FINANCIAL_AMOUNT
    AS (val NUMBER)
    RETURNS NUMBER
    COMMENT = 'Masks financial amounts. Full: DATA_ADMIN, ANALYST, ML_ENGINEER. Masked: READONLY.'
    ->
    CASE
        -- Full access: Most functional roles need financial data
        WHEN CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ML_ADMIN', 'INV_ANALYST', 'INV_DATA_ENGINEER', 'INV_ML_ENGINEER', 'ACCOUNTADMIN') THEN val
        -- No access: Return NULL for READONLY and others
        ELSE NULL
    END;

-- ------------------------------------------------------------
-- POLICY 4: MASK_PHONE_EMAIL
-- ------------------------------------------------------------
/*
PURPOSE: Protect client contact information

CONTACT INFORMATION RISKS:
──────────────────────────
Exposed phone/email can be used for:
  - Phishing attacks targeting clients
  - Social engineering
  - Spam/harassment
  - Identity verification fraud

MASKING STRATEGY:
─────────────────
Email: "john.smith@company.com" → "jo***@***.com"
Phone: "555-123-4567" → "***-***-4567"

This provides:
  - Enough info to recognize: "Is this the john.s*** email?"
  - Protection: Can't reconstruct full contact
*/
CREATE OR REPLACE MASKING POLICY MASK_PHONE_EMAIL
    AS (val STRING)
    RETURNS STRING
    COMMENT = 'Masks phone numbers and emails.'
    ->
    CASE
        -- Full access: Admin and Analyst
        WHEN CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN') THEN val
        -- Partial mask for email (contains @)
        WHEN CONTAINS(val, '@') THEN CONCAT(LEFT(val, 2), '***@***.com')
        -- Partial mask for phone (10+ digits)
        WHEN LENGTH(val) >= 10 THEN CONCAT('***-***-', RIGHT(val, 4))
        -- Fallback
        ELSE '***'
    END;

-- VERIFICATION
SHOW MASKING POLICIES IN SCHEMA INV_GOVERNANCE_DB.POLICIES;


-- ============================================================
-- SECTION 3: CREATE ROW ACCESS POLICIES
-- ============================================================
/*
WHAT ARE ROW ACCESS POLICIES?
─────────────────────────────
Row access policies filter which ROWS a user can see, based on
column values and the user's role/attributes.

MASKING vs ROW ACCESS:
──────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Masking Policy      │ Row Access Policy                                      │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ Hides COLUMN values │ Hides entire ROWS                                      │
│ Shows *** or NULL   │ Row doesn't appear in results                          │
│ All rows visible    │ Filtered rows not visible                              │
│ COUNT(*) unchanged  │ COUNT(*) shows only visible rows                       │
└─────────────────────┴────────────────────────────────────────────────────────┘

HOW ROW ACCESS WORKS:
─────────────────────
┌─────────────────────────────────────────────────────────────────┐
│                     ROW ACCESS FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Original Table: CLIENTS                                       │
│   ┌────────────┬──────────────┬─────────────┐                  │
│   │ CLIENT_ID  │ CLIENT_NAME  │ CLIENT_TIER │                  │
│   ├────────────┼──────────────┼─────────────┤                  │
│   │ 1          │ Hedge Fund A │ INSTITUTIONAL│                 │
│   │ 2          │ John Smith   │ RETAIL       │                  │
│   │ 3          │ Pension Fund │ INSTITUTIONAL│                 │
│   │ 4          │ Jane Doe     │ RETAIL       │                  │
│   └────────────┴──────────────┴─────────────┘                  │
│                                                                 │
│   Query by INV_DATA_ENGINEER:                                   │
│   SELECT * FROM CLIENTS                                         │
│                                                                 │
│   Row Access Policy evaluates each row:                         │
│   - Row 1: INSTITUTIONAL + ENGINEER role → TRUE (visible)       │
│   - Row 2: RETAIL + ENGINEER role → FALSE (hidden)              │
│   - Row 3: INSTITUTIONAL + ENGINEER role → TRUE (visible)       │
│   - Row 4: RETAIL + ENGINEER role → FALSE (hidden)              │
│                                                                 │
│   Result for INV_DATA_ENGINEER:                                 │
│   ┌────────────┬──────────────┬─────────────┐                  │
│   │ CLIENT_ID  │ CLIENT_NAME  │ CLIENT_TIER │                  │
│   ├────────────┼──────────────┼─────────────┤                  │
│   │ 1          │ Hedge Fund A │ INSTITUTIONAL│                 │
│   │ 3          │ Pension Fund │ INSTITUTIONAL│                 │
│   └────────────┴──────────────┴─────────────┘                  │
│                                                                 │
│   (Retail clients are completely invisible!)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

-- ------------------------------------------------------------
-- POLICY 1: ROW_ACCESS_DATA_QUALITY
-- ------------------------------------------------------------
/*
PURPOSE: Prevent use of bad data by filtering quarantined rows

WHY FILTER BY DATA QUALITY?
───────────────────────────
Imagine this scenario:
  - Analyst runs: SELECT AVG(price) FROM prices
  - Table contains 1000 CERTIFIED rows and 50 QUARANTINED rows
  - QUARANTINED rows have incorrect prices (data error)
  - Without filtering: Average includes bad data = wrong answer
  - With filtering: Only CERTIFIED rows = correct answer

ACCESS MATRIX:
┌─────────────────────┬───────────┬─────────────┬─────────────┬────────────┐
│ Role                │ CERTIFIED │ UNDER_REVIEW│ QUARANTINED │ DEPRECATED │
├─────────────────────┼───────────┼─────────────┼─────────────┼────────────┤
│ INV_DATA_ADMIN      │ ✓         │ ✓           │ ✓           │ ✓          │
│ INV_DATA_ENGINEER   │ ✓         │ ✓           │ ✓           │ ✓          │
│ ACCOUNTADMIN        │ ✓         │ ✓           │ ✓           │ ✓          │
├─────────────────────┼───────────┼─────────────┼─────────────┼────────────┤
│ INV_ANALYST         │ ✓         │ ✗           │ ✗           │ ✗          │
│ INV_ML_ENGINEER     │ ✓         │ ✗           │ ✗           │ ✗          │
│ INV_READONLY        │ ✓         │ ✗           │ ✗           │ ✗          │
└─────────────────────┴───────────┴─────────────┴─────────────┴────────────┘
*/
CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_DATA_QUALITY
    AS (dq_status STRING)
    RETURNS BOOLEAN
    COMMENT = 'DQ-based access. CERTIFIED: all. QUARANTINED: engineers only.'
    ->
    CASE
        -- CERTIFIED data: Everyone can see
        WHEN dq_status = 'CERTIFIED' THEN TRUE
        -- UNDER_REVIEW: Only data team can see
        WHEN dq_status = 'UNDER_REVIEW' THEN
            CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_DATA_ENGINEER', 'ACCOUNTADMIN')
        -- QUARANTINED/DEPRECATED: Only data team can see (for fixing)
        WHEN dq_status IN ('QUARANTINED', 'DEPRECATED') THEN
            CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_DATA_ENGINEER', 'ACCOUNTADMIN')
        -- Default: Allow (for rows without DQ status)
        ELSE TRUE
    END;

-- ------------------------------------------------------------
-- POLICY 2: ROW_ACCESS_CLIENT_TIER
-- ------------------------------------------------------------
/*
PURPOSE: Segregate access between institutional and retail clients

WHY SEGREGATE BY CLIENT TIER?
─────────────────────────────
Regulatory and business reasons:
  - INSTITUTIONAL (hedge funds, pensions): 
    - Less privacy regulation
    - Engineers need access for system integration
  - RETAIL (individuals):
    - More privacy regulation (SEC Reg S-P)
    - Only need-to-know access

This implements "least privilege" - give access only where needed.
*/
CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_CLIENT_TIER
    AS (client_tier STRING)
    RETURNS BOOLEAN
    COMMENT = 'Client tier access. INSTITUTIONAL: full access. RETAIL: restricted.'
    ->
    CASE
        -- Admin and Analyst: See all clients
        WHEN CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN') THEN TRUE
        -- Engineers: Only see institutional clients
        WHEN client_tier = 'INSTITUTIONAL' THEN
            CURRENT_ROLE() IN ('INV_DATA_ENGINEER', 'INV_ML_ENGINEER')
        -- Retail clients: Only Admin and Analyst
        WHEN client_tier = 'RETAIL' THEN
            CURRENT_ROLE() IN ('INV_DATA_ADMIN', 'INV_ANALYST', 'ACCOUNTADMIN')
        -- Default: Allow
        ELSE TRUE
    END;

-- VERIFICATION
SHOW ROW ACCESS POLICIES IN SCHEMA INV_GOVERNANCE_DB.POLICIES;


-- ============================================================
-- SECTION 4: GOVERNANCE GRANTS
-- ============================================================
/*
GOVERNANCE PRIVILEGE HIERARCHY:
───────────────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Privilege           │ What It Allows                                         │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CREATE TAG          │ Create new tags in the schema                          │
│ CREATE MASKING POLICY│ Create masking policies in the schema                 │
│ CREATE ROW ACCESS   │ Create row access policies in the schema               │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ APPLY TAG           │ Attach tags to objects across the account              │
│ APPLY MASKING POLICY│ Attach masking policies to columns                     │
│ APPLY ROW ACCESS    │ Attach row access policies to tables                   │
└─────────────────────┴────────────────────────────────────────────────────────┘

WHO GETS WHAT:
──────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Role                │ Governance Privileges                                  │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_DATA_ADMIN      │ FULL: Create + Apply all governance objects            │
│                     │ Reason: Responsible for data platform governance       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_DATA_ENGINEER   │ APPLY TAG only                                         │
│                     │ Reason: Tag data during ETL, but can't create policies │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INV_ML_ADMIN        │ READ tags only (USAGE on schema)                       │
│                     │ Reason: Understand data classification, not modify     │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ Other roles         │ No governance privileges                               │
│                     │ Reason: Consumers, not governors                       │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/

-- DATA_ADMIN: Full governance access
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.TAGS TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.POLICIES TO ROLE INV_DATA_ADMIN;

GRANT CREATE TAG ON SCHEMA INV_GOVERNANCE_DB.TAGS TO ROLE INV_DATA_ADMIN;
GRANT CREATE MASKING POLICY ON SCHEMA INV_GOVERNANCE_DB.POLICIES TO ROLE INV_DATA_ADMIN;
GRANT CREATE ROW ACCESS POLICY ON SCHEMA INV_GOVERNANCE_DB.POLICIES TO ROLE INV_DATA_ADMIN;

GRANT APPLY TAG ON ACCOUNT TO ROLE INV_DATA_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE INV_DATA_ADMIN;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE INV_DATA_ADMIN;

-- ML_ADMIN: Read tags only
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.TAGS TO ROLE INV_ML_ADMIN;

-- DATA_ENGINEER: Apply tags (for tagging during ETL)
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.TAGS TO ROLE INV_DATA_ENGINEER;
GRANT APPLY TAG ON ACCOUNT TO ROLE INV_DATA_ENGINEER;


-- ============================================================
-- SECTION 5: TAG APPLICATION EXAMPLES
-- ============================================================
/*
HOW TO APPLY TAGS TO YOUR DATA:
───────────────────────────────
After creating tags and policies, you need to:
1. Apply tags to tables/columns
2. Apply masking policies to columns
3. Apply row access policies to tables

SYNTAX EXAMPLES:
────────────────
-- Tag a table
ALTER TABLE database.schema.table
    SET TAG tag_name = 'tag_value';

-- Tag a column
ALTER TABLE database.schema.table
    MODIFY COLUMN column_name
    SET TAG tag_name = 'tag_value';

-- Apply masking policy to column
ALTER TABLE database.schema.table
    MODIFY COLUMN column_name
    SET MASKING POLICY policy_name;

-- Apply row access policy to table
ALTER TABLE database.schema.table
    ADD ROW ACCESS POLICY policy_name
    ON (column_name);  -- Column that policy evaluates
*/

-- ============================================================
-- UNCOMMENT AND MODIFY FOR YOUR ACTUAL DATA MODEL:
-- ============================================================

/*
-- ============================================================
-- EXAMPLE 1: Tag and mask a CLIENT dimension table
-- ============================================================

-- Tag the table with domain
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    SET TAG INV_GOVERNANCE_DB.TAGS.DATA_DOMAIN = 'CLIENT';

-- Tag and mask client name (Direct PII)
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN CLIENT_NAME
    SET TAG INV_GOVERNANCE_DB.TAGS.PII_CLASSIFICATION = 'DIRECT_PII';

ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN CLIENT_NAME
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_CLIENT_PII;

-- Tag and mask SSN (Direct PII)
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN SSN
    SET TAG INV_GOVERNANCE_DB.TAGS.PII_CLASSIFICATION = 'DIRECT_PII';

ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN SSN
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_CLIENT_PII;

-- Tag and mask account number
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN ACCOUNT_NUMBER
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_ACCOUNT_NUMBER;

-- Tag and mask email
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    MODIFY COLUMN EMAIL
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_PHONE_EMAIL;

-- Apply row access policy for client tier segregation
ALTER TABLE INV_ANALYTICS_DB.CORE.DIM_CLIENT
    ADD ROW ACCESS POLICY INV_GOVERNANCE_DB.POLICIES.ROW_ACCESS_CLIENT_TIER
    ON (CLIENT_TIER);


-- ============================================================
-- EXAMPLE 2: Tag and protect a TRANSACTIONS fact table
-- ============================================================

-- Tag with domain and layer
ALTER TABLE INV_ANALYTICS_DB.CORE.FACT_TRANSACTIONS
    SET TAG INV_GOVERNANCE_DB.TAGS.DATA_DOMAIN = 'TRANSACTIONS',
        TAG INV_GOVERNANCE_DB.TAGS.MEDALLION_LAYER = 'GOLD',
        TAG INV_GOVERNANCE_DB.TAGS.DATA_QUALITY_STATUS = 'CERTIFIED';

-- Mask transaction amounts
ALTER TABLE INV_ANALYTICS_DB.CORE.FACT_TRANSACTIONS
    MODIFY COLUMN TRANSACTION_AMOUNT
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_FINANCIAL_AMOUNT;

ALTER TABLE INV_ANALYTICS_DB.CORE.FACT_TRANSACTIONS
    MODIFY COLUMN NET_AMOUNT
    SET MASKING POLICY INV_GOVERNANCE_DB.POLICIES.MASK_FINANCIAL_AMOUNT;


-- ============================================================
-- EXAMPLE 3: Tag market data (non-PII)
-- ============================================================

-- Market data has no PII - just tag for classification
ALTER TABLE INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES
    SET TAG INV_GOVERNANCE_DB.TAGS.DATA_DOMAIN = 'MARKET_DATA',
        TAG INV_GOVERNANCE_DB.TAGS.MEDALLION_LAYER = 'SILVER',
        TAG INV_GOVERNANCE_DB.TAGS.SOURCE_SYSTEM = 'BLOOMBERG',
        TAG INV_GOVERNANCE_DB.TAGS.REFRESH_FREQUENCY = 'DAILY',
        TAG INV_GOVERNANCE_DB.TAGS.DATA_QUALITY_STATUS = 'CERTIFIED';

-- Apply DQ row access policy
ALTER TABLE INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES
    ADD ROW ACCESS POLICY INV_GOVERNANCE_DB.POLICIES.ROW_ACCESS_DATA_QUALITY
    ON (DQ_STATUS);
*/


-- ============================================================
-- SECTION 6: VERIFICATION
-- ============================================================

-- Verify all tags
SHOW TAGS IN SCHEMA INV_GOVERNANCE_DB.TAGS;

-- Verify all masking policies
SHOW MASKING POLICIES IN SCHEMA INV_GOVERNANCE_DB.POLICIES;

-- Verify all row access policies
SHOW ROW ACCESS POLICIES IN SCHEMA INV_GOVERNANCE_DB.POLICIES;

-- Verify grants to DATA_ADMIN
SHOW GRANTS TO ROLE INV_DATA_ADMIN;

-- Check where tags are applied (after you apply them)
-- SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
-- WHERE TAG_DATABASE = 'INV_GOVERNANCE_DB'
-- ORDER BY OBJECT_DATABASE, OBJECT_SCHEMA, OBJECT_NAME;


-- ============================================================
-- SECTION 7: COMPREHENSIVE SUMMARY
-- ============================================================
/*
================================================================================
PHASE 08: DATA GOVERNANCE - COMPREHENSIVE SUMMARY
================================================================================

WHAT WE BUILT:
──────────────
A complete data governance layer for investment analysis with:
  - 8 classification tags
  - 4 masking policies
  - 2 row access policies
  - Role-based access control

TAGS CREATED (8):
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Tag                   │ Purpose                                               │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ PII_CLASSIFICATION    │ Client PII level (DIRECT_PII, QUASI_PII, etc.)       │
│                       │ Use: Tag columns containing personal information      │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ DATA_SENSITIVITY      │ Sensitivity level (CONFIDENTIAL, INTERNAL, etc.)     │
│                       │ Use: Overall access control decisions                 │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ DATA_DOMAIN           │ Business domain (MARKET_DATA, PORTFOLIO, etc.)       │
│                       │ Use: Organize and discover data by function           │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MEDALLION_LAYER       │ Data layer (BRONZE, SILVER, GOLD, PLATINUM)          │
│                       │ Use: Indicate data maturity and trust level           │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ DATA_QUALITY_STATUS   │ DQ status (CERTIFIED, QUARANTINED, etc.)             │
│                       │ Use: Prevent use of bad data, enable DQ workflows     │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ SOURCE_SYSTEM         │ Data source (BLOOMBERG, REUTERS, etc.)               │
│                       │ Use: Data lineage, troubleshooting, SLA tracking      │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ REFRESH_FREQUENCY     │ Refresh cadence (REAL_TIME, DAILY, etc.)             │
│                       │ Use: Set user expectations, monitor SLAs              │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ RETENTION_POLICY      │ SEC 17a-4 retention (7_YEARS, 10_YEARS, etc.)        │
│                       │ Use: Compliance, data lifecycle management            │
└───────────────────────┴───────────────────────────────────────────────────────┘

MASKING POLICIES CREATED (4):
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Policy                │ Purpose & Behavior                                    │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_CLIENT_PII       │ Protects client names, identifiers                   │
│                       │ Admin/Analyst: Full value                             │
│                       │ Engineers: Last 4 chars                               │
│                       │ Others: ***MASKED***                                  │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_ACCOUNT_NUMBER   │ Protects financial account numbers                   │
│                       │ Admin/Analyst: Full value                             │
│                       │ Others: ****-****-1234 (last 4 only)                  │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_FINANCIAL_AMOUNT │ Protects monetary values                             │
│                       │ Most roles: Full value                                │
│                       │ READONLY: NULL                                        │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_PHONE_EMAIL      │ Protects contact information                         │
│                       │ Admin/Analyst: Full value                             │
│                       │ Others: jo***@***.com or ***-***-4567                 │
└───────────────────────┴───────────────────────────────────────────────────────┘

ROW ACCESS POLICIES CREATED (2):
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Policy                │ Purpose & Behavior                                    │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ ROW_ACCESS_DATA_QUALITY│ Filters rows by DQ status                            │
│                       │ CERTIFIED: All roles see                              │
│                       │ QUARANTINED: Only engineers see                       │
│                       │ Prevents bad data in production analytics             │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ ROW_ACCESS_CLIENT_TIER │ Filters rows by client type                          │
│                       │ INSTITUTIONAL: Engineers can see                      │
│                       │ RETAIL: Only Admin/Analyst see                        │
│                       │ Implements client data segregation                    │
└───────────────────────┴───────────────────────────────────────────────────────┘

GOVERNANCE GRANTS SUMMARY:
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Role                  │ Governance Privileges                                 │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ INV_DATA_ADMIN        │ CREATE + APPLY: tags, masking, row access            │
│ INV_DATA_ENGINEER     │ APPLY: tags only                                     │
│ INV_ML_ADMIN          │ READ: tags only                                      │
│ Others                │ No governance privileges                              │
└───────────────────────┴───────────────────────────────────────────────────────┘

REGULATORY COMPLIANCE ACHIEVED:
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Regulation            │ How We Address It                                     │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ SOX Section 404       │ Internal controls via masking policies               │
│                       │ Role-based access control documented                  │
│                       │ Audit trail via Snowflake access history              │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ SEC Regulation S-P    │ Client PII masking policies                          │
│                       │ Retail client segregation via row access             │
│                       │ Contact information protection                        │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ SEC 17a-4             │ Retention policy tags                                │
│                       │ 7-year retention tracking                             │
│                       │ Data lifecycle documentation                          │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ FINRA Rule 3110       │ Role-based supervision via RBAC                      │
│                       │ Audit capabilities via tags and logging               │
└───────────────────────┴───────────────────────────────────────────────────────┘

NEXT STEPS:
───────────
1. Identify tables/columns containing PII
2. Apply appropriate tags to classify data
3. Apply masking policies to sensitive columns
4. Apply row access policies to tables with DQ_STATUS or CLIENT_TIER
5. Test with each role to verify masking behavior
6. Document governance in data catalog
7. Train users on data classification

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 08: DATA GOVERNANCE COMPLETE'
UNION ALL
SELECT '  8 Tags + 4 Masking + 2 Row Access'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 08: DATA GOVERNANCE
-- ============================================================
