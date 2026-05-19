# ENHANCEMENT2 — Teams / Power Automate Approval Integration

Extends the Work Order Approval system (`SAPLZFG_WO_APPROVAL`) to route
approval requests through Microsoft Teams via Power Automate.

---

## What It Does

When a Helpdesk user clicks **Remind via Teams** (`&RTMS`) on Screen 0300,
SAP sends selected WO items to Power Automate. The assigned approver receives
a Teams Adaptive Card and clicks **Approve** or **Reject**. Power Automate
POSTs the decision back to SAP, which stamps the result in `ZTWOAPPR` and
`ZTWO_APPR_TMS`.

```
Screen 0300 → [Remind via Teams]
  └── FORM remind_items_via_teams  (LZFG_WO_APPROVALF01)
        └── FM: Z_WO_APPR_TEAMS_SEND  (in ZFG_WO_APPROVAL)
              └── TEAMS_IN_HANDLER->send_approval()
                    └── HTTP POST → Azure APIM → Power Automate
                                          │
                          Teams Adaptive Card to approver
                                          │
                    Power Automate POST → /sap/bc/zwo_appr_teams/callback
                          └── TEAMS_IN_HANDLER (SICF handler)
                                └── UPDATE ztwoappr + ztwo_appr_tms
```

---

## Approval Levels

| Level | Who approves | Field updated in ZTWOAPPR |
|-------|-------------|---------------------------|
| `LVL3` | SDH Branch Plant | `APPROVAL_LVL3`, `APPR_BY_LVL3` |
| `LVL1` | HO ADM (`viandraf@unitedtractors.com`) | `APPROVAL_LVL1`, `APPR_BY_LVL1` |

The system selects the level automatically:
- If `APPROVAL_LVL3` is blank → sends to **SDH** (`LVL3`)
- If `APPROVAL_LVL3 = 'X'` → escalates to **HO ADM** (`LVL1`)

---

## Objects Built in This Enhancement

| Object | Type | Transaction | Note |
|--------|------|-------------|------|
| `ZTWO_APPR_TMS` | Table | SE11 | Teams request tracking |
| `ZAPIGWACL` | Table rows | SM30 | Add APIM IPs (table already exists) |
| `ZCL_VND_JSON_TO_ABAP` | Class | SE24 | JSON parser from ZIP |
| `ZCL_BASE_HTTP` | Class | SE24 | IP auth + response helper |
| `TEAMS_IN_HANDLER` | Class | SE24 | Single class: inbound ICF + outbound send |
| `Z_WO_APPR_TEAMS_SEND` | Function Module | SE37 | Added to existing `ZFG_WO_APPROVAL` |
| `/sap/bc/zwo_appr_teams/callback` | SICF service | SICF | Callback endpoint |
| `Z_WO_APPR_APIM_URL` | TVARVC entry | STVARV | Power Automate / APIM URL |
| `Z_WO_APPR_APIM_KEY` | TVARVC entry | STVARV | APIM subscription key |
| `Z_WO_APPR_API` | Role | PFCG | Assign to service user `TEAMS_API` |

---

## Files in This Folder

| File | Description |
|------|-------------|
| `README.md` | This file — overview and quick reference |
| `ENHANCEMENT2.md` | Original design spec (Teams + Azure APIM architecture) |
| `ENHANCEMENT2_IMPLEMENTATION_GUIDE.md` | Step-by-step SAP build guide (SE11 → SE24 → SE37 → SICF) |

---

## Screen 0300 Changes

| File | Change |
|------|--------|
| `2. Function_Group/3. PAI Modules/USER_COMMAND_0300.abap` | Added `WHEN '&RTMS'. PERFORM remind_items_via_teams.` |
| `2. Function_Group/7. includes/LZFG_WO_APPROVALF01.abap` | Added `FORM remind_items_via_teams` at end |
| `2. Function_Group/5. GUI Status/ZSTAT_0300.abap` | Add button `&RTMS` / "Remind via Teams" / Shift+F7 |

---

## Request ID Format

```
UTX-20260514083045-A1B2C3
│    │              └── First 6 chars of CL_SYSTEM_UUID C32
│    └── YYYYMMDDHHMMSS  (sy-datum + sy-uzeit)
└── sy-sysid
```

---

## Callback JSON (Power Automate → SAP)

```json
{
  "request_id": "UTX-20260514083045-A1B2C3",
  "aufnr":      "0000004711",
  "appr_level": "LVL3",
  "decision":   "APPROVED",
  "approver":   "demakb@unitedtractors.com",
  "comments":   "OK",
  "timestamp":  "2026-05-18T10:30:00Z"
}
```

`decision` accepted values: `APPROVED` · `REJECTED` · `TIMEOUT`

---

## Quick Setup Checklist

- [ ] Create table `ZTWO_APPR_TMS` (SE11)
- [ ] Create class `ZCL_VND_JSON_TO_ABAP` from ZIP (SE24)
- [ ] Create class `ZCL_BASE_HTTP` (SE24)
- [ ] Create class `TEAMS_IN_HANDLER` (SE24)
- [ ] Create FM `Z_WO_APPR_TEAMS_SEND` inside `ZFG_WO_APPROVAL` (SE80/SE37)
- [ ] Create SICF service `/sap/bc/zwo_appr_teams/callback` (SICF)
- [ ] Maintain `Z_WO_APPR_APIM_URL` + `Z_WO_APPR_APIM_KEY` in TVARVC (STVARV)
- [ ] Add APIM egress IPs to `ZAPIGWACL` (SM30)
- [ ] Add `&RTMS` button to `ZSTAT_0300` (SE41)
- [ ] Test with Postman (see guide Step 11)
