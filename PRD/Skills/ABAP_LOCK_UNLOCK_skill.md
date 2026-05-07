# Lock/Unlock Skill — Reusable OOP Pattern

## Overview

This document defines a **reusable, class-based skill** for locking and unlocking Work Orders (WOs) in SAP ABAP. The skill encapsulates all lock/unlock logic in an ABAP class that can be instantiated and reused across multiple reports, user exits, and function modules.

**Key Benefits:**
- **Single source of truth** — all lock/unlock logic in one class
- **Reusable across reports** — instantiate and call from any context
- **Consistent error handling** — standardized message management
- **Testable** — unit test the class independently
- **Maintainable** — changes in one place affect all consumers
- **Type-safe** — leverages ABAP OOP features

---

## Class Definition: `ZCL_WO_LOCK_MANAGER`

### Class Structure

```abap
CLASS zcl_wo_lock_manager DEFINITION.
  PUBLIC SECTION.
    " Constants
    CONSTANTS: cv_lock_mode_shared     TYPE char1 VALUE 'S',
               cv_lock_mode_exclusive  TYPE char1 VALUE 'E',
               cv_msg_class            TYPE msgid VALUE 'ALM_ME',
               cv_msg_number           TYPE msgno VALUE '802'.

    " Types
    TYPES: BEGIN OF ty_wo_entry,
             aufnr TYPE aufnr,
             werks TYPE werks_d,
           END OF ty_wo_entry,
           tt_wo_entries TYPE TABLE OF ty_wo_entry WITH KEY aufnr,
           
           BEGIN OF ty_lock_result,
             success      TYPE flag,
             locked_count TYPE i,
             failed_count TYPE i,
             failed_wos   TYPE TABLE OF aufnr,
             error_msg    TYPE string,
           END OF ty_lock_result.

    " Methods
    METHODS: constructor,
             lock_multiple
               IMPORTING it_aufnr_list    TYPE tt_wo_entries
                         iv_lock_mode     TYPE char1 DEFAULT cv_lock_mode_shared
               EXPORTING ev_success       TYPE flag
                         ev_locked_count  TYPE i
                         ev_failed_count  TYPE i
                         et_failed_wos    TYPE TABLE OF aufnr,
             
             unlock_single
               IMPORTING iv_aufnr TYPE aufnr
                         iv_silent TYPE flag DEFAULT space
               EXPORTING ev_success TYPE flag,
             
             unlock_multiple
               IMPORTING it_aufnr_list TYPE TABLE OF aufnr
                         iv_silent     TYPE flag DEFAULT space
               EXPORTING ev_success    TYPE flag
                         ev_count      TYPE i,
             
             rollback_locks
               IMPORTING it_aufnr_list TYPE TABLE OF aufnr
                         iv_silent     TYPE flag DEFAULT space
               EXPORTING ev_success    TYPE flag
                         ev_count      TYPE i.

  PRIVATE SECTION.
    DATA: mt_locked_wos TYPE tt_wo_entries.

    METHODS: build_enqueue_table
               IMPORTING it_aufnr_list TYPE tt_wo_entries
               EXPORTING et_enqueue    TYPE TABLE OF ordtyp_pre,
             
             handle_lock_failure
               IMPORTING it_not_locked TYPE TABLE OF ord_pre
                         it_locked     TYPE TABLE OF ordtyp_pre
               EXPORTING ev_success    TYPE flag
                         et_failed_wos TYPE TABLE OF aufnr
                         ev_error_msg  TYPE string.

ENDCLASS.
```

### Class Implementation

```abap
CLASS zcl_wo_lock_manager IMPLEMENTATION.

  METHOD constructor.
    CLEAR mt_locked_wos.
  ENDMETHOD.

  METHOD lock_multiple.
    DATA: lt_enqueue    TYPE TABLE OF ordtyp_pre,
          lt_not_locked TYPE TABLE OF ord_pre,
          lv_xcount     TYPE i.

    ev_success = 'X'.
    CLEAR: ev_locked_count, ev_failed_count.

    " 1. Build enqueue table
    CALL METHOD me->build_enqueue_table
      EXPORTING
        it_aufnr_list = it_aufnr_list
      IMPORTING
        et_enqueue    = lt_enqueue.

    IF lt_enqueue IS INITIAL.
      ev_success = space.
      RETURN.
    ENDIF.

    " 2. Call lock function module
    CALL FUNCTION 'CO_ZF_ORDER_LOCK_MULTI'
      EXPORTING
        lock_mode   = iv_lock_mode
      TABLES
        enqueue_tab = lt_enqueue
        not_locked  = lt_not_locked.

    DESCRIBE TABLE lt_not_locked LINES lv_xcount.

    " 3. Handle results
    IF lv_xcount > 0.
      CALL METHOD me->handle_lock_failure
        EXPORTING
          it_not_locked = lt_not_locked
          it_locked     = lt_enqueue
        IMPORTING
          ev_success    = ev_success
          et_failed_wos = et_failed_wos
          ev_error_msg  = DATA(lv_error_msg).
      ev_failed_count = lv_xcount.
      ev_locked_count = lines( lt_enqueue ) - lv_xcount.
    ELSE.
      " All locked successfully
      mt_locked_wos = it_aufnr_list.
      ev_locked_count = lines( lt_enqueue ).
    ENDIF.

  ENDMETHOD.

  METHOD unlock_single.
    DATA: lv_aufnr TYPE aufnr.

    ev_success = 'X'.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_aufnr
      IMPORTING
        output = lv_aufnr.

    CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
      EXPORTING
        aufnr = lv_aufnr
      EXCEPTIONS
        OTHERS = 1.

    IF sy-subrc <> 0 AND iv_silent = space.
      ev_success = space.
    ENDIF.

  ENDMETHOD.

  METHOD unlock_multiple.
    DATA: lv_success TYPE flag.

    ev_success = 'X'.
    CLEAR ev_count.

    LOOP AT it_aufnr_list INTO DATA(lv_aufnr_item).
      CALL METHOD me->unlock_single
        EXPORTING
          iv_aufnr = lv_aufnr_item
          iv_silent = iv_silent
        IMPORTING
          ev_success = lv_success.
      IF lv_success = 'X'.
        ev_count = ev_count + 1.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD rollback_locks.
    " Rollback: unlock all successfully locked WOs
    CALL METHOD me->unlock_multiple
      EXPORTING
        it_aufnr_list = it_aufnr_list
        iv_silent     = iv_silent
      IMPORTING
        ev_success    = ev_success
        ev_count      = ev_count.
    CLEAR mt_locked_wos.
  ENDMETHOD.

  METHOD build_enqueue_table.
    DATA: ls_caufv TYPE caufv,
          ls_enqueue TYPE ordtyp_pre,
          lv_aufnr TYPE aufnr.

    CLEAR et_enqueue.

    LOOP AT it_aufnr_list INTO DATA(ls_wo_entry).
      lv_aufnr = ls_wo_entry-aufnr.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_aufnr
        IMPORTING
          output = lv_aufnr.

      " Skip duplicates
      READ TABLE et_enqueue WITH KEY aufnr = lv_aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM caufv INTO @ls_caufv WHERE aufnr = @lv_aufnr.
        IF sy-subrc = 0.
          MOVE-CORRESPONDING ls_caufv TO ls_enqueue.
          IF ls_caufv-prueflos IS INITIAL.
            ls_enqueue-kein_prlos = 'X'.
          ENDIF.
          APPEND ls_enqueue TO et_enqueue.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD handle_lock_failure.
    DATA: lv_aufnr TYPE aufnr.

    ev_success = space.
    CLEAR et_failed_wos.

    CALL FUNCTION 'MESSAGES_INITIALIZE'.

    LOOP AT it_not_locked INTO DATA(ls_not_locked).
      APPEND ls_not_locked-aufnr TO et_failed_wos.
      
      CALL FUNCTION 'MESSAGE_STORE'
        EXPORTING
          msgid = cv_msg_class
          msgty = 'E'
          msgno = cv_msg_number
          msgv1 = 'Order '
          msgv2 = ls_not_locked-aufnr
          msgv3 = 'is currently'
          msgv4 = 'being processed'.
    ENDLOOP.

    " Rollback: unlock all successfully locked WOs
    LOOP AT it_locked INTO DATA(ls_locked).
      READ TABLE it_not_locked WITH KEY aufnr = ls_locked-aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
          EXPORTING
            aufnr = ls_locked-aufnr.
      ENDIF.
    ENDLOOP.

    ev_error_msg = |{ lines( et_failed_wos ) } WO(s) could not be locked|.

  ENDMETHOD.

ENDCLASS.
```

---

## Usage Examples

### Example 1: Simple Lock & Process (Shared Mode)

```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lv_success  TYPE flag,
      lv_count    TYPE i.

" Create instance
CREATE OBJECT lo_lock_mgr.

" Prepare WO list
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
ENDLOOP.

" Lock all WOs
lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list   = lt_wos
    iv_lock_mode    = zcl_wo_lock_manager=>cv_lock_mode_shared
  IMPORTING
    ev_success      = lv_success
    ev_locked_count = lv_count ).

IF lv_success <> 'X'.
  MESSAGE 'Failed to lock WOs' TYPE 'E'.
  RETURN.
ENDIF.

" Process each WO
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  PERFORM update_approval_record USING gs_alv_data.
  lo_lock_mgr->unlock_single( EXPORTING iv_aufnr = gs_alv_data-aufnr ).
ENDLOOP.

COMMIT WORK AND WAIT.
MESSAGE |{ lv_count } WO(s) processed| TYPE 'S'.
```

### Example 2: Approve Workflow with Deferred Unlock

```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lv_success  TYPE flag.

CREATE OBJECT lo_lock_mgr.

" Build WO list from selection
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
ENDLOOP.

" Lock all WOs
lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos
  IMPORTING
    ev_success    = lv_success ).

CHECK lv_success = 'X'.

" Process approvals
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  PERFORM update_approval_record USING gs_alv_data.
ENDLOOP.

COMMIT WORK AND WAIT.

" Unlock all after commit (deferred unlock strategy)
lo_lock_mgr->unlock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos ).

MESSAGE 'Approval completed' TYPE 'S'.
```

### Example 3: Error Handling with Rollback

```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lt_failed   TYPE TABLE OF aufnr,
      lv_success  TYPE flag,
      lv_failed   TYPE i.

CREATE OBJECT lo_lock_mgr.

" Prepare WO list
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
ENDLOOP.

" Try to lock
lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos
  IMPORTING
    ev_success    = lv_success
    ev_failed_count = lv_failed
    et_failed_wos = lt_failed ).

IF lv_success <> 'X'.
  " Display failed WOs
  LOOP AT lt_failed INTO DATA(lv_aufnr).
    WRITE: / |WO { lv_aufnr } is locked by another user|.
  ENDLOOP.
  
  " Automatic rollback happens inside lock_multiple
  RETURN.
ENDIF.

" Safe to process
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  PERFORM update_approval_record USING gs_alv_data.
ENDLOOP.

COMMIT WORK AND WAIT.
```

### Example 4: User Exit Integration

```abap
" In User Exit ZXWO1U02 (WO Release Check)
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lv_success  TYPE flag.

CREATE OBJECT lo_lock_mgr.

" Lock the WO being released
APPEND VALUE #( aufnr = xaufk-aufnr
                werks = xaufk-werks ) TO lt_wos.

lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos
    iv_lock_mode  = zcl_wo_lock_manager=>cv_lock_mode_exclusive
  IMPORTING
    ev_success    = lv_success ).

IF lv_success = 'X'.
  " Perform release checks
  PERFORM check_approval_status USING xaufk-aufnr.
  
  " Unlock after check
  lo_lock_mgr->unlock_single( EXPORTING iv_aufnr = xaufk-aufnr ).
ELSE.
  no_release = 'X'.
ENDIF.
```

### Example 5: Reject Workflow (Unlock Inside Loop)

```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lv_success  TYPE flag.

CREATE OBJECT lo_lock_mgr.

" Build WO list
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
ENDLOOP.

" Lock all WOs
lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos
  IMPORTING
    ev_success    = lv_success ).

CHECK lv_success = 'X'.

" Process rejection - unlock inside loop (shared mode pattern)
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  gs_alv_data-approval_stat = 'Reject Approval'.
  PERFORM update_approval_record USING gs_alv_data.
  
  " Unlock immediately after update (safe for shared locks)
  lo_lock_mgr->unlock_single( EXPORTING iv_aufnr = gs_alv_data-aufnr ).
ENDLOOP.

COMMIT WORK AND WAIT.
MESSAGE 'Items rejected' TYPE 'S'.
```

### Example 6: Reset Workflow with Bulk Unlock

```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries,
      lt_aufnr    TYPE TABLE OF aufnr,
      lv_success  TYPE flag.

CREATE OBJECT lo_lock_mgr.

" Build WO list
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
  APPEND gs_alv_data-aufnr TO lt_aufnr.
ENDLOOP.

" Lock all WOs
lo_lock_mgr->lock_multiple(
  EXPORTING
    it_aufnr_list = lt_wos
  IMPORTING
    ev_success    = lv_success ).

CHECK lv_success = 'X'.

" Process reset
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  gs_alv_data-approval_stat = 'Pending Approve'.
  PERFORM update_approval_record USING gs_alv_data.
ENDLOOP.

COMMIT WORK AND WAIT.

" Bulk unlock all at once
lo_lock_mgr->unlock_multiple(
  EXPORTING
    it_aufnr_list = lt_aufnr ).

MESSAGE 'Items reset to pending' TYPE 'S'.
```

---

## Integration Guide

### Step 1: Create the Class in Your System

1. In SE24 (Class Builder), create class `ZCL_WO_LOCK_MANAGER`
2. Copy the class definition and implementation above
3. Activate the class

### Step 2: Refactor Existing Reports

**Before (FORM-based):**
```abap
PERFORM lock CHANGING lv_continue.
CHECK lv_continue = 'X'.
LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  PERFORM update_record USING gs_alv_data.
  PERFORM unlock USING gs_alv_data-aufnr.
ENDLOOP.
COMMIT WORK AND WAIT.
```

**After (Class-based):**
```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager,
      lt_wos      TYPE zcl_wo_lock_manager=>tt_wo_entries.

CREATE OBJECT lo_lock_mgr.

LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  APPEND VALUE #( aufnr = gs_alv_data-aufnr
                  werks = gs_alv_data-werks ) TO lt_wos.
ENDLOOP.

lo_lock_mgr->lock_multiple( EXPORTING it_aufnr_list = lt_wos
                            IMPORTING ev_success = lv_success ).
CHECK lv_success = 'X'.

LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
  PERFORM update_record USING gs_alv_data.
  lo_lock_mgr->unlock_single( EXPORTING iv_aufnr = gs_alv_data-aufnr ).
ENDLOOP.

COMMIT WORK AND WAIT.
```

### Step 3: Use in New Reports

Simply instantiate and call:
```abap
DATA: lo_lock_mgr TYPE REF TO zcl_wo_lock_manager.
CREATE OBJECT lo_lock_mgr.
lo_lock_mgr->lock_multiple( ... ).
```

---

## Method Reference

### `lock_multiple`

Locks multiple WOs in a single call using `CO_ZF_ORDER_LOCK_MULTI`.

**Parameters:**
- `it_aufnr_list` (IMPORTING): Table of WO entries (aufnr + werks)
- `iv_lock_mode` (IMPORTING, optional): `'S'` (shared, default) or `'E'` (exclusive)
- `ev_success` (EXPORTING): `'X'` if all locked, space if any failed
- `ev_locked_count` (EXPORTING): Number of successfully locked WOs
- `ev_failed_count` (EXPORTING): Number of failed locks
- `et_failed_wos` (EXPORTING): List of WOs that could not be locked

**Behavior:**
- All-or-nothing: If any WO fails to lock, all successfully locked WOs are automatically unlocked (rollback)
- Automatic error message display via `MESSAGES_INITIALIZE` and `MESSAGE_STORE`

---

### `unlock_single`

Unlocks a single WO using `CO_ZF_ORDER_DELOCK`.

**Parameters:**
- `iv_aufnr` (IMPORTING): Work Order number
- `iv_silent` (IMPORTING, optional): `'X'` to suppress error messages
- `ev_success` (EXPORTING): `'X'` if successful

---

### `unlock_multiple`

Unlocks multiple WOs in a loop.

**Parameters:**
- `it_aufnr_list` (IMPORTING): Table of WO numbers
- `iv_silent` (IMPORTING, optional): `'X'` to suppress error messages
- `ev_success` (EXPORTING): `'X'` if all successful
- `ev_count` (EXPORTING): Number of successfully unlocked WOs

---

### `rollback_locks`

Rolls back (unlocks) all WOs that were locked by this instance.

**Parameters:**
- `it_aufnr_list` (IMPORTING): Table of WO numbers to unlock
- `iv_silent` (IMPORTING, optional): `'X'` to suppress error messages
- `ev_success` (EXPORTING): `'X'` if successful
- `ev_count` (EXPORTING): Number of unlocked WOs

---

## Best Practices

1. **Always check `ev_success`** after calling `lock_multiple`
2. **Use `iv_lock_mode` parameter** to choose between shared (`'S'`) and exclusive (`'E'`) modes
3. **Defer unlock for exclusive locks** — unlock after `COMMIT WORK`
4. **Unlock immediately for shared locks** — unlock inside the processing loop
5. **Handle errors gracefully** — check `et_failed_wos` to inform users
6. **Silent mode** — use `iv_silent = 'X'` in unlock calls if you don't want error messages
7. **Reuse instances** — create one instance per operation, not per WO
8. **Type-safe** — use the class types (`tt_wo_entries`, `ty_wo_entry`) for consistency

---

## Lock Mode Decision Matrix

| Scenario | Lock Mode | Unlock Timing | Example |
|---|---|---|---|
| Updating custom approval table only | Shared (`'S'`) | Inside loop or bulk | Approval report |
| Modifying WO object (status, BOM) | Exclusive (`'E'`) | After COMMIT | User exit, direct WO update |
| Multi-step workflow (approve → sync) | Shared (`'S'`) | Deferred (in helper FORM) | Approve with header sync |
| Quick validation check | Shared (`'S'`) | Immediately after check | Release validation |

---

## Related Files

- **Original Skill:** `lock.md`
- **Report:** `ZR_SVC_WO_APPROVAL_v8.5.abap`
- **Custom Tables:** `ZTWOAPPR`, `ZTWOAPPRH`
- **Function Modules:** `CO_ZF_ORDER_LOCK_MULTI`, `CO_ZF_ORDER_DELOCK`

---

## Version History

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-04-22 | Class-based reusable Lock/Unlock Skill with OOP pattern |
