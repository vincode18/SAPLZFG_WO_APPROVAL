# 📗 FILE 2 — PROJECT CONFIGURATION & DATA TABLES (v2.0)
## Work Order Approval System — Complete Setup Guide

**Version:** 2.0 (Updated with ZTWOAPPRH + LVL_STATUS + SBWP DLI)
**Target:** SAP Basis / Functional Consultant / ABAP Developer
**Scope:** DDIC Objects, Authorization, TVARVC, SBWP Email Config, Deployment

---

## 🔄 CHANGES FROM v1.0

| Change | Details |
|--------|---------|
| **Table name** | `ZTWOAPPR_H` → **`ZTWOAPPRH`** (no underscore before H) |
| **New field** | Added `LVL_STATUS` to ZTWOAPPRH (type ZDE_LVLSTUS, values 0/1/2) |
| **Removed tables** | ~~`ZTWOEMAIL`~~ and ~~`ZTWOEMAIL_LOG`~~ — no longer needed |
| **Email approach** | Uses **SBWP Distribution Lists (DLI)** — maintained by end users |
| **Lock object** | `EZTWOAPPR_H` → **`EZTWOAPPRH`** (matches table name) |
| **New domain** | `ZDOM_LVLSTUS` for LVL_STATUS field |
| **New data element** | `ZDE_LVLSTUS` for LVL_STATUS field |

---

## 📑 TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [DDIC Domains](#2-ddic-domains)
3. [DDIC Data Elements](#3-ddic-data-elements)
4. [Database Tables](#4-database-tables)
5. [Lock Objects](#5-lock-objects)
6. [Authorization Object](#6-authorization-object)
7. [TVARVC Configuration](#7-tvarvc-configuration)
8. [SBWP Email Configuration (DLI)](#8-sbwp-email-configuration-dli)
9. [Message Class](#9-message-class)
10. [Transaction Code](#10-transaction-code)
11. [PFCG Roles](#11-pfcg-roles)
12. [Deployment Checklist](#12-deployment-checklist)

---

## 1. PROJECT OVERVIEW

### System Architecture (v2.0)

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    SAP WO APPROVAL SYSTEM — v2.0                            ║
║                     ARCHITECTURE OVERVIEW                                   ║
╚════════════════════════════════════════════════════════════════════════════╝

    ┌─────────────────┐         ┌─────────────────┐         ┌───────────────┐
    │  BRANCH USER    │         │  BCSPPD HO (L1) │         │   SDH (L3)    │
    │                 │         │                 │         │               │
    │  Submit WO      │────┐    │  Approve red    │────┐    │  Final Appr   │
    │  for Approval   │    │    │  lines only     │    │    │  All lines    │
    │                 │    │    │ LVL_STATUS→1    │    │    │ LVL_STATUS→2  │
    └─────────────────┘    │    └─────────────────┘    │    └───────────────┘
                           │                           │            │
                           ▼                           ▼            ▼
                    ┌──────────────────────────────────────────────────┐
                    │           SAPMZWO_APPROVAL                        │
                    │         (Module Pool Program)                     │
                    │                                                   │
                    │  Screen 0100 → 0300 → 0310 → 0320 → 0330         │
                    └──────────────────────┬───────────────────────────┘
                                           │
                ┌──────────────────────────┼──────────────────────────┐
                │                          │                          │
                ▼                          ▼                          ▼
    ┌──────────────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
    │   DATA LAYER         │   │   AUTH LAYER        │   │   CONFIG LAYER       │
    │                      │   │                     │   │                      │
    │  • ZTWOAPPRH         │   │  • ZWO_APPR         │   │  • TVARVC            │
    │    (NEW: LVL_STATUS) │   │    (L1/L3/AD)       │   │    ZWO_REJECT_REASON │
    │  • ZTWOAPPR          │   │  • Lock EZTWOAPPRH  │   │    ZWO_CHANGE_REASON │
    │                      │   │                     │   │  • Message Class     │
    │  ❌ NO EMAIL TABLES  │   │                     │   │    ZWO_APPR          │
    │                      │   │                     │   │                      │
    └──────────┬───────────┘   └─────────────────────┘   └──────────────────────┘
               │                                                    │
               │                                                    ▼
               │                                    ┌──────────────────────────┐
               │                                    │   SBWP DLI CONFIG         │
               │                                    │   (No Z tables needed)    │
               │                                    │                           │
               │                                    │   • APPR_100_HO (shared)  │
               │                                    │   • APPR_100_BR (shared)  │
               │                                    │   • APPR_200_HO (shared)  │
               │                                    │   • APPR_200_BR (shared)  │
               │                                    │                           │
               │                                    │   Maintained in SBWP      │
               │                                    │   by end-users themselves │
               │                                    └──────────────────────────┘
               │                                                    ▲
               ▼                                                    │
    ┌──────────────────────────────────────────────────────────────────────────┐
    │  STANDARD SAP (Read-only)              EMAIL RUNTIME                      │
    │                                                                          │
    │  • VIAUFKS (WO Header View)           • CL_BCS (send email)             │
    │  • RESB (Reservations)                • SO_DLI_READ_API1 (read DLI)     │
    │  • PLKO, PLMZ, STPO (Task List)      • SOST (monitor queue)            │
    │  • AUFK, MAKT, MARA                   • SCOT (SMTP config)              │
    └──────────────────────────────────────────────────────────────────────────┘
```

### Object Inventory (v2.0)

| Category | Object | Count |
|----------|--------|-------|
| Domains | `ZDOM_*` | **6** (was 5, added ZDOM_LVLSTUS) |
| Data Elements | `ZDE_*` | **6** (was 5, added ZDE_LVLSTUS) |
| Tables (Z) | `ZTWO*` | **2** (was 4, removed ZTWOEMAIL + ZTWOEMAIL_LOG) |
| Lock Objects | `EZTWOAPPRH` | 1 |
| Authorization | `ZWO_APPR` | 1 |
| TVARVC Entries | `ZWO_*_REASON` | 2 |
| Message Class | `ZWO_APPR` | 1 |
| Transaction | `ZWOAPP` | 1 |
| Function Group | `ZFG_WO_APPROVAL` | 1 |
| Module Pool | `SAPMZWO_APPROVAL` | 1 |
| **SBWP DLIs (NEW)** | `APPR_<plant>_<type>` | per-plant |

---

## 2. DDIC DOMAINS

### Transaction: `SE11` → Domain

### 2.1 ZDOM_APPRSTUS (Header Approval Status)

```
Domain:       ZDOM_APPRSTUS
Description:  WO Approval Status Domain (APPR_STATUS)
Data Type:    CHAR
Length:       1
Output Length: 1

Fixed Values:
┌──────────────┬───────────────────────────┐
│ Single Value │ Short Description          │
├──────────────┼───────────────────────────┤
│ 0            │ No Approval                │
│ 1            │ Request Approval           │
│ 2            │ Parts Approved             │
└──────────────┴───────────────────────────┘
```

### 2.2 ZDOM_LVLSTUS (Level Status — NEW)

```
Domain:       ZDOM_LVLSTUS
Description:  WO Approval Level Status Domain (LVL_STATUS)
Data Type:    CHAR
Length:       1
Output Length: 1

Fixed Values:
┌──────────────┬───────────────────────────┐
│ Single Value │ Short Description          │
├──────────────┼───────────────────────────┤
│ 0            │ Draft (no level approval)  │
│ 1            │ L1 Completed (waiting L3)  │
│ 2            │ L3 Completed (Final)       │
└──────────────┴───────────────────────────┘
```

### 2.3 ZDOM_APPRSTAT (Item Status)

```
Domain:       ZDOM_APPRSTAT
Description:  WO Approval Item Status Domain
Data Type:    CHAR
Length:       20
Output Length: 20

Fixed Values:
┌──────────────┬───────────────────────────┐
│ Single Value │ Short Description          │
├──────────────┼───────────────────────────┤
│ PENDING      │ Pending Approve            │
│ APPROVE      │ Approve Parts              │
│ REJECT       │ Reject Approval            │
└──────────────┴───────────────────────────┘
```

### 2.4 ZDOM_RNCHANGE (Reason for Change)

```
Domain:       ZDOM_RNCHANGE
Description:  Reason for Changes Domain
Data Type:    CHAR
Length:       40
Output Length: 40

No fixed values (loaded from TVARVC ZWO_CHANGE_REASON)
```

### 2.5 ZDOM_RNREJECT (Reason for Reject)

```
Domain:       ZDOM_RNREJECT
Description:  Reason for Rejection Domain
Data Type:    CHAR
Length:       40
Output Length: 40

No fixed values (loaded from TVARVC ZWO_REJECT_REASON)
```

### 2.6 ZDOM_APPRLV (Authorization Level)

```
Domain:       ZDOM_APPRLV
Description:  Approval Authorization Level
Data Type:    CHAR
Length:       2
Output Length: 2

Fixed Values:
┌──────────────┬───────────────────────────┐
│ Single Value │ Short Description          │
├──────────────┼───────────────────────────┤
│ L1           │ Level 1 - BCSPPD HO        │
│ L3           │ Level 3 - Check SDH        │
│ L4           │ Level 4 - Branch           │
│ L5           │ Level 5 - HELPDESK         │
│ AD           │ Administrator              │
└──────────────┴───────────────────────────┘
```

---

## 3. DDIC DATA ELEMENTS

### 3.1 ZDE_APPRSTUS (Header Status)

```
Data Element:  ZDE_APPRSTUS
Description:   WO Approval Status
Domain:        ZDOM_APPRSTUS

Field Labels:
  Short:   Appr.Sts    (10)
  Medium:  Approval Sts (15)
  Long:    Approval Status (20)
  Heading: Approval Status (20)
```

### 3.2 ZDE_LVLSTUS (Level Status — NEW)

```
Data Element:  ZDE_LVLSTUS
Description:   WO Level Status
Domain:        ZDOM_LVLSTUS

Field Labels:
  Short:   Lvl.Sts       (10)
  Medium:  Level Status  (15)
  Long:    Level Status  (20)
  Heading: Level Status  (20)
```

### 3.3 ZDE_APPRSTAT

```
Data Element:  ZDE_APPRSTAT
Description:   Approval Item Status
Domain:        ZDOM_APPRSTAT

Field Labels:
  Short:   Appr.Stat
  Medium:  Approval Stat
  Long:    Approval Status Item
  Heading: Approval Status Item
```

### 3.4 ZDE_RNCHANGE

```
Data Element:  ZDE_RNCHANGE
Description:   Reason for Changes
Domain:        ZDOM_RNCHANGE

Field Labels:
  Short:   Rsn.Chg
  Medium:  Rsn Change
  Long:    Reason for Changes
  Heading: Reason for Changes
```

### 3.5 ZDE_RNREJECT

```
Data Element:  ZDE_RNREJECT
Description:   Reason for Rejection
Domain:        ZDOM_RNREJECT

Field Labels:
  Short:   Rsn.Rej
  Medium:  Rsn Reject
  Long:    Reason for Rejection
  Heading: Reason for Rejection
```

### 3.6 ZDE_APPRLV

```
Data Element:  ZDE_APPRLV
Description:   Approval Level
Domain:        ZDOM_APPRLV

Field Labels:
  Short:   Appr.Lvl
  Medium:  Appr Level
  Long:    Approval Level
  Heading: Approval Level
```

---

## 4. DATABASE TABLES

### 4.1 Table: `ZTWOAPPRH` (Header — RENAMED + NEW FIELD)

**Transaction:** `SE11` → Database Table

```
Table:              ZTWOAPPRH          ← No underscore before H
Description:        WO Approval Header
Delivery Class:     A (Application table)
Browser/Maintenance: Display/Maintenance Allowed
```

**Fields (19 total — was 18, added LVL_STATUS):**

```
┌────┬───────────────────┬─────┬──────┬──────────────┬────────────────────────────┐
│ No │ Field             │ Key │ Init │ Data Element │ Description                │
├────┼───────────────────┼─────┼──────┼──────────────┼────────────────────────────┤
│    │                   │     │      │              │                            │
│    │ ─── KEY ───       │     │      │              │                            │
│  1 │ MANDT             │  ✓  │  ✓   │ MANDT        │ Client                     │
│  2 │ AUFNR             │  ✓  │  ✓   │ AUFNR        │ Work Order Number          │
│    │                   │     │      │              │                            │
│    │ ─── STATUS ───    │     │      │              │                            │
│  3 │ APPR_STATUS       │     │      │ ZDE_APPRSTUS │ Approval Status (0/1/2)    │
│  4 │ LVL_STATUS    ⭐  │     │      │ ZDE_LVLSTUS  │ Level Status (0/1/2) NEW   │
│    │                   │     │      │              │                            │
│    │ ─── WO INFO ───   │     │      │              │                            │
│  5 │ WERKS             │     │      │ WERKS_D      │ Plant                      │
│  6 │ GSBER             │     │      │ GSBER        │ Business Area              │
│  7 │ AUART             │     │      │ AUFART       │ Order Type                 │
│    │                   │     │      │              │                            │
│    │ ─── REQUEST ───   │     │      │              │                            │
│  8 │ REQUESTED_BY      │     │      │ UNAME        │ First release by           │
│  9 │ REQUESTED_DATE    │     │      │ DATUM        │ First release date         │
│ 10 │ REQUESTED_TIME    │     │      │ UZEIT        │ First release time         │
│    │                   │     │      │              │                            │
│    │ ─── FINAL ───     │     │      │              │                            │
│ 11 │ APPROVED_BY       │     │      │ UNAME        │ Final approver (L3)        │
│ 12 │ APPROVED_DATE     │     │      │ DATUM        │ Final approval date        │
│ 13 │ APPROVED_TIME     │     │      │ UZEIT        │ Final approval time        │
│    │                   │     │      │              │                            │
│    │ ─── AUDIT ───     │     │      │              │                            │
│ 14 │ CREATED_BY        │     │      │ UNAME        │ Created by                 │
│ 15 │ CREATED_DATE      │     │      │ DATUM        │ Creation date              │
│ 16 │ CREATED_TIME      │     │      │ UZEIT        │ Creation time              │
│ 17 │ CHANGED_BY        │     │      │ UNAME        │ Last changed by            │
│ 18 │ CHANGED_DATE      │     │      │ DATUM        │ Last change date           │
│ 19 │ CHANGED_TIME      │     │      │ UZEIT        │ Last change time           │
│    │                   │     │      │              │                            │
└────┴───────────────────┴─────┴──────┴──────────────┴────────────────────────────┘

Legend: ⭐ = NEW field in v2.0
```

**Technical Settings:**
- Data Class: `APPL0` (Master data)
- Size Category: `0` (0-5,400 records)
- Buffering: `Not Allowed`
- Enhancement Category: `Can Be Enhanced (Character-Type)`

**TMG (Table Maintenance Generator):**
- Authorization Group: `&NC&`
- Function Group: `ZTWOAPPRH_MT`
- Maintenance Type: One Step
- Screen Number: `0001`

### 🔄 Status State Machine (LVL_STATUS + APPR_STATUS)

```
┌──────────────────────────────────────────────────────────────────────┐
│              COMBINED STATE MATRIX                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   State               APPR_STATUS   LVL_STATUS   Description         │
│   ─────────────────   ───────────   ──────────   ─────────────────   │
│   Initial                  0            0        Draft               │
│   Branch Submitted         1            0        Pending L1          │
│   L1 Saved (Partial)       1            1        L1 Done, Pend L3    │
│   L3 Final Saved           2            2        Fully Approved ✓    │
│                                                                      │
│   Valid transitions:                                                 │
│     0,0 → 1,0 (submit)                                               │
│     1,0 → 1,1 (L1 save)                                              │
│     1,1 → 2,2 (L3 final → triggers email)                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 4.2 Table: `ZTWOAPPR` (Detail — unchanged)

```
Table:              ZTWOAPPR
Description:        WO Approval Detail (Per Material)
Delivery Class:     A
Browser/Maintenance: Display/Maintenance Allowed
```

**Fields:**

```
┌────┬───────────────────┬─────┬──────┬──────────────┬────────────────────────────┐
│ No │ Field             │ Key │ Init │ Data Element │ Description                │
├────┼───────────────────┼─────┼──────┼──────────────┼────────────────────────────┤
│  1 │ MANDT             │  ✓  │  ✓   │ MANDT        │ Client                     │
│  2 │ AUFNR             │  ✓  │  ✓   │ AUFNR        │ Work Order Number          │
│  3 │ MATNR             │  ✓  │  ✓   │ MATNR        │ Material Number            │
│  4 │ CHANGE_ID         │  ✓  │      │ CHAR10       │ Change ID                  │
│  5 │ REASON_CHANGE     │     │      │ ZDE_RNCHANGE │ Reason for Change          │
│  6 │ APPROVAL_STAT     │     │      │ ZDE_APPRSTAT │ Item Status                │
│  7 │ REASON_REJECT     │     │      │ ZDE_RNREJECT │ Reason for Reject          │
│  8 │ APPROVAL_LVL1     │     │      │ FLAG         │ L1 Flag (BCSPPD HO)        │
│  9 │ APPROVAL_LVL3     │     │      │ FLAG         │ L3 Flag (SDH)              │
│ 10 │ APPR_BY_LVL1      │     │      │ SYUNAME      │ L1 Approver                │
│ 11 │ APPR_DATE_LVL1    │     │      │ DATUM        │ L1 Approval Date           │
│ 12 │ APPR_TIME_LVL1    │     │      │ UZEIT        │ L1 Approval Time           │
│ 13 │ APPR_BY_LVL3      │     │      │ SYUNAME      │ L3 Approver                │
│ 14 │ APPR_DATE_LVL3    │     │      │ DATUM        │ L3 Approval Date           │
│ 15 │ APPR_TIME_LVL3    │     │      │ UZEIT        │ L3 Approval Time           │
│ 16 │ AGINGDAYS         │     │      │ INT4         │ Aging in Days              │
│ 17 │ APPR_VALID        │     │      │ FLAG         │ Final Valid Flag           │
│ 18 │ WAERS             │     │      │ WAERS        │ Currency (IDR)             │
│ 19 │ MEINS             │     │      │ MEINS        │ Base Unit                  │
│ 20 │ CREATED_BY        │     │      │ SYUNAME      │ Created By                 │
│ 21 │ CREATED_DATE      │     │      │ DATUM        │ Creation Date              │
│ 22 │ CREATED_TIME      │     │      │ UZEIT        │ Creation Time              │
│ 23 │ CHANGED_BY        │     │      │ SYUNAME      │ Changed By                 │
│ 24 │ CHANGED_DATE      │     │      │ DATUM        │ Change Date                │
│ 25 │ CHANGED_TIME      │     │      │ UZEIT        │ Change Time                │
└────┴───────────────────┴─────┴──────┴──────────────┴────────────────────────────┘
```

---

### 4.3 ❌ REMOVED: `ZTWOEMAIL` (Email Recipients)

**No longer needed.** Recipients are now maintained in **SBWP Distribution Lists**
(see Section 8 below). End-users maintain lists themselves via transaction SBWP,
no ABAP table required.

### 4.4 ❌ REMOVED: `ZTWOEMAIL_LOG` (Email Audit Log)

**No longer needed.** Email monitoring uses **SOST** (SAPconnect Send Requests)
which provides full audit trail of all sent emails natively.

---

## 5. LOCK OBJECTS

### 5.1 EZTWOAPPRH (Renamed)

```
Lock Object:    EZTWOAPPRH         ← No underscore
Description:    Lock for WO Approval Header
Type:           Write Lock (E - Exclusive)

Primary Table:  ZTWOAPPRH

Lock Arguments:
┌──────────┬──────────┬────────────┐
│ Table    │ Field    │ Lock Args  │
├──────────┼──────────┼────────────┤
│ ZTWOAPPRH│ MANDT    │     ✓      │
│ ZTWOAPPRH│ AUFNR    │     ✓      │
└──────────┴──────────┴────────────┘
```

**Generated Function Modules (auto):**
- `ENQUEUE_EZTWOAPPRH` — Set Lock
- `DEQUEUE_EZTWOAPPRH` — Release Lock

---

## 6. AUTHORIZATION OBJECT

### 6.1 ZWO_APPR (unchanged)

```
╔═══════════════════════════════════════════════════════════════════╗
║ Authorization Object: ZWO_APPR                                     ║
║ Class:                ZPM (Custom PM)                              ║
║ Description:          Work Order Approval Authorization            ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║ Authorization Fields:                                             ║
║ ┌─────────────┬──────────────┬──────────────────────────────────┐║
║ │ Field Name  │ Data Element │ Description                      │║
║ ├─────────────┼──────────────┼──────────────────────────────────┤║
║ │ ACTVT       │ ACTVT_GEN    │ Activity (Standard)              │║
║ │ ZAPPR_LVL   │ ZDE_APPRLV   │ Approval Level (L1/L3/L4/L5/AD)  │║
║ │ WERKS       │ WERKS_D      │ Plant                            │║
║ └─────────────┴──────────────┴──────────────────────────────────┘║
║                                                                   ║
║ Activity Values Allowed:                                          ║
║   03 = Display                                                    ║
║   43 = Release/Approve                                            ║
║   02 = Change                                                     ║
║   06 = Delete                                                     ║
║   85 = Reverse                                                    ║
║   *  = All (Admin only)                                           ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Authorization Behavior Matrix

```
┌─────────────────┬──────────┬─────────────┬──────────────────────────────────────────────┐
│ User Level      │ ACTVT    │ ZAPPR_LVL   │ Behavior in Program                          │
├─────────────────┼──────────┼─────────────┼──────────────────────────────────────────────┤
│ Branch User     │ 03, 02   │ (none)      │ Can submit, cannot approve                   │
│ BCSPPD HO (L1)  │ 02       │ L1          │ Approve RED lines → LVL_STATUS=1             │
│ Check SDH (L3)  │ 02       │ L3          │ Approve ALL lines → LVL_STATUS=2             │
│ Branch (L4)     │ 02       │ L4          │ Approve ALL lines → LVL_STATUS=2             │
│ HELPDESK (L5)   │ 02       │ L5          │ Approve ALL lines → LVL_STATUS=2             │
│ Admin (AD)      │ *        │ AD          │ Full access + SBWP DLI mgmt                  │
└─────────────────┴──────────┴─────────────┴──────────────────────────────────────────────┘

Plant Authorization (I_SWERK):
  All levels use FORM build_plant_range to restrict visible plants via I_SWERK / IW33.
  r_swerk is populated from t001w filtered by s_werks + I_SWERK authority check.
```

---

## 7. TVARVC CONFIGURATION

### Transaction: `STVARV` or `STVARVC`

### 7.1 ZWO_REJECT_REASON

```
╔══════════════════════════════════════════════════════════════════════╗
║ Variable Name:  ZWO_REJECT_REASON                                    ║
║ Type:           S (Selection Options - Multiple)                     ║
║ Description:    Reject Reasons for WO Approval                       ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ ┌────────┬──────┬──────┬──────┬─────────────────────────────────────┐║
║ │ NUMB   │ SIGN │ OPTI │ LOW  │ HIGH (Description)                  │║
║ ├────────┼──────┼──────┼──────┼─────────────────────────────────────┤║
║ │ 0001   │  I   │  EQ  │ R01  │ PN tidak sesuai dengan Unit Model   │║
║ │ 0002   │  I   │  EQ  │ R02  │ PN tidak termasuk Parts PS          │║
║ └────────┴──────┴──────┴──────┴─────────────────────────────────────┘║
║                                                                      ║
║ Convention:                                                          ║
║   LOW  = Reason Code (R01, R02, ...)                                ║
║   HIGH = Reason Description (displayed in dropdown)                  ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 7.2 ZWO_CHANGE_REASON

```
╔══════════════════════════════════════════════════════════════════════╗
║ Variable Name:  ZWO_CHANGE_REASON                                    ║
║ Type:           S                                                    ║
║ Description:    Change Reasons for WO Approval                       ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ ┌────────┬──────┬──────┬──────┬─────────────────────────────────────┐║
║ │ NUMB   │ SIGN │ OPTI │ LOW  │ HIGH (Description)                  │║
║ ├────────┼──────┼──────┼──────┼─────────────────────────────────────┤║
║ │ 0001   │  I   │  EQ  │ C01  │ PN Parts Tidak Tersedia             │║
║ │ 0002   │  I   │  EQ  │ C02  │ PN Interchange (ITC)                │║
║ │ 0003   │  I   │  EQ  │ C03  │ PN Parts Subtitusi                  │║
║ │ 0004   │  I   │  EQ  │ C04  │ PN Mengikuti OMM                    │║
║ └────────┴──────┴──────┴──────┴─────────────────────────────────────┘║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Maintenance Steps:

```
1. Transaction: STVARV
2. Click "Change"
3. Tab: "Selection Options"
4. New entry:
   Variable Name:  ZWO_REJECT_REASON
   Type:           S
   Description:    Reject Reasons WO
5. Double-click → Add rows (R01, R02)
6. Save & Activate
7. Repeat for ZWO_CHANGE_REASON
```

### Future Expansion (no code change needed):

```
Add row in STVARV:
  Variable:  ZWO_REJECT_REASON
  LOW:       R03
  HIGH:      PN tidak compatible dengan mesin

→ Immediately available in program dropdown
```

---

## 8. SBWP EMAIL CONFIGURATION (DLI) — NEW APPROACH

> **🔄 CHANGE FROM v1.0:** Previously used custom tables `ZTWOEMAIL` and `ZTWOEMAIL_LOG`.
> Now uses **SBWP Distribution Lists** — native SAP, maintained by end users, no Z tables.

### 8.1 Why SBWP DLI?

| Aspect | ZTWOEMAIL Table (OLD) | SBWP DLI (NEW) |
|--------|----------------------|----------------|
| Who maintains | Basis/Developer (SM30) | End-users themselves (SBWP) |
| Transport needed | Yes (customizing) | No |
| Audit trail | Custom ZTWOEMAIL_LOG | Native SOST |
| Change effort | Data maintenance + transport | User edits in SBWP directly |
| Code complexity | Custom SELECT logic | Standard `SO_DLI_READ_API1` |
| Per-plant routing | Via WERKS field | Via DLI naming convention |

### 8.2 DLI Naming Convention

```
╔══════════════════════════════════════════════════════════════════════╗
║                   DLI NAMING SCHEMA                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║   Pattern:  APPR_<WERKS3>_<TYPE>                                     ║
║                                                                      ║
║   Where:                                                             ║
║     WERKS3 = First 3 chars of Plant code                             ║
║     TYPE   = HO (BCSPPD Head Office)                                 ║
║              BR (Branch)                                             ║
║                                                                      ║
║   Examples:                                                          ║
║     APPR_100_HO  → Plant 1000, BCSPPD HO recipients                  ║
║     APPR_100_BR  → Plant 1000, Branch recipients                     ║
║     APPR_200_HO  → Plant 2000, BCSPPD HO recipients                  ║
║     APPR_200_BR  → Plant 2000, Branch recipients                     ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 8.3 Creating Shared DLI in SBWP

```
Transaction: SBWP
```

**Step-by-step:**

```
1. Run transaction: /NSBWP (SAP Business Workplace)

2. Navigate: Menu bar → Distribution Lists
              or Path: Folders → Distribution lists

3. Click "Create" (F5)

4. Fill in DLI properties:
   ┌────────────────────────────────────────────────────────┐
   │ Title:         APPR_100_HO                             │
   │ Description:   BCSPPD HO Recipients for Plant 100      │
   │ Folder:        General distribution lists (SHARED)     │
   │ Classification: Public                                 │
   └────────────────────────────────────────────────────────┘

5. After creating, add recipients:
   - Tab "Dist. List Content"
   - Click "Insert Recipient" or drag from address book
   - Recipient type: "Internet address" (SMTP email)
   - Enter: john.doe@company.com
   - Name:  John Doe (BCSPPD HO)
   - Repeat for each recipient

6. Save (Ctrl+S)

7. Test read via SE37:
   Function: SO_DLI_READ_API1
   Parameters:
     DLI_NAME:   APPR_100_HO
     SHARED_DLI: X
   → Should return entries in DLI_ENTRIES table
```

### 8.4 Shared vs Personal DLI Fallback

The program implements **2-level fallback** logic:

```
┌───────────────────────────────────────────────────────────────────┐
│                    DLI LOOKUP STRATEGY                             │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1️⃣  Try SHARED DLI first (SHARED_DLI = 'X')                     │
│      │                                                            │
│      ├─ Found → Use shared list ✓                                 │
│      │                                                            │
│      └─ Not found → Go to step 2                                  │
│                                                                   │
│  2️⃣  Fallback to PERSONAL DLI (SHARED_DLI = ' ')                 │
│      │                                                            │
│      ├─ Found → Use personal list ✓                               │
│      │                                                            │
│      └─ Not found → Skip gracefully with warning ⚠️               │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### 8.5 Required SBWP DLIs per Deployment

Create these DLIs per Plant (example for Plants 100, 200):

```
┌────────────────┬──────┬─────────────────────────────────────┐
│ DLI Name       │ Type │ Recipients                          │
├────────────────┼──────┼─────────────────────────────────────┤
│ APPR_100_HO    │ HO   │ BCSPPD HO users for Plant 100       │
│ APPR_100_BR    │ BR   │ Branch team for Plant 100 (Jakarta) │
│ APPR_200_HO    │ HO   │ BCSPPD HO users for Plant 200       │
│ APPR_200_BR    │ BR   │ Branch team for Plant 200 (Surabaya)│
│ APPR_300_HO    │ HO   │ BCSPPD HO users for Plant 300       │
│ APPR_300_BR    │ BR   │ Branch team for Plant 300 (Medan)   │
└────────────────┴──────┴─────────────────────────────────────┘
```

### 8.6 Email Sending Flow

```
╔══════════════════════════════════════════════════════════════════════╗
║                 EMAIL FLOW (v2.0 — SBWP Based)                        ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  [Program Event]                                                     ║
║    (L3 Final Save or Manual Send)                                   ║
║         │                                                            ║
║         ▼                                                            ║
║  [ORCHESTRATOR: process_send_email]                                  ║
║    Collect selected items → Group by PLANT                          ║
║         │                                                            ║
║         ▼                                                            ║
║  [Loop per Plant]                                                    ║
║    Build DLI name: APPR_<plant3>_<type>                             ║
║         │                                                            ║
║         ▼                                                            ║
║  [DLI READER: get_email_from_dli]                                   ║
║    SO_DLI_READ_API1 (shared) → fallback personal                    ║
║    Extract member_adr → gt_recipients                               ║
║         │                                                            ║
║         ▼                                                            ║
║  [HTML BUILDER: build_email_html]                                   ║
║    FIRST: <html><head><style>...headers                             ║
║    BODY:  <tr> per item (red/green rows)                            ║
║    LAST:  </table> + summary + signature                            ║
║         │                                                            ║
║         ▼                                                            ║
║  [BCS SENDER: send_email_bcs]                                       ║
║    cl_bcs=>create_persistent                                        ║
║    cl_document_bcs=>create_document (type='HTM')                    ║
║    cl_cam_address_bcs=>create_internet_address                      ║
║    set_sender / add_recipient / set_send_immediately / send         ║
║    COMMIT WORK                                                      ║
║         │                                                            ║
║         ▼                                                            ║
║  [SOST Queue] → SMTP Gateway → Recipient Inbox                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 8.7 SAP Email Infrastructure Setup (SCOT)

```
Transaction: SCOT
Configuration Required:
  ┌──────────────────────────────────────────┐
  │ 1. Node Type:  SMTP                      │
  │ 2. Mail Host:  mail.company.com          │
  │ 3. Port:       25 (or 587 for TLS)       │
  │ 4. Domain:     company.com               │
  │ 5. Authentication: Yes (if required)     │
  │ 6. Output Format: HTM (for HTML body)    │
  └──────────────────────────────────────────┘

Background Job (SM36):
  Name:        SAPCONNECT_SENDALL
  ABAP Prog:   RSCONN01
  Variant:     SAP&CONNECTALL
  Schedule:    Every 5 minutes
  (Not critical because program uses set_send_immediately)

Monitor Queue:
  Transaction: SOST (Send Requests)
```

### 8.8 SOST Monitoring (Native Audit Trail)

Since we removed `ZTWOEMAIL_LOG`, monitoring is done via SAP-native SOST:

```
Transaction: SOST
Filters:
  Sender:      Your system user or noreply@yourcompany.com
  Sent Date:   Date range
  Status:      🟢 Sent / 🟡 Waiting / 🔴 Error

Status Codes:
  🟢 Sent    = Delivered to SMTP gateway
  🟡 Waiting = In queue (will send via SCOT job or immediate)
  🔴 Error   = Check logs (usually SMTP relay issue)

Drill-down:
  Double-click any row → See recipient list, subject, full HTML body
```

---

## 9. MESSAGE CLASS

### Transaction: `SE91` → Create Message Class `ZWO_APPR`

```
Message Class: ZWO_APPR
Description:   Work Order Approval Messages

Messages:
┌──────┬─────────────────────────────────────────────────────────────┐
│ No.  │ Text                                                        │
├──────┼─────────────────────────────────────────────────────────────┤
│ 001  │ You are not authorized for WO Approval                      │
│ 002  │ TVARVC ZWO_REJECT_REASON not configured                     │
│ 003  │ TVARVC ZWO_CHANGE_REASON not configured                     │
│ 004  │ Work Order &1 not found                                     │
│ 010  │ Please select Reject Reason for item &1                     │
│ 011  │ Please select Change Reason for item &1                     │
│ 012  │ Cannot use Change Reason for rejected item                  │
│ 013  │ Cannot use Reject Reason for approved item                  │
│ 020  │ Please enter Work Order number                              │
│ 021  │ WO &1 is locked by user &2                                  │
│ 030  │ &1 mismatched parts found (red lines)                       │
│ 031  │ All parts match the Task List                               │
│ 040  │ Please select reason for mismatched item &1                 │
│ 050  │ Approval saved successfully                                 │
│ 051  │ L3 final approval complete. Email sent to Branch via SBWP.  │
│ 052  │ L1 approval saved. Pending L3 review.                       │
│ 060  │ Please select at least one line to email                    │
│ 070  │ Please enter Work Order number in email screen              │
│ 080  │ Email sent successfully via SBWP DLI                        │
│ 081  │ Email sending failed: &1                                    │
│ 090  │ No recipients found in DLI &1 — skipped                     │
└──────┴─────────────────────────────────────────────────────────────┘
```

---

## 10. TRANSACTION CODE

### Transaction: `SE93` → Create Transaction Code

```
╔═══════════════════════════════════════════════════════════════════╗
║ Transaction Code: ZWOAPP                                           ║
║ Description:      Work Order Approval                              ║
║ Transaction Type: Dialog Transaction                               ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║ Program:          SAPMZWO_APPROVAL                                 ║
║ Screen Number:    0100 (Main Menu)                                 ║
║                                                                   ║
║ Classification:                                                   ║
║   [ ] Profession. User Transaction                                ║
║   [X] Easy Web Transaction                                        ║
║                                                                   ║
║ GUI Support:                                                      ║
║   [X] SAP GUI for HTML                                            ║
║   [X] SAP GUI for Windows                                         ║
║   [ ] SAP GUI for Java                                            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## 11. PFCG ROLES

### 11.1 Role Hierarchy

```
╔══════════════════════════════════════════════════════════════════════╗
║                          PFCG ROLE STRUCTURE                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║     ┌────────────────────────────────────┐                          ║
║     │  Z:PM:WO_APPR_ADMIN (Composite)    │                          ║
║     │  Full admin + SBWP DLI management  │                          ║
║     └────────────┬───────────────────────┘                          ║
║                  │                                                   ║
║                  ├──▶ Z:PM:WO_APPR_L1 (Single)                      ║
║                  │    BCSPPD HO                                       ║
║                  │    ZWO_APPR: ZAPPR_LVL=L1, ACTVT=43               ║
║                  │    Saves → LVL_STATUS=1                           ║
║                  │                                                   ║
║                  ├──▶ Z:PM:WO_APPR_L3 (Single)                      ║
║                  │    SDH                                             ║
║                  │    ZWO_APPR: ZAPPR_LVL=L3, ACTVT=43               ║
║                  │    Saves → LVL_STATUS=2 + auto email              ║
║                  │                                                   ║
║                  └──▶ Z:PM:WO_APPR_BRANCH (Single)                  ║
║                       Branch User (Submit only)                      ║
║                       ZWO_APPR: ACTVT=02,03 (no approval)            ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 11.2 Role: Z:PM:WO_APPR_L1 (BCSPPD HO)

```
Role Name:     Z:PM:WO_APPR_L1
Description:   WO Approval - BCSPPD HO Level 1

Authorizations:
┌──────────────────┬──────────────────────────────┐
│ Object           │ Values                        │
├──────────────────┼──────────────────────────────┤
│ ZWO_APPR         │ ACTVT      = 03, 43          │
│                  │ ZAPPR_LVL  = L1              │
│                  │ WERKS      = (assigned plant)│
├──────────────────┼──────────────────────────────┤
│ S_TCODE          │ TCD = ZWOAPP, SBWP           │
├──────────────────┼──────────────────────────────┤
│ S_TABU_DIS       │ Display ZTWOAPPRH, ZTWOAPPR  │
└──────────────────┴──────────────────────────────┘

Additional SBWP Permissions:
  - Read SHARED distribution lists (APPR_*_HO)

Users Assigned: BCSPPD01, BCSPPD02
```

### 11.3 Role: Z:PM:WO_APPR_L3 (SDH)

```
Role Name:     Z:PM:WO_APPR_L3
Description:   WO Approval - SDH Level 3

Authorizations:
┌──────────────────┬──────────────────────────────┐
│ Object           │ Values                        │
├──────────────────┼──────────────────────────────┤
│ ZWO_APPR         │ ACTVT      = 03, 43, 85      │
│                  │ ZAPPR_LVL  = L3              │
│                  │ WERKS      = (assigned plant)│
├──────────────────┼──────────────────────────────┤
│ S_TCODE          │ TCD = ZWOAPP, SBWP, SOST     │
├──────────────────┼──────────────────────────────┤
│ S_TABU_DIS       │ Change ZTWOAPPRH, ZTWOAPPR   │
└──────────────────┴──────────────────────────────┘

Users Assigned: SDH_USER01, SDH_USER02
```

### 11.4 Role: Z:PM:WO_APPR_ADMIN (Composite)

```
Role Name:     Z:PM:WO_APPR_ADMIN
Description:   WO Approval - Administrator

Authorizations:
┌──────────────────┬──────────────────────────────┐
│ Object           │ Values                        │
├──────────────────┼──────────────────────────────┤
│ ZWO_APPR         │ ACTVT      = *               │
│                  │ ZAPPR_LVL  = AD              │
│                  │ WERKS      = *               │
├──────────────────┼──────────────────────────────┤
│ S_TCODE          │ ZWOAPP, STVARV, SBWP, SCOT,  │
│                  │ SOST, SM30                   │
├──────────────────┼──────────────────────────────┤
│ S_TABU_DIS       │ Maintain TVARVC              │
└──────────────────┴──────────────────────────────┘

Additional SBWP Permissions:
  - Create/maintain SHARED distribution lists
  - Maintain APPR_*_HO and APPR_*_BR lists
```

---

## 12. DEPLOYMENT CHECKLIST (v2.0)

### 12.1 Development System (DEV)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    DEV DEPLOYMENT CHECKLIST                          │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ DDIC Domains:                                                        │
│  ☐ Create domain ZDOM_APPRSTUS                                       │
│  ☐ Create domain ZDOM_LVLSTUS       ⭐ NEW                            │
│  ☐ Create domain ZDOM_APPRSTAT                                       │
│  ☐ Create domain ZDOM_RNCHANGE                                       │
│  ☐ Create domain ZDOM_RNREJECT                                       │
│  ☐ Create domain ZDOM_APPRLV                                         │
│                                                                      │
│ DDIC Data Elements:                                                  │
│  ☐ Create data element ZDE_APPRSTUS                                  │
│  ☐ Create data element ZDE_LVLSTUS  ⭐ NEW                            │
│  ☐ Create data element ZDE_APPRSTAT                                  │
│  ☐ Create data element ZDE_RNCHANGE                                  │
│  ☐ Create data element ZDE_RNREJECT                                  │
│  ☐ Create data element ZDE_APPRLV                                    │
│                                                                      │
│ Tables:                                                              │
│  ☐ Create table ZTWOAPPRH (19 fields including LVL_STATUS) ⭐        │
│  ☐ Create table ZTWOAPPR  (25 fields)                                │
│  ❌ ZTWOEMAIL     → NOT NEEDED (use SBWP DLI)                        │
│  ❌ ZTWOEMAIL_LOG → NOT NEEDED (use SOST)                            │
│                                                                      │
│ Lock Object:                                                         │
│  ☐ Create lock object EZTWOAPPRH                                     │
│  ☐ Verify auto-generated FMs: ENQUEUE/DEQUEUE_EZTWOAPPRH             │
│                                                                      │
│ Authorization:                                                       │
│  ☐ Create authorization object ZWO_APPR (SU21)                       │
│                                                                      │
│ Configuration:                                                       │
│  ☐ Maintain TVARVC ZWO_REJECT_REASON                                 │
│  ☐ Maintain TVARVC ZWO_CHANGE_REASON                                 │
│                                                                      │
│ SBWP Distribution Lists (NEW): ⭐                                    │
│  ☐ Create shared DLI APPR_100_HO                                     │
│  ☐ Create shared DLI APPR_100_BR                                     │
│  ☐ Create shared DLI APPR_200_HO                                     │
│  ☐ Create shared DLI APPR_200_BR                                     │
│  ☐ (Repeat per plant as needed)                                      │
│  ☐ Populate each DLI with email addresses                            │
│  ☐ Test read via SE37 / SO_DLI_READ_API1                             │
│                                                                      │
│ Email Infrastructure:                                                │
│  ☐ Configure SCOT SMTP node                                          │
│  ☐ Schedule job SAPCONNECT_SENDALL (backup for queued emails)        │
│                                                                      │
│ Message Class:                                                       │
│  ☐ Create message class ZWO_APPR (SE91)                              │
│                                                                      │
│ Program:                                                             │
│  ☐ Create function group ZFG_WO_APPROVAL                             │
│  ☐ Create module pool SAPMZWO_APPROVAL                               │
│  ☐ Design all screens (0100, 0300, 0310, 0320, 0330)                │
│  ☐ Implement 4-layer email F06 (Orchestrator/DLI/HTML/BCS)           │
│  ☐ Verify LVL_STATUS logic in save_as_l1 and save_as_l3              │
│  ☐ Create transaction ZWOAPP (SE93)                                  │
│                                                                      │
│ Roles:                                                               │
│  ☐ Create PFCG role Z:PM:WO_APPR_L1                                  │
│  ☐ Create PFCG role Z:PM:WO_APPR_L3                                  │
│  ☐ Create PFCG role Z:PM:WO_APPR_ADMIN                               │
│  ☐ Assign users to roles                                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 12.2 Transport to QAS

```
Transport Request Sequence:
  ┌─────────────────────────────────────────────────┐
  │ TR1: DDIC Objects (Workbench)                   │
  │      - 6 Domains, 6 Data Elements               │
  │      - 2 Tables (ZTWOAPPRH + ZTWOAPPR)          │
  │      - Lock object EZTWOAPPRH                   │
  │                                                  │
  │ TR2: Authorization Object (Workbench)           │
  │      - ZWO_APPR                                 │
  │                                                  │
  │ TR3: Configuration (Customizing)                │
  │      - TVARVC entries (reason codes)            │
  │      ⚠️ SBWP DLIs NOT transportable             │
  │         → Manual create in each system           │
  │                                                  │
  │ TR4: Message Class (Workbench)                  │
  │      - ZWO_APPR                                 │
  │                                                  │
  │ TR5: Program & Screens (Workbench)              │
  │      - ZFG_WO_APPROVAL                          │
  │      - SAPMZWO_APPROVAL                         │
  │      - Transaction ZWOAPP                       │
  │                                                  │
  │ TR6: Roles (Workbench)                          │
  │      - Z:PM:WO_APPR_*                           │
  └─────────────────────────────────────────────────┘

Post-Transport Manual Steps in QAS/PRD:
  1. Create SBWP DLIs (APPR_*_HO, APPR_*_BR) — manual per system
  2. Populate DLIs with QAS/PRD email addresses
  3. Verify SCOT SMTP is active
  4. Test end-to-end
```

### 12.3 QAS Testing

```
┌──────────────────────────────────────────────────────────────────────┐
│                    QAS TESTING CHECKLIST                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ Functional Testing:                                                  │
│  ☐ Test ZWOAPP transaction access                                    │
│  ☐ Test authorization (L1 cannot approve as L3)                     │
│  ☐ Test L1 save → verify LVL_STATUS=1 in ZTWOAPPRH   ⭐              │
│  ☐ Test L3 save → verify LVL_STATUS=2 in ZTWOAPPRH   ⭐              │
│  ☐ Test state transitions 0,0 → 1,0 → 1,1 → 2,2                     │
│  ☐ Test dropdown loads from TVARVC                                   │
│  ☐ Test adding new reason in TVARVC appears dynamically              │
│  ☐ Test status progression APPR_STATUS 0 → 1 → 2                     │
│  ☐ Test lock mechanism via EZTWOAPPRH (concurrent users)             │
│                                                                      │
│ Email Testing (SBWP DLI): ⭐                                         │
│  ☐ Create test DLIs in QAS                                           │
│  ☐ Test read via SO_DLI_READ_API1 (SE37)                             │
│  ☐ Test email send to HO — verify DLI APPR_<plant>_HO read          │
│  ☐ Test email send to Branch — verify DLI APPR_<plant>_BR read      │
│  ☐ Test auto-email on L3 final save                                  │
│  ☐ Test empty DLI graceful skip (no dump)                            │
│  ☐ Test fallback shared → personal DLI                               │
│  ☐ Verify emails in SOST                                             │
│  ☐ Verify HTML rendering in Outlook                                  │
│                                                                      │
│ Pending Approval Screen:                                             │
│  ☐ Test Pending list filter (LVL_STATUS in 0,1)                     │
│  ☐ Test date range default (last 30 days)                            │
│                                                                      │
│ History Screen:                                                      │
│  ☐ Test History filter (LVL_STATUS=2 only)                          │
│                                                                      │
│ Performance:                                                         │
│  ☐ Load test with 1000 WO items                                      │
│  ☐ Email queue processing time (SOST)                                │
│                                                                      │
│ Code Quality:                                                        │
│  ☐ SCI (Code Inspector) — Priority 1 & 2 = 0                         │
│  ☐ ATC check                                                         │
│  ☐ Extended Syntax Check                                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 12.4 Production Go-Live

```
┌──────────────────────────────────────────────────────────────────────┐
│                    PRODUCTION GO-LIVE CHECKLIST                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ Pre-Go-Live:                                                         │
│  ☐ All transports released and tested in QAS                         │
│  ☐ UAT sign-off received                                             │
│  ☐ User training completed                                           │
│  ☐ SBWP DLI training for admins (how to add/remove members)          │
│  ☐ End-user documentation prepared                                   │
│  ☐ Support team briefed                                              │
│                                                                      │
│ Go-Live Day:                                                         │
│  ☐ Import transports to PRD in sequence                              │
│  ☐ Verify DDIC activation (including LVL_STATUS field)               │
│  ☐ Verify authorization object                                       │
│  ☐ Verify TVARVC entries                                             │
│  ☐ CREATE SBWP DLIs in PRD (manual):        ⭐                       │
│     ☐ APPR_100_HO, APPR_100_BR                                       │
│     ☐ APPR_200_HO, APPR_200_BR                                       │
│     ☐ (per plant)                                                    │
│  ☐ Populate DLIs with PRD email addresses                            │
│  ☐ Verify SCOT email configuration                                   │
│  ☐ Test transaction ZWOAPP                                           │
│  ☐ Test end-to-end with pilot WO                                     │
│  ☐ Verify email delivery via SOST                                    │
│  ☐ Assign users to PFCG roles                                        │
│                                                                      │
│ Post-Go-Live:                                                        │
│  ☐ Monitor SOST for email issues (replaces ZTWOEMAIL_LOG)            │
│  ☐ Monitor ST22 for dumps                                            │
│  ☐ Monitor SM21 for system errors                                    │
│  ☐ Hypercare support (7 days)                                        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 📊 DATA FLOW VISUAL (v2.0)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║              COMPLETE DATA FLOW DIAGRAM — v2.0 (SBWP DLI)                     ║
╚══════════════════════════════════════════════════════════════════════════════╝

    ┌─────────────────────────┐
    │   BRANCH USER SUBMIT    │
    │   (via Screen 0300)     │
    └───────────┬─────────────┘
                │
                ▼
    ┌────────────────────────────────────────────────────────────┐
    │                  COMPARISON LOGIC                           │
    │   VIAUFKS + RESB (WO)  ⟷  PLKO + PLMZ + STPO (TaskList)    │
    │   KEY: RESB-MATNR = STPO-IDNRK                              │
    └───────────┬─────────────────────────────────────────────────┘
                │
                ▼
    ┌─────────────────────────────┐
    │   INSERT/UPDATE ZTWOAPPRH   │
    │   APPR_STATUS = '1'         │
    │   LVL_STATUS  = '0' (Draft) │  ⭐ NEW
    │   REQUESTED_BY/_DATE        │
    └───────────┬─────────────────┘
                │
                ▼
    ┌──────────────────────────────────┐
    │   L1 (BCSPPD HO) REVIEWS         │
    │   See red lines only             │
    │   Check/Uncheck + reason         │
    └───────────┬──────────────────────┘
                │
                ▼
    ┌──────────────────────────────────────┐
    │  UPDATE ZTWOAPPR per MATNR + L1      │
    │  UPDATE ZTWOAPPRH:                    │
    │    APPR_STATUS = '1' (still Request) │
    │    LVL_STATUS  = '1' (L1 Done) ⭐     │
    │                                       │
    │  No email triggered yet              │
    └───────────┬──────────────────────────┘
                │
                ▼
    ┌──────────────────────────────────┐
    │   L3 (SDH) REVIEWS               │
    │   See ALL lines                   │
    │   Review L1 decisions             │
    │   Final approve/override          │
    └───────────┬──────────────────────┘
                │
                ▼
    ┌──────────────────────────────────────┐
    │  UPDATE ZTWOAPPR per MATNR + L3      │
    │  IF all items LVL3 = 'X':             │
    │    UPDATE ZTWOAPPRH:                  │
    │      APPR_STATUS = '2'               │
    │      LVL_STATUS  = '2' (Final) ⭐     │
    │      APPROVED_BY/_DATE/_TIME         │
    └───────────┬──────────────────────────┘
                │
                ▼
    ┌────────────────────────────────────────────────────┐
    │  AUTO EMAIL TRIGGER — via SBWP DLI                 │
    │                                                     │
    │  1. SO_DLI_READ_API1(APPR_<plant>_BR, shared=X)    │
    │     → Read recipients from SBWP                    │
    │                                                     │
    │  2. Build HTML (FIRST + BODY + LAST)               │
    │                                                     │
    │  3. CL_BCS:                                         │
    │     - create_persistent                            │
    │     - create_document (i_type='HTM')               │
    │     - set_sender (noreply@company.com)             │
    │     - add_recipient per DLI member                 │
    │     - set_send_immediately('X')                    │
    │     - send                                          │
    │                                                     │
    │  4. COMMIT WORK                                    │
    │                                                     │
    │  5. Monitor in SOST (replaces ZTWOEMAIL_LOG)       │
    └───────────┬────────────────────────────────────────┘
                │
                ▼
         ┌──────────────┐
         │  EXECUTION   │
         │  IW38/IW39   │
         └──────────────┘
```

---

## 🔍 TABLE RELATIONSHIP DIAGRAM (v2.0)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                  ENTITY RELATIONSHIP DIAGRAM — v2.0                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

      ┌─────────────────────────┐
      │     ZTWOAPPRH           │  ← Header (1 per WO)
      │  ──────────────         │
      │ PK: MANDT, AUFNR        │
      │     APPR_STATUS (0/1/2) │
      │     LVL_STATUS  (0/1/2) │ ⭐ NEW
      │     WERKS, GSBER, AUART │
      │     REQUESTED_BY/_DATE  │
      │     APPROVED_BY/_DATE   │
      │     (+ audit fields)    │
      └──────────┬──────────────┘
                 │ 1:N
                 │ (by AUFNR)
                 ▼
      ┌─────────────────────────┐
      │     ZTWOAPPR            │  ← Detail (N per WO, 1 per material)
      │  ──────────────         │
      │ PK: MANDT, AUFNR,       │
      │     MATNR, CHANGE_ID    │
      │     APPROVAL_STAT       │
      │     APPROVAL_LVL1 (X/ ) │
      │     APPROVAL_LVL3 (X/ ) │
      │     APPR_BY_LVL1/_DATE  │
      │     APPR_BY_LVL3/_DATE  │
      │     REASON_CHANGE       │
      │     REASON_REJECT       │
      │     APPR_VALID          │
      └─────────────────────────┘
                 │
                 │ Read-only JOIN
                 ▼
      ┌─────────────────────────┐
      │     STANDARD SAP        │
      │  ─────────────────      │
      │  VIAUFKS (WO Header)    │
      │  RESB (Reservations)    │
      │  PLKO (Task List)       │
      │  PLMZ (Comp. Alloc.)    │
      │  STPO (BOM Components)  │
      │  AUFK (Order)           │
      │  MAKT (Material Desc.)  │
      └─────────────────────────┘

      ┌─────────────────────────────────────────┐
      │   ❌ NO MORE Z EMAIL TABLES             │
      │                                         │
      │   Recipients → SBWP Distribution List   │
      │   (managed by end-users in SBWP)        │
      │                                         │
      │   Email Audit → SOST transaction        │
      │   (native SAP, no custom log needed)    │
      └─────────────────────────────────────────┘
```

---

## 📋 QUICK REFERENCE CARD

### Status Codes Reference (v2.0)

```
ZTWOAPPRH.APPR_STATUS:
  0 = No Approval (Draft)
  1 = Request (Pending)
  2 = Parts Approved (Complete)

ZTWOAPPRH.LVL_STATUS:        ⭐ NEW
  0 = Draft (no level approved)
  1 = L1 Completed (waiting L3)
  2 = L3 Completed (Final)

Combined Matrix:
  APPR=0, LVL=0 → Initial draft
  APPR=1, LVL=0 → Branch submitted, pending L1
  APPR=1, LVL=1 → L1 done, pending L3
  APPR=2, LVL=2 → Fully approved ✓

ZTWOAPPR.APPROVAL_STAT:
  PENDING  = Not yet processed
  APPROVE  = Approved
  REJECT   = Rejected

ZTWOAPPR Flags:
  APPROVAL_LVL1 = X (L1 approved)
  APPROVAL_LVL3 = X (L3 approved)
  APPR_VALID    = X (Final valid, L3 only)

Authorization ZAPPR_LVL:
  L1 = BCSPPD HO (red lines only)
  L3 = SDH       (all lines)
  AD = Admin     (full)
```

### TVARVC Reason Codes Reference

```
Reject Reasons (ZWO_REJECT_REASON):
  R01 = PN tidak sesuai dengan Unit Model
  R02 = PN tidak termasuk Parts PS
  (Expandable via STVARV)

Change Reasons (ZWO_CHANGE_REASON):
  C01 = PN Parts Tidak Tersedia
  C02 = PN Interchange (ITC)
  C03 = PN Parts Subtitusi
  C04 = PN Mengikuti OMM
  (Expandable via STVARV)
```

### SBWP DLI Reference (v2.0)

```
DLI Naming Convention:
  APPR_<WERKS3>_<TYPE>
  
  WERKS3 = First 3 chars of plant
  TYPE   = HO (BCSPPD Head Office)
         = BR (Branch)

Examples:
  APPR_100_HO  → Plant 1000 BCSPPD HO
  APPR_100_BR  → Plant 1000 Branch
  APPR_200_HO  → Plant 2000 BCSPPD HO
  APPR_200_BR  → Plant 2000 Branch

Lookup Strategy:
  1. Try SHARED DLI (SHARED_DLI='X')
  2. Fallback PERSONAL DLI (SHARED_DLI=' ')
  3. Skip gracefully if both empty

Function Module: SO_DLI_READ_API1
Sender Email:    noreply@yourcompany.com (configurable)
```

### Screen Navigation Reference

```
0100 → Main Menu
0300 → Approval WO (Table Control + LVL_STATUS display)
0310 → Pending Approval (LVL_STATUS IN 0,1)
0320 → Approval History (LVL_STATUS=2)
0330 → Email Sending (via SBWP DLI)
```

### Key Transactions Reference

```
Developer Tools:
  SE11   - DDIC Objects
  SE80   - Object Navigator
  SE91   - Message Class
  SE93   - Transaction Code
  SU21   - Authorization Object
  STVARV - TVARVC Maintenance
  SE37   - Function Module Test (for SO_DLI_READ_API1)

User Tools:
  ZWOAPP - WO Approval Transaction
  SBWP   - Maintain Distribution Lists ⭐
  SOST   - Email Queue Monitor ⭐ (replaces ZTWOEMAIL_LOG)
  SCOT   - Email Configuration

Admin Tools:
  PFCG   - Role Maintenance
  SU01   - User Administration
  SM37   - Background Jobs
  ST22   - Dump Analysis
```

---

## 🎯 FINAL SUMMARY (v2.0)

### What This Project Delivers

```
✅ 2-Level Approval Workflow (L1 BCSPPD HO + L3 SDH)
✅ Work Order vs Task List Parts Comparison
✅ Red Line Visualization for Mismatches
✅ Dynamic Reason Codes via TVARVC (no code changes)
✅ Table-based State Machine (APPR_STATUS + LVL_STATUS) ⭐
✅ SBWP Distribution List Email (NO custom email tables) ⭐
✅ Per-plant email segregation via DLI naming
✅ Custom Authorization Object (L1/L3/AD)
✅ Complete Audit Trail (L1/L3 stamps + native SOST)
✅ Pending Approval monitoring with LVL_STATUS filter
✅ History & Reporting (LVL_STATUS=2 only)
✅ Lock mechanism for concurrent access
✅ Graceful DLI fallback (shared → personal → skip)
```

### Comparison: v1.0 vs v2.0

| Aspect | v1.0 (Previous) | v2.0 (Current) |
|--------|-----------------|----------------|
| Header table | ZTWOAPPR_H (18 fields) | **ZTWOAPPRH (19 fields)** |
| Lock object | EZTWOAPPR_H | **EZTWOAPPRH** |
| LVL_STATUS field | Not present | **Added (0/1/2)** |
| Email recipients | Custom table ZTWOEMAIL | **SBWP DLI (SO_DLI_READ_API1)** |
| Email audit | Custom table ZTWOEMAIL_LOG | **Native SOST transaction** |
| Email library | CL_BCS + custom SELECT | **CL_BCS + SBWP skill pattern** |
| DLI naming | n/a | **APPR_<plant>_<type>** |
| Tables needed | 4 (ZTWOAPPR_H/APPR/EMAIL/LOG) | **2 (ZTWOAPPRH/APPR)** |
| Config transport | Required for email changes | **No transport for DLI changes** |
| End-user control | IT only | **End-users maintain DLIs in SBWP** |

### Files Covered

```
📘 File 1: 01_ABAP_PROGRAMMING_PROMPT.md (v2.0)
   - ZTWOAPPRH + LVL_STATUS logic
   - 4-layer SBWP email pattern
   - All function group includes
   - PBO/PAI modules
   - Screen ASCII views

📗 File 2: 02_PROJECT_CONFIGURATION.md (v2.0) — This file
   - All DDIC objects (6 domains + 6 data elements)
   - 2 tables (ZTWOAPPRH with LVL_STATUS + ZTWOAPPR)
   - SBWP DLI setup (replaces email tables)
   - Authorization + TVARVC
   - PFCG roles
   - Deployment checklist
```

---

**END OF FILE 2 v2.0 — PROJECT CONFIGURATION & DATA TABLES**
**With ZTWOAPPRH + LVL_STATUS + SBWP Distribution List Integration**
