# ENHANCEMENT2 — Step-by-Step SAP Development Guide

> **Scope:** Full SAP build sequence to implement the Teams / Power Automate
> approval + auto-release enhancement defined in
> [`ENHANCEMENT2.md`](./ENHANCEMENT2.md).
>
> **Architecture used in this guide:**
> - **Function Group** `ZFG_WO_APPR_TEAMS` (new — does not touch existing FG `ZFG_WO_APPROVAL`)
> - **6 Function Modules** for SEND / CALLBACK / FLAG_UPDATE / CHECK_COMPLETE / AUTO_RELEASE / LOG
> - **3 Classes** — one reusable base + two handlers (outbound caller + inbound `IF_HTTP_EXTENSION`)
> - **HTTP handler pattern is taken from the reference doc
>   `SAP_HTTP_Handler_Documentation.md`** (ZCL_BASE_HTTP, IP whitelist, JSON
>   serializer, request lifecycle, error cascade).
> - **2 new transparent tables** + **1 IP-whitelist table** + **1 optional view**.
> - **2 exception classes** for typed HTTP / Auth errors.
> - **No modification** to `ZTWOAPPR` / `ZTWOAPPRH` (read-only contract).
>
> Follow the steps **in order** — later steps reference DDIC objects and classes
> created earlier.

---

## Table of Contents

1. [Build Order Overview](#1-build-order-overview)
2. [Step 1 — Create Package & Transport](#2-step-1--create-package--transport)
3. [Step 2 — DDIC Objects (SE11)](#3-step-2--ddic-objects-se11)
4. [Step 3 — Exception Classes (SE24)](#4-step-3--exception-classes-se24)
5. [Step 4 — Reusable Base Class `ZCL_BASE_HTTP` (SE24)](#5-step-4--reusable-base-class-zcl_base_http-se24)
6. [Step 5 — Outbound Handler Class `ZCL_WO_APPR_TEAMS_HANDLER` (SE24)](#6-step-5--outbound-handler-class-zcl_wo_appr_teams_handler-se24)
7. [Step 6 — Inbound HTTP Handler Class `ZCL_WO_APPR_TEAMS_HTTP` (SE24)](#7-step-6--inbound-http-handler-class-zcl_wo_appr_teams_http-se24)
8. [Step 7 — Create Function Group `ZFG_WO_APPR_TEAMS` (SE80)](#8-step-7--create-function-group-zfg_wo_appr_teams-se80)
9. [Step 8 — Function Module 1: `Z_WO_APPR_TEAMS_SEND`](#9-step-8--function-module-1-z_wo_appr_teams_send)
10. [Step 9 — Function Module 2: `Z_WO_APPR_TEAMS_CALLBACK`](#10-step-9--function-module-2-z_wo_appr_teams_callback)
11. [Step 10 — Function Module 3: `Z_WO_APPR_FLAG_UPDATE`](#11-step-10--function-module-3-z_wo_appr_flag_update)
12. [Step 11 — Function Module 4: `Z_WO_APPR_CHECK_COMPLETE`](#12-step-11--function-module-4-z_wo_appr_check_complete)
13. [Step 12 — Function Module 5: `Z_WO_APPR_AUTO_RELEASE`](#13-step-12--function-module-5-z_wo_appr_auto_release)
14. [Step 13 — Function Module 6: `Z_WO_APPR_TEAMS_LOG`](#14-step-13--function-module-6-z_wo_appr_teams_log)
15. [Step 14 — SICF Service Setup](#15-step-14--sicf-service-setup)
16. [Step 15 — SOAMANAGER / OAuth Configuration](#16-step-15--soamanager--oauth-configuration)
17. [Step 16 — TVARVC + IP Whitelist Population](#17-step-16--tvarvc--ip-whitelist-population)
18. [Step 17 — Hook into Existing Screen 0300 (`ZFG_WO_APPROVAL`)](#18-step-17--hook-into-existing-screen-0300-zfg_wo_approval)
19. [Step 18 — End-to-End Test Plan](#19-step-18--end-to-end-test-plan)
20. [Step 19 — APIM / Production Hardening](#20-step-19--apim--production-hardening)
21. [Appendix A — Object Catalog](#21-appendix-a--object-catalog)
22. [Appendix B — Reusable HTTP Skeleton Reference](#22-appendix-b--reusable-http-skeleton-reference)

---

## 1. Build Order Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│  1. Package + Transport            (SE21 / SE80)                          │
│  2. DDIC                          (SE11)                                  │
│       ├─ Domains / Data Elements                                          │
│       ├─ Table ZTWO_APPR_TMS                                              │
│       ├─ Table ZTWO_APPR_TMSH                                             │
│       ├─ Table ZHTTP_IP_AUTH        ◄── from HTTP-Handler reference doc   │
│       └─ View  ZV_WO_APPR_FULL  (optional)                                │
│  3. Exception classes              (SE24)                                 │
│       ├─ ZCX_WO_APPR_TEAMS_HTTP                                           │
│       └─ ZCX_WO_APPR_TEAMS_AUTH                                           │
│  4. Reusable base class            (SE24)                                 │
│       └─ ZCL_BASE_HTTP            ◄── pattern from reference doc          │
│  5. Outbound handler class         (SE24)                                 │
│       └─ ZCL_WO_APPR_TEAMS_HANDLER                                        │
│  6. Inbound HTTP handler class     (SE24)                                 │
│       └─ ZCL_WO_APPR_TEAMS_HTTP   (implements IF_HTTP_EXTENSION)          │
│  7. Function Group + 6 FMs         (SE80 / SE37)                          │
│       └─ ZFG_WO_APPR_TEAMS                                                │
│  8. SICF service                   (SICF)                                 │
│  9. SOAMANAGER OAuth profile       (SOAMANAGER)                           │
│ 10. TVARVC + IP whitelist          (STVARV / SM30)                        │
│ 11. Hook into ZFG_WO_APPROVAL      (modify Screen 0300 GUI + PAI)         │
│ 12. Test (Postman → APIM → Teams)                                         │
└────────────────────────────────────────────────────────────────────────────┘
```

> Steps 1 → 6 are dependency-only ABAP objects; steps 7+ wire them together.
> You can verify the whole chain with Postman after Step 14, even before
> Power Automate is built.

---

## 2. Step 1 — Create Package & Transport

1. **SE21** → Create package `ZWO_APPROVAL_TEAMS`.
   - Short text: `WO Approval — Teams / Power Automate Integration`
   - Application component: `PM-WOC` (or your local equivalent).
   - Transport layer: your standard customer transport layer.
2. **SE10** → Create a workbench request, e.g.
   `Dxx K9 00001234 — ENHANCEMENT2 Teams Approval`.
3. Assign all objects created in the following steps to this package and
   transport.

> ⚠ **Do not** place anything in package `ZWO_APPROVAL` (the original system).
> The Teams enhancement must ship as an isolated transport.

---

## 3. Step 2 — DDIC Objects (SE11)

### 3.1 Data elements (SE11 → Data type → Data Element)

| Data Element       | Domain       | Description                            |
| ------------------ | ------------ | -------------------------------------- |
| `ZDE_TEAMS_REQ_ID` | `CHAR32`     | Power Automate run / correlation id    |
| `ZDE_TEAMS_STATUS` | `CHAR10`     | SENT / APPROVED / REJECTED / TIMEOUT   |
| `ZDE_EVENT_TYPE`   | `CHAR10`     | SEND / APPROVE / REJECT / RELEASE / ERROR |
| `ZDE_APPR_VALID`   | `CHAR1`      | `X` approved, `R` rejected, `' '` open |

### 3.2 Table `ZTWO_APPR_TMS` — Teams approval state

**Transaction:** SE11 → Database table → Create.

| Field          | Key | Data Element / Type | Description                              |
| -------------- | --- | ------------------- | ---------------------------------------- |
| `MANDT`        | ✔   | MANDT               | Client                                   |
| `AUFNR`        | ✔   | AUFNR               | Work order                               |
| `POSNR`        | ✔   | POSNR               | Item                                     |
| `TEAMS_REQ_ID` | ✔   | ZDE_TEAMS_REQ_ID    | Correlation id                           |
| `APPR_VALID`   |     | ZDE_APPR_VALID      | Approval flag                            |
| `TEAMS_STATUS` |     | ZDE_TEAMS_STATUS    | Lifecycle status                         |
| `WERKS`        |     | WERKS_D             | Plant — used for approver routing        |
| `APPR_USER`    |     | SYUNAME             | Approver                                 |
| `APPR_DATE`    |     | DATS                | Approval date                            |
| `APPR_TIME`    |     | TIMS                | Approval time                            |
| `SENT_BY`      |     | SYUNAME             | Helpdesk user that triggered the request |
| `SENT_AT`      |     | TIMESTAMPL          | Send timestamp                           |
| `LAST_UPDATED` |     | TIMESTAMPL          | Last status change                       |

- **Delivery class:** `A` (Application data).
- **Maintenance:** *Display/Maintenance allowed*.
- **Technical settings:** Data class `APPL1`, Size category `0`.
- **Secondary index** `Z01` on `TEAMS_REQ_ID` (non-unique).
- **Foreign key** `(AUFNR, POSNR) → ZTWOAPPR` (check table, *No check*, just for documentation).

Activate.

### 3.3 Table `ZTWO_APPR_TMSH` — append-only audit log

| Field          | Key | Data Element / Type | Description                  |
| -------------- | --- | ------------------- | ---------------------------- |
| `MANDT`        | ✔   | MANDT               | Client                       |
| `LOG_ID`       | ✔   | SYSUUID_X16         | GUID per event               |
| `TEAMS_REQ_ID` |     | ZDE_TEAMS_REQ_ID    | Correlation id               |
| `AUFNR`        |     | AUFNR               | Work order                   |
| `POSNR`        |     | POSNR               | Item                         |
| `EVENT_TYPE`   |     | ZDE_EVENT_TYPE      | Event                        |
| `EVENT_USER`   |     | SYUNAME             | User                         |
| `EVENT_TS`     |     | TIMESTAMPL          | UTC timestamp                |
| `HTTP_CODE`    |     | INT4                | HTTP status                  |
| `MESSAGE`      |     | STRING              | Free text                    |
| `PAYLOAD`      |     | STRING              | Optional JSON for forensics  |

Delivery class `L` (Log), Display/Maintenance *not allowed* via SM30
(append-only from code). Activate.

### 3.4 Table `ZHTTP_IP_AUTH` — IP allowlist (from HTTP Handler reference doc §8.2)

This is the table consulted by `ZCL_BASE_HTTP=>M_CHECK_IP_AUTH`.

| Field         | Key | Type         | Description                          |
| ------------- | --- | ------------ | ------------------------------------ |
| `MANDT`       | ✔   | MANDT        | Client                               |
| `CLASS_NAME`  | ✔   | REPID        | Handler class name (e.g. `ZCL_WO_APPR_TEAMS_HTTP`) |
| `IP_LOW`      | ✔   | RFCIPV6ADDR  | IP range start                       |
| `IP_HIGH`     |     | RFCIPV6ADDR  | IP range end (same as LOW for single IP) |
| `ACTIVE`      |     | CHAR1        | `X` = active                         |
| `DESCRIPTION` |     | STRING       | Free text (e.g. *Azure APIM South-East-Asia outbound*) |

- **Delivery class:** `C` (Customizing).
- **Maintenance:** SM30 generated (`Z_VC_HTTP_IP_AUTH` view + maintenance dialog).
- One row per (CLASS_NAME, IP_LOW) — multiple rows per handler are allowed.

Activate, then SE54 → generate maintenance dialog so admins can maintain rows
in SM30.

### 3.5 Optional view `ZV_WO_APPR_FULL`

CDS or DDIC view joining `ZTWOAPPR` ⋈ `ZTWO_APPR_TMS` (for reporting only —
see ENHANCEMENT2 §2.3 for the source).

---

## 4. Step 3 — Exception Classes (SE24)

Both classes inherit from `CX_STATIC_CHECK` so callers must declare them.

### 4.1 `ZCX_WO_APPR_TEAMS_HTTP`

```abap
CLASS zcx_wo_appr_teams_http DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA http_code TYPE i.
    METHODS constructor
      IMPORTING
        textid    LIKE if_t100_message=>t100key OPTIONAL
        previous  LIKE previous OPTIONAL
        http_code TYPE i OPTIONAL.
ENDCLASS.

CLASS zcx_wo_appr_teams_http IMPLEMENTATION.
  METHOD constructor.
    super->constructor( textid = textid previous = previous ).
    me->http_code = http_code.
  ENDMETHOD.
ENDCLASS.
```

### 4.2 `ZCX_WO_APPR_TEAMS_AUTH`

Identical pattern, no extra attributes.

```abap
CLASS zcx_wo_appr_teams_auth DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING textid LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL.
ENDCLASS.

CLASS zcx_wo_appr_teams_auth IMPLEMENTATION.
  METHOD constructor.
    super->constructor( textid = textid previous = previous ).
  ENDMETHOD.
ENDCLASS.
```

Activate both.

---

## 5. Step 4 — Reusable Base Class `ZCL_BASE_HTTP` (SE24)

> **Source pattern:** `SAP_HTTP_Handler_Documentation.md` §8.
> This class centralises IP whitelisting, JSON ↔ ABAP conversion, and HTTP
> response building so every handler stays focused on business logic.

### 5.1 Class definition

```abap
CLASS zcl_base_http DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Validate caller IP against ZHTTP_IP_AUTH
    METHODS m_check_ip_auth
      IMPORTING i_ip         TYPE rfcipv6addr
                i_class_name TYPE repid
      EXPORTING e_error      TYPE c.

    "! Serialize any ABAP data → JSON string (camelCase, compress empties)
    METHODS m_itab_to_json
      IMPORTING data TYPE any
      EXPORTING json TYPE string.

    "! Deserialize JSON string → ABAP structure
    METHODS m_json_to_abap
      IMPORTING json TYPE string
      CHANGING  data TYPE any.

    "! Set HTTP status, content-type, body in one call
    METHODS m_set_response
      IMPORTING io_server    TYPE REF TO if_http_server
                i_code       TYPE i
                i_reason     TYPE string
                i_body       TYPE string.

    "! Append a row to BAL (or fallback to SLG1) — audit trail
    METHODS m_log_request
      IMPORTING i_class_name TYPE repid
                i_ip         TYPE rfcipv6addr
                i_body       TYPE string
                i_error      TYPE c OPTIONAL.

ENDCLASS.
```

### 5.2 Implementation highlights

```abap
CLASS zcl_base_http IMPLEMENTATION.

  METHOD m_check_ip_auth.
    e_error = 'X'.   " default deny

    SELECT SINGLE @abap_true
      FROM zhttp_ip_auth
      INTO @DATA(lv_found)
      WHERE class_name = @i_class_name
        AND active     = 'X'
        AND ip_low     <= @i_ip
        AND ip_high    >= @i_ip.

    IF sy-subrc = 0 AND lv_found = abap_true.
      CLEAR e_error.
    ENDIF.
  ENDMETHOD.

  METHOD m_itab_to_json.
    json = /ui2/cl_json=>serialize(
             data        = data
             compress    = abap_true
             pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  ENDMETHOD.

  METHOD m_json_to_abap.
    " Strip '#' chars (Teams Markdown artefacts) — see reference §8.3
    DATA(lv_clean) = json.
    REPLACE ALL OCCURRENCES OF '#' IN lv_clean WITH ''.

    /ui2/cl_json=>deserialize(
      EXPORTING json        = lv_clean
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data        = data ).
  ENDMETHOD.

  METHOD m_set_response.
    io_server->response->set_status( code = i_code reason = i_reason ).
    io_server->response->set_header_field(
      name = 'Content-Type' value = 'application/json' ).
    io_server->response->set_cdata( data = i_body ).
  ENDMETHOD.

  METHOD m_log_request.
    " Minimal SLG1 logging — replace with BAL_LOG_* helpers if desired
    MESSAGE i000(38) WITH i_class_name i_ip
                          COND #( WHEN i_error = 'X' THEN 'ERR' ELSE 'OK' )
                          i_body(40) INTO DATA(lv_msg).
    " Optionally INSERT into your audit table here.
  ENDMETHOD.

ENDCLASS.
```

Activate.

---

## 6. Step 5 — Outbound Handler Class `ZCL_WO_APPR_TEAMS_HANDLER` (SE24)

This class is the **outbound** side — SAP → Power Automate / APIM. It:

- Reads the URL + secrets from TVARVC / Key Vault.
- Builds the JSON payload with `WERKS` for plant-based routing.
- Acquires an OAuth 2.0 token via SOAMANAGER profile `ZOA2C_MS_FLOW`.
- Sends HTTP POST and returns the run id + HTTP code.

### 6.1 Definition

```abap
CLASS zcl_wo_appr_teams_handler DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_appr_line,
             aufnr       TYPE aufnr,
             posnr       TYPE posnr,
             werks       TYPE werks_d,
             description TYPE string,
             qty         TYPE menge_d,
             uom         TYPE meins,
           END OF ty_appr_line,
           tt_appr_line TYPE STANDARD TABLE OF ty_appr_line WITH DEFAULT KEY.

    METHODS constructor.

    METHODS send_approval
      IMPORTING it_items     TYPE tt_appr_line
                iv_requestor TYPE syuname
      EXPORTING ev_req_id    TYPE char32
                ev_http_code TYPE i
      RAISING   zcx_wo_appr_teams_http
                zcx_wo_appr_teams_auth.

    METHODS verify_callback_signature
      IMPORTING iv_body      TYPE xstring
                iv_signature TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.

  PRIVATE SECTION.
    DATA: mv_flow_url     TYPE string,
          mv_apim_key     TYPE string,
          mv_hmac_secret  TYPE xstring,
          mo_http         TYPE REF TO if_http_client,
          mo_base         TYPE REF TO zcl_base_http.

    METHODS get_oauth_token
      RETURNING VALUE(rv_token) TYPE string
      RAISING   zcx_wo_appr_teams_auth.

    METHODS build_payload
      IMPORTING it_items       TYPE tt_appr_line
                iv_req_id      TYPE char32
                iv_user        TYPE syuname
      RETURNING VALUE(rv_json) TYPE string.

    METHODS load_config.

ENDCLASS.
```

### 6.2 Key methods

```abap
CLASS zcl_wo_appr_teams_handler IMPLEMENTATION.

  METHOD constructor.
    CREATE OBJECT mo_base.
    load_config( ).
  ENDMETHOD.

  METHOD load_config.
    SELECT SINGLE low FROM tvarvc INTO @mv_flow_url
      WHERE name = 'Z_WO_APPR_APIM_URL' AND type = 'P'.

    SELECT SINGLE low FROM tvarvc INTO @mv_apim_key
      WHERE name = 'Z_WO_APPR_APIM_KEY' AND type = 'P'.
    " mv_hmac_secret should come from STRUST / SSF — never from TVARVC.
  ENDMETHOD.

  METHOD send_approval.
    DATA: lv_token   TYPE string,
          lv_body    TYPE string,
          lv_status  TYPE i,
          lv_reason  TYPE string,
          lv_payload TYPE xstring,
          lv_sig     TYPE string.

    ev_req_id = cl_system_uuid=>create_uuid_c32_static( ).
    lv_token  = get_oauth_token( ).
    lv_body   = build_payload( it_items  = it_items
                               iv_req_id = ev_req_id
                               iv_user   = iv_requestor ).

    cl_http_client=>create_by_url(
      EXPORTING url = mv_flow_url IMPORTING client = mo_http ).

    mo_http->request->set_method( if_http_request=>co_request_method_post ).
    mo_http->request->set_header_field(
      name = 'Content-Type' value = 'application/json' ).
    mo_http->request->set_header_field(
      name = 'Authorization' value = |Bearer { lv_token }| ).
    mo_http->request->set_header_field(
      name = 'Ocp-Apim-Subscription-Key' value = mv_apim_key ).
    mo_http->request->set_header_field(
      name = 'X-SAP-Req-Id' value = ev_req_id ).

    " HMAC of body for X-Flow-Signature (the receiver can verify symmetrically)
    lv_payload = cl_abap_codepage=>convert_to( lv_body ).
    lv_sig = cl_abap_hmac=>calculate_hmac_for_raw(
               if_algorithm = 'SHA256'
               if_key       = mv_hmac_secret
               if_data      = lv_payload )-hmacstring.
    mo_http->request->set_header_field( name = 'X-Flow-Signature' value = lv_sig ).

    mo_http->request->set_cdata( lv_body ).
    mo_http->send( ).
    mo_http->receive( ).
    mo_http->response->get_status( IMPORTING code = ev_http_code reason = lv_reason ).
    mo_http->close( ).

    IF ev_http_code <> 200 AND ev_http_code <> 202.
      RAISE EXCEPTION TYPE zcx_wo_appr_teams_http
        EXPORTING http_code = ev_http_code.
    ENDIF.
  ENDMETHOD.

  METHOD build_payload.
    " Convert ABAP table → JSON via the base helper
    DATA: BEGIN OF ls_envelope,
            request_id TYPE char32,
            requestor  TYPE syuname,
            items      TYPE tt_appr_line,
          END OF ls_envelope.

    ls_envelope-request_id = iv_req_id.
    ls_envelope-requestor  = iv_user.
    ls_envelope-items      = it_items.

    mo_base->m_itab_to_json(
      EXPORTING data = ls_envelope
      IMPORTING json = rv_json ).
  ENDMETHOD.

  METHOD verify_callback_signature.
    DATA(lv_calc) = cl_abap_hmac=>calculate_hmac_for_raw(
                      if_algorithm = 'SHA256'
                      if_key       = mv_hmac_secret
                      if_data      = iv_body )-hmacstring.
    rv_ok = xsdbool( to_upper( lv_calc ) = to_upper( iv_signature ) ).
  ENDMETHOD.

  METHOD get_oauth_token.
    " Use OA2C_GRANT / cl_oauth2_client; profile ZOA2C_MS_FLOW (Step 15)
    " Fill rv_token with the access_token from the response.
    " (Skeleton — implement using your OAuth wrapper.)
  ENDMETHOD.

ENDCLASS.
```

Activate.

---

## 7. Step 6 — Inbound HTTP Handler Class `ZCL_WO_APPR_TEAMS_HTTP` (SE24)

> This is the **inbound** SICF handler. It strictly follows the
> reference doc (Section 4 — Request Lifecycle, Section 5 — skeleton):
> read body FIRST, then IP check, then deserialize, then process, then respond.

### 7.1 Definition

```abap
CLASS zcl_wo_appr_teams_http DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_callback_item,
             wo    TYPE aufnr,
             pos   TYPE posnr,
             werks TYPE werks_d,
           END OF ty_callback_item,
           tt_callback_item TYPE STANDARD TABLE OF ty_callback_item WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_callback,
             request_id TYPE char32,
             decision   TYPE char10,           " APPROVED / REJECTED / TIMEOUT
             user       TYPE string,
             items      TYPE tt_callback_item,
           END OF ty_callback.

    METHODS process_request
      IMPORTING is_data    TYPE ty_callback
                iv_body_x  TYPE xstring
                iv_sig     TYPE string
      EXPORTING ev_error   TYPE c
                ev_message TYPE string.

ENDCLASS.
```

### 7.2 Implementation — the full lifecycle

```abap
CLASS zcl_wo_appr_teams_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA: lv_request   TYPE string,
          lv_body_x    TYPE xstring,
          lv_sig       TYPE string,
          lv_response  TYPE string,
          lv_error     TYPE c,
          lv_ip        TYPE rfcipv6addr,
          ls_data      TYPE ty_callback,
          o_http       TYPE REF TO zcl_base_http,
          lv_class_nm  TYPE repid.

    DATA: BEGIN OF lw_msg,
            msgty   TYPE char1,
            message TYPE string,
          END OF lw_msg.

    " Allow other ICF handlers in the chain
    server->set_compression( options = if_http_server=>co_compress_based_on_mime_type ).

    " ─── Phase 1: read body FIRST ──────────────────────────────────────────
    lv_request = server->request->get_cdata( ).
    lv_body_x  = server->request->get_data( ).
    lv_sig     = server->request->get_header_field( 'X-Flow-Signature' ).

    " ─── Phase 2: IP authorization ─────────────────────────────────────────
    CREATE OBJECT o_http.
    lv_ip = cl_http_server=>c_caller_ip.

    lv_class_nm = cl_abap_classdescr=>get_class_name( me ).
    lv_class_nm = lv_class_nm+7.   " strip '\CLASS='

    o_http->m_check_ip_auth(
      EXPORTING i_ip = lv_ip i_class_name = lv_class_nm
      IMPORTING e_error = lv_error ).

    IF lv_error = 'X'.
      lw_msg = VALUE #( msgty = 'E' message = 'IP not authorized' ).
    ENDIF.

    " ─── Phase 3: body not empty ───────────────────────────────────────────
    IF lv_error IS INITIAL AND lv_request IS INITIAL.
      lv_error = 'X'.
      lw_msg = VALUE #( msgty = 'E' message = 'Request body is empty' ).
    ENDIF.

    " ─── Phase 4: deserialize JSON ─────────────────────────────────────────
    IF lv_error IS INITIAL.
      TRY.
          o_http->m_json_to_abap(
            EXPORTING json = lv_request
            CHANGING  data = ls_data ).
        CATCH cx_root INTO DATA(lx).
          lv_error = 'X'.
          lw_msg = VALUE #( msgty = 'E' message = lx->get_text( ) ).
      ENDTRY.
    ENDIF.

    " ─── Phase 5+6: validate + business logic ──────────────────────────────
    IF lv_error IS INITIAL.
      process_request(
        EXPORTING is_data    = ls_data
                  iv_body_x  = lv_body_x
                  iv_sig     = lv_sig
        IMPORTING ev_error   = lv_error
                  ev_message = lw_msg-message ).
      lw_msg-msgty = COND #( WHEN lv_error = 'X' THEN 'E' ELSE 'S' ).
    ENDIF.

    " ─── Phase 7: build & send response ────────────────────────────────────
    o_http->m_itab_to_json(
      EXPORTING data = lw_msg IMPORTING json = lv_response ).

    o_http->m_set_response(
      io_server = server
      i_code    = COND #( WHEN lv_error = 'X' THEN 400 ELSE 200 )
      i_reason  = COND #( WHEN lv_error = 'X' THEN `Bad Request` ELSE `OK` )
      i_body    = lv_response ).

    o_http->m_log_request(
      i_class_name = lv_class_nm
      i_ip         = lv_ip
      i_body       = lv_request
      i_error      = lv_error ).

  ENDMETHOD.

  METHOD process_request.

    " 1) HMAC verification — uses the outbound handler class as a helper
    DATA(lo_h) = NEW zcl_wo_appr_teams_handler( ).
    IF lo_h->verify_callback_signature(
         iv_body = iv_body_x iv_signature = iv_sig ) = abap_false.
      ev_error   = 'X'.
      ev_message = 'Bad HMAC signature'.
      RETURN.
    ENDIF.

    " 2) Whitelist decision value
    DATA(lv_decision) = is_data-decision.
    TRANSLATE lv_decision TO UPPER CASE.
    IF lv_decision <> 'APPROVED' AND lv_decision <> 'REJECTED'
       AND lv_decision <> 'TIMEOUT'.
      ev_error   = 'X'.
      ev_message = |Invalid decision: { lv_decision }|.
      RETURN.
    ENDIF.

    " 3) Build TT_APPR_LINE expected by the callback FM
    DATA lt_items TYPE zcl_wo_appr_teams_handler=>tt_appr_line.
    LOOP AT is_data-items ASSIGNING FIELD-SYMBOL(<i>).
      APPEND VALUE #( aufnr = <i>-wo
                      posnr = <i>-pos
                      werks = <i>-werks ) TO lt_items.
    ENDLOOP.

    " 4) Delegate to the orchestrator FM
    DATA lv_released TYPE flag.
    CALL FUNCTION 'Z_WO_APPR_TEAMS_CALLBACK'
      EXPORTING iv_req_id   = is_data-request_id
                iv_decision = lv_decision
                iv_user     = CONV syuname( is_data-user )
                it_items    = lt_items
      IMPORTING ev_released = lv_released
      EXCEPTIONS update_failed  = 1
                 release_failed = 2
                 OTHERS         = 3.

    IF sy-subrc <> 0.
      ev_error   = 'X'.
      ev_message = |FM error subrc { sy-subrc }|.
      RETURN.
    ENDIF.

    ev_message = COND #( WHEN lv_released = 'X'
                         THEN |Approved and order released|
                         ELSE |Approval processed successfully| ).
  ENDMETHOD.

ENDCLASS.
```

Activate. This class is what you'll bind to the SICF service in Step 14.

---

## 8. Step 7 — Create Function Group `ZFG_WO_APPR_TEAMS` (SE80)

1. **SE80** → Function Group → Create → `ZFG_WO_APPR_TEAMS`.
2. Short text: `WO Approval — Teams / Power Automate Integration`.
3. SAP auto-creates `LZFG_WO_APPR_TEAMSTOP` + `LZFG_WO_APPR_TEAMSUXX`.
4. In `LZFG_WO_APPR_TEAMSTOP`, add the shared types + constants:

```abap
FUNCTION-POOL zfg_wo_appr_teams.

TYPES: BEGIN OF ty_appr_line,
         aufnr       TYPE aufnr,
         posnr       TYPE posnr,
         werks       TYPE werks_d,         " plant — drives MS Flow approver routing
         description TYPE string,
         qty         TYPE menge_d,
         uom         TYPE meins,
       END OF ty_appr_line,
       tt_appr_line TYPE STANDARD TABLE OF ty_appr_line WITH DEFAULT KEY.

CONSTANTS:
  c_status_sent     TYPE char10 VALUE 'SENT',
  c_status_approved TYPE char10 VALUE 'APPROVED',
  c_status_rejected TYPE char10 VALUE 'REJECTED',
  c_status_timeout  TYPE char10 VALUE 'TIMEOUT',
  c_event_send      TYPE char10 VALUE 'SEND',
  c_event_release   TYPE char10 VALUE 'RELEASE',
  c_flag_x          TYPE char1  VALUE 'X',
  c_flag_r          TYPE char1  VALUE 'R'.
```

Activate the function group.

---

## 9. Step 8 — Function Module 1: `Z_WO_APPR_TEAMS_SEND`

### 9.1 Interface (SE37 → Create FM)

| Tab        | Name             | Type              | Pass value |
| ---------- | ---------------- | ----------------- | ---------- |
| Import     | `IT_ITEMS`       | TYPE `TT_APPR_LINE` | ✔        |
| Import     | `IV_REQUESTOR`   | TYPE `SYUNAME` DEFAULT `SY-UNAME` | ✔ |
| Export     | `EV_REQ_ID`      | TYPE `CHAR32`     | ✔          |
| Export     | `EV_HTTP_CODE`   | TYPE `I`          | ✔          |
| Exception  | `HTTP_ERROR`     | —                 | —          |
| Exception  | `AUTH_ERROR`     | —                 | —          |
| Exception  | `PAYLOAD_EMPTY`  | —                 | —          |

### 9.2 Source

```abap
FUNCTION z_wo_appr_teams_send.
*"--------------------------------------------------------------------
*"*"Local Interface:  see SE37 (mirrors §9.1)
*"--------------------------------------------------------------------
  IF it_items IS INITIAL.
    RAISE payload_empty.
  ENDIF.

  DATA(lo_handler) = NEW zcl_wo_appr_teams_handler( ).

  TRY.
      lo_handler->send_approval(
        EXPORTING it_items     = it_items
                  iv_requestor = iv_requestor
        IMPORTING ev_req_id    = ev_req_id
                  ev_http_code = ev_http_code ).
    CATCH zcx_wo_appr_teams_auth.
      RAISE auth_error.
    CATCH zcx_wo_appr_teams_http.
      RAISE http_error.
  ENDTRY.

  " Persist tracker rows in ZTWO_APPR_TMS
  DATA lt_tms TYPE STANDARD TABLE OF ztwo_appr_tms.
  GET TIME STAMP FIELD DATA(lv_now).

  LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
    APPEND VALUE ztwo_appr_tms(
      mandt        = sy-mandt
      aufnr        = <ls>-aufnr
      posnr        = <ls>-posnr
      werks        = <ls>-werks
      teams_req_id = ev_req_id
      teams_status = c_status_sent
      sent_by      = iv_requestor
      sent_at      = lv_now
      last_updated = lv_now ) TO lt_tms.
  ENDLOOP.
  MODIFY ztwo_appr_tms FROM TABLE lt_tms.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING iv_event     = c_event_send
              iv_req_id    = ev_req_id
              iv_user      = iv_requestor
              iv_http_code = ev_http_code
              it_items     = it_items.

  COMMIT WORK.
ENDFUNCTION.
```

---

## 10. Step 9 — Function Module 2: `Z_WO_APPR_TEAMS_CALLBACK`

### 10.1 Interface

| Tab        | Name           | Type              |
| ---------- | -------------- | ----------------- |
| Import     | `IV_REQ_ID`    | TYPE `CHAR32`     |
| Import     | `IV_DECISION`  | TYPE `CHAR10`     |
| Import     | `IV_USER`      | TYPE `SYUNAME`    |
| Import     | `IT_ITEMS`     | TYPE `TT_APPR_LINE` |
| Export     | `EV_RELEASED`  | TYPE `FLAG`       |
| Exception  | `UPDATE_FAILED`| —                 |
| Exception  | `RELEASE_FAILED`| —                |

### 10.2 Source

```abap
FUNCTION z_wo_appr_teams_callback.
  DATA: lv_flag    TYPE char1,
        lv_all     TYPE flag,
        lt_aufnr   TYPE STANDARD TABLE OF aufnr.

  lv_flag = COND #( WHEN iv_decision = c_status_approved THEN c_flag_x
                    WHEN iv_decision = c_status_rejected THEN c_flag_r
                    ELSE ' ' ).

  LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
    CALL FUNCTION 'Z_WO_APPR_FLAG_UPDATE'
      EXPORTING iv_aufnr  = <ls>-aufnr
                iv_posnr  = <ls>-posnr
                iv_flag   = lv_flag
                iv_user   = iv_user
                iv_req_id = iv_req_id
      EXCEPTIONS update_failed = 1 OTHERS = 2.
    IF sy-subrc <> 0. RAISE update_failed. ENDIF.
    COLLECT <ls>-aufnr INTO lt_aufnr.
  ENDLOOP.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING iv_event  = iv_decision
              iv_req_id = iv_req_id
              iv_user   = iv_user
              it_items  = it_items.

  IF iv_decision = c_status_approved.
    LOOP AT lt_aufnr INTO DATA(lv_aufnr).
      CALL FUNCTION 'Z_WO_APPR_CHECK_COMPLETE'
        EXPORTING  iv_aufnr   = lv_aufnr
        IMPORTING  ev_all_done = lv_all.

      IF lv_all = c_flag_x.
        CALL FUNCTION 'Z_WO_APPR_AUTO_RELEASE'
          EXPORTING iv_aufnr = lv_aufnr
          EXCEPTIONS release_failed = 1.
        IF sy-subrc = 0.
          ev_released = c_flag_x.
        ELSE.
          RAISE release_failed.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.

  COMMIT WORK AND WAIT.
ENDFUNCTION.
```

---

## 11. Step 10 — Function Module 3: `Z_WO_APPR_FLAG_UPDATE`

### 11.1 Interface

| Tab | Name | Type |
| --- | --- | --- |
| Import | `IV_AUFNR` | TYPE `AUFNR` |
| Import | `IV_POSNR` | TYPE `POSNR` |
| Import | `IV_FLAG`  | TYPE `CHAR1` |
| Import | `IV_USER`  | TYPE `SYUNAME` |
| Import | `IV_REQ_ID`| TYPE `CHAR32` |
| Exception | `UPDATE_FAILED` | — |

### 11.2 Source

```abap
FUNCTION z_wo_appr_flag_update.
  GET TIME STAMP FIELD DATA(lv_now).

  UPDATE ztwo_appr_tms
     SET appr_valid   = iv_flag
         appr_user    = iv_user
         appr_date    = sy-datum
         appr_time    = sy-uzeit
         teams_status = COND #( WHEN iv_flag = c_flag_x THEN c_status_approved
                                WHEN iv_flag = c_flag_r THEN c_status_rejected
                                ELSE c_status_timeout )
         last_updated = lv_now
   WHERE aufnr        = iv_aufnr
     AND posnr        = iv_posnr
     AND teams_req_id = iv_req_id.

  IF sy-subrc <> 0. RAISE update_failed. ENDIF.
  " ZTWOAPPR is intentionally NOT written here.
ENDFUNCTION.
```

---

## 12. Step 11 — Function Module 4: `Z_WO_APPR_CHECK_COMPLETE`

### 12.1 Interface

| Tab | Name | Type |
| --- | --- | --- |
| Import | `IV_AUFNR` | TYPE `AUFNR` |
| Export | `EV_ALL_DONE` | TYPE `FLAG` |

### 12.2 Source

```abap
FUNCTION z_wo_appr_check_complete.
  DATA: lv_total TYPE i,
        lv_done  TYPE i.

  SELECT COUNT(*) FROM ztwoappr
    WHERE aufnr = @iv_aufnr
    INTO @lv_total.

  SELECT COUNT(*) FROM ztwoappr      AS h
       INNER JOIN ztwo_appr_tms AS t
         ON  h~aufnr = t~aufnr
         AND h~posnr = t~posnr
    WHERE h~aufnr      = @iv_aufnr
      AND t~appr_valid = @c_flag_x
    INTO @lv_done.

  ev_all_done = COND #( WHEN lv_total > 0 AND lv_total = lv_done
                        THEN c_flag_x ELSE space ).
ENDFUNCTION.
```

---

## 13. Step 12 — Function Module 5: `Z_WO_APPR_AUTO_RELEASE`

### 13.1 Interface

| Tab | Name | Type |
| --- | --- | --- |
| Import | `IV_AUFNR` | TYPE `AUFNR` |
| Exception | `RELEASE_FAILED` | — |

### 13.2 Source

```abap
FUNCTION z_wo_appr_auto_release.
  DATA: lt_return  TYPE STANDARD TABLE OF bapiret2,
        lt_methods TYPE STANDARD TABLE OF bapi_alm_order_method,
        ls_method  LIKE LINE OF lt_methods,
        ls_header  TYPE bapi_alm_order_headers_i,
        lt_header  TYPE STANDARD TABLE OF bapi_alm_order_headers_i.

  ls_method-refnumber  = '000001'.
  ls_method-objecttype = 'HEADER'.
  ls_method-method     = 'RELEASE'.
  ls_method-objectkey  = iv_aufnr.
  APPEND ls_method TO lt_methods.

  ls_method-method = 'SAVE'.
  CLEAR ls_method-objectkey.
  APPEND ls_method TO lt_methods.

  ls_header-orderid = iv_aufnr.
  APPEND ls_header TO lt_header.

  CALL FUNCTION 'BAPI_ALM_ORDER_MAINTAIN'
    TABLES it_methods = lt_methods
           it_header  = lt_header
           return     = lt_return.

  IF line_exists( lt_return[ type = 'E' ] )
  OR line_exists( lt_return[ type = 'A' ] ).
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    RAISE release_failed.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING iv_event = c_event_release
              iv_user  = sy-uname
              it_items = VALUE #( ( aufnr = iv_aufnr posnr = '0000' ) ).
ENDFUNCTION.
```

---

## 14. Step 13 — Function Module 6: `Z_WO_APPR_TEAMS_LOG`

### 14.1 Interface

| Tab | Name | Type | Optional |
| --- | --- | --- | --- |
| Import | `IV_EVENT` | TYPE `CHAR10` | — |
| Import | `IV_REQ_ID` | TYPE `CHAR32` | ✔ |
| Import | `IV_USER` | TYPE `SYUNAME` DEFAULT `SY-UNAME` | — |
| Import | `IV_HTTP_CODE` | TYPE `I` | ✔ |
| Import | `IV_MESSAGE` | TYPE `STRING` | ✔ |
| Import | `IV_PAYLOAD` | TYPE `STRING` | ✔ |
| Import | `IT_ITEMS` | TYPE `TT_APPR_LINE` | ✔ |

### 14.2 Source

```abap
FUNCTION z_wo_appr_teams_log.
  GET TIME STAMP FIELD DATA(lv_now).

  LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
    INSERT ztwo_appr_tmsh FROM @( VALUE #(
      mandt        = sy-mandt
      log_id       = cl_system_uuid=>create_uuid_x16_static( )
      teams_req_id = iv_req_id
      aufnr        = <ls>-aufnr
      posnr        = <ls>-posnr
      event_type   = iv_event
      event_user   = iv_user
      event_ts     = lv_now
      http_code    = iv_http_code
      message      = iv_message
      payload      = iv_payload ) ).
  ENDLOOP.
ENDFUNCTION.
```

After creating all 6 FMs, run **mass activation** on the function group
(SE80 → right-click → Activate).

---

## 15. Step 14 — SICF Service Setup

1. **SICF** → service tree → `default_host/sap/bc`.
2. Right-click → **New Sub-Element** → **Service**.

| Setting | Value |
| --- | --- |
| Name | `zfg_wo_appr_teams` |
| Description | `Teams Approval Callback` |
| Handler list → 1 | `ZCL_WO_APPR_TEAMS_HTTP` |
| Logon procedure | Alternative — Standard + Basic |
| Service user (techn.) | `TEAMS_API` (PFCG role `Z_WO_APPR_API`) |
| HTTPS | Mandatory |
| Security session | Enabled |

3. Add sub-node `callback` (so the URL becomes
   `/sap/bc/zfg_wo_appr_teams/callback`).
4. Right-click → **Activate** the whole subtree.

> Test connectivity with **SICF → Test Service** before going further.

---

## 16. Step 15 — SOAMANAGER / OAuth Configuration

1. **SOAMANAGER** → **OAuth 2.0 Client Profiles** → Create.

| Field | Value |
| --- | --- |
| Profile name | `ZOA2C_MS_FLOW` |
| Authorization endpoint | `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token` |
| Grant type | Client credentials |
| Scope | `https://service.flow.microsoft.com/.default` |
| Client-ID | from Azure App Registration |
| Client-Secret | stored in STRUST / SSF |

2. **STRUST** → import the Microsoft public certificate chain into
   *SSL Client (Anonymous)* PSE.

3. **PFCG** → role `Z_WO_APPR_API` — only `S_ICF` for the SICF node and
   `S_RFC` for FG `ZFG_WO_APPR_TEAMS`. No `SAP_ALL`.

---

## 17. Step 16 — TVARVC + IP Whitelist Population

### 17.1 TVARVC (transaction STVARV)

| Name | Type | Value |
| --- | --- | --- |
| `Z_WO_APPR_APIM_URL` | P | `https://aut-sap-apim.azure-api.net/wo-approval/teams-trigger` |
| `Z_WO_APPR_APIM_KEY` | P | subscription key (DEV) |
| `Z_WO_APPR_FLOW_URL` | P | *(only for direct-to-Flow fallback)* |

> Secrets that must NOT live in TVARVC (HMAC secret, client secret):
> store them in STRUST or SSF and read at runtime.

### 17.2 IP Whitelist `ZHTTP_IP_AUTH` (SM30)

Maintain one row per APIM outbound IP range:

| CLASS_NAME | IP_LOW | IP_HIGH | ACTIVE | DESCRIPTION |
| --- | --- | --- | --- | --- |
| `ZCL_WO_APPR_TEAMS_HTTP` | `13.66.140.0` | `13.66.140.255` | `X` | Azure APIM SEA outbound |
| `ZCL_WO_APPR_TEAMS_HTTP` | `40.74.28.0` | `40.74.31.255` | `X` | Azure APIM SEA outbound |
| `ZCL_WO_APPR_TEAMS_HTTP` | `127.0.0.1` | `127.0.0.1` | `X` | Local Postman tests |

`ZCL_BASE_HTTP=>M_CHECK_IP_AUTH` consults this table on every callback.

---

## 18. Step 17 — Hook into Existing Screen 0300 (`ZFG_WO_APPROVAL`)

### 18.1 GUI Status `ZSTAT_0300`

Add toolbar entry next to the existing `&RAPR`:

| Function Code | Text | F-Key |
| --- | --- | --- |
| `&RTMS` | Remind via Teams | Shift+F7 |

### 18.2 PAI `USER_COMMAND_0300`

```abap
CASE save_ok.
  ...
  WHEN '&RAPR'.
    PERFORM reset_approval_items.
  WHEN '&RTMS'.                       "<-- NEW
    PERFORM remind_items_via_teams.
  WHEN 'SAVE'.
    PERFORM save_approval.
ENDCASE.
```

### 18.3 New FORM in `LZFG_WO_APPROVALF01`

```abap
FORM remind_items_via_teams.
  DATA: lt_items TYPE zcl_wo_appr_teams_handler=>tt_appr_line.

  LOOP AT gt_items_tc INTO gs_items_tc WHERE mark = abap_true.
    APPEND VALUE #(
      aufnr       = gs_items_tc-aufnr
      posnr       = gs_items_tc-rspos
      werks       = gs_items_tc-werks
      description = gs_items_tc-maktx
      qty         = gs_items_tc-bdmng
      uom         = gs_items_tc-meins ) TO lt_items.
  ENDLOOP.

  IF lt_items IS INITIAL.
    MESSAGE 'Select at least one item before sending Teams reminder' TYPE 'I'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'
    EXPORTING it_items     = lt_items
    IMPORTING ev_req_id    = DATA(lv_req)
              ev_http_code = DATA(lv_code)
    EXCEPTIONS http_error    = 1
               auth_error    = 2
               payload_empty = 3.

  IF sy-subrc = 0.
    MESSAGE |Teams approval { lv_req } sent ({ lv_code })| TYPE 'S'.
  ELSE.
    MESSAGE 'Failed to trigger Teams approval' TYPE 'E'.
  ENDIF.
ENDFORM.
```

> This is the **only** change to the existing function group. Activate the
> include and re-generate the screens.

---

## 19. Step 18 — End-to-End Test Plan

| # | Test | Tool | Expected |
| - | --- | --- | --- |
| 1 | `ZCL_BASE_HTTP=>M_CHECK_IP_AUTH` matches localhost | SE24 unit test | `e_error = ''` |
| 2 | Manual ICF call from Postman with whitelisted IP | Postman | HTTP 200, `{"msgty":"S",...}` |
| 3 | Same call from blacklisted IP | Postman | HTTP 400, `{"msgty":"E","message":"IP not authorized"}` |
| 4 | Wrong HMAC signature | Postman | HTTP 400, `Bad HMAC signature` |
| 5 | Empty body | Postman | HTTP 400, `Request body is empty` |
| 6 | Malformed JSON | Postman | HTTP 400, CX_ROOT message in body |
| 7 | Click `&RTMS` in Screen 0300 with 1 item | ZWOAPP | FM returns 200/202; row in `ZTWO_APPR_TMS-TEAMS_STATUS = SENT` |
| 8 | Approve in Teams within SLA | Teams | `APPR_VALID = X`, `TEAMS_STATUS = APPROVED` |
| 9 | All items of WO `4711` approved | DB check | `Z_WO_APPR_AUTO_RELEASE` released order 4711 |
| 10 | One item rejected | Teams | `APPR_VALID = R`, no release |
| 11 | Power Automate retries same `request_id` | Flow | Idempotent — only one row updated in `ZTWO_APPR_TMS`; distinct `LOG_ID` rows in `ZTWO_APPR_TMSH` |
| 12 | Timeout after 24h | Flow | `TEAMS_STATUS = TIMEOUT`, no release |

### 19.1 Postman example

```bash
curl -X POST https://aut-sap-apim.azure-api.net/wo-approval/callback \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: <key>" \
  -H "X-Flow-Signature: <base64 HMAC SHA256>" \
  -d '{
    "request_id": "PING-001",
    "decision":   "APPROVED",
    "user":       "alice@unitedtractors.com",
    "items": [ { "wo": "4711", "pos": "10", "werks": "1000" } ]
  }'
```

Expected response:

```json
{ "msgty": "S", "message": "Approved and order released" }
```

---

## 20. Step 19 — APIM / Production Hardening

Follow [`ENHANCEMENT2.md` Part 2](./ENHANCEMENT2.md#part-2--azure-api-management--gateway-for-sap-ztest_ass--zfg_wo_appr_teams)
to put Azure APIM in front of SAP:

- `aut-sap-apim` instance with `Developer` SKU (DEV) / `Standard v2` (PRD).
- Backend `sap-dev-zfg-wo-appr` with Basic auth from Key Vault.
- API `wo-approval` with operations `/callback`, `/test-callback`, `/health`,
  `/teams-trigger`.
- Global policy: rate-limit (60/min), quota (10 000/day), IP allow-list,
  `check-header` for subscription key.
- Operation policy on `/callback`: HMAC verify, `set-backend-service`,
  `rewrite-uri` to `/sap/bc/zfg_wo_appr_teams/callback?sap-client=030`.
- Product `WO Approval Consumers` with per-consumer subscription keys.

The SAP-side code in this guide is already APIM-aware:
`ZCL_WO_APPR_TEAMS_HANDLER->send_approval` sends the
`Ocp-Apim-Subscription-Key` header on every outbound call, and
`ZHTTP_IP_AUTH` for `ZCL_WO_APPR_TEAMS_HTTP` should be restricted to APIM's
outbound IPs only — direct internet calls will be rejected at Phase 2.

---

## 21. Appendix A — Object Catalog

| Object | Type | Package | Purpose |
| --- | --- | --- | --- |
| `ZTWO_APPR_TMS` | Table | `ZWO_APPROVAL_TEAMS` | Teams approval state |
| `ZTWO_APPR_TMSH` | Table | `ZWO_APPROVAL_TEAMS` | Audit history |
| `ZHTTP_IP_AUTH` | Table | `ZWO_APPROVAL_TEAMS` | IP whitelist |
| `ZV_WO_APPR_FULL` | View | `ZWO_APPROVAL_TEAMS` | Reporting (optional) |
| `ZCX_WO_APPR_TEAMS_HTTP` | Class | `ZWO_APPROVAL_TEAMS` | HTTP exception |
| `ZCX_WO_APPR_TEAMS_AUTH` | Class | `ZWO_APPROVAL_TEAMS` | Auth exception |
| `ZCL_BASE_HTTP` | Class | `ZWO_APPROVAL_TEAMS` | Reusable base — IP / JSON / response |
| `ZCL_WO_APPR_TEAMS_HANDLER` | Class | `ZWO_APPROVAL_TEAMS` | Outbound caller (SAP → APIM) |
| `ZCL_WO_APPR_TEAMS_HTTP` | Class | `ZWO_APPROVAL_TEAMS` | Inbound `IF_HTTP_EXTENSION` |
| `ZFG_WO_APPR_TEAMS` | FG | `ZWO_APPROVAL_TEAMS` | 6 function modules |
| `Z_WO_APPR_TEAMS_SEND` | FM | `ZFG_WO_APPR_TEAMS` | Outbound entry point |
| `Z_WO_APPR_TEAMS_CALLBACK` | FM | `ZFG_WO_APPR_TEAMS` | Inbound orchestrator |
| `Z_WO_APPR_FLAG_UPDATE` | FM | `ZFG_WO_APPR_TEAMS` | Single-item tracker write |
| `Z_WO_APPR_CHECK_COMPLETE` | FM | `ZFG_WO_APPR_TEAMS` | All-items-approved check |
| `Z_WO_APPR_AUTO_RELEASE` | FM | `ZFG_WO_APPR_TEAMS` | BAPI release |
| `Z_WO_APPR_TEAMS_LOG` | FM | `ZFG_WO_APPR_TEAMS` | Audit row writer |
| `/sap/bc/zfg_wo_appr_teams/callback` | SICF | — | Callback URL |
| `ZOA2C_MS_FLOW` | OAuth profile | SOAMANAGER | Outbound bearer token |
| `Z_WO_APPR_APIM_URL` | TVARVC | — | APIM endpoint URL |
| `Z_WO_APPR_APIM_KEY` | TVARVC | — | Subscription key |
| `Z_WO_APPR_API` | PFCG role | — | Service-user authorisation |

---

## 22. Appendix B — Reusable HTTP Skeleton Reference

The pattern in `ZCL_WO_APPR_TEAMS_HTTP` is the same one you can copy for any
future external JSON callback (webhook receiver, mobile app endpoint, etc.).
Only `process_request` changes per use case.

```
START
  │
  ▼
  1. server->request->get_cdata( )         ← read body FIRST
  2. ZCL_BASE_HTTP->M_CHECK_IP_AUTH       ← reject untrusted IPs
  3. body not empty
  4. ZCL_BASE_HTTP->M_JSON_TO_ABAP        ← JSON → ABAP struct
  5. Validate mandatory fields
  6. process_request( … )                  ← YOUR BUSINESS LOGIC
  7. ZCL_BASE_HTTP->M_SET_RESPONSE        ← 200 / 400 + JSON body
```

Standard JSON response:

```json
{ "msgty": "S", "message": "..." }
```

| `msgty` | Meaning | HTTP status |
| --- | --- | --- |
| `S` | Success | 200 |
| `E` | Error | 400 |

To create a new handler:

1. Copy `ZCL_WO_APPR_TEAMS_HTTP` and rename the class.
2. Replace the `ty_callback` types with your own payload structure.
3. Replace `process_request` with your business logic (call your own FM).
4. Add a new row in `ZHTTP_IP_AUTH` for the new class name.
5. Create a new SICF node bound to the new handler class.

The base class (`ZCL_BASE_HTTP`) is reused **as-is** — no copy needed.

---

*Implementation guide built on top of `ENHANCEMENT2.md` (design) and
`SAP_HTTP_Handler_Documentation.md` (reusable HTTP handler pattern).*
