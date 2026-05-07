*&---------------------------------------------------------------------*
*& ZTWOAPPR TABLE DEFINITION
*&---------------------------------------------------------------------*
*& Transaction: SE11
*& Table Name: ZTWOAPPR
*& Description: Approval Parts Based on Tasklist BOM
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* FIELD DEFINITIONS (Create in SE11)
*----------------------------------------------------------------------*

FIELD NAME          DATA ELEMENT         KEY   LENGTH   DESCRIPTION
----------------    -----------------    ----  ------   ---------------------
MANDT               MANDT                X     3        Client
AUFNR               AUFNR                X     12       Order Number
MATNR               MATNR                X     18       Material Number
CHANGE_ID           CHAR10               X     10       Change ID
REASON_CHANGE       ZDE_RNCHANGE               40       Reason for Changes
APPROVAL_STAT       ZDE_APPRSTAT               20       Approval Status (Domain)
REASON_REJECT       ZDE_RNREJECT               40       Reason for Rejection
APPROVAL_LVL1	      FLAG                        1       Approval Level 1 Flag (BCSPPD/HO)
APPROVAL_LVL3	      FLAG                        1       Approval Level 3 Flag (SDH)
APPROVED_BY_LVL1    SYUNAME                    12       Approved By User - Level 1 (BCSPPD)
APPROVED_DATE_LVL1  DATUM                      8        Approval Date - Level 1 (BCSPPD)
APPROVED_TIME_LVL1  UZEIT                      6        Approval Time - Level 1 (BCSPPD)
APPROVED_BY_LVL3    SYUNAME                    12       Approved By User - Level 3 (SDH)
APPROVED_DATE_LVL3  DATUM                      8        Approval Date - Level 3 (SDH)
APPROVED_TIME_LVL3  UZEIT                      6        Approval Time - Level 3 (SDH)
AGINGDAYS           INT4                       10       Aging in Days
CREATED_BY          SYUNAME                    12       Created By
CREATED_DATE        DATUM                      8        Created Date
CREATED_TIME        UZEIT                      6        Created Time
CHANGED_BY          SYUNAME                    12       Changed By
CHANGED_DATE        DATUM                      8        Changed Date
CHANGED_TIME        UZEIT                      6        Changed Time
APPR_VALID          FLAG                        1       Approval Validation Flag
WAERS               WAERS                       5        Currency Key (hardcoded IDR)
MEINS               MEINS                       3        Base Unit of Measure

*----------------------------------------------------------------------*
* NOTE: APPROVAL_STATUS uses custom data element with domain
*----------------------------------------------------------------------*
Data Element: ZAPPROVAL_STATUS
Domain: ZAPPROVAL_STATUS_DOM
Fixed Values:
  - PENDING  (Pending Approve)
  - APPROVE  (Approve Parts)
  - REJECT   (Reject Approval)

*----------------------------------------------------------------------*
* APPROVAL LEVEL TRACKING FIELDS
*----------------------------------------------------------------------*
Level 1 (BCSPPD/HO) Tracking:
  - APPROVED_BY_LVL1:   Username of BCSPPD approver
  - APPROVED_DATE_LVL1: Date when BCSPPD approved (YYYY-MM-DD)
  - APPROVED_TIME_LVL1: Time when BCSPPD approved (HH:MM:SS)

Level 3 (SDH) Tracking:
  - APPROVED_BY_LVL3:   Username of SDH approver
  - APPROVED_DATE_LVL3: Date when SDH approved (YYYY-MM-DD)
  - APPROVED_TIME_LVL3: Time when SDH approved (HH:MM:SS)

Note: Level 2 (PDH) was removed from the approval flow (v8.2+)
      Only L1 (BCSPPD) and L3 (SDH) are tracked

*----------------------------------------------------------------------*
* MIGRATION/UPDATE STEPS FOR NEW FIELDS (SAP v8.2+)
*----------------------------------------------------------------------*

If upgrading from v7.8 to v8.2+:

Step 1: Add new fields to ZTWOAPPR table in SE11
  - APPROVED_BY_LVL1   (Data Type: SYUNAME, Length: 12)
  - APPROVED_DATE_LVL1 (Data Type: DATUM, Length: 8)
  - APPROVED_TIME_LVL1 (Data Type: UZEIT, Length: 6)
  - APPROVED_BY_LVL3   (Data Type: SYUNAME, Length: 12)
  - APPROVED_DATE_LVL3 (Data Type: DATUM, Length: 8)
  - APPROVED_TIME_LVL3 (Data Type: UZEIT, Length: 6)

Step 2: Remove PDH field (if present)
  - APPROVAL_LVL2      (Data Type: FLAG)
  - APPROVED_BY_LVL2   (if exists from earlier versions)
  - APPROVED_DATE_LVL2 (if exists from earlier versions)
  - APPROVED_TIME_LVL2 (if exists from earlier versions)

Step 3: Ensure generic tracking fields remain:
  - CREATED_BY, CREATED_DATE, CREATED_TIME (for record creation)
  - CHANGED_BY, CHANGED_DATE, CHANGED_TIME (for last modification)

Step 4: Deploy updated approval report ZR_SVC_WO_APPROVAL v8.2+
  - Implements automatic population of level-specific tracking fields
  - Maintains backward compatibility with existing data

*----------------------------------------------------------------------*

*----------------------------------------------------------------------*
* TECHNICAL SETTINGS (SE11 > Technical Settings)
*----------------------------------------------------------------------*
Data Class:     APPL1 (Master data)
Size Category:  9 (0 to 1,000 records)
Buffering:      Not allowed

*----------------------------------------------------------------------*
* DATA ELEMENTS TO CREATE (if not exist)
*----------------------------------------------------------------------*
CHAR10:  Domain CHAR10 with type CHAR length 10
CHAR20:  Domain CHAR20 with type CHAR length 20
CHAR100: Domain CHAR100 with type CHAR length 100

*----------------------------------------------------------------------*
* SAMPLE DATA INSERT (Using Domain Values)
*----------------------------------------------------------------------*
INSERT INTO ztwoappr VALUES 
('100', '000100001234', '100000001', 'CHG0001', 'Material substitution', 
 'PENDING', '', 'X', ' ', 
 '', '00000000', '000000', '', '00000000', '000000',
 5, 'USER01', '20250120', '120000', 'USER01', '20250120', '120000',
 'USER01', '20250120', '120000', ' ', 'IDR', 'EA').

INSERT INTO ztwoappr VALUES 
('100', '000100001235', '100000002', 'CHG0002', 'Quality improvement', 
 'APPROVE', '', 'X', 'X', 
 'SUPER01', '20250115', '100000', 'SUPER02', '20250119', '140000',
 15, 'USER01', '20250105', '120000', 'SUPER02', '20250119', '150000',
 'SUPER02', '20250119', '150000', 'X', 'IDR', 'EA').

INSERT INTO ztwoappr VALUES 
('100', '000100001236', '100000003', 'CHG0003', 'Cost optimization', 
 'REJECT', 'Insufficient justification', 'X', ' ', 
 'SUPER01', '20250114', '095000', '', '00000000', '000000',
 10, 'USER01', '20250110', '120000', 'SUPER01', '20250114', '100000',
 'USER01', '20250110', '120000', ' ', 'IDR', 'EA').

*----------------------------------------------------------------------*
* NOTE: Domain values used
*----------------------------------------------------------------------*
PENDING = Pending Approve (displays as "Pending Approve" in ALV)
APPROVE = Approve Parts (displays as "Approve Parts" in ALV)
REJECT  = Reject Approval (displays as "Reject Approval" in ALV)

*----------------------------------------------------------------------*
* APPROVAL TRACKING ENHANCEMENT (v8.2+)
*----------------------------------------------------------------------*
The new tracking fields (APPROVED_BY_LVL1/3, APPROVED_DATE_LVL1/3,
APPROVED_TIME_LVL1/3) are automatically populated by the report 
ZR_SVC_WO_APPROVAL when an approver approves a component.

Tracking Behavior:
  • APPROVED_BY_LVL1 is set when APPROVAL_LVL1 flag = 'X'
  • APPROVED_DATE_LVL1 records the approval date in YYYY-MM-DD format
  • APPROVED_TIME_LVL1 records the approval time in HH:MM:SS format
  • Same pattern applies for APPROVED_BY_LVL3, APPROVED_DATE_LVL3, APPROVED_TIME_LVL3
  
Audit Trail Query:
  SELECT aufnr, matnr, approved_by_lvl1, approved_date_lvl1,
         approved_by_lvl3, approved_date_lvl3, approval_stat
    FROM ztwoappr
    WHERE approved_by_lvl1 = 'USERNAME'
    ORDER BY approved_date_lvl1 DESC;