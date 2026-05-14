# ENHANCEMENT2 — Teams / Power Automate Approval & Auto-Release + Azure APIM Gateway

> Combined design specification for the next evolution of `SAPMZWO_APPROVAL`
> (Tx `ZWOAPP`). This single document supersedes the separate working drafts:
>
> * Part 1 — ZFG_WO_APPR_TEAMS (ABAP function group, tables, classes, Power Automate flow)
> * Part 2 — Azure API Management gateway between Power Automate and SAP
>
> **Plant-aware approver routing** is included in Part 1 — every payload carries
> `WERKS`, and Power Automate maps plant → approver email.

---
---

# PART 1 — ZFG_WO_APPR_TEAMS — Teams/Power Automate Approval & Auto-Release Enhancement

**Parent program:** `SAPMZWO_APPROVAL` (Function Group `ZFG_WO_APPROVAL`, Tx `ZWOAPP`)
**New function group:** `ZFG_WO_APPR_TEAMS`
**Status:** Design specification (v1.0)
**Trigger button on Screen 0300:** `&RTMS` — *Remind via Teams* (placed next to existing `&RAPR`)

---

## 1. End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  HELPDESK (Screen 0300 — ZWOAPP)                                            │
│  1. Selects line(s) in gt_items_tc with appr_flag = '' / appr_valid = ''    │
│  2. Clicks toolbar button &RTMS  ──►  PAI USER_COMMAND_0300                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FORM remind_items_via_teams  (in 7. includes / LZFG_WO_APPROVALF01)        │
│      └── CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Z_WO_APPR_TEAMS_SEND  (FM in ZFG_WO_APPR_TEAMS)                            │
│      └── ZCL_WO_APPR_TEAMS_HANDLER=>SEND_APPROVAL                           │
│            ├── Build JSON payload (DTO)                                     │
│            ├── OAuth2 token from OAUTH 2.0 Client (SOAMANAGER)              │
│            └── HTTP POST → MS Power Automate Flow URL                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  POWER AUTOMATE (cloud)                                                     │
│  Trigger: "When an HTTP request is received"                                │
│      ├── Action: "Start and wait for an approval (Teams Adaptive Card)"     │
│      ├── Sent to: assignee@company.com  (resolved per WERKS)                │
│      └── Result: Approve / Reject / TimeOut                                 │
│  Then:  HTTP POST → SAP SICF endpoint                                       │
│         /sap/bc/zfg_wo_appr_teams/callback                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SICF Service: ZFG_WO_APPR_TEAMS_CB  (handler ZCL_WO_APPR_TEAMS_HTTP)       │
│      ├── Verify HMAC signature / shared secret                              │
│      └── CALL FUNCTION 'Z_WO_APPR_TEAMS_CALLBACK'                           │
│             ├── Z_WO_APPR_FLAG_UPDATE   (ZTWO_APPR_TMS-APPR_VALID = 'X')    │
│             ├── Z_WO_APPR_TEAMS_LOG     (audit row in ZTWO_APPR_TMSH)       │
│             └── Z_WO_APPR_CHECK_COMPLETE  (all items per WO = 'X' ?)        │
│                    └── if YES → Z_WO_APPR_AUTO_RELEASE  (BAPI release)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. New Tables (ZTWOAPPR is **NOT** modified)

> **Constraint:** the existing `ZTWOAPPR` and `ZTWOAPPRH` are read-only for this
> enhancement. All Teams-approval state lives in **two new transparent tables**
> linked back to `ZTWOAPPR` only by the natural key `AUFNR + POSNR`.
> No append structure, no field added, no existing program touched on the data side.

### 2.1 `ZTWO_APPR_TMS` — Teams approval status (one row per item per request)

| Field           | Key | Type / Domain | Description                                  |
| --------------- | --- | ------------- | -------------------------------------------- |
| `MANDT`         | ✔   | MANDT         | Client                                       |
| `AUFNR`         | ✔   | AUFNR         | Work order (matches `ZTWOAPPR-AUFNR`)        |
| `POSNR`         | ✔   | POSNR         | Item     (matches `ZTWOAPPR-POSNR`)          |
| `TEAMS_REQ_ID`  | ✔   | CHAR32        | MS Flow run-id / correlation id              |
| `APPR_VALID`    |     | CHAR1         | `'X'` = approved, `'R'` = rejected, `' '`    |
| `TEAMS_STATUS`  |     | CHAR10        | `SENT / APPROVED / REJECTED / TIMEOUT`       |
| `WERKS`         |     | WERKS_D       | Plant — used by MS Flow to look up approver  |
| `APPR_USER`     |     | SYUNAME       | Approver SAP / AAD user that responded       |
| `APPR_DATE`     |     | DATS          | Approval date                                |
| `APPR_TIME`     |     | TIMS          | Approval time                                |
| `SENT_BY`       |     | SYUNAME       | Helpdesk user who pressed `&RTMS`            |
| `SENT_AT`       |     | TIMESTAMPL    | When the request was sent                    |
| `LAST_UPDATED`  |     | TIMESTAMPL    | Last status change                           |

* Delivery class **A**, Display/Maintenance **`X` (display/maintenance allowed)**
* Secondary index on `TEAMS_REQ_ID`
* Foreign key from `(AUFNR, POSNR)` → `ZTWOAPPR` (read-only check)

### 2.2 `ZTWO_APPR_TMSH` — full audit history (append-only event log)

| Field          | Key | Type / Domain | Description                                  |
| -------------- | --- | ------------- | -------------------------------------------- |
| `MANDT`        | ✔   | MANDT         | Client                                       |
| `LOG_ID`       | ✔   | SYSUUID_X16   | GUID — generated on each event               |
| `TEAMS_REQ_ID` |     | CHAR32        | Correlation id                               |
| `AUFNR`        |     | AUFNR         | Work order                                   |
| `POSNR`        |     | POSNR         | Item                                         |
| `EVENT_TYPE`   |     | CHAR10        | `SEND / APPROVE / REJECT / TIMEOUT / RELEASE / ERROR` |
| `EVENT_USER`   |     | SYUNAME       | User that triggered the event                |
| `EVENT_TS`     |     | TIMESTAMPL    | UTC timestamp                                |
| `HTTP_CODE`    |     | INT4          | Last HTTP status (when applicable)           |
| `MESSAGE`      |     | STRING        | Free text / error                            |
| `PAYLOAD`      |     | STRING        | Optional raw JSON for forensics              |

> Both tables sit in package `ZWO_APPROVAL_TEAMS` and travel in their own
> transport, so the original `ZTWOAPPR` / `ZTWOAPPRH` packages are not even
> opened.

### 2.3 Optional read-only view `ZV_WO_APPR_FULL`

To make UI / reporting easy, create a CDS or DDIC view that left-joins
`ZTWOAPPR` with `ZTWO_APPR_TMS` on `(AUFNR, POSNR)` and exposes the latest
Teams status without writing into `ZTWOAPPR`.

```abap
@AbapCatalog.sqlViewName: 'ZVWOAPPRFULL'
define view ZV_WO_APPR_FULL as
  select from ztwoappr as h
    left outer join ztwo_appr_tms as t
      on  h.aufnr = t.aufnr
      and h.posnr = t.posnr
{
  key h.aufnr,
  key h.posnr,
      h.appr_flag,
      h.reason_code,
      t.appr_valid,
      t.teams_status,
      t.teams_req_id,
      t.appr_user,
      t.appr_date
}
```

---

## 3. New Function Group: `ZFG_WO_APPR_TEAMS`

Created via **SE80 → Function Group → Create**.
Top include `LZFG_WO_APPR_TEAMSTOP`:

```abap
FUNCTION-POOL zfg_wo_appr_teams.

TYPES: BEGIN OF ty_appr_line,
         aufnr        TYPE aufnr,
         posnr        TYPE posnr,
         werks        TYPE werks_d,       " plant — drives approver routing in MS Flow
         description  TYPE string,
         qty          TYPE menge_d,
         uom          TYPE meins,
       END OF ty_appr_line,
       tt_appr_line TYPE STANDARD TABLE OF ty_appr_line WITH DEFAULT KEY.

CONSTANTS:
  c_status_sent     TYPE char10 VALUE 'SENT',
  c_status_approved TYPE char10 VALUE 'APPROVED',
  c_status_rejected TYPE char10 VALUE 'REJECTED',
  c_status_timeout  TYPE char10 VALUE 'TIMEOUT',
  c_flag_x          TYPE char1  VALUE 'X'.
```

### 3.1 Function modules in this group

| FM                              | Purpose                                                   |
| ------------------------------- | --------------------------------------------------------- |
| `Z_WO_APPR_TEAMS_SEND`          | Send selected items to MS Power Automate                  |
| `Z_WO_APPR_TEAMS_CALLBACK`      | Receive Power Automate callback, orchestrate update flow  |
| `Z_WO_APPR_FLAG_UPDATE`         | Set `APPR_VALID = 'X'` (or 'R') for one item              |
| `Z_WO_APPR_CHECK_COMPLETE`      | Return `EV_ALL_DONE = 'X'` if every item of WO is 'X'     |
| `Z_WO_APPR_AUTO_RELEASE`        | BAPI release the work order(s) when complete              |
| `Z_WO_APPR_TEAMS_LOG`           | Append row in `ZTWO_APPR_TMSH` (audit trail)              |

---

## 4. Function Module Source (skeletons)

### 4.1 `Z_WO_APPR_TEAMS_SEND` — fire MS Flow

```abap
FUNCTION z_wo_appr_teams_send.
*"--------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"    VALUE(IT_ITEMS) TYPE  TT_APPR_LINE
*"    VALUE(IV_REQUESTOR) TYPE SYUNAME DEFAULT SY-UNAME
*"  EXPORTING
*"    VALUE(EV_REQ_ID) TYPE CHAR32
*"    VALUE(EV_HTTP_CODE) TYPE I
*"  EXCEPTIONS
*"    HTTP_ERROR
*"    AUTH_ERROR
*"    PAYLOAD_EMPTY
*"--------------------------------------------------------------------
  IF it_items IS INITIAL.
    RAISE payload_empty.
  ENDIF.

  DATA(lo_handler) = NEW zcl_wo_appr_teams_handler( ).

  TRY.
      lo_handler->send_approval(
        EXPORTING
          it_items     = it_items
          iv_requestor = iv_requestor
        IMPORTING
          ev_req_id    = ev_req_id
          ev_http_code = ev_http_code ).
    CATCH zcx_wo_appr_teams_auth.
      RAISE auth_error.
    CATCH zcx_wo_appr_teams_http.
      RAISE http_error.
  ENDTRY.

  " Insert / refresh row in the dedicated tracking table (ZTWOAPPR untouched)
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

  MODIFY ztwo_appr_tms FROM TABLE lt_tms.        " upsert by full key

  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING iv_event    = 'SEND'
              iv_req_id   = ev_req_id
              iv_user     = iv_requestor
              iv_http_code = ev_http_code
              it_items    = it_items.

  COMMIT WORK.
ENDFUNCTION.
```

### 4.2 `Z_WO_APPR_TEAMS_CALLBACK` — orchestrator

```abap
FUNCTION z_wo_appr_teams_callback.
*"--------------------------------------------------------------------
*"  IMPORTING
*"    VALUE(IV_REQ_ID)   TYPE CHAR32
*"    VALUE(IV_DECISION) TYPE CHAR10        " APPROVED / REJECTED
*"    VALUE(IV_USER)     TYPE SYUNAME
*"    VALUE(IT_ITEMS)    TYPE TT_APPR_LINE
*"  EXPORTING
*"    VALUE(EV_RELEASED) TYPE FLAG
*"  EXCEPTIONS
*"    UPDATE_FAILED
*"    RELEASE_FAILED
*"--------------------------------------------------------------------
  DATA: lv_all_done TYPE flag,
        lv_flag     TYPE char1,
        lt_aufnr    TYPE STANDARD TABLE OF aufnr.

  lv_flag = COND #( WHEN iv_decision = c_status_approved THEN c_flag_x ELSE 'R' ).

  LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
    CALL FUNCTION 'Z_WO_APPR_FLAG_UPDATE'
      EXPORTING
        iv_aufnr  = <ls>-aufnr
        iv_posnr  = <ls>-posnr
        iv_flag   = lv_flag
        iv_user   = iv_user
        iv_req_id = iv_req_id
      EXCEPTIONS
        update_failed = 1
        OTHERS        = 2.
    IF sy-subrc <> 0. RAISE update_failed. ENDIF.

    COLLECT <ls>-aufnr INTO lt_aufnr.
  ENDLOOP.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING
      iv_req_id   = iv_req_id
      iv_decision = iv_decision
      iv_user     = iv_user
      it_items    = it_items.

  " Trigger auto-release per WO when 100 % approved
  IF iv_decision = c_status_approved.
    LOOP AT lt_aufnr INTO DATA(lv_aufnr).
      CALL FUNCTION 'Z_WO_APPR_CHECK_COMPLETE'
        EXPORTING  iv_aufnr   = lv_aufnr
        IMPORTING  ev_all_done = lv_all_done.

      IF lv_all_done = c_flag_x.
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

### 4.3 `Z_WO_APPR_FLAG_UPDATE` — writes to `ZTWO_APPR_TMS` only

```abap
FUNCTION z_wo_appr_flag_update.
*"  IMPORTING IV_AUFNR IV_POSNR IV_FLAG IV_USER IV_REQ_ID
*"  EXCEPTIONS UPDATE_FAILED
  GET TIME STAMP FIELD DATA(lv_now).

  UPDATE ztwo_appr_tms
     SET appr_valid   = iv_flag
         appr_user    = iv_user
         appr_date    = sy-datum
         appr_time    = sy-uzeit
         teams_status = COND #( WHEN iv_flag = 'X' THEN 'APPROVED' ELSE 'REJECTED' )
         last_updated = lv_now
   WHERE aufnr        = iv_aufnr
     AND posnr        = iv_posnr
     AND teams_req_id = iv_req_id.
  IF sy-subrc <> 0. RAISE update_failed. ENDIF.
  " NOTE: ZTWOAPPR is intentionally NOT written here.
ENDFUNCTION.
```

### 4.4 `Z_WO_APPR_CHECK_COMPLETE` — joins ZTWOAPPR (item universe) with ZTWO_APPR_TMS

The "100 % approved" check looks at the *item universe* still living in
`ZTWOAPPR` (read-only), and counts how many of those items have a matching
`APPR_VALID = 'X'` row in our new tracker table.

```abap
FUNCTION z_wo_appr_check_complete.
*"  IMPORTING IV_AUFNR
*"  EXPORTING EV_ALL_DONE TYPE FLAG

  DATA: lv_total TYPE i,
        lv_done  TYPE i.

  " 1) Total approvable items for this WO (from the existing read-only table)
  SELECT COUNT(*) FROM ztwoappr
     WHERE aufnr = @iv_aufnr
     INTO @lv_total.

  " 2) Items that already received APPR_VALID = 'X' from Teams
  SELECT COUNT(*) FROM ztwoappr  AS h
       INNER JOIN ztwo_appr_tms AS t
         ON  h~aufnr = t~aufnr
         AND h~posnr = t~posnr
     WHERE h~aufnr      = @iv_aufnr
       AND t~appr_valid = 'X'
     INTO @lv_done.

  ev_all_done = COND #( WHEN lv_total > 0 AND lv_total = lv_done
                        THEN 'X' ELSE space ).
ENDFUNCTION.
```

### 4.5 `Z_WO_APPR_AUTO_RELEASE` — BAPI release

> Reuses the same BAPI calls used by program **`ZR_*` / `RIAFVX_RELEASE`** in
> `2. Function_Group/8. Function Modules` of the existing repo.

```abap
FUNCTION z_wo_appr_auto_release.
*"  IMPORTING IV_AUFNR
*"  EXCEPTIONS RELEASE_FAILED
  DATA: lt_return  TYPE STANDARD TABLE OF bapiret2,
        lt_methods TYPE STANDARD TABLE OF bapi_alm_order_method,
        ls_method  LIKE LINE OF lt_methods,
        ls_header  TYPE bapi_alm_order_headers_i.

  ls_method-refnumber = '000001'.
  ls_method-objecttype = 'HEADER'.
  ls_method-method     = 'RELEASE'.
  ls_method-objectkey  = iv_aufnr.
  APPEND ls_method TO lt_methods.

  ls_method-method = 'SAVE'.
  CLEAR ls_method-objectkey.
  APPEND ls_method TO lt_methods.

  ls_header-orderid = iv_aufnr.

  CALL FUNCTION 'BAPI_ALM_ORDER_MAINTAIN'
    TABLES
      it_methods = lt_methods
      it_header  = VALUE #( ( ls_header ) )
      return     = lt_return.

  IF line_exists( lt_return[ type = 'E' ] )
  OR line_exists( lt_return[ type = 'A' ] ).
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    RAISE release_failed.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

  " Audit only — never touch ZTWOAPPRH
  CALL FUNCTION 'Z_WO_APPR_TEAMS_LOG'
    EXPORTING iv_event   = 'RELEASE'
              iv_req_id  = space
              iv_user    = sy-uname
              it_items   = VALUE #( ( aufnr = iv_aufnr posnr = '0000' ) ).
ENDFUNCTION.
```

### 4.6 `Z_WO_APPR_TEAMS_LOG` — writes to `ZTWO_APPR_TMSH` only

```abap
FUNCTION z_wo_appr_teams_log.
*"  IMPORTING
*"    VALUE(IV_EVENT)     TYPE CHAR10           " SEND/APPROVE/REJECT/...
*"    VALUE(IV_REQ_ID)    TYPE CHAR32 OPTIONAL
*"    VALUE(IV_USER)      TYPE SYUNAME DEFAULT SY-UNAME
*"    VALUE(IV_HTTP_CODE) TYPE I OPTIONAL
*"    VALUE(IV_MESSAGE)   TYPE STRING OPTIONAL
*"    VALUE(IV_PAYLOAD)   TYPE STRING OPTIONAL
*"    VALUE(IT_ITEMS)     TYPE TT_APPR_LINE OPTIONAL
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

---

## 5. Class Handler — `ZCL_WO_APPR_TEAMS_HANDLER`

ABAP OO class created in **SE24 / SE80**. It hides all HTTP/JSON/OAuth2 glue
from the function modules.

### 5.1 Public interface

```abap
CLASS zcl_wo_appr_teams_handler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS:
      constructor,

      send_approval
        IMPORTING it_items     TYPE tt_appr_line
                  iv_requestor TYPE syuname
        EXPORTING ev_req_id    TYPE char32
                  ev_http_code TYPE i
        RAISING   zcx_wo_appr_teams_http
                  zcx_wo_appr_teams_auth,

      verify_callback_signature
        IMPORTING iv_body      TYPE xstring
                  iv_signature TYPE string
        RETURNING VALUE(rv_ok) TYPE abap_bool.

  PRIVATE SECTION.
    DATA:
      mv_flow_url   TYPE string,
      mv_secret     TYPE xstring,
      mo_http       TYPE REF TO if_http_client.

    METHODS:
      get_oauth_token RETURNING VALUE(rv_token) TYPE string
                      RAISING   zcx_wo_appr_teams_auth,

      build_payload   IMPORTING it_items   TYPE tt_appr_line
                                iv_req_id  TYPE char32
                                iv_user    TYPE syuname
                      RETURNING VALUE(rv_json) TYPE string,

      load_config.
ENDCLASS.
```

### 5.2 Implementation highlights

```abap
CLASS zcl_wo_appr_teams_handler IMPLEMENTATION.

  METHOD constructor.
    load_config( ).        " reads URL + secret from TVARVC / RFC dest
  ENDMETHOD.

  METHOD send_approval.

    DATA(lv_req_id) = cl_system_uuid=>create_uuid_c32_static( ).
    DATA(lv_token)  = get_oauth_token( ).
    DATA(lv_body)   = build_payload(
                        it_items  = it_items
                        iv_req_id = lv_req_id
                        iv_user   = iv_requestor ).

    cl_http_client=>create_by_url(
      EXPORTING url = mv_flow_url IMPORTING client = mo_http ).

    mo_http->request->set_method( if_http_request=>co_request_method_post ).
    mo_http->request->set_header_field( name  = 'Content-Type'
                                        value = 'application/json' ).
    mo_http->request->set_header_field( name  = 'Authorization'
                                        value = |Bearer { lv_token }| ).
    mo_http->request->set_header_field( name  = 'X-SAP-Req-Id'
                                        value = lv_req_id ).
    mo_http->request->set_cdata( lv_body ).

    mo_http->send( ).
    mo_http->receive( ).

    mo_http->response->get_status( IMPORTING code = ev_http_code ).
    IF ev_http_code <> 200 AND ev_http_code <> 202.
      RAISE EXCEPTION TYPE zcx_wo_appr_teams_http
        EXPORTING http_code = ev_http_code.
    ENDIF.

    ev_req_id = lv_req_id.
    mo_http->close( ).
  ENDMETHOD.

  METHOD build_payload.
    DATA(lo_w) = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).
    " Use /UI2/CL_JSON or cl_abap_json_serializer instead for production
    rv_json =
      |\{ "request_id":"{ iv_req_id }",| &&
      | "requestor":"{ iv_user }",|     &&
      | "items":[ |.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls>).
      rv_json = rv_json &&
        |\{ "wo":"{ <ls>-aufnr }",|         &&
        |  "pos":"{ <ls>-posnr }",|         &&
        |  "werks":"{ <ls>-werks }",|       && " plant → MS Flow looks up approver email
        |  "desc":"{ <ls>-description }",|  &&
        |  "qty":"{ <ls>-qty }",|           &&
        |  "uom":"{ <ls>-uom }" \}|.
      IF sy-tabix < lines( it_items ). rv_json = rv_json && |, |. ENDIF.
    ENDLOOP.
    rv_json = rv_json && | ] \}|.
  ENDMETHOD.

  METHOD verify_callback_signature.
    " HMAC-SHA256 over body, compare with header X-Flow-Signature
    DATA(lv_calc) = cl_abap_hmac=>calculate_hmac_for_raw(
                      if_algorithm  = 'SHA256'
                      if_key        = mv_secret
                      if_data       = iv_body )-hmacstring.
    rv_ok = xsdbool( to_upper( lv_calc ) = to_upper( iv_signature ) ).
  ENDMETHOD.

  METHOD get_oauth_token.
    " Use OA2C_GRANT or wrapper of cl_oauth2_client to fetch access token.
    " Configure OAuth 2.0 Client Profile in SOAMANAGER:
    "   Profile  : ZOA2C_MS_FLOW
    "   Grant    : Client Credentials
    "   Scope    : https://service.flow.microsoft.com/.default
    DATA: lo_oauth TYPE REF TO if_oauth2_client.
    " ... (acquire token, return rv_token)
  ENDMETHOD.

  METHOD load_config.
    SELECT SINGLE low FROM tvarvc INTO @mv_flow_url
      WHERE name = 'Z_WO_APPR_FLOW_URL' AND type = 'P'.
    " mv_secret loaded from STRUST or SSF storage; never hard-code
  ENDMETHOD.

ENDCLASS.
```

### 5.3 Custom exception classes

```abap
CLASS zcx_wo_appr_teams_http DEFINITION INHERITING FROM cx_static_check
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA http_code TYPE i.
    METHODS constructor IMPORTING http_code TYPE i OPTIONAL.
ENDCLASS.

CLASS zcx_wo_appr_teams_auth DEFINITION INHERITING FROM cx_static_check
  PUBLIC FINAL CREATE PUBLIC.
ENDCLASS.
```

### 5.4 Inbound HTTP handler — `ZCL_WO_APPR_TEAMS_HTTP`

Bound to SICF service `/sap/bc/zfg_wo_appr_teams/callback`.

```abap
CLASS zcl_wo_appr_teams_http DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
ENDCLASS.

CLASS zcl_wo_appr_teams_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA(lv_body)  = server->request->get_data( ).
    DATA(lv_sig)   = server->request->get_header_field( 'X-Flow-Signature' ).

    DATA(lo_h) = NEW zcl_wo_appr_teams_handler( ).
    IF lo_h->verify_callback_signature(
         iv_body = lv_body  iv_signature = lv_sig ) = abap_false.
      server->response->set_status( code = 401 reason = 'Bad signature' ).
      RETURN.
    ENDIF.

    " /UI2/CL_JSON=>deserialize( EXPORTING json = lv_body
    "                            CHANGING data = ls_payload ).
    DATA: ls_payload TYPE zwo_appr_callback_dto.    " your DDIC structure

    CALL FUNCTION 'Z_WO_APPR_TEAMS_CALLBACK'
      EXPORTING iv_req_id   = ls_payload-request_id
                iv_decision = ls_payload-decision
                iv_user     = ls_payload-user
                it_items    = ls_payload-items
      EXCEPTIONS update_failed = 1
                 release_failed = 2
                 OTHERS         = 3.

    IF sy-subrc = 0.
      server->response->set_status( code = 200 reason = 'OK' ).
    ELSE.
      server->response->set_status( code = 500 reason = 'SAP error' ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
```

---

## 6. Hook into existing Screen 0300

### 6.1 GUI Status `ZSTAT_0300` — add new button

```text
Application Toolbar:
  &EXEC  — [Execute]                F8
  &SALL  — [Select All]             Shift+F3
  &APPR  — [Approve]                Shift+F1
  &RJCT  — [Reject]                 Shift+F2
  &RSET  — [Reset Reason]           Shift+F4
  &RAPR  — [Reset Approval]         Shift+F6
  &RTMS  — [Remind via Teams]       Shift+F7   <-- NEW
  &SAVE  — [Save]                   Ctrl+S
```

### 6.2 PAI module `USER_COMMAND_0300` — add WHEN block

```abap
CASE save_ok.
  ...
  WHEN '&RAPR'.
    PERFORM reset_approval_items.
  WHEN '&RTMS'.                    "<-- NEW
    PERFORM remind_items_via_teams.
  WHEN 'SAVE'.
    PERFORM save_approval.
  ...
ENDCASE.
```

### 6.3 New FORM in `7. includes/LZFG_WO_APPROVALF01`

```abap
FORM remind_items_via_teams.
  DATA: lt_items TYPE zfg_wo_appr_teams=>tt_appr_line.

  LOOP AT gt_items_tc INTO gs_items_tc WHERE selected = abap_true.
    APPEND VALUE #(
      aufnr        = gs_items_tc-aufnr
      posnr        = gs_items_tc-posnr
      werks        = gs_items_tc-werks      " plant drives Teams routing
      description  = gs_items_tc-matxt
      qty          = gs_items_tc-bdmng
      uom          = gs_items_tc-meins )
      TO lt_items.
  ENDLOOP.

  IF lt_items IS INITIAL.
    MESSAGE 'Select at least one item to send the Teams reminder' TYPE 'I'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'
    EXPORTING it_items   = lt_items
    IMPORTING ev_req_id  = DATA(lv_req)
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

---

## 7. SICF Configuration

| Setting             | Value                                                             |
| ------------------- | ----------------------------------------------------------------- |
| Service path        | `/sap/bc/zfg_wo_appr_teams/callback`                              |
| Handler             | `ZCL_WO_APPR_TEAMS_HTTP`                                          |
| Logon procedure     | Alternative — Required + Standard (Basic via tech. user)          |
| Service user        | `WF_BATCH` or dedicated `TEAMS_API` (only object S_RFC + Z_FM)    |
| SSL                 | Mandatory — terminate at WebDispatcher / API GW                   |

Activate with `SICF` → Right-click → Activate.

---

## 8. SOAMANAGER Configuration

1. **OAuth 2.0 Client Profile** `ZOA2C_MS_FLOW`
   * Authorization Server: `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token`
   * Grant type: `client_credentials`
   * Scope: `https://service.flow.microsoft.com/.default`
   * Client-ID / Secret: from Azure App Registration
2. **STRUST** — import the Microsoft public certificate chain into PSE
   `SSL Client (Anonymous)`.
3. **TVARVC** entry `Z_WO_APPR_FLOW_URL` (type `P`) →
   the *HTTP POST URL* of the Power Automate trigger (or the APIM URL — see Part 2).

---

## 9. MS Power Automate Flow (step-by-step)

> Tx: **make.powerautomate.com → New Flow → Automated cloud flow → blank**

### 9.1 Trigger

* **When an HTTP request is received**
* Request body JSON schema (paste the exact shape SAP sends — note `werks`):

```json
{
  "type": "object",
  "properties": {
    "request_id": { "type": "string" },
    "requestor":  { "type": "string" },
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "wo":    { "type": "string" },
          "pos":   { "type": "string" },
          "werks": { "type": "string" },
          "desc":  { "type": "string" },
          "qty":   { "type": "string" },
          "uom":   { "type": "string" }
        }
      }
    }
  }
}
```

### 9.2 Plant → approver mapping (inside the flow)

Add a **Compose** action `cmpPlantApproverMap` that holds the lookup table:

```json
{
  "1000": "alice@unitedtractors.com",
  "1100": "bob@unitedtractors.com",
  "1200": "charlie@unitedtractors.com",
  "1300": "dewi@unitedtractors.com",
  "9999": "fallback@unitedtractors.com"
}
```

> For larger plant lists keep this map in **SharePoint List** or **Dataverse**
> and replace `cmpPlantApproverMap` with a *Get items* on that list.

### 9.3 Action — *Apply to each item*

Inside the loop:

1. **Compose** `cmpApproverEmail` =
   `@{coalesce(outputs('cmpPlantApproverMap')[items('Apply')['werks']], outputs('cmpPlantApproverMap')['9999'])}`

2. **Start and wait for an approval** (Teams / Outlook connector)
   * Approval type: **Approve / Reject – First to respond**
   * Title:        `WO @{items('Apply')['wo']} pos @{items('Apply')['pos']} (Plant @{items('Apply')['werks']}) — Approval Required`
   * **Assigned to:**  `@{outputs('cmpApproverEmail')}`
   * Details (Markdown):
     ```
     **Work Order:** @{items('Apply')['wo']}
     **Item:**       @{items('Apply')['pos']} — @{items('Apply')['desc']}
     **Plant:**      @{items('Apply')['werks']}
     **Quantity:**   @{items('Apply')['qty']} @{items('Apply')['uom']}
     **Requested by:** @{triggerBody()['requestor']}
     ```

### 9.4 Compose the SAP callback payload

```json
{
  "request_id": "@{triggerBody()['request_id']}",
  "decision":   "@{outputs('Start_and_wait')?['body/outcome']}",
  "user":       "@{outputs('Start_and_wait')?['body/responses'][0]/responder/userPrincipalName}",
  "items": [
    {
      "wo":    "@{items('Apply')['wo']}",
      "pos":   "@{items('Apply')['pos']}",
      "werks": "@{items('Apply')['werks']}"
    }
  ]
}
```

### 9.5 Action — **HTTP POST → SAP** (direct) *or* **APIM** (recommended, see Part 2)

* URI:    `https://<sap-host>/sap/bc/zfg_wo_appr_teams/callback`
  *(or — preferred — `https://aut-sap-apim.azure-api.net/wo-approval/callback`)*
* Method: POST
* Headers:
  * `Content-Type: application/json`
  * `X-Flow-Signature: @{base64(hmacSha256(body, parameters('SAP_SECRET')))}`
  * *If APIM:* `Ocp-Apim-Subscription-Key: @{variables('varApimSubscriptionKey')}`
* Body: the JSON above
* Authentication: **Basic** (direct) *or* APIM handles it for you

### 9.6 Configure run-after for failures

Add a parallel branch on **failure** that posts to a Teams ops channel with
`@{actions('HTTP').outputs.statusCode}` and `request_id`.

---

## 10. MS Teams Adaptive Card (rendered automatically)

The **Start and wait for an approval** action renders an Adaptive Card on the
approver's personal **Approvals** app and as a chat message. No card JSON is
required unless you want a custom design — in that case use **Post adaptive
card and wait for a response** instead and embed:

```json
{
  "type": "AdaptiveCard",
  "version": "1.4",
  "body": [
    { "type": "TextBlock", "size": "Large", "weight": "Bolder",
      "text": "Work Order Approval Required" },
    { "type": "FactSet",
      "facts": [
        { "title": "WO #",     "value": "@{items('Apply')['wo']}" },
        { "title": "Item",     "value": "@{items('Apply')['pos']}" },
        { "title": "Plant",    "value": "@{items('Apply')['werks']}" },
        { "title": "Material", "value": "@{items('Apply')['desc']}" },
        { "title": "Qty",      "value": "@{items('Apply')['qty']} @{items('Apply')['uom']}" }
      ] }
  ],
  "actions": [
    { "type": "Action.Submit", "title": "Approve",
      "data": { "decision": "APPROVED" } },
    { "type": "Action.Submit", "title": "Reject",
      "data": { "decision": "REJECTED" } }
  ]
}
```

---

## 11. Security checklist

| Risk                    | Mitigation                                                  |
| ----------------------- | ----------------------------------------------------------- |
| Spoofed callback        | HMAC-SHA256 signature verified by `verify_callback_signature` |
| Replay of old callback  | Reject if `teams_req_id` not `SENT` or already `APPROVED`   |
| Token leak              | Store secrets in STRUST / SSF, never in TVARVC              |
| Mass auto-release       | `Z_WO_APPR_AUTO_RELEASE` re-checks completeness server-side |
| Wrong approver          | Validate `iv_user` against `ZTWOAPPR-APPROVER` before flag  |
| HTTPS                   | Enforce TLS 1.2+ on SICF & WebDispatcher                    |
| Direct SAP exposure     | Front with Azure APIM — see Part 2                          |

---

## 12. Test plan

| # | Scenario                                                              | Expected                                        |
| - | --------------------------------------------------------------------- | ----------------------------------------------- |
| 1 | Helpdesk selects 1 item, clicks `&RTMS`                               | FM `Z_WO_APPR_TEAMS_SEND` returns HTTP 202      |
| 2 | Approver clicks **Approve** in Teams within SLA                       | `APPR_VALID = 'X'`, `TEAMS_STATUS = APPROVED`   |
| 3 | All items of WO 4711 reach `APPR_VALID = 'X'`                         | `Z_WO_APPR_AUTO_RELEASE` released order 4711    |
| 4 | One item rejected                                                     | `APPR_VALID = 'R'`, no auto-release             |
| 5 | Power Automate retries callback with same `request_id`                | Idempotent — only one final row in `ZTWO_APPR_TMS`, history rows in `ZTWO_APPR_TMSH` are tagged with distinct `LOG_ID` |
| 6 | Callback with bad HMAC                                                | HTTP 401 returned, no DB update                 |
| 7 | Approval times out (24h)                                              | Flow posts `decision = TIMEOUT` → status updated, no release |
| 8 | Items from 3 different plants in one batch                            | Each item is sent to its own approver email     |

---

## 13. Deliverables checklist — Part 1

- [ ] **NEW** transparent table `ZTWO_APPR_TMS` (SE11) — *no append on ZTWOAPPR*
- [ ] **NEW** transparent table `ZTWO_APPR_TMSH` (SE11)
- [ ] Optional CDS / DDIC view `ZV_WO_APPR_FULL` joining ZTWOAPPR + ZTWO_APPR_TMS
- [ ] Function group `ZFG_WO_APPR_TEAMS` (SE80)
- [ ] 6 function modules created & active
- [ ] `ZCL_WO_APPR_TEAMS_HANDLER` + `ZCL_WO_APPR_TEAMS_HTTP` (SE24)
- [ ] Exception classes `ZCX_WO_APPR_TEAMS_HTTP` / `_AUTH`
- [ ] SICF service `zfg_wo_appr_teams/callback` activated
- [ ] OAuth 2.0 Client `ZOA2C_MS_FLOW` configured (SOAMANAGER)
- [ ] STRUST chain for `*.flow.microsoft.com` imported
- [ ] TVARVC `Z_WO_APPR_FLOW_URL` populated per system
- [ ] Power Automate flow imported & turned on
- [ ] Plant → approver map (`cmpPlantApproverMap` or SharePoint List) populated
- [ ] Azure App Registration with `Flow.ReadWrite.All` & client secret
- [ ] GUI Status `ZSTAT_0300` updated with `&RTMS`
- [ ] PAI `USER_COMMAND_0300` extended
- [ ] FORM `remind_items_via_teams` in `LZFG_WO_APPROVALF01`
- [ ] Transport request created & released
- [ ] Test cases #1–#8 executed

---
---

# PART 2 — Azure API Management — Gateway for SAP `ZTEST_ASS` / `ZFG_WO_APPR_TEAMS`

This part describes the **network/gateway layer** only: how to put **Azure API
Management (APIM)** between MS Power Automate and SAP so the cloud never talks
to SAP directly.

The current direct call (per Postman screenshot) is:

```
POST https://sapdevapp1.unitedtractors.com:8050/ptut/service/ztest_ass?sap-client=030
```

After this part, Power Automate will call:

```
POST https://aut-sap-apim.azure-api.net/wo-approval/callback
Header: Ocp-Apim-Subscription-Key: <subscription-key>
```

…and APIM will forward to SAP, injecting `?sap-client=030`, basic auth,
the right headers, and verifying HMAC + caller identity.

---

## P2-0. Why APIM in front of SAP

| Concern | Direct SAP | With APIM |
|---|---|---|
| SAP host exposed publicly | Yes — `sapdevapp1` reachable from internet | No — only APIM is public; SAP can be private / IP-restricted |
| Single throttle / quota | Per ICF service (limited) | Per subscription / IP / product |
| Auth at edge | Basic only | Subscription key + JWT + client cert + HMAC |
| Cert rotation | Restart ICM | Update once in APIM |
| Observability | `SMICM` logs | App Insights, every call traced |
| Multiple consumers (Flow, Logic Apps, mobile) | Each has SAP creds | Each gets its own subscription key |
| Versioning | Hard | `/v1` `/v2` paths in APIM |
| Cost of SAP outage | Bad UX | APIM caches/retries, returns clean 503 |

---

## P2-1. Target architecture

```
┌──────────────────┐       ┌─────────────────────────┐       ┌────────────────────────┐
│  MS Power        │ HTTPS │  Azure API Management   │  TLS  │  SAP NetWeaver ICF     │
│  Automate Flow   │──────►│  aut-sap-apim           │──────►│  /sap/bc/.../callback  │
│  (or Postman,    │  +    │   • subscription key    │   +   │   /ptut/service/...    │
│   Logic Apps,    │  HMAC │   • JWT validate (opt)  │  Basic│                        │
│   mobile app)    │       │   • IP allow-list       │  Auth │                        │
│                  │       │   • rate-limit / quota  │       │                        │
│                  │       │   • set-backend-service │       │                        │
│                  │       │   • App Insights trace  │       │                        │
└──────────────────┘       └─────────────────────────┘       └────────────────────────┘
                                       ▲
                                       │  Hybrid Connection / VNET
                                       │  Private Link to on-prem SAP
                                       │
                                ┌──────┴──────┐
                                │  Azure VNET │
                                │  + Cloud    │
                                │  Connector  │
                                └─────────────┘
```

---

## P2-2. Prerequisites

| Item | Value (example) |
|---|---|
| Azure subscription with `Contributor` rights | `UT-Prod` |
| Resource group | `rg-sap-integration` |
| Region | `Southeast Asia` (close to Jakarta DC) |
| APIM SKU | **Developer** (DEV/QA), **Standard v2** or **Premium** (PRD with VNET) |
| Existing SAP HTTP service active in SICF | `/sap/bc/zfg_wo_appr_teams/callback` AND/OR `/ptut/service/ztest_ass` |
| SAP service user | `TEAMS_API` with role `Z_WO_APPR_API` |
| Azure Key Vault | `kv-sap-int` holding SAP password + HMAC secret |
| App Insights workspace | `appi-sap-int` |
| DNS / hostname for SAP reachable from APIM | `sapdevapp1.unitedtractors.com:8050` |

---

## P2-3. Step 1 — Create the APIM instance

Tx in Azure Portal (or use Bicep below).

1. **Create a resource → API Management service**.
2. Fields:
   * Name: `aut-sap-apim` (gives URL `aut-sap-apim.azure-api.net`)
   * Resource group: `rg-sap-integration`
   * Region: `Southeast Asia`
   * Organization name: `United Tractors`
   * Admin email: `it-integration@unitedtractors.com`
   * Pricing tier: **Developer** (no SLA, OK for non-prod) or **Standard v2** for prod
3. **Managed identity** → System-assigned **On** (so APIM can read Key Vault).
4. Wait 30–45 minutes for provisioning.

### P2-3.1 Bicep one-liner (optional, for IaC pipelines)

```bicep
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: 'aut-sap-apim'
  location: 'southeastasia'
  sku: { name: 'Developer', capacity: 1 }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: 'it-integration@unitedtractors.com'
    publisherName:  'United Tractors'
  }
}
```

### P2-3.2 Grant APIM access to Key Vault

Key Vault → **Access policies** → Add policy → secret-permissions `Get, List`
→ principal = `aut-sap-apim` (the managed identity).

---

## P2-4. Step 2 — Register the SAP backend

This decouples the SAP URL/credentials from each API operation.

APIM portal → **Backends** → **+ Add**.

| Field | Value |
|---|---|
| Name | `sap-dev-ztest-ass` |
| URL  | `https://sapdevapp1.unitedtractors.com:8050` |
| Resource ID | leave empty |
| Credentials → **Authorization** | **Basic** |
| Username | `TEAMS_API` |
| Password | reference from Key Vault: `{{sap-teams-api-pwd}}` |
| TLS settings → Validate certificate chain | **On** |
| TLS settings → Validate certificate name | **On** |

> If SAP uses a self-signed cert, upload the cert under
> APIM → **Certificates** → **CA certificates**, then keep validation **On**.
> Don't disable validation — that's how MitM happens.

Repeat for the WO-approval-Teams callback if it lives on a different host:
`sap-dev-zfg-wo-appr` → `https://sapdevapp1.unitedtractors.com:8050`.

### P2-4.1 Named values (for the password & secrets)

APIM → **Named values** → **+ Add**:

| Display name | Type | Value |
|---|---|---|
| `sap-teams-api-pwd`   | Secret (Key Vault) | `https://kv-sap-int.vault.azure.net/secrets/sap-teams-api-pwd` |
| `sap-client`          | Plain | `030` (DEV), `100` (PRD) |
| `wo-approval-hmac`    | Secret (Key Vault) | `https://kv-sap-int.vault.azure.net/secrets/wo-approval-hmac` |

---

## P2-5. Step 3 — Create the API

APIM portal → **APIs** → **+ Add API** → **HTTP** (manually defined).

| Field | Value |
|---|---|
| Display name | `WO Approval` |
| Name | `wo-approval` |
| Web service URL | leave empty (we'll use the backend) |
| URL scheme | HTTPS |
| API URL suffix | `wo-approval` |
| Tags | `sap`, `teams`, `approval` |
| Products | Add to **Internal** (or create new product `WO-Approval-Consumers`) |
| Subscription required | **On** |
| Subscription key header name | `Ocp-Apim-Subscription-Key` (default) |
| Version | `v1` (path-based) |

Result: callers will use `https://aut-sap-apim.azure-api.net/wo-approval/...`.

---

## P2-6. Step 4 — Add operations

Add three operations under the API `wo-approval`.

### P2-6.1 `POST /callback` — Teams approval callback (used by Power Automate)

| Field | Value |
|---|---|
| Display name | `Teams Approval Callback` |
| URL | `POST` `/callback` |
| Description | Receives APPROVED / REJECTED / TIMEOUT from Power Automate; forwards to SAP FM `Z_WO_APPR_TEAMS_CALLBACK`. |

**Sample request body** (the WO-approval payload):

```json
{
  "request_id": "REQ-001",
  "decision":   "APPROVED",
  "user":       "alice@unitedtractors.com",
  "items": [
    { "wo": "4711", "pos": "10", "werks": "1000" }
  ]
}
```

### P2-6.2 `POST /test-callback` — generic ASS-test path (matches your screenshot)

| Field | Value |
|---|---|
| Display name | `Test Callback (ZTEST_ASS)` |
| URL | `POST` `/test-callback` |

**Sample request body** (matches your Postman):

```json
{
  "approval_key": "9000000040",
  "release_code": "AC",
  "status":       "APPROVED",
  "approver":     "Viandraf@unitedtractors.com",
  "comments":     "OK",
  "timestamp":    "2026-02-21T17:48:50Z"
}
```

### P2-6.3 `GET /health` — synthetic ping

| Field | Value |
|---|---|
| Display name | `Health` |
| URL | `GET` `/health` |
| Description | Returns 200 if APIM and SAP are both reachable. |

---

## P2-7. Step 5 — Inbound / Backend / Outbound policies

In APIM, every operation has an XML **policy** that runs in four scopes:
`<inbound>`, `<backend>`, `<outbound>`, `<on-error>`.

### P2-7.1 Global policy (applies to *all* WO-approval operations)

API `wo-approval` → **Design** → **All operations** → **Policies → </> Code editor**.

```xml
<policies>
  <inbound>
    <base />

    <!-- 1. CORS (only if you'll call from a browser) -->
    <cors allow-credentials="false">
      <allowed-origins><origin>*</origin></allowed-origins>
      <allowed-methods><method>POST</method><method>GET</method></allowed-methods>
      <allowed-headers><header>*</header></allowed-headers>
    </cors>

    <!-- 2. Rate limit per subscription: 60 calls/min -->
    <rate-limit-by-key calls="60" renewal-period="60"
                       counter-key="@(context.Subscription?.Key ?? context.Request.IpAddress)" />

    <!-- 3. Daily quota: 10 000/day per subscription -->
    <quota-by-key calls="10000" renewal-period="86400"
                  counter-key="@(context.Subscription?.Key ?? context.Request.IpAddress)" />

    <!-- 4. IP allow-list (Power Automate egress IPs for the region) -->
    <ip-filter action="allow">
      <address-range from="13.66.140.0" to="13.66.140.255" />
      <address-range from="40.74.28.0"  to="40.74.31.255"  />
      <!-- add the rest from https://learn.microsoft.com/.../power-automate/ip-address-configuration -->
    </ip-filter>

    <!-- 5. Reject if subscription key missing -->
    <check-header name="Ocp-Apim-Subscription-Key" failed-check-httpcode="401"
                  failed-check-error-message="Missing subscription key" ignore-case="true" />

    <!-- 6. Inject correlation id for tracing -->
    <set-header name="X-Correlation-Id" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
  </inbound>

  <backend>
    <base />
  </backend>

  <outbound>
    <base />
    <!-- Strip SAP headers we don't want to leak -->
    <set-header name="Server"          exists-action="delete" />
    <set-header name="X-Powered-By"    exists-action="delete" />
    <set-header name="sap-server"      exists-action="delete" />
    <set-header name="sap-perf-fesrec" exists-action="delete" />
  </outbound>

  <on-error>
    <base />
    <set-header name="X-Error-Source" exists-action="override">
      <value>APIM</value>
    </set-header>
  </on-error>
</policies>
```

### P2-7.2 Operation policy — `POST /callback` (forward to FM `Z_WO_APPR_TEAMS_CALLBACK`)

API `wo-approval` → **Design** → operation `Teams Approval Callback` →
**Policies → </> Code editor**.

```xml
<policies>
  <inbound>
    <base />

    <!-- 1. Verify HMAC header sent by Power Automate -->
    <set-variable name="bodyText" value="@(context.Request.Body.As<string>(preserveContent: true))" />
    <set-variable name="hmacSecret" value="{{wo-approval-hmac}}" />
    <set-variable name="expectedSig" value="@{
        var key   = Encoding.UTF8.GetBytes((string)context.Variables["hmacSecret"]);
        var bytes = Encoding.UTF8.GetBytes((string)context.Variables["bodyText"]);
        using (var h = new System.Security.Cryptography.HMACSHA256(key)) {
            return Convert.ToBase64String(h.ComputeHash(bytes));
        }
    }" />
    <choose>
      <when condition="@(context.Request.Headers.GetValueOrDefault('X-Flow-Signature','') != (string)context.Variables['expectedSig'])">
        <return-response>
          <set-status code="401" reason="Bad signature" />
        </return-response>
      </when>
    </choose>

    <!-- 2. Route to the SAP backend -->
    <set-backend-service backend-id="sap-dev-zfg-wo-appr" />
    <rewrite-uri template="/sap/bc/zfg_wo_appr_teams/callback?sap-client={{sap-client}}" />

    <!-- 3. Replace the caller's auth with the SAP service-user basic auth from backend -->
    <set-header name="Authorization" exists-action="delete" />

    <!-- 4. Make sure SAP gets JSON -->
    <set-header name="Content-Type" exists-action="override">
      <value>application/json; charset=utf-8</value>
    </set-header>
  </inbound>

  <backend>
    <forward-request timeout="60" />
  </backend>

  <outbound>
    <base />
  </outbound>
</policies>
```

### P2-7.3 Operation policy — `POST /test-callback` (your ZTEST_ASS path)

```xml
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="sap-dev-ztest-ass" />
    <rewrite-uri template="/ptut/service/ztest_ass?sap-client={{sap-client}}" />
    <set-header name="Authorization" exists-action="delete" />
  </inbound>
  <backend><forward-request timeout="60" /></backend>
  <outbound><base /></outbound>
</policies>
```

### P2-7.4 Operation policy — `GET /health`

```xml
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="sap-dev-zfg-wo-appr" />
    <rewrite-uri template="/sap/bc/ping" />
    <set-method>GET</set-method>
  </inbound>
  <backend><forward-request timeout="10" /></backend>
  <outbound>
    <base />
    <choose>
      <when condition="@(context.Response.StatusCode == 200)">
        <return-response>
          <set-status code="200" reason="OK" />
          <set-body>{"status":"healthy","sap":"reachable"}</set-body>
        </return-response>
      </when>
    </choose>
  </outbound>
</policies>
```

---

## P2-8. Step 6 — Subscriptions / Products

APIM portal → **Products** → **+ Add**:

| Field | Value |
|---|---|
| Display name | `WO Approval Consumers` |
| Id | `wo-approval-consumers` |
| Description | Consumers of the SAP WO approval gateway |
| State | **Published** |
| Requires subscription | **Yes** |
| Requires approval | **Yes** (admin must approve every new consumer) |
| Subscription count limit | 20 |
| APIs | add `wo-approval` |

Then **Subscriptions** → **+ Add**:

* `flow-prod` — assigned to product `WO Approval Consumers` → key goes into Power Automate.
* `flow-dev` — for testing.
* `postman-vfajar` — for manual tests.

> Each consumer gets its own key, so revoking one doesn't break the others.

---

## P2-9. Step 7 — Network connectivity to on-prem SAP

Pick **one** depending on your security posture.

### P2-9.1 Public SAP host + APIM IP allow-list (simplest)

* Already what your screenshot uses (`sapdevapp1.unitedtractors.com:8050`
  is reachable on the public internet).
* In SAP, restrict the SICF service to APIM's outbound IP range
  (find it in APIM → **Properties → Public IP**).
* Pros: no networking work. Cons: SAP still has a public surface.

### P2-9.2 Standard v2 + VNET integration (recommended)

* APIM Standard v2 supports outbound VNET integration.
* Put SAP's load balancer in an Azure VNET reachable via ExpressRoute /
  Azure VPN / S2S to your on-prem.
* In APIM → **Network → Virtual network → External or Internal**.
* In APIM **Backend**, override the URL to the private hostname.

### P2-9.3 Premium + Internal mode + Application Gateway (max security)

* APIM is fully private, exposed only via App Gateway WAF.
* Power Automate calls App Gateway public IP; App Gateway → APIM (private) → SAP (private).
* Cert pinning between App Gateway and APIM.

### P2-9.4 Hybrid Connection (when ExpressRoute is overkill)

* APIM → **Self-hosted gateway** running on a Linux box inside the SAP DC.
* Cloud APIM forwards to the self-hosted gateway, which calls SAP via the
  internal DNS name.

---

## P2-10. Step 8 — Lock down SAP itself

After APIM is in front, harden SAP so it **only** accepts calls from APIM.

### P2-10.1 SICF — restrict by IP

`SICF → /sap/bc/zfg_wo_appr_teams/callback → right-click → Service Data →
GUI Configuration tab`. Add APIM's outbound IP under **Allowed IPs**.

> If your kernel doesn't expose this, do it at the WebDispatcher
> (`icm/HTTP/auth_<n>` or `icm/HTTP/redirect_<n>` rules).

### P2-10.2 Mutual TLS (mTLS) — strongest

1. Generate a client certificate for APIM (CSR signed by your internal CA).
2. APIM → **Certificates** → **Client certificates** → upload the PFX.
3. In the operation policy add:

```xml
<authentication-certificate thumbprint="ABCDEF1234..." />
```

4. SAP STRUST → **SSL Server Standard** PSE → trust the issuing CA.
5. Web Dispatcher: `icm/HTTPS/verify_client = 2` (strict mTLS).

### P2-10.3 Service-user role

`PFCG → role Z_WO_APPR_API` with **only** these auth objects:
* `S_ICF` for the SICF service
* `S_RFC` for FG `ZFG_WO_APPR_TEAMS`
* `S_TCODE` empty
* No `SAP_ALL`, no `SAP_NEW`, no DDIC priv.

---

## P2-11. Step 9 — Update SAP-side `ZCL_WO_APPR_TEAMS_HANDLER`

Originally it called Power Automate directly. Now it must call APIM, **and**
APIM must be the only thing Power Automate can call back. So *both* directions
go through APIM.

```abap
METHOD load_config.
  " was: Z_WO_APPR_FLOW_URL  (direct Power Automate URL)
  " now: Z_WO_APPR_APIM_URL  (APIM URL)
  SELECT SINGLE low FROM tvarvc INTO @mv_flow_url
    WHERE name = 'Z_WO_APPR_APIM_URL' AND type = 'P'.
ENDMETHOD.
```

`TVARVC` value (DEV):
```
https://aut-sap-apim.azure-api.net/wo-approval/teams-trigger
```

> Add a new APIM operation `POST /teams-trigger` whose backend is the Power
> Automate **HTTP-request-received** trigger URL — same pattern in reverse.
> That way SAP holds an APIM URL, not a Power Automate URL, and the Flow URL
> can rotate without an SAP transport.

In the SAP HTTP request, set:

```abap
mo_http->request->set_header_field(
  name  = 'Ocp-Apim-Subscription-Key'
  value = lv_apim_key ).            " stored in STRUST/SSF, NOT TVARVC
```

---

## P2-12. Step 10 — Update Power Automate to use APIM

Open `Flow_WO_Approval_PlantBased`.

### P2-12.1 Change the callback variable

| Variable | Old value | **New value** |
|---|---|---|
| `varSapCallbackUrl` | `https://sapdevapp1.unitedtractors.com:8050/sap/bc/zfg_wo_appr_teams/callback` | `https://aut-sap-apim.azure-api.net/wo-approval/callback` |

### P2-12.2 Add the subscription-key header on the HTTP step

The HTTP step's headers become:

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |
| `Ocp-Apim-Subscription-Key` | `@{variables('varApimSubscriptionKey')}` |
| `X-Flow-Signature` | `@{base64(hmac('SHA256', body('cmpPayload'), variables('varSapSecret')))}` |

Initialize one more variable at the top of the flow:

| # | Name | Type | Value |
|---|---|---|---|
| 5 | `varApimSubscriptionKey` | String | Reference Key Vault secret `apim-flow-prod-key` |

### P2-12.3 Drop SAP basic auth from the flow

Remove the `Authentication = Basic` block on the HTTP action — APIM handles
that now. Power Automate only needs the subscription key + HMAC.

---

## P2-13. Step 11 — Test the chain

### P2-13.1 Smoke test from APIM Test console

APIM portal → **APIs → wo-approval → Test → Teams Approval Callback**.

* Body:
```json
{"request_id":"PING-001","decision":"APPROVED","user":"vfajar@unitedtractors.com","items":[{"wo":"4711","pos":"10","werks":"1000"}]}
```
* Click **Send**.
* Expected: HTTP 200 with `{"msgty":"S","message":"Approval processed successfully"}` (same shape your screenshot shows).

### P2-13.2 Test from Postman with subscription key

```http
POST https://aut-sap-apim.azure-api.net/wo-approval/test-callback
Ocp-Apim-Subscription-Key: <postman-vfajar-key>
Content-Type: application/json

{
  "approval_key": "9000000040",
  "release_code": "AC",
  "status":       "APPROVED",
  "approver":     "Viandraf@unitedtractors.com",
  "comments":     "OK",
  "timestamp":    "2026-02-21T17:48:50Z"
}
```

* Without the key → `401 Subscription not valid`.
* With wrong HMAC → `401 Bad signature`.
* With both correct → `200 OK` with SAP's body.

### P2-13.3 End-to-end test from MS Teams

1. Trigger `&RTMS` in transaction `ZWOAPP`.
2. Approve in Teams.
3. Watch APIM → **Monitor → Application Insights** for two traces:
   * `POST /wo-approval/teams-trigger` (SAP → APIM → Flow)
   * `POST /wo-approval/callback`      (Flow → APIM → SAP)
4. Verify `ZTWO_APPR_TMS-APPR_VALID = 'X'` and BAPI release fired.

---

## P2-14. Monitoring & alerts

| Where | What to watch | Alert when |
|---|---|---|
| APIM → Metrics | Total Requests, Failed Requests | Failed > 5 / 5 min |
| APIM → Metrics | Backend Duration | p95 > 30 s |
| App Insights | `requests` table, `resultCode` | 5xx rate > 1 % over 15 min |
| App Insights | Custom event `HmacFailed` (logged from policy) | > 0 in 5 min |
| Azure Monitor | Subscription-key usage | Any *unknown* key tries to call |
| SAP `SMICM` | ICF logs for the service | Surge from non-APIM IPs |

---

## P2-15. Cost guideline (May 2026)

| SKU | ~Monthly USD | Use for |
|---|---|---|
| Developer | ~50 | DEV / QA only — no SLA |
| Basic v2 | ~150 | Small prod, no VNET |
| Standard v2 | ~700 | Most prod (VNET integration, autoscale) |
| Premium | ~2 800 / unit | Multi-region, internal mode, mTLS, zonal redundancy |

For one SAP DEV + one PRD UnitedTractors typically lands on:
**Developer** in non-prod, **Standard v2** in PRD.

---

## P2-16. Final checklist — Part 2

- [ ] APIM service `aut-sap-apim` deployed in `rg-sap-integration`
- [ ] System-assigned identity granted **Get / List** on Key Vault `kv-sap-int`
- [ ] Named values `sap-client`, `sap-teams-api-pwd`, `wo-approval-hmac` configured
- [ ] Backend `sap-dev-zfg-wo-appr` created with Basic auth from Key Vault
- [ ] API `wo-approval` published, version `v1`
- [ ] Operations `/callback`, `/test-callback`, `/health`, `/teams-trigger`
- [ ] Global policy: rate-limit, quota, IP allow-list, `check-header`
- [ ] Operation policies: HMAC verify, `set-backend-service`, `rewrite-uri`
- [ ] Product `WO Approval Consumers` created with subscriptions
- [ ] Power Automate updated: APIM URL + `Ocp-Apim-Subscription-Key` + HMAC
- [ ] SAP `TVARVC Z_WO_APPR_APIM_URL` populated per system
- [ ] SAP class `ZCL_WO_APPR_TEAMS_HANDLER` calls APIM, sends subscription-key header
- [ ] SICF service IP-restricted to APIM outbound IPs (or mTLS)
- [ ] App Insights linked, alerts configured
- [ ] End-to-end test: Postman → APIM → SAP returns `200 OK` with `msgty:"S"` (matches screenshot)
- [ ] Run-book attached to Service-Now ticket for production cut-over

---
---

## How to upload this file to the GitHub repo

This document is now in `C:\Users\Viandra Fajar\ENHANCEMENT2.md`. To attach it
to the GitHub repository `vincode18/SAPLZFG_WO_APPROVAL`:

### Option A — Web UI (no git needed)

1. Sign in to https://github.com/vincode18/SAPLZFG_WO_APPROVAL .
2. Click **Add file → Upload files**.
3. Drag `ENHANCEMENT2.md` into the drop zone (or browse to it).
4. Commit message: `Add ENHANCEMENT2 — Teams approval + APIM gateway spec`.
5. Commit directly to `main`, or open a PR.

### Option B — Git CLI

```bash
git clone https://github.com/vincode18/SAPLZFG_WO_APPROVAL.git
cd SAPLZFG_WO_APPROVAL
cp "C:/Users/Viandra Fajar/ENHANCEMENT2.md" ./ENHANCEMENT2.md
git add ENHANCEMENT2.md
git commit -m "Add ENHANCEMENT2 — Teams approval + APIM gateway spec"
git push origin main
```

### Option C — GitHub CLI

```bash
cd SAPLZFG_WO_APPROVAL
gh repo clone vincode18/SAPLZFG_WO_APPROVAL
cp "C:/Users/Viandra Fajar/ENHANCEMENT2.md" ./ENHANCEMENT2.md
gh api repos/vincode18/SAPLZFG_WO_APPROVAL/contents/ENHANCEMENT2.md \
  --method PUT \
  -f message="Add ENHANCEMENT2 — Teams approval + APIM gateway spec" \
  -f content="$(base64 -w0 ENHANCEMENT2.md)"
```
