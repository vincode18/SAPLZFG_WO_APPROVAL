# ENHANCEMENT2 — Step-by-Step SAP Build Guide
## Teams / Power Automate Approval Callback

> **Goal:** When a Helpdesk user clicks **Remind via Teams** on Screen 0300,
> SAP sends selected WO items to Power Automate. The approver gets a Teams
> Adaptive Card. When they click **Approve / Reject**, Power Automate POSTs
> back to SAP. SAP updates `ZTWO_APPR_TMS` and optionally auto-releases the
> Work Order.
>
> **What we build:**
> - **1 DDIC table** — `ZTWO_APPR_TMS` (business state)
> - **IP whitelist** — existing table `ZAPIGWACL` (`API_NAME` + `EXT_IP` exact match)
> - **3 Classes** — `ZCL_VND_JSON_TO_ABAP` · `ZCL_BASE_HTTP` · `TEAMS_IN_HANDLER`
> - **1 Function Group + 1 FM** — `ZFG_WO_APPR_TEAMS` · `Z_WO_APPR_TEAMS_SEND`
> - **1 SICF service** — the callback URL Power Automate POSTs to
> - **Screen 0300 hook** — `&RTMS` button in existing program

> **Class design — one class does everything:**
> `TEAMS_IN_HANDLER` is the **single main class**.
> - **Inbound** (callback from Power Automate) → implements `IF_HTTP_EXTENSION`
> - **Outbound** (trigger to Power Automate) → public method `SEND_APPROVAL`
>
> No separate outbound class needed. The FM calls `TEAMS_IN_HANDLER->send_approval`.
> The SICF service binds `TEAMS_IN_HANDLER` as the HTTP handler.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Step 1 — Package](#2-step-1--package)
3. [Step 2 — Table ZTWO_APPR_TMS](#3-step-2--table-ztwo_appr_tms)
4. [Step 3 — IP Whitelist: existing table ZAPIGWACL](#4-step-3--ip-whitelist-existing-table-zapigwacl)
5. [Step 4 — Class ZCL_VND_JSON_TO_ABAP (from ZIP)](#5-step-4--class-zcl_vnd_json_to_abap-from-zip)
6. [Step 5 — Class ZCL_BASE_HTTP](#6-step-5--class-zcl_base_http)
7. [Step 6 — Class TEAMS_IN_HANDLER (single main class)](#7-step-6--class-teams_in_handler-single-main-class)
8. [Step 7 — Function Group & FM Z_WO_APPR_TEAMS_SEND](#8-step-7--function-group--fm-z_wo_appr_teams_send)
9. [Step 8 — SICF Service](#9-step-8--sicf-service)
10. [Step 9 — TVARVC + ZAPIGWACL entries](#10-step-9--tvarvc--zapigwacl-entries)
11. [Step 10 — Hook into Screen 0300](#11-step-10--hook-into-screen-0300)
12. [Step 11 — Test with Postman](#12-step-11--test-with-postman)
13. [Object Summary](#13-object-summary)

---

## 1. Architecture Overview

```
Screen 0300 (ZWOAPP)
  │  Helpdesk marks items → clicks [Remind via Teams]
  │
  ▼
FORM remind_items_via_teams  (LZFG_WO_APPROVALF01)
  └── FM: Z_WO_APPR_TEAMS_SEND
        └── TEAMS_IN_HANDLER->send_approval( )       ← outbound side
              ├── INSERT rows in ZTWO_APPR_TMS (TEAMS_STATUS = SENT)
              └── HTTP POST → Power Automate / APIM
                                │
                                │  Teams Adaptive Card sent to approver
                                │  Approver clicks  Approve / Reject
                                ▼
                  Power Automate POSTs callback JSON
                                │
                                ▼
           SICF: /sap/bc/zwo_appr_teams/callback
                                │
                                ▼
           TEAMS_IN_HANDLER (IF_HTTP_EXTENSION)      ← inbound side
             1. Read body FIRST
             2. IP check via ZCL_BASE_HTTP → ZAPIGWACL
             3. Clean body + parse JSON with ZCL_VND_JSON_TO_ABAP->json_to_abap
             4. Validate required fields
             5. UPDATE ZTWO_APPR_TMS
             6. If APPROVED: check all done → BAPI release WO
             7. Return JSON response
```

**Callback JSON payload** (Power Automate → SAP):

```json
{
  "request_id": "UTX-20260514083045-A1B2C3",
  "aufnr":      "0000004711",
  "decision":   "APPROVED",
  "approver":   "alice@unitedtractors.com",
  "comments":   "OK, approved",
  "timestamp":  "2026-05-18T10:30:00Z"
}
```

---

## 2. Step 1 — Package

**Transaction: SE21**

1. Create package `ZWO_APPROVAL_TEAMS`
   - Short text: `WO Approval — Teams Integration`
   - Application component: `PM` (or your customer component)
2. Assign a workbench transport request
3. All objects in this guide go into this package — **do not mix with** `ZWO_APPROVAL`

---

## 3. Step 2 — Table ZTWO_APPR_TMS

**Transaction: SE11 → Database table → Create**

One row per Teams request (INSERT on SEND, UPDATE on APPROVED / REJECTED / TIMEOUT).

### Field definition

| Field | Key | Type/Domain | Description |
|-------|-----|------------|-------------|
| `MANDT` | ✔ | `MANDT` | Client |
| `AUFNR` | ✔ | `AUFNR` | Work Order |
| `TEAMS_REQ_ID` | ✔ | `CHAR32` | Power Automate run-id (correlation) |
| `APPR_VALID` | | `CHAR1` | `X`=Approved · `R`=Rejected · ` `=Open |
| `TEAMS_STATUS` | | `CHAR10` | `SENT` · `APPROVED` · `REJECTED` · `TIMEOUT` |
| `APPR_LEVEL` | | `CHAR4` | `LVL1`=HO ADM · `LVL3`=SDH Branch Plant |
| `WERKS` | | `WERKS_D` | Plant |
| `APPR_USER` | | `SYUNAME` | Who approved/rejected in Teams |
| `APPR_DATE` | | `DATS` | Date of decision |
| `APPR_TIME` | | `TIMS` | Time of decision |
| `SENT_BY` | | `SYUNAME` | Helpdesk user who triggered send |
| `SENT_AT` | | `TIMESTAMPL` | When the request was sent |
| `LAST_UPDATED` | | `TIMESTAMPL` | Last status change |

### Settings
- **Delivery class:** `A`
- **Display/Maintenance:** Allowed
- **Technical settings:** Data class `APPL1`, Size category `0`
- **Secondary index `Z01`** on `TEAMS_REQ_ID` (non-unique)

Activate.

---

## 4. Step 3 — IP Whitelist: existing table ZAPIGWACL

> **No new table needed.** `ZCL_BASE_HTTP->m_check_ip_auth` queries
> `ZAPIGWACL` — the same table and the same logic you already use in
> production:
>
> ```abap
> SELECT SINGLE * FROM zapigwacl
>   WHERE api_name = i_class_name   " = 'TEAMS_IN_HANDLER'
>     AND ext_ip   = i_ip.          " exact caller IP
> ```

`API_NAME` is the handler class name stripped of the `\CLASS=` prefix.
Because we use one merged class, every row for this integration will have
`API_NAME = TEAMS_IN_HANDLER`.

You will populate the actual IP rows in **Step 9**.

> ⚠️ `EXT_IP` is an **exact match** — add one row per individual APIM
> outbound IP.

---

## 5. Step 4 — Class ZCL_VND_JSON_TO_ABAP (from ZIP)

**Transaction: SE24 → Create class**

### 5.1 Class header (Properties tab)

| Field | Value |
|-------|-------|
| Class name | `ZCL_VND_JSON_TO_ABAP` |
| Description | `JSON to ABAP deserializer` |
| Instantiation | `Public` |
| Final | Yes |

### 5.2 Attributes tab

| Name | Visibility | Level | Typing | Type |
|------|-----------|-------|--------|------|
| `MV_JSON` | Private | Instance | TYPE | `STRING` |

### 5.3 Methods tab

| Method | Level | Visibility |
|--------|-------|-----------|
| `CONSTRUCTOR` | Instance | Public |
| `JSON_TO_ABAP` | Instance | Public |
| `PARSE` | Instance | Public |
| `STRIP_QUOTES` | Instance | Private |
| `UNESCAPE` | Instance | Private |

### 5.4 Method parameters

**CONSTRUCTOR**

| Dir | Name | Typing | Type |
|-----|------|--------|------|
| Import | `IV_JSON` | TYPE | `STRING` |

**JSON_TO_ABAP** ← this is the method we call directly

| Dir | Name | Typing | Type |
|-----|------|--------|------|
| Import (Exporting) | `IV_JSON` | TYPE | `STRING` |
| Changing | `CS_DATA` | TYPE | `ANY` |

> Note: In SE24, `IV_JSON` goes on the **Importing** side of the method
> interface (it is input to the method, named `IV_`).

**PARSE**

| Dir | Name | Typing | Type |
|-----|------|--------|------|
| Changing | `CS_DATA` | TYPE | `ANY` |

**STRIP_QUOTES**

| Dir | Name | Typing | Type |
|-----|------|--------|------|
| Import | `IV_INPUT` | TYPE | `STRING` |
| Return | `RV_OUTPUT` | TYPE | `STRING` |

**UNESCAPE**

| Dir | Name | Typing | Type |
|-----|------|--------|------|
| Import | `IV_INPUT` | TYPE | `STRING` |
| Return | `RV_OUTPUT` | TYPE | `STRING` |

### 5.5 Source code

Copy method bodies from the ZIP files exactly as-is:
- `CONSTRUCTOR.abap` → `CONSTRUCTOR`
- `JSON_TO_ABAP.abap` → `JSON_TO_ABAP`
- `PARSE.abap` → `PARSE`
- `STRIP_QUOTES.abap` → `STRIP_QUOTES`
- `UNESCAPE.abap` → `UNESCAPE`

Activate.

### 5.6 Usage pattern in `TEAMS_IN_HANDLER`

```abap
" Create instance, then call json_to_abap METHOD directly
DATA(lo_json) = NEW zcl_vnd_json_to_abap( iv_json = lv_request ).
lo_json->json_to_abap(
  EXPORTING iv_json = lv_request
  CHANGING  cs_data = ls_data ).
```

---

## 6. Step 5 — Class ZCL_BASE_HTTP

**Transaction: SE24 → Create class**

Reusable helper: IP check + response builder.
Queries `ZAPIGWACL` exactly as your existing production handler does.

### 6.1 Class header

| Field | Value |
|-------|-------|
| Class name | `ZCL_BASE_HTTP` |
| Description | `HTTP handler base — IP auth + JSON response` |
| Instantiation | `Public` |

### 6.2 Methods

| Method | Level | Visibility |
|--------|-------|-----------|
| `M_CHECK_IP_AUTH` | Instance | Public |
| `M_ITAB_TO_JSON` | Instance | Public |
| `M_SET_RESPONSE` | Instance | Public |

### 6.3 Method parameters

**M_CHECK_IP_AUTH**

| Dir | Name | Type |
|-----|------|------|
| Import | `I_IP` | `RFCIPV6ADDR` |
| Import | `I_CLASS_NAME` | `REPID` |
| Export | `E_ERROR` | `CHAR1` |

**M_ITAB_TO_JSON**

| Dir | Name | Type |
|-----|------|------|
| Import | `DATA` | `ANY` |
| Export | `JSON` | `STRING` |

**M_SET_RESPONSE**

| Dir | Name | Type |
|-----|------|------|
| Import | `IO_SERVER` | `REF TO IF_HTTP_SERVER` |
| Import | `I_CODE` | `I` |
| Import | `I_REASON` | `STRING` |
| Import | `I_BODY` | `STRING` |

### 6.4 Implementation

```abap
CLASS zcl_base_http IMPLEMENTATION.

  METHOD m_check_ip_auth.
    " Same query as your existing production handler
    DATA lw_extip TYPE zapigwacl.

    SELECT SINGLE * FROM zapigwacl
      INTO lw_extip
      WHERE api_name = i_class_name
        AND ext_ip   = i_ip.

    IF sy-subrc <> 0.
      e_error = 'X'.
    ENDIF.
  ENDMETHOD.

  METHOD m_itab_to_json.
    json = /ui2/cl_json=>serialize(
             data     = data
             compress = abap_true ).
  ENDMETHOD.

  METHOD m_set_response.
    io_server->response->set_status( code = i_code reason = i_reason ).
    io_server->response->set_header_field(
      name = 'Content-Type' value = 'application/json' ).
    io_server->response->set_cdata( data = i_body ).
  ENDMETHOD.

ENDCLASS.
```

Activate.

---

## 7. Step 6 — Class TEAMS_IN_HANDLER (single main class)

**Transaction: SE24 → Create class**

This is the **one class** that does everything:
- **Inbound** — implements `IF_HTTP_EXTENSION` so SAP ICF routes the
  Power Automate callback to it.
- **Outbound** — `SEND_APPROVAL` method is called by the FM when the
  Helpdesk presses `&RTMS`. This replaces the old separate
  `SAP_OUT_MSFLOW` / `ZCL_WO_APPR_TEAMS_HANDLER` class.

```
TEAMS_IN_HANDLER
  ├── IF_HTTP_EXTENSION~HANDLE_REQUEST   ← SICF inbound handler
  ├── SEND_APPROVAL (public)             ← outbound to Power Automate
  ├── UPDATE_APPROVAL_STATUS (private)   ← writes ZTWO_APPR_TMS
  └── CHECK_AND_RELEASE (private)        ← BAPI release when all approved
```

### 7.1 Class header (Properties tab)

| Field | Value |
|-------|-------|
| Class name | `TEAMS_IN_HANDLER` |
| Description | `Teams approval — inbound callback + outbound trigger` |
| Instantiation | `Public` |
| Final | Yes |

### 7.2 Interfaces tab

Add: `IF_HTTP_EXTENSION`

### 7.3 Types tab

```abap
TYPES: BEGIN OF ty_appr_line,
         aufnr TYPE aufnr,
         werks TYPE werks_d,
         maktx TYPE maktx,
         bdmng TYPE bdmng,
         meins TYPE meins,
       END OF ty_appr_line,
       tt_appr_line TYPE STANDARD TABLE OF ty_appr_line WITH DEFAULT KEY.
```

### 7.4 Methods tab

| Method | Level | Visibility | Description |
|--------|-------|-----------|-------------|
| `IF_HTTP_EXTENSION~HANDLE_REQUEST` | Instance | Public | ICF entry — inbound callback |
| `SEND_APPROVAL` | Instance | Public | Outbound — POST to Power Automate |
| `UPDATE_APPROVAL_STATUS` | Instance | Private | Write decision to ZTWO_APPR_TMS |
| `CHECK_AND_RELEASE` | Instance | Private | BAPI release if all items approved |

### 7.5 Method parameters

**SEND_APPROVAL**

| Dir | Name | Type | Note |
|-----|------|------|------|
| Import | `IT_ITEMS` | `TEAMS_IN_HANDLER=>TT_APPR_LINE` | Selected TC rows |
| Import | `IV_AUFNR` | `AUFNR` | Work Order |
| Import | `IV_REQUESTOR` | `SYUNAME` | Helpdesk user |
| Import | `IV_APPR_LEVEL` | `CHAR4` | `LVL1`=HO ADM · `LVL3`=SDH Branch |
| Export | `EV_REQ_ID` | `CHAR32` | Generated correlation id |
| Export | `EV_HTTP_CODE` | `I` | HTTP response code from Flow |
| Export | `EV_ERROR` | `CHAR1` | `X` = failed |
| Export | `EV_MESSAGE` | `STRING` | Error description |

> **Level routing logic:**
> - `LVL3` → SDH Branch Plant approves items in Teams (workers → SDH)
> - `LVL1` → HO ADM approves in Teams (Branch L4 → HO, using `"ADM"` key in `cmpPlantApproverMap`)
>
> Power Automate uses `appr_level` to pick the right approver from `cmpPlantApproverMap`.
> When Teams callback arrives, SAP writes the flag to the matching column in `ZTWOAPPR`.

**UPDATE_APPROVAL_STATUS**

| Dir | Name | Type |
|-----|------|------|
| Import | `IV_AUFNR` | `AUFNR` |
| Import | `IV_REQ_ID` | `CHAR32` |
| Import | `IV_DECISION` | `CHAR10` |
| Import | `IV_APPROVER` | `STRING` |
| Import | `IV_APPR_LEVEL` | `CHAR4` | `LVL1` or `LVL3` |
| Export | `EV_ERROR` | `CHAR1` |
| Export | `EV_MESSAGE` | `STRING` |

**CHECK_AND_RELEASE**

| Dir | Name | Type |
|-----|------|------|
| Import | `IV_AUFNR` | `AUFNR` |
| Export | `EV_RELEASED` | `CHAR1` |

### 7.6 Full implementation

```abap
CLASS teams_in_handler IMPLEMENTATION.

*----------------------------------------------------------------------*
* INBOUND — IF_HTTP_EXTENSION~HANDLE_REQUEST
* Called by SAP ICF when Power Automate POSTs to the SICF callback URL
*----------------------------------------------------------------------*
  METHOD if_http_extension~handle_request.

    DATA: lv_request    TYPE string,
          lv_response   TYPE string,
          lv_error      TYPE c,
          lv_ip         TYPE rfcipv6addr,
          lv_class_name TYPE repid,
          o_http        TYPE REF TO zcl_base_http.

    DATA: BEGIN OF lw_message,
            msgty   TYPE char1,
            message TYPE string,
          END OF lw_message.

    " JSON payload — field names must match what Power Automate sends back
    DATA: BEGIN OF ls_data,
            request_id  TYPE string,
            aufnr       TYPE string,
            appr_level  TYPE string,   " LVL1=HO ADM, LVL3=SDH Branch
            decision    TYPE string,
            approver    TYPE string,
            comments    TYPE string,
            timestamp   TYPE string,
          END OF ls_data.

    " Allow other ICF extensions in the chain
    if_http_extension~flow_rc = if_http_extension=>co_flow_ok_others_opt.

    " ── Phase 1: Read body FIRST ─────────────────────────────────────────
    " get_cdata() MUST come before get_form_fields()
    " get_form_fields() consumes the stream → get_cdata() returns empty
    lv_request = server->request->get_cdata( ).

    " ── Phase 2: IP authorization ────────────────────────────────────────
    CREATE OBJECT o_http.
    lv_ip         = cl_http_server=>c_caller_ip.
    lv_class_name = cl_abap_classdescr=>get_class_name( me ).
    lv_class_name = lv_class_name+7.  " strip '\CLASS=' → gives 'TEAMS_IN_HANDLER'

    o_http->m_check_ip_auth(
      EXPORTING i_ip         = lv_ip
                i_class_name = lv_class_name
      IMPORTING e_error      = lv_error ).

    IF lv_error = 'X'.
      lw_message-msgty   = 'E'.
      lw_message-message = 'Your IP is not Authorize'.
    ENDIF.

    " ── Phase 3: Validate body not empty ─────────────────────────────────
    IF lv_error IS INITIAL AND lv_request IS INITIAL.
      lv_error = 'X'.
      lw_message-msgty   = 'E'.
      lw_message-message = 'Request is empty'.
    ENDIF.

    " ── Phase 4: Parse JSON using ZCL_VND_JSON_TO_ABAP->json_to_abap ─────
    IF lv_error IS INITIAL.
      " Clean up Teams Markdown artefacts
      REPLACE ALL OCCURRENCES OF '#' IN lv_request WITH ''.
      CONDENSE lv_request.

      TRY.
          DATA(lo_json) = NEW zcl_vnd_json_to_abap( iv_json = lv_request ).
          lo_json->json_to_abap(
            EXPORTING iv_json = lv_request
            CHANGING  cs_data = ls_data ).
        CATCH cx_root INTO DATA(lx_err).
          lv_error = 'X'.
          lw_message-msgty   = 'E'.
          lw_message-message = lx_err->get_text( ).
          server->response->set_status( code = 400 reason = 'Bad Request' ).
      ENDTRY.
    ENDIF.

    " ── Phase 5: Validate required fields ────────────────────────────────
    IF lv_error IS INITIAL.
      IF ls_data-aufnr IS INITIAL OR ls_data-decision IS INITIAL.
        lv_error = 'X'.
        lw_message-msgty   = 'E'.
        lw_message-message = 'Missing required fields: aufnr or decision'.
      ENDIF.
    ENDIF.

    IF lv_error IS INITIAL.
      TRANSLATE ls_data-appr_level TO UPPER CASE.
      IF ls_data-appr_level <> 'LVL1' AND ls_data-appr_level <> 'LVL3'.
        " Default to LVL3 (SDH) when field is absent / legacy flow
        ls_data-appr_level = 'LVL3'.
      ENDIF.
    ENDIF.

    " ── Phase 6: Business logic ───────────────────────────────────────────
    IF lv_error IS INITIAL.

      TRANSLATE ls_data-decision TO UPPER CASE.

      DATA: lv_ev_err   TYPE char1,
            lv_ev_msg   TYPE string,
            lv_released TYPE char1.

      IF ls_data-decision = 'APPROVED'
      OR ls_data-decision = 'REJECTED'
      OR ls_data-decision = 'TIMEOUT'.

        " Write decision to ZTWO_APPR_TMS and stamp ZTWOAPPR by appr_level
        update_approval_status(
          EXPORTING iv_aufnr     = CONV #( ls_data-aufnr )
                    iv_req_id    = CONV #( ls_data-request_id )
                    iv_decision  = ls_data-decision
                    iv_approver  = ls_data-approver
                    iv_appr_level = CONV #( ls_data-appr_level )
          IMPORTING ev_error     = lv_ev_err
                    ev_message   = lv_ev_msg ).

        IF lv_ev_err = 'X'.
          lv_error = 'X'.
          lw_message-msgty   = 'E'.
          lw_message-message = lv_ev_msg.
        ELSE.
          " If APPROVED: check if all items done → auto-release WO
          IF ls_data-decision = 'APPROVED'.
            check_and_release(
              EXPORTING iv_aufnr    = CONV #( ls_data-aufnr )
              IMPORTING ev_released = lv_released ).
          ENDIF.

          lw_message-msgty   = 'S'.
          lw_message-message = COND #(
            WHEN lv_released = 'X'
            THEN |{ ls_data-decision } — Work Order released|
            ELSE |{ ls_data-decision } processed successfully| ).
          server->response->set_status( code = 200 reason = 'OK' ).
        ENDIF.

      ELSE.
        lv_error = 'X'.
        lw_message-msgty   = 'E'.
        lw_message-message = |Invalid decision: { ls_data-decision }. Must be APPROVED/REJECTED/TIMEOUT|.
        server->response->set_status( code = 400 reason = 'Bad Request' ).
      ENDIF.

    ELSE.
      server->response->set_status( code = 400 reason = 'Bad Request' ).
    ENDIF.

    " ── Phase 7: Build & send response ───────────────────────────────────
    server->response->set_header_field(
      name = 'Content-Type' value = 'application/json' ).

    o_http->m_itab_to_json(
      EXPORTING data = lw_message
      IMPORTING json = lv_response ).

    server->response->set_cdata( data = lv_response ).

  ENDMETHOD.

*----------------------------------------------------------------------*
* OUTBOUND — SEND_APPROVAL
* Called by FM Z_WO_APPR_TEAMS_SEND when Helpdesk clicks &RTMS
* Replaces the old separate SAP_OUT_MSFLOW / ZCL_WO_APPR_TEAMS_HANDLER
*----------------------------------------------------------------------*
  METHOD send_approval.

    DATA: lv_flow_url TYPE string,
          lv_apim_key TYPE string,
          lv_body     TYPE string,
          lo_http     TYPE REF TO if_http_client.

    " Read endpoint URL and optional APIM subscription key from TVARVC
    SELECT SINGLE low FROM tvarvc INTO @lv_flow_url
      WHERE name = 'Z_WO_APPR_APIM_URL' AND type = 'P'.

    SELECT SINGLE low FROM tvarvc INTO @lv_apim_key
      WHERE name = 'Z_WO_APPR_APIM_KEY' AND type = 'P'.

    IF lv_flow_url IS INITIAL.
      ev_error   = 'X'.
      ev_message = 'TVARVC Z_WO_APPR_APIM_URL not maintained'.
      RETURN.
    ENDIF.

    " Generate unique correlation id  →  e.g. UTX-20260514083045-A1B2C3
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_c32_static( ).
    ev_req_id = |{ sy-sysid }-{ sy-datum }{ sy-uzeit }-{ lv_uuid+0(6) }|.

    " Build JSON payload — appr_level tells Power Automate which approver to pick:
    "   LVL3 → cmpPlantApproverMap[werks]  (SDH Branch Plant)
    "   LVL1 → cmpPlantApproverMap['ADM']  (HO ADM: viandraf@unitedtractors.com)
    lv_body = |\{"request_id":"{ ev_req_id }","aufnr":"{ iv_aufnr }",|
           && |"appr_level":"{ iv_appr_level }",|
           && |"requestor":"{ iv_requestor }","items":[|.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
      lv_body = lv_body &&
        |\{"werks":"{ <ls>-werks }","maktx":"{ <ls>-maktx }",|  &&
        |"bdmng":"{ <ls>-bdmng }","meins":"{ <ls>-meins }"\}|.
      IF sy-tabix < lines( it_items ).
        lv_body = lv_body && ','.
      ENDIF.
    ENDLOOP.
    lv_body = lv_body && ']}'.

    " HTTP POST to Power Automate / APIM
    cl_http_client=>create_by_url(
      EXPORTING url = lv_flow_url IMPORTING client = lo_http ).

    lo_http->request->set_method( if_http_request=>co_request_method_post ).
    lo_http->request->set_header_field(
      name = 'Content-Type' value = 'application/json' ).

    IF lv_apim_key IS NOT INITIAL.
      lo_http->request->set_header_field(
        name = 'Ocp-Apim-Subscription-Key' value = lv_apim_key ).
    ENDIF.

    lo_http->request->set_cdata( lv_body ).
    lo_http->send( ).
    lo_http->receive( ).
    lo_http->response->get_status( IMPORTING code = ev_http_code ).
    lo_http->close( ).

    IF ev_http_code <> 200 AND ev_http_code <> 202.
      ev_error   = 'X'.
      ev_message = |HTTP { ev_http_code } — Flow trigger failed|.
      RETURN.
    ENDIF.

    " Insert one SENT row per item in ZTWO_APPR_TMS
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<row>).
      INSERT ztwo_appr_tms FROM @( VALUE #(
        mandt        = sy-mandt
        aufnr        = iv_aufnr
        teams_req_id = ev_req_id
        teams_status = 'SENT'
        appr_level   = iv_appr_level   " LVL1 or LVL3
        werks        = <row>-werks
        sent_by      = iv_requestor
        sent_at      = lv_now
        last_updated = lv_now ) ).
    ENDLOOP.
    COMMIT WORK.

  ENDMETHOD.

*----------------------------------------------------------------------*
* PRIVATE — UPDATE_APPROVAL_STATUS
* Updates ZTWO_APPR_TMS with the decision received from Power Automate
*----------------------------------------------------------------------*
  METHOD update_approval_status.

    DATA: lv_flag   TYPE char1,
          lv_status TYPE char10.

    lv_flag   = COND #( WHEN iv_decision = 'APPROVED' THEN 'X'
                        WHEN iv_decision = 'REJECTED' THEN 'R'
                        ELSE ' ' ).
    lv_status = iv_decision.

    GET TIME STAMP FIELD DATA(lv_now).

    " ── 1. Update Teams tracking table ──────────────────────────────────
    UPDATE ztwo_appr_tms
       SET appr_valid   = lv_flag
           teams_status = lv_status
           appr_user    = CONV syuname( iv_approver )
           appr_date    = sy-datum
           appr_time    = sy-uzeit
           last_updated = lv_now
     WHERE aufnr        = iv_aufnr
       AND teams_req_id = iv_req_id.

    IF sy-subrc <> 0.
      ev_error   = 'X'.
      ev_message = |No row found in ZTWO_APPR_TMS for WO { iv_aufnr } / { iv_req_id }|.
      RETURN.
    ENDIF.

    " ── 2. Stamp the matching approval column in ZTWOAPPR ────────────────
    " Only write the 'X' flag on APPROVED; leave blank for REJECTED/TIMEOUT.
    IF iv_decision = 'APPROVED'.
      CASE iv_appr_level.

        WHEN 'LVL3'.
          " SDH Branch Plant approved via Teams → set APPROVAL_LVL3
          UPDATE ztwoappr
             SET approval_lvl3  = 'X'
                 appr_by_lvl3   = CONV appr_by_lvl3(  iv_approver )
                 appr_date_lvl3 = sy-datum
                 appr_time_lvl3 = sy-uzeit
           WHERE aufnr = iv_aufnr.

        WHEN 'LVL1'.
          " HO ADM approved via Teams → set APPROVAL_LVL1
          UPDATE ztwoappr
             SET approval_lvl1  = 'X'
                 appr_by_lvl1   = CONV appr_by_lvl1(  iv_approver )
                 appr_date_lvl1 = sy-datum
                 appr_time_lvl1 = sy-uzeit
           WHERE aufnr = iv_aufnr.

      ENDCASE.
    ENDIF.

  ENDMETHOD.

*----------------------------------------------------------------------*
* PRIVATE — CHECK_AND_RELEASE
* If every ZTWO_APPR_TMS row for this WO has APPR_VALID='X', release WO
*----------------------------------------------------------------------*
  METHOD check_and_release.

    DATA: lv_total TYPE i,
          lv_done  TYPE i.

    SELECT COUNT(*) FROM ztwo_appr_tms
      WHERE aufnr = @iv_aufnr INTO @lv_total.

    SELECT COUNT(*) FROM ztwo_appr_tms
      WHERE aufnr = @iv_aufnr AND appr_valid = 'X' INTO @lv_done.

    " Only release when ALL rows are approved
    IF lv_total = 0 OR lv_total <> lv_done.
      RETURN.
    ENDIF.

    DATA: lt_return  TYPE STANDARD TABLE OF bapiret2,
          lt_methods TYPE STANDARD TABLE OF bapi_alm_order_method,
          lt_header  TYPE STANDARD TABLE OF bapi_alm_order_headers_i.

    APPEND VALUE bapi_alm_order_method(
      refnumber  = '000001'
      objecttype = 'HEADER'
      method     = 'RELEASE'
      objectkey  = iv_aufnr ) TO lt_methods.

    APPEND VALUE bapi_alm_order_method(
      refnumber  = '000001'
      objecttype = 'HEADER'
      method     = 'SAVE' ) TO lt_methods.

    APPEND VALUE bapi_alm_order_headers_i( orderid = iv_aufnr ) TO lt_header.

    CALL FUNCTION 'BAPI_ALM_ORDER_MAINTAIN'
      TABLES it_methods = lt_methods
             it_header  = lt_header
             return     = lt_return.

    IF line_exists( lt_return[ type = 'E' ] )
    OR line_exists( lt_return[ type = 'A' ] ).
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    ev_released = 'X'.

  ENDMETHOD.

ENDCLASS.
```

Activate. Resolve any syntax errors before moving on.

---

## 8. Step 7 — Function Group & FM Z_WO_APPR_TEAMS_SEND

**Transaction: SE80**

### 8.1 Create Function Group

1. SE80 → Function Group → Create → `ZFG_WO_APPR_TEAMS`
2. Short text: `WO Approval — Teams Integration`
3. Activate — SAP auto-creates `LZFG_WO_APPR_TEAMSTOP` + `LZFG_WO_APPR_TEAMSUXX`

### 8.2 Create FM Z_WO_APPR_TEAMS_SEND

SE80 → right-click `ZFG_WO_APPR_TEAMS` → **Create → Function Module**

**Import tab:**

| Parameter | Pass value | Type | Type name |
|-----------|-----------|------|-----------|
| `IV_AUFNR` | ✔ | TYPE | `AUFNR` |
| `IV_REQUESTOR` | ✔ | TYPE | `SYUNAME` DEFAULT `SY-UNAME` |
| `IV_APPR_LEVEL` | ✔ | TYPE | `CHAR4` DEFAULT `'LVL3'` |

**Tables tab:**

| Parameter | Type |
|-----------|------|
| `IT_ITEMS` | `TEAMS_IN_HANDLER=>TT_APPR_LINE` |

**Export tab:**

| Parameter | Pass value | Type | Type name |
|-----------|-----------|------|-----------|
| `EV_REQ_ID` | ✔ | TYPE | `CHAR32` |
| `EV_HTTP_CODE` | ✔ | TYPE | `I` |

**Exceptions tab:**

| Exception |
|-----------|
| `HTTP_ERROR` |
| `PAYLOAD_EMPTY` |

**Source code:**

```abap
FUNCTION z_wo_appr_teams_send.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_AUFNR) TYPE  AUFNR
*"     VALUE(IV_REQUESTOR) TYPE  SYUNAME DEFAULT SY-UNAME
*"     VALUE(IV_APPR_LEVEL) TYPE  CHAR4 DEFAULT 'LVL3'
*"       " LVL3 = SDH Branch Plant (workers → SDH)
*"       " LVL1 = HO ADM (Branch L4 → HO, key 'ADM' in cmpPlantApproverMap)
*"  TABLES
*"      IT_ITEMS TYPE  TEAMS_IN_HANDLER=>TT_APPR_LINE
*"  EXPORTING
*"     VALUE(EV_REQ_ID) TYPE  CHAR32
*"     VALUE(EV_HTTP_CODE) TYPE  I
*"  EXCEPTIONS
*"      HTTP_ERROR
*"      PAYLOAD_EMPTY
*"----------------------------------------------------------------------

  IF it_items IS INITIAL.
    RAISE payload_empty.
  ENDIF.

  DATA: lv_error   TYPE char1,
        lv_message TYPE string.

  DATA(lo_handler) = NEW teams_in_handler( ).

  lo_handler->send_approval(
    EXPORTING it_items      = it_items
              iv_aufnr      = iv_aufnr
              iv_requestor  = iv_requestor
              iv_appr_level = iv_appr_level
    IMPORTING ev_req_id     = ev_req_id
              ev_http_code  = ev_http_code
              ev_error      = lv_error
              ev_message    = lv_message ).

  IF lv_error = 'X'.
    RAISE http_error.
  ENDIF.

ENDFUNCTION.
```

Activate the FM and the Function Group.

---

## 9. Step 8 — SICF Service

**Transaction: SICF**

1. Navigate: `default_host → sap → bc`
2. Right-click `bc` → **New Sub-Element**:

| Field | Value |
|-------|-------|
| Name | `zwo_appr_teams` |
| Description | `WO Teams Approval` |

3. Right-click the new node → **New Sub-Element**:

| Field | Value |
|-------|-------|
| Name | `callback` |
| Description | `Approval callback from Power Automate` |

4. Open `callback` → **Handler List** tab → add: **`TEAMS_IN_HANDLER`**

5. **Logon Data** tab:
   - Logon procedure: `Standard` + `Basic`
   - Service user: `TEAMS_API`

6. Right-click `callback` → **Activate**

**Result — callback URL:**
```
https://<sap-host>:<port>/sap/bc/zwo_appr_teams/callback?sap-client=<client>
```

### Service user TEAMS_API (PFCG — role Z_WO_APPR_API)

| Auth object | Field | Value |
|-------------|-------|-------|
| `S_ICF` | `ICF_VALUE` | `/sap/bc/zwo_appr_teams/callback` |
| `S_RFC` | `RFC_NAME` | `ZFG_WO_APPR_TEAMS` |
| `S_RFC` | `RFC_TYPE` | `FUGR` |

No `SAP_ALL`. No `S_TCODE`.

---

## 10. Step 9 — TVARVC + ZAPIGWACL entries

### 10.1 TVARVC (transaction STVARV)

| Name | Type | Value |
|------|------|-------|
| `Z_WO_APPR_APIM_URL` | `P` | `https://aut-sap-apim.azure-api.net/wo-approval/teams-trigger` |
| `Z_WO_APPR_APIM_KEY` | `P` | `<APIM subscription key>` |

### 10.2 ZAPIGWACL rows (SM30)

`API_NAME` must be exactly `TEAMS_IN_HANDLER` — that is what
`cl_abap_classdescr=>get_class_name( me )+7` returns inside the handler.

| API_NAME | EXT_IP | Description |
|----------|--------|-------------|
| `TEAMS_IN_HANDLER` | `13.66.140.1` | Azure APIM SEA egress IP |
| `TEAMS_IN_HANDLER` | `40.74.28.1` | Azure APIM SEA egress IP |
| `TEAMS_IN_HANDLER` | `127.0.0.1` | Localhost — DEV / Postman only |

> Get the exact APIM outbound IPs from:
> **Azure Portal → APIM instance → Overview → Public IP addresses**
> Each IP needs its own row (exact match, no ranges).

---

## 11. Step 10 — Hook into Screen 0300

### 11.1 GUI Status ZSTAT_0300 (SE41)

Add button after `&RAPR`:

| Function code | Text | F-Key |
|--------------|------|-------|
| `&RTMS` | Remind via Teams | Shift+F7 |

### 11.2 PAI module USER_COMMAND_0300

File: `2. Function_Group/3. PAI Modules/USER_COMMAND_0300.abap`

Inside `CASE save_ok`:

```abap
WHEN '&RTMS'.
  PERFORM remind_items_via_teams.
```

### 11.3 FORM in LZFG_WO_APPROVALF01

File: `2. Function_Group/7. includes/LZFG_WO_APPROVALF01.abap`

Add at the end:

```abap
*&---------------------------------------------------------------------*
*& FORM remind_items_via_teams
*& Sends marked Table Control rows to Power Automate via Teams
*&---------------------------------------------------------------------*
FORM remind_items_via_teams.

  DATA lt_items TYPE teams_in_handler=>tt_appr_line.

  LOOP AT gt_items_tc INTO gs_items_tc WHERE mark = abap_true.
    APPEND VALUE #(
      aufnr = gs_items_tc-aufnr
      werks = gs_items_tc-werks
      maktx = gs_items_tc-maktx
      bdmng = gs_items_tc-bdmng
      meins = gs_items_tc-meins ) TO lt_items.
  ENDLOOP.

  IF lt_items IS INITIAL.
    MESSAGE 'Mark at least one item before sending Teams reminder' TYPE 'I'.
    RETURN.
  ENDIF.

  " ── Determine which approval level to request ──────────────────────────
  " LVL3 = SDH Branch Plant (first approval, from workers)
  " LVL1 = HO ADM (escalation after SDH has approved)
  DATA: lv_appr_level TYPE char4,
        lv_lvl3_done  TYPE char1.

  SELECT SINGLE approval_lvl3 FROM ztwoappr
    INTO @lv_lvl3_done
    WHERE aufnr = @gv_aufnr.

  IF lv_lvl3_done = 'X'.
    lv_appr_level = 'LVL1'.   " SDH done → escalate to HO ADM
  ELSE.
    lv_appr_level = 'LVL3'.   " Send to SDH Branch Plant first
  ENDIF.

  DATA: lv_req_id    TYPE char32,
        lv_http_code TYPE i.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'
    EXPORTING  iv_aufnr      = gv_aufnr
               iv_requestor  = sy-uname
               iv_appr_level = lv_appr_level
    TABLES     it_items      = lt_items
    IMPORTING  ev_req_id     = lv_req_id
               ev_http_code  = lv_http_code
    EXCEPTIONS http_error    = 1
               payload_empty = 2.

  CASE sy-subrc.
    WHEN 0.
      DATA(lv_level_txt) = COND #( WHEN lv_appr_level = 'LVL1'
                                   THEN 'HO ADM (LVL1)'
                                   ELSE 'SDH Branch (LVL3)' ).
      MESSAGE |Teams reminder sent to { lv_level_txt }. Request: { lv_req_id }| TYPE 'S'.
    WHEN 2.
      MESSAGE 'No items marked' TYPE 'I'.
    WHEN OTHERS.
      MESSAGE |Teams trigger failed — HTTP { lv_http_code }| TYPE 'E'.
  ENDCASE.

ENDFORM.
```

Activate include + PAI module.

---

## 12. Step 11 — Test with Postman

### 12.1 Insert a SENT row in ZTWO_APPR_TMS first (SE16)

```
MANDT        = <your client>
AUFNR        = 0000004711
TEAMS_REQ_ID = UTX-20260514083045-A1B2C3
TEAMS_STATUS = SENT
APPR_LEVEL   = LVL3
SENT_BY      = <your user>
```

### 12.2 Happy path — SDH approves (LVL3)

```http
POST https://<host>:<port>/sap/bc/zwo_appr_teams/callback?sap-client=<client>
Authorization: Basic <base64(TEAMS_API:password)>
Content-Type: application/json

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

Expected: `{"msgty":"S","message":"APPROVED processed successfully"}`

Check SE16 → `ZTWO_APPR_TMS`: `APPR_VALID = X`, `TEAMS_STATUS = APPROVED`, `APPR_LEVEL = LVL3`
Check SE16 → `ZTWOAPPR`: `APPROVAL_LVL3 = X`, `APPR_BY_LVL3 = demakb@...`

### 12.3 Happy path — HO ADM approves (LVL1)

```http
POST https://<host>:<port>/sap/bc/zwo_appr_teams/callback?sap-client=<client>
Authorization: Basic <base64(TEAMS_API:password)>
Content-Type: application/json

{
  "request_id": "UTX-20260514090000-B3C4D5",
  "aufnr":      "0000004711",
  "appr_level": "LVL1",
  "decision":   "APPROVED",
  "approver":   "viandraf@unitedtractors.com",
  "comments":   "Approved by HO ADM",
  "timestamp":  "2026-05-18T09:00:00Z"
}
```

Expected: `{"msgty":"S","message":"APPROVED processed successfully"}`

Check SE16 → `ZTWOAPPR`: `APPROVAL_LVL1 = X`, `APPR_BY_LVL1 = viandraf@...`

### 12.4 Blocked IP

Delete `127.0.0.1` row from `ZAPIGWACL` for `TEAMS_IN_HANDLER`, retry Postman.

Expected: `{"msgty":"E","message":"Your IP is not Authorize"}`

### 12.5 Missing required field

```json
{ "aufnr": "0000004711" }
```

Expected: `{"msgty":"E","message":"Missing required fields: aufnr or decision"}`

---

## 13. Object Summary

| Object | Transaction | Type | Action |
|--------|-------------|------|--------|
| `ZTWO_APPR_TMS` | SE11 | Table | **Create** |
| `ZAPIGWACL` | SM30 | Table rows | **Add rows** (table already exists) |
| `ZCL_VND_JSON_TO_ABAP` | SE24 | Class | **Create** from ZIP |
| `ZCL_BASE_HTTP` | SE24 | Class | **Create** |
| `TEAMS_IN_HANDLER` | SE24 | Class | **Create** — single class (inbound + outbound) |
| `ZFG_WO_APPR_TEAMS` | SE80 | Function Group | **Create** |
| `Z_WO_APPR_TEAMS_SEND` | SE37 | Function Module | **Create** |
| `/sap/bc/zwo_appr_teams/callback` | SICF | ICF service | **Create + activate** |
| `Z_WO_APPR_APIM_URL` | STVARV | TVARVC entry | **Maintain** |
| `Z_WO_APPR_APIM_KEY` | STVARV | TVARVC entry | **Maintain** |
| `Z_WO_APPR_API` | PFCG | Role | **Create** — assign to `TEAMS_API` user |

---

*Guide v3 — one class `TEAMS_IN_HANDLER` handles both inbound callback and
outbound trigger. JSON parsed via `ZCL_VND_JSON_TO_ABAP->JSON_TO_ABAP`.
IP whitelist via existing `ZAPIGWACL` table.*
