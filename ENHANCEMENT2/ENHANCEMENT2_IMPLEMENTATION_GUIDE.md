# ENHANCEMENT2 — Step-by-Step SAP Build Guide
## Teams / Power Automate Approval Callback

> **Goal:** When a Helpdesk user clicks **Remind via Teams** on Screen 0300,
> SAP sends selected WO items to Power Automate. The approver gets a Teams
> Adaptive Card. When they click **Approve / Reject**, Power Automate POSTs
> back to SAP. SAP updates one tracking table and optionally auto-releases the
> Work Order.
>
> **What we build:**
> - **2 DDIC tables** — `ZTWO_APPR_TMS` (business state) + `ZHTTP_IP_AUTH` (IP whitelist)
> - **4 Classes** — `ZCL_VND_JSON_TO_ABAP` · `ZCL_BASE_HTTP` · `ZCL_WO_APPR_TEAMS_HTTP` · `ZCL_WO_APPR_TEAMS_HANDLER`
> - **1 Function Group + 1 FM** — `ZFG_WO_APPR_TEAMS` · `Z_WO_APPR_TEAMS_SEND`
> - **1 SICF service** — the callback URL Power Automate POSTs to
> - **Screen 0300 hook** — `&RTMS` button in existing program

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Step 1 — Package](#2-step-1--package)
3. [Step 2 — Table ZTWO_APPR_TMS](#3-step-2--table-ztwo_appr_tms)
4. [Step 3 — Table ZHTTP_IP_AUTH](#4-step-3--table-zhttp_ip_auth)
5. [Step 4 — Class ZCL_VND_JSON_TO_ABAP](#5-step-4--class-zcl_vnd_json_to_abap)
6. [Step 5 — Class ZCL_BASE_HTTP](#6-step-5--class-zcl_base_http)
7. [Step 6 — Class ZCL_WO_APPR_TEAMS_HTTP (Inbound Handler)](#7-step-6--class-zcl_wo_appr_teams_http-inbound-handler)
8. [Step 7 — Class ZCL_WO_APPR_TEAMS_HANDLER (Outbound Caller)](#8-step-7--class-zcl_wo_appr_teams_handler-outbound-caller)
9. [Step 8 — Function Group & FM Z_WO_APPR_TEAMS_SEND](#9-step-8--function-group--fm-z_wo_appr_teams_send)
10. [Step 9 — SICF Service](#10-step-9--sicf-service)
11. [Step 10 — TVARVC + IP Whitelist](#11-step-10--tvarvc--ip-whitelist)
12. [Step 11 — Hook into Screen 0300](#12-step-11--hook-into-screen-0300)
13. [Step 12 — Test with Postman](#13-step-12--test-with-postman)

---

## 1. Architecture Overview

```
Screen 0300 (ZWOAPP)
  │  Helpdesk selects items → clicks [Remind via Teams]
  │
  ▼
Z_WO_APPR_TEAMS_SEND (FM)
  └── ZCL_WO_APPR_TEAMS_HANDLER→send_approval( )
        ├── Inserts rows in ZTWO_APPR_TMS (status = SENT)
        └── HTTP POST → Power Automate / APIM
                          │
                          │  Teams Adaptive Card → Approver
                          │
                          │  Approver clicks Approve / Reject
                          ▼
              Power Automate POSTs callback JSON
                          │
                          ▼
         SICF: /sap/bc/zwo_appr_teams/callback
                          │
                          ▼
         ZCL_WO_APPR_TEAMS_HTTP (IF_HTTP_EXTENSION)
           1. Read body
           2. IP check   (ZCL_BASE_HTTP)
           3. Parse JSON (ZCL_VND_JSON_TO_ABAP)
           4. Update ZTWO_APPR_TMS
           5. Check all approved → BAPI Release
           6. Return JSON response
```

**Callback JSON payload** (Power Automate → SAP):

```json
{
  "request_id": "abc123",
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

One row is created per item per Teams request (INSERT on SEND, UPDATE on APPROVED/REJECTED).

### Field definition

| Field | Key | Type/Domain | Description |
|-------|-----|------------|-------------|
| `MANDT` | ✔ | `MANDT` | Client |
| `AUFNR` | ✔ | `AUFNR` | Work Order |
| `TEAMS_REQ_ID` | ✔ | `CHAR32` | Power Automate run-id (correlation) |
| `APPR_VALID` | | `CHAR1` | `X`=Approved · `R`=Rejected · ` `=Open |
| `TEAMS_STATUS` | | `CHAR10` | `SENT` · `APPROVED` · `REJECTED` · `TIMEOUT` |
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
- **Secondary index `Z01`** on field `TEAMS_REQ_ID` (non-unique)

Activate.

---

## 4. Step 3 — Table ZHTTP_IP_AUTH

**Transaction: SE11 → Database table → Create**

IP whitelist used by `ZCL_BASE_HTTP` to authorise incoming HTTP requests per
handler class.

### Field definition

| Field | Key | Type | Description |
|-------|-----|------|-------------|
| `MANDT` | ✔ | `MANDT` | Client |
| `CLASS_NAME` | ✔ | `REPID` | Handler class, e.g. `ZCL_WO_APPR_TEAMS_HTTP` |
| `IP_LOW` | ✔ | `RFCIPV6ADDR` | Start of allowed IP range |
| `IP_HIGH` | | `RFCIPV6ADDR` | End of range (= `IP_LOW` for a single IP) |
| `ACTIVE` | | `CHAR1` | `X` = active |
| `DESCRIPTION` | | `CHAR60` | Free text (e.g. *Azure APIM SEA outbound*) |

- **Delivery class:** `C` (Customizing)
- **Maintenance:** Yes

After activating, go to **SE54 → Generate table maintenance dialog** so you can
maintain rows via SM30.

---

## 5. Step 4 — Class ZCL_VND_JSON_TO_ABAP

**Transaction: SE24 → Create class**

This is the custom JSON-to-ABAP parser provided in the ZIP file. Create the
class manually in SE24 and copy each method body from the ZIP files.

### 5.1 Class header (SE24 → Properties tab)

| Field | Value |
|-------|-------|
| Class name | `ZCL_VND_JSON_TO_ABAP` |
| Description | `JSON to ABAP deserializer` |
| Instantiation | `Public` |
| Final | Yes |

### 5.2 Attributes (SE24 → Attributes tab)

| Name | Visibility | Type | Typing | Type Name |
|------|-----------|------|--------|-----------|
| `MV_JSON` | Private | Instance attr. | TYPE | `STRING` |

### 5.3 Methods (SE24 → Methods tab)

| Method | Level | Visibility | Description |
|--------|-------|-----------|-------------|
| `CONSTRUCTOR` | Instance | Public | Store JSON string |
| `JSON_TO_ABAP` | Instance | Public | Core parser (recursive) |
| `PARSE` | Instance | Public | Entry point — calls `json_to_abap` |
| `STRIP_QUOTES` | Instance | Private | Remove surrounding `"` |
| `UNESCAPE` | Instance | Private | Unescape `\"` `\n` etc. |

### 5.4 Method parameters

**`CONSTRUCTOR`**

| Dir | Name | Type | Type name |
|-----|------|------|-----------|
| Import | `IV_JSON` | TYPE | `STRING` |

**`JSON_TO_ABAP`**

| Dir | Name | Type | Type name |
|-----|------|------|-----------|
| Export | `IV_JSON` | TYPE | `STRING` |
| Changing | `CS_DATA` | TYPE | `ANY` |

**`PARSE`**

| Dir | Name | Type | Type name |
|-----|------|------|-----------|
| Changing | `CS_DATA` | TYPE | `ANY` |

**`STRIP_QUOTES`**

| Dir | Name | Type | Type name |
|-----|------|------|-----------|
| Import | `IV_INPUT` | TYPE | `STRING` |
| Return | `RV_OUTPUT` | TYPE | `STRING` |

**`UNESCAPE`**

| Dir | Name | Type | Type name |
|-----|------|------|-----------|
| Import | `IV_INPUT` | TYPE | `STRING` |
| Return | `RV_OUTPUT` | TYPE | `STRING` |

### 5.5 Source code

Copy each method body from the ZIP files exactly as-is. The CONSTRUCTOR:

```abap
METHOD constructor.
  mv_json = iv_json.
ENDMETHOD.
```

The PARSE method:

```abap
METHOD parse.
  json_to_abap(
    EXPORTING iv_json = mv_json
    CHANGING  cs_data = cs_data ).
ENDMETHOD.
```

Paste `JSON_TO_ABAP.abap`, `STRIP_QUOTES.abap`, `UNESCAPE.abap` from the ZIP.

Activate.

### 5.6 How to call it (usage pattern)

```abap
" Create instance with JSON string, call parse with your target structure
DATA(lo_parser) = NEW zcl_vnd_json_to_abap( iv_json = lv_request ).
lo_parser->parse( CHANGING cs_data = ls_data ).
```

---

## 6. Step 5 — Class ZCL_BASE_HTTP

**Transaction: SE24 → Create class**

Reusable helper: IP check, JSON serialiser for response, HTTP response builder.

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

**`M_CHECK_IP_AUTH`**

| Dir | Name | Type |
|-----|------|------|
| Import | `I_IP` | `RFCIPV6ADDR` |
| Import | `I_CLASS_NAME` | `REPID` |
| Export | `E_ERROR` | `CHAR1` |

**`M_ITAB_TO_JSON`**

| Dir | Name | Type |
|-----|------|------|
| Import | `DATA` | `ANY` |
| Export | `JSON` | `STRING` |

**`M_SET_RESPONSE`**

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
    e_error = 'X'.  " default: deny

    SELECT SINGLE @abap_true
      FROM zhttp_ip_auth
      INTO @DATA(lv_ok)
      WHERE mandt      = @sy-mandt
        AND class_name = @i_class_name
        AND active     = 'X'
        AND ip_low    <= @i_ip
        AND ip_high   >= @i_ip.

    IF sy-subrc = 0.
      CLEAR e_error.
    ENDIF.
  ENDMETHOD.

  METHOD m_itab_to_json.
    " Simple key:value JSON — works for flat structures like lw_message
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

## 7. Step 6 — Class ZCL_WO_APPR_TEAMS_HTTP (Inbound Handler)

**Transaction: SE24 → Create class**

This is the **SICF handler** — the class that SAP calls when Power Automate
POSTs the approval callback. It follows the same pattern as the reference
sample exactly:

```
1. Read body (FIRST — before anything else)
2. IP check
3. Validate body not empty
4. Parse JSON → ls_data
5. Validate required fields
6. Process: update ZTWO_APPR_TMS + optional BAPI release
7. Send JSON response
```

### 7.1 Class header

| Field | Value |
|-------|-------|
| Class name | `ZCL_WO_APPR_TEAMS_HTTP` |
| Description | `Teams approval callback — SICF handler` |
| Instantiation | `Public` |
| Final | Yes |

### 7.2 Interfaces tab

Add: `IF_HTTP_EXTENSION`

### 7.3 Methods — only one public + two private

| Method | Visibility | Description |
|--------|-----------|-------------|
| `IF_HTTP_EXTENSION~HANDLE_REQUEST` | Public | ICF entry point |
| `UPDATE_APPROVAL_STATUS` | Private | Write to ZTWO_APPR_TMS |
| `CHECK_AND_RELEASE` | Private | BAPI release if all approved |

### 7.4 Method parameters

**`UPDATE_APPROVAL_STATUS`**

| Dir | Name | Type |
|-----|------|------|
| Import | `IV_AUFNR` | `AUFNR` |
| Import | `IV_REQ_ID` | `CHAR32` |
| Import | `IV_DECISION` | `CHAR10` |
| Import | `IV_APPROVER` | `STRING` |
| Export | `EV_ERROR` | `CHAR1` |
| Export | `EV_MESSAGE` | `STRING` |

**`CHECK_AND_RELEASE`**

| Dir | Name | Type |
|-----|------|------|
| Import | `IV_AUFNR` | `AUFNR` |
| Export | `EV_RELEASED` | `CHAR1` |

### 7.5 Full implementation

```abap
CLASS zcl_wo_appr_teams_http IMPLEMENTATION.

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

    " JSON payload: must match ALL fields Power Automate sends
    DATA: BEGIN OF ls_data,
            request_id TYPE string,
            aufnr      TYPE string,
            decision   TYPE string,
            approver   TYPE string,
            comments   TYPE string,
            timestamp  TYPE string,
          END OF ls_data.

    " Allow other ICF extensions
    if_http_extension~flow_rc = if_http_extension=>co_flow_ok_others_opt.

    " ── Phase 1: Read body FIRST ─────────────────────────────────────────
    " WARNING: get_cdata() MUST be called before get_form_fields()
    " get_form_fields() consumes the body stream — get_cdata() returns empty after
    lv_request = server->request->get_cdata( ).

    " ── Phase 2: IP authorization ────────────────────────────────────────
    CREATE OBJECT o_http.
    lv_ip         = cl_http_server=>c_caller_ip.
    lv_class_name = cl_abap_classdescr=>get_class_name( me ).
    lv_class_name = lv_class_name+7.  " strip '\CLASS=' prefix

    o_http->m_check_ip_auth(
      EXPORTING i_ip         = lv_ip
                i_class_name = lv_class_name
      IMPORTING e_error      = lv_error ).

    IF lv_error = 'X'.
      lw_message-msgty   = 'E'.
      lw_message-message = 'Your IP is not authorized'.
    ENDIF.

    " ── Phase 3: Validate body not empty ─────────────────────────────────
    IF lv_error IS INITIAL AND lv_request IS INITIAL.
      lv_error = 'X'.
      lw_message-msgty   = 'E'.
      lw_message-message = 'Request body is empty'.
    ENDIF.

    " ── Phase 4: Parse JSON ───────────────────────────────────────────────
    IF lv_error IS INITIAL.
      " Clean up Teams Markdown artefacts before parsing
      REPLACE ALL OCCURRENCES OF '#' IN lv_request WITH ''.
      CONDENSE lv_request.

      TRY.
          DATA(lo_parser) = NEW zcl_vnd_json_to_abap( iv_json = lv_request ).
          lo_parser->parse( CHANGING cs_data = ls_data ).
        CATCH cx_root INTO DATA(lx_err).
          lv_error = 'X'.
          lw_message-msgty   = 'E'.
          lw_message-message = lx_err->get_text( ).
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

    " ── Phase 6: Business logic ───────────────────────────────────────────
    IF lv_error IS INITIAL.

      TRANSLATE ls_data-decision TO UPPER CASE.

      IF ls_data-decision = 'APPROVED' OR ls_data-decision = 'REJECTED'.

        DATA: lv_ev_err TYPE char1,
              lv_ev_msg TYPE string,
              lv_released TYPE char1.

        " Write decision to ZTWO_APPR_TMS
        me->update_approval_status(
          EXPORTING iv_aufnr   = CONV #( ls_data-aufnr )
                    iv_req_id  = CONV #( ls_data-request_id )
                    iv_decision = ls_data-decision
                    iv_approver = ls_data-approver
          IMPORTING ev_error   = lv_ev_err
                    ev_message = lv_ev_msg ).

        IF lv_ev_err = 'X'.
          lv_error = 'X'.
          lw_message-msgty   = 'E'.
          lw_message-message = lv_ev_msg.
        ELSE.
          " If APPROVED: check if all items done → release WO
          IF ls_data-decision = 'APPROVED'.
            me->check_and_release(
              EXPORTING iv_aufnr    = CONV #( ls_data-aufnr )
              IMPORTING ev_released = lv_released ).
          ENDIF.

          lw_message-msgty   = 'S'.
          lw_message-message = COND #(
            WHEN lv_released = 'X'
            THEN |{ ls_data-decision } — Work Order released|
            ELSE |{ ls_data-decision } recorded successfully| ).
        ENDIF.

      ELSEIF ls_data-decision = 'TIMEOUT'.
        " Log timeout — just update status, no release
        me->update_approval_status(
          EXPORTING iv_aufnr    = CONV #( ls_data-aufnr )
                    iv_req_id   = CONV #( ls_data-request_id )
                    iv_decision = 'TIMEOUT'
                    iv_approver = ls_data-approver
          IMPORTING ev_error    = lv_ev_err
                    ev_message  = lv_ev_msg ).
        lw_message-msgty   = 'S'.
        lw_message-message = 'Timeout recorded'.

      ELSE.
        lv_error = 'X'.
        lw_message-msgty   = 'E'.
        lw_message-message = |Invalid decision: { ls_data-decision }. Must be APPROVED/REJECTED/TIMEOUT|.
      ENDIF.

    ENDIF.

    " ── Phase 7: Build & send response ───────────────────────────────────
    DATA(lv_code) = COND i( WHEN lv_error = 'X' THEN 400 ELSE 200 ).
    DATA(lv_reason) = COND string( WHEN lv_error = 'X' THEN `Bad Request` ELSE `OK` ).

    o_http->m_itab_to_json(
      EXPORTING data = lw_message
      IMPORTING json = lv_response ).

    o_http->m_set_response(
      io_server = server
      i_code    = lv_code
      i_reason  = lv_reason
      i_body    = lv_response ).

  ENDMETHOD.

  METHOD update_approval_status.

    DATA: ls_tms      TYPE ztwo_appr_tms,
          lv_flag     TYPE char1,
          lv_status   TYPE char10.

    lv_flag   = COND #( WHEN iv_decision = 'APPROVED' THEN 'X'
                        WHEN iv_decision = 'REJECTED' THEN 'R'
                        ELSE ' ' ).
    lv_status = iv_decision.  " APPROVED / REJECTED / TIMEOUT

    GET TIME STAMP FIELD DATA(lv_now).

    UPDATE ztwo_appr_tms
       SET appr_valid    = lv_flag
           teams_status  = lv_status
           appr_user     = CONV syuname( iv_approver )
           appr_date     = sy-datum
           appr_time     = sy-uzeit
           last_updated  = lv_now
     WHERE aufnr        = iv_aufnr
       AND teams_req_id = iv_req_id.

    IF sy-subrc <> 0.
      ev_error   = 'X'.
      ev_message = |No ZTWO_APPR_TMS row found for { iv_aufnr } / { iv_req_id }|.
    ENDIF.

  ENDMETHOD.

  METHOD check_and_release.

    " Check: does every ZTWO_APPR_TMS row for this WO have APPR_VALID = 'X'?
    DATA: lv_total TYPE i,
          lv_done  TYPE i.

    SELECT COUNT(*) FROM ztwo_appr_tms
      WHERE aufnr = @iv_aufnr
      INTO @lv_total.

    SELECT COUNT(*) FROM ztwo_appr_tms
      WHERE aufnr      = @iv_aufnr
        AND appr_valid = 'X'
      INTO @lv_done.

    IF lv_total = 0 OR lv_total <> lv_done.
      RETURN.  " Not all approved yet
    ENDIF.

    " All approved — release Work Order via BAPI
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

    APPEND VALUE bapi_alm_order_headers_i(
      orderid = iv_aufnr ) TO lt_header.

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

Activate. Fix any syntax errors before continuing.

---

## 8. Step 7 — Class ZCL_WO_APPR_TEAMS_HANDLER (Outbound Caller)

**Transaction: SE24 → Create class**

This class is called by the FM (Step 8) when the Helpdesk clicks `&RTMS`. It sends
the WO items to Power Automate / APIM via HTTP POST.

### 8.1 Class header

| Field | Value |
|-------|-------|
| Class name | `ZCL_WO_APPR_TEAMS_HANDLER` |
| Description | `Teams approval — outbound HTTP caller` |
| Instantiation | `Public` |

### 8.2 Types (SE24 → Types tab)

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

### 8.3 Methods

| Method | Level | Visibility |
|--------|-------|-----------|
| `SEND_APPROVAL` | Instance | Public |

**`SEND_APPROVAL` parameters:**

| Dir | Name | Type |
|-----|------|------|
| Import | `IT_ITEMS` | `ZCL_WO_APPR_TEAMS_HANDLER=>TT_APPR_LINE` |
| Import | `IV_AUFNR` | `AUFNR` |
| Import | `IV_REQUESTOR` | `SYUNAME` |
| Export | `EV_REQ_ID` | `CHAR32` |
| Export | `EV_HTTP_CODE` | `I` |
| Export | `EV_ERROR` | `CHAR1` |
| Export | `EV_MESSAGE` | `STRING` |

### 8.4 Implementation

```abap
CLASS zcl_wo_appr_teams_handler IMPLEMENTATION.

  METHOD send_approval.

    DATA: lv_flow_url  TYPE string,
          lv_apim_key  TYPE string,
          lv_body      TYPE string,
          lv_status    TYPE i,
          lo_http      TYPE REF TO if_http_client.

    " ── Read config from TVARVC ──────────────────────────────────────────
    SELECT SINGLE low FROM tvarvc INTO @lv_flow_url
      WHERE name = 'Z_WO_APPR_APIM_URL' AND type = 'P'.

    SELECT SINGLE low FROM tvarvc INTO @lv_apim_key
      WHERE name = 'Z_WO_APPR_APIM_KEY' AND type = 'P'.

    IF lv_flow_url IS INITIAL.
      ev_error   = 'X'.
      ev_message = 'TVARVC Z_WO_APPR_APIM_URL not maintained'.
      RETURN.
    ENDIF.

    " ── Build unique request id ───────────────────────────────────────────
    ev_req_id = cl_system_uuid=>create_uuid_c32_static( ).

    " ── Build JSON payload ────────────────────────────────────────────────
    lv_body = |\{"request_id":"{ ev_req_id }","aufnr":"{ iv_aufnr }","requestor":"{ iv_requestor }","items":[|.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
      lv_body = lv_body &&
        |\{"werks":"{ <ls>-werks }","maktx":"{ <ls>-maktx }","bdmng":"{ <ls>-bdmng }","meins":"{ <ls>-meins }"\}|.
      IF sy-tabix < lines( it_items ).
        lv_body = lv_body && ','.
      ENDIF.
    ENDLOOP.
    lv_body = lv_body && ']}' .

    " ── HTTP POST ────────────────────────────────────────────────────────
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
    ENDIF.

    " ── Insert SENT rows in ZTWO_APPR_TMS ────────────────────────────────
    IF ev_error IS INITIAL.
      GET TIME STAMP FIELD DATA(lv_now).

      LOOP AT it_items ASSIGNING FIELD-SYMBOL(<row>).
        INSERT ztwo_appr_tms FROM @( VALUE #(
          mandt        = sy-mandt
          aufnr        = iv_aufnr
          teams_req_id = ev_req_id
          teams_status = 'SENT'
          werks        = <row>-werks
          sent_by      = iv_requestor
          sent_at      = lv_now
          last_updated = lv_now ) ).
      ENDLOOP.
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
```

Activate.

---

## 9. Step 8 — Function Group & FM Z_WO_APPR_TEAMS_SEND

**Transaction: SE80**

### 9.1 Create Function Group

1. SE80 → Function Group → Create → `ZFG_WO_APPR_TEAMS`
2. Short text: `WO Approval — Teams Integration`
3. Activate — SAP creates `LZFG_WO_APPR_TEAMSTOP` + `LZFG_WO_APPR_TEAMSUXX`

### 9.2 Create FM Z_WO_APPR_TEAMS_SEND

SE80 → right-click `ZFG_WO_APPR_TEAMS` → **Create → Function Module**

**FM Interface (Import tab):**

| Parameter | Type | Type name | Description |
|-----------|------|-----------|-------------|
| `IV_AUFNR` | TYPE | `AUFNR` | Work Order |
| `IV_REQUESTOR` | TYPE | `SYUNAME` DEFAULT `SY-UNAME` | User triggering |

**FM Interface (Tables tab):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IT_ITEMS` | `ZCL_WO_APPR_TEAMS_HANDLER=>TT_APPR_LINE` | Selected items |

**FM Interface (Export tab):**

| Parameter | Type | Type name |
|-----------|------|-----------|
| `EV_REQ_ID` | TYPE | `CHAR32` |
| `EV_HTTP_CODE` | TYPE | `I` |

**FM Interface (Exceptions tab):**

| Exception | Description |
|-----------|-------------|
| `HTTP_ERROR` | Flow trigger failed |
| `PAYLOAD_EMPTY` | No items selected |

**Source code:**

```abap
FUNCTION z_wo_appr_teams_send.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_AUFNR) TYPE  AUFNR
*"     VALUE(IV_REQUESTOR) TYPE  SYUNAME DEFAULT SY-UNAME
*"  TABLES
*"      IT_ITEMS TYPE  ZCL_WO_APPR_TEAMS_HANDLER=>TT_APPR_LINE
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

  DATA(lo_handler) = NEW zcl_wo_appr_teams_handler( ).

  DATA: lv_error   TYPE char1,
        lv_message TYPE string.

  lo_handler->send_approval(
    EXPORTING it_items     = it_items
              iv_aufnr     = iv_aufnr
              iv_requestor = iv_requestor
    IMPORTING ev_req_id    = ev_req_id
              ev_http_code = ev_http_code
              ev_error     = lv_error
              ev_message   = lv_message ).

  IF lv_error = 'X'.
    RAISE http_error.
  ENDIF.

ENDFUNCTION.
```

Activate the FM and the Function Group.

---

## 10. Step 9 — SICF Service

**Transaction: SICF**

1. Navigate: `default_host → sap → bc`
2. Right-click `bc` → **New Sub-Element** → fill:

| Field | Value |
|-------|-------|
| Name | `zwo_appr_teams` |
| Description | `WO Teams Approval` |

3. On the new node, right-click → **New Sub-Element**:

| Field | Value |
|-------|-------|
| Name | `callback` |
| Description | `Approval callback from Power Automate` |

4. Open the `callback` node → **Handler List** tab → add: `ZCL_WO_APPR_TEAMS_HTTP`

5. **Logon Data** tab:
   - Logon procedure: `Standard` + `Basic`
   - Assign a dedicated service user `TEAMS_API` (limited authorizations — see below)

6. Right-click `callback` → **Activate**

**Result:** Power Automate will POST to:
```
https://<sap-host>:<port>/sap/bc/zwo_appr_teams/callback?sap-client=<client>
```

### Service user `TEAMS_API` authorizations (PFCG)

Create role `Z_WO_APPR_API` with only:

| Auth object | Field | Value |
|-------------|-------|-------|
| `S_ICF` | `ICF_VALUE` | `/sap/bc/zwo_appr_teams/callback` |
| `S_RFC` | `RFC_NAME` | `ZFG_WO_APPR_TEAMS` |
| `S_RFC` | `RFC_TYPE` | `FUGR` |

No `SAP_ALL`. No `S_TCODE`.

---

## 11. Step 10 — TVARVC + IP Whitelist

### 11.1 TVARVC entries (transaction STVARV)

| Name | Type | Value | Notes |
|------|------|-------|-------|
| `Z_WO_APPR_APIM_URL` | `P` | `https://aut-sap-apim.azure-api.net/wo-approval/teams-trigger` | APIM endpoint (or direct Flow URL) |
| `Z_WO_APPR_APIM_KEY` | `P` | `<subscription-key>` | Only if going via APIM |

### 11.2 ZHTTP_IP_AUTH entries (SM30)

Add one row per allowed IP range for the callback:

| CLASS_NAME | IP_LOW | IP_HIGH | ACTIVE | DESCRIPTION |
|-----------|--------|---------|--------|-------------|
| `ZCL_WO_APPR_TEAMS_HTTP` | `13.66.140.0` | `13.66.140.255` | `X` | Azure APIM SEA |
| `ZCL_WO_APPR_TEAMS_HTTP` | `40.74.28.0` | `40.74.31.255` | `X` | Azure APIM SEA |
| `ZCL_WO_APPR_TEAMS_HTTP` | `127.0.0.1` | `127.0.0.1` | `X` | Local / Postman |

> For the full current list of Power Automate outbound IPs for your region,
> see:
> https://learn.microsoft.com/en-us/power-automate/ip-address-configuration

---

## 12. Step 11 — Hook into Screen 0300

### 12.1 GUI Status ZSTAT_0300 (SE41)

Add one button to the application toolbar:

| Function code | Icon / Text | F-Key | Position |
|--------------|-------------|-------|---------|
| `&RTMS` | Remind via Teams | Shift+F7 | After `&RAPR` |

### 12.2 PAI module USER_COMMAND_0300

File: `2. Function_Group/3. PAI Modules/USER_COMMAND_0300.abap`

Add one `WHEN` block inside the `CASE save_ok` statement:

```abap
WHEN '&RTMS'.
  PERFORM remind_items_via_teams.
```

### 12.3 New FORM in LZFG_WO_APPROVALF01

Add at the end of `7. includes/LZFG_WO_APPROVALF01.abap`:

```abap
*&---------------------------------------------------------------------*
*& FORM remind_items_via_teams
*& Triggered by &RTMS — sends marked TC items to Power Automate
*&---------------------------------------------------------------------*
FORM remind_items_via_teams.

  DATA lt_items TYPE zcl_wo_appr_teams_handler=>tt_appr_line.

  " Collect all marked rows from the Table Control
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

  DATA: lv_req_id    TYPE char32,
        lv_http_code TYPE i.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'
    EXPORTING  iv_aufnr     = gv_aufnr
               iv_requestor = sy-uname
    TABLES     it_items     = lt_items
    IMPORTING  ev_req_id    = lv_req_id
               ev_http_code = lv_http_code
    EXCEPTIONS http_error    = 1
               payload_empty = 2.

  IF sy-subrc = 0.
    MESSAGE |Teams reminder sent — Request ID: { lv_req_id } (HTTP { lv_http_code })| TYPE 'S'.
  ELSEIF sy-subrc = 2.
    MESSAGE 'No items selected' TYPE 'I'.
  ELSE.
    MESSAGE |Teams trigger failed — HTTP { lv_http_code }| TYPE 'E'.
  ENDIF.

ENDFORM.
```

Activate both the include and the PAI module.

---

## 13. Step 12 — Test with Postman

Before connecting Power Automate, verify the SICF callback works end-to-end.

### 13.1 Insert a test row in ZTWO_APPR_TMS

```sql
-- Via SE16 → ZTWO_APPR_TMS → Create entry
MANDT        = <your client>
AUFNR        = 0000004711
TEAMS_REQ_ID = TESTREQ0000000000000000000000001
TEAMS_STATUS = SENT
SENT_BY      = <your user>
```

### 13.2 Postman — APPROVED

```http
POST https://<sap-host>:<port>/sap/bc/zwo_appr_teams/callback?sap-client=<client>
Authorization: Basic <base64 TEAMS_API:password>
Content-Type: application/json

{
  "request_id": "TESTREQ0000000000000000000000001",
  "aufnr":      "0000004711",
  "decision":   "APPROVED",
  "approver":   "alice@unitedtractors.com",
  "comments":   "Looks good",
  "timestamp":  "2026-05-18T10:30:00Z"
}
```

**Expected response:**
```json
{ "msgty": "S", "message": "APPROVED recorded successfully" }
```

**Verify in SE16 → ZTWO_APPR_TMS:**
- `APPR_VALID = X`
- `TEAMS_STATUS = APPROVED`
- `APPR_USER = alice@unitedtractors.com`

### 13.3 Postman — blocked IP

Remove `127.0.0.1` from `ZHTTP_IP_AUTH` (or test from an unlisted IP).

**Expected response:**
```json
{ "msgty": "E", "message": "Your IP is not authorized" }
```

### 13.4 Postman — bad JSON

```json
{ "aufnr": "4711" }
```
*(missing `decision`)*

**Expected response:**
```json
{ "msgty": "E", "message": "Missing required fields: aufnr or decision" }
```

---

## Object Summary

| Object | Tx | Type | Purpose |
|--------|-----|------|---------|
| `ZTWO_APPR_TMS` | SE11 | Table | Approval state (one row per item per request) |
| `ZHTTP_IP_AUTH` | SE11 | Table | IP whitelist for SICF handlers |
| `ZCL_VND_JSON_TO_ABAP` | SE24 | Class | JSON → ABAP deserializer (from ZIP) |
| `ZCL_BASE_HTTP` | SE24 | Class | IP check + response builder |
| `ZCL_WO_APPR_TEAMS_HTTP` | SE24 | Class | Inbound: `IF_HTTP_EXTENSION` callback handler |
| `ZCL_WO_APPR_TEAMS_HANDLER` | SE24 | Class | Outbound: POST to Power Automate |
| `ZFG_WO_APPR_TEAMS` | SE80 | Function Group | Container for FM |
| `Z_WO_APPR_TEAMS_SEND` | SE37 | Function Module | Outbound entry point from Screen 0300 |
| `/sap/bc/zwo_appr_teams/callback` | SICF | ICF service | HTTP endpoint for Power Automate |
| `Z_WO_APPR_APIM_URL` | STVARV | TVARVC | Flow / APIM URL |
| `Z_WO_APPR_APIM_KEY` | STVARV | TVARVC | APIM subscription key |
| `Z_WO_APPR_API` | PFCG | Role | Service user `TEAMS_API` authorization |

---

*Guide v2 — simplified to one business table, `ZCL_VND_JSON_TO_ABAP` as
the JSON deserializer, inbound handler pattern aligned with the
`SAP_HTTP_Handler_Documentation.md` reference.*
