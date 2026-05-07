# ABAP Send Email using SBWP (BCS) — Reusable Skill
**Pattern:** HTML Email via `CL_BCS` with Distribution List Integration (DLI)
**Reference:** Service WO Component Approval — Plant-based Email Notification
**Date:** April 2026

---

## 1. Overview

This skill documents a reusable, production-ready pattern for sending **HTML-formatted emails** from ABAP programs using **SAP Business Communication Services (BCS)** — the modern replacement for legacy `SO_*` function modules. The pattern supports:

1. **HTML email bodies** with embedded CSS styling (tables, colors, formatting)
2. **Distribution List Integration (DLI)** — read recipients from shared/personal SAP distribution lists (SBWP)
3. **Plant-based / group-based segmentation** — send separate emails per logical grouping
4. **Custom sender address** — override default system sender
5. **Exception handling** via `cx_bcs` class-based exceptions
6. **FIRST/BODY/LAST HTML builder pattern** — modular, maintainable HTML construction

---

## 2. Architecture — 4-Layer Pattern

```
┌────────────────────────────────────────────────────────────┐
│ LAYER 1: ORCHESTRATOR (process_send_email)                 │
│  - Validate authorization                                  │
│  - Collect selected items                                  │
│  - Group by plant/key                                      │
│  - Loop each group → call DLI reader → build HTML → send   │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ LAYER 2: DLI READER (get_email_from_dli)                   │
│  - Call SO_DLI_READ_API1 (shared first, personal fallback) │
│  - Extract member_adr → gt_recipients                      │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ LAYER 3: HTML BUILDER (build_email_html_xxx)               │
│  - FIRST: <html><head><style>…<table header>               │
│  - BODY : <tr><td>…</td></tr> per row                      │
│  - LAST : </table><summary></body></html>                  │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ LAYER 4: BCS SENDER (send_email_bcs)                       │
│  - cl_bcs=>create_persistent                               │
│  - cl_document_bcs=>create_document (type='HTM')           │
│  - cl_cam_address_bcs=>create_internet_address             │
│  - set_sender / add_recipient / send                       │
└────────────────────────────────────────────────────────────┘
```

---

## 3. Required Data Types & Globals

```abap
" --- Type for email recipient ---
TYPES: BEGIN OF ty_email_recipient,
         recipient TYPE ad_smtpadr,   " SMTP email address
         name      TYPE so_obj_des,   " Display name
       END OF ty_email_recipient.

" --- Type for grouping key (example: plant) ---
TYPES: BEGIN OF ty_group_key,
         werks TYPE werks_d,
       END OF ty_group_key.

" --- Globals ---
DATA: gt_selected    TYPE TABLE OF ty_alv_output,   " Selected items
      gt_recipients  TYPE TABLE OF ty_email_recipient. " Email recipients
```

---

## 4. Layer 1 — Orchestrator Template

```abap
FORM process_send_email CHANGING p_rs_selfield_refresh.

  DATA: lv_count        TYPE i,
        lv_answer       TYPE char1,
        lv_dli_name     TYPE so_recname,
        lt_html         TYPE bcsy_text,
        lv_subject      TYPE so_obj_des,
        lv_date_str(10) TYPE c,
        lv_werks_3      TYPE char3,
        lv_total_sent   TYPE i,
        lv_total_items  TYPE i,
        lv_group_count  TYPE i,
        lv_item_count   TYPE i,
        lv_skip_count   TYPE i.

  DATA: lt_groups        TYPE TABLE OF ty_group_key,
        ls_group         TYPE ty_group_key,
        lt_group_items   TYPE TABLE OF ty_alv_output,
        lt_save_selected TYPE TABLE OF ty_alv_output.

  " --- Step 1: Authorization check ---
  IF gv_auth_helpdesk = ' ' AND gv_auth_bcsppd = ' '.
    MESSAGE 'Only authorized users can send email' TYPE 'E'.
    RETURN.
  ENDIF.

  " --- Step 2: Collect selected items + unique groups ---
  CLEAR: gt_selected, gt_recipients, lv_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
    APPEND gs_alv_data TO gt_selected.

    READ TABLE lt_groups WITH KEY werks = gs_alv_data-werks
                         TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_group-werks = gs_alv_data-werks.
      APPEND ls_group TO lt_groups.
    ENDIF.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item' TYPE 'I'.
    RETURN.
  ENDIF.

  lv_group_count = lines( lt_groups ).

  " --- Step 3: Confirmation popup ---
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Send Email Notification'
      text_question         = |Send email for { lv_count } item(s) | &&
                              |across { lv_group_count } group(s)?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  WRITE sy-datum TO lv_date_str DD/MM/YYYY.
  lt_save_selected = gt_selected.

  " --- Step 4: Loop each group → send separate email ---
  CLEAR: lv_total_sent, lv_total_items, lv_skip_count.
  LOOP AT lt_groups INTO ls_group.

    " Filter items for this group
    CLEAR: lt_group_items, gt_recipients.
    LOOP AT lt_save_selected INTO gs_alv_data WHERE werks = ls_group-werks.
      APPEND gs_alv_data TO lt_group_items.
    ENDLOOP.

    CHECK lt_group_items IS NOT INITIAL.
    lv_item_count = lines( lt_group_items ).

    " Build DLI name dynamically (convention: PREFIX_<key>)
    lv_werks_3 = ls_group-werks(3).
    CONCATENATE 'APPR_' lv_werks_3 INTO lv_dli_name.
    CONDENSE lv_dli_name NO-GAPS.

    " Read recipients from DLI
    PERFORM get_email_from_dli USING lv_dli_name.

    " Skip if DLI empty
    IF gt_recipients IS INITIAL.
      MESSAGE |No recipients in DLI { lv_dli_name } - skipped|
              TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " Set gt_selected to group items (HTML builder reads from gt_selected)
    gt_selected = lt_group_items.

    " Build subject
    lv_subject = |Approval - { lv_item_count } Item(s) | &&
                 |Plant { ls_group-werks } - Request for Review|.

    " Build HTML (FIRST + BODY + LAST)
    CLEAR lt_html.
    PERFORM build_email_html USING 'FIRST' lv_date_str lv_item_count
                             CHANGING lt_html.
    PERFORM build_email_html USING 'BODY'  lv_date_str lv_item_count
                             CHANGING lt_html.
    PERFORM build_email_html USING 'LAST'  lv_date_str lv_item_count
                             CHANGING lt_html.

    " Send via BCS
    TRY.
        PERFORM send_email_bcs TABLES gt_recipients
                               USING  lv_subject lt_html.
        lv_total_sent  = lv_total_sent + 1.
        lv_total_items = lv_total_items + lv_item_count.

      CATCH cx_bcs INTO DATA(lx_bcs).
        MESSAGE |Error sending for { ls_group-werks }: | &&
                |{ lx_bcs->get_text( ) }| TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_count = lv_skip_count + 1.
    ENDTRY.

  ENDLOOP.

  " Restore
  gt_selected = lt_save_selected.

  " Final summary
  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } group(s) | &&
                   |for { lv_total_items } item(s)|.
    IF lv_skip_count > 0.
      lv_msg = lv_msg && |, { lv_skip_count } skipped|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent - check Distribution Lists' TYPE 'W'.
  ENDIF.

  p_rs_selfield_refresh = 'X'.

ENDFORM.
```

---

## 5. Layer 2 — DLI Reader Template

> **SBWP Distribution Lists** are maintained in transaction `SBWP` → *Distribution Lists*.
> Shared DLIs are visible to all users; personal DLIs belong to `sy-uname`.

```abap
FORM get_email_from_dli USING p_lv_dli_name.

  DATA: dli_entries          LIKE sodlienti1 OCCURS 0 WITH HEADER LINE,
        ls_recipient         TYPE ty_email_recipient,
        lv_dli_name_internal LIKE soobjinfi1-obj_name.

  CLEAR gt_recipients.
  lv_dli_name_internal = p_lv_dli_name.

  " --- Try SHARED DLI first ---
  CALL FUNCTION 'SO_DLI_READ_API1'
    EXPORTING
      dli_name                   = lv_dli_name_internal
      shared_dli                 = 'X'
    TABLES
      dli_entries                = dli_entries
    EXCEPTIONS
      dli_not_exist              = 1
      operation_no_authorization = 2
      parameter_error            = 3
      x_error                    = 4
      OTHERS                     = 5.

  " --- Fallback to PERSONAL DLI ---
  IF sy-subrc <> 0.
    REFRESH dli_entries.
    CALL FUNCTION 'SO_DLI_READ_API1'
      EXPORTING
        dli_name                   = lv_dli_name_internal
        shared_dli                 = ' '
      TABLES
        dli_entries                = dli_entries
      EXCEPTIONS
        dli_not_exist              = 1
        operation_no_authorization = 2
        parameter_error            = 3
        x_error                    = 4
        OTHERS                     = 5.
  ENDIF.

  IF sy-subrc <> 0.
    RETURN.   " DLI not found in either scope → empty gt_recipients
  ENDIF.

  " --- Extract email addresses ---
  LOOP AT dli_entries.
    IF dli_entries-member_adr IS NOT INITIAL.
      CLEAR ls_recipient.
      ls_recipient-recipient = dli_entries-member_adr.
      ls_recipient-name      = dli_entries-member_nam.
      APPEND ls_recipient TO gt_recipients.
    ENDIF.
  ENDLOOP.

ENDFORM.
```

### DLI Naming Conventions

| Pattern | Example | Use Case |
|---|---|---|
| `APPR_<plant3>` | `APPR_P01`, `APPR_P02` | Per-plant approval notifications |
| `NOTIF_<dept>` | `NOTIF_PPIC`, `NOTIF_FIN` | Department-level broadcasts |
| `ESC_<level>` | `ESC_L1`, `ESC_L2` | Escalation tiers |

> **Best Practice:** Agree on DLI naming convention with SAP Basis team and document in your project wiki. DLI names are **case-insensitive** but uppercase is conventional.

---

## 6. Layer 3 — HTML Builder (FIRST/BODY/LAST Pattern)

### Why Split into 3 Phases?

| Phase | Responsibility | Changes per Request? |
|---|---|---|
| `FIRST` | HTML skeleton, `<style>`, table headers | ❌ Static template |
| `BODY` | `<tr><td>…</td></tr>` from loop over `gt_selected` | ✅ Dynamic per dataset |
| `LAST` | Summary, signature, closing tags | ❌ Mostly static |

This separation lets you **reuse** FIRST/LAST across reports while only customizing BODY.

### Template

```abap
FORM build_email_html USING p_flag     TYPE string
                            p_date_str TYPE c
                            p_count    TYPE i
                   CHANGING pt_html    TYPE bcsy_text.

  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_alv_output,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string.

  lv_count_str = p_count.
  lv_date_str  = p_date_str.

  CASE p_flag.
    WHEN 'FIRST'.
      APPEND '<html>' TO pt_html.
      APPEND '<head>' TO pt_html.
      APPEND '<style type="text/css">' TO pt_html.
      APPEND 'body { font-family: Arial, sans-serif; font-size: 12px; }'
             TO pt_html.
      APPEND 'table { border-collapse: collapse; width: 100%; ' &&
             'border: 2px solid #000000; }' TO pt_html.
      APPEND 'th, td { padding: 8px; border: 1px solid #ddd; ' &&
             'text-align: left; word-break: break-word; }' TO pt_html.
      APPEND 'th { background-color: #FFD700; font-weight: bold; ' &&
             'color: #000000; }' TO pt_html.
      APPEND 'tr:nth-child(even) { background-color: #FFFFFF; }' TO pt_html.
      APPEND '.highlight { background-color: #fff2cc; }' TO pt_html.
      APPEND '</style></head><body>' TO pt_html.

      APPEND '<h2 style="color:#2E75B6;">Email Subject Header</h2>' TO pt_html.
      APPEND '<p>Dear Team,</p>' TO pt_html.
      APPEND '<p>Intro message describing the purpose...</p><br>' TO pt_html.

      APPEND '<table>' TO pt_html.
      APPEND '<tr>' TO pt_html.
      APPEND '<th>No</th>' TO pt_html.
      APPEND '<th>Work Order</th>' TO pt_html.
      APPEND '<th>Plant</th>' TO pt_html.
      " ... add more column headers ...
      APPEND '</tr>' TO pt_html.

    WHEN 'BODY'.
      CLEAR lv_counter.
      LOOP AT gt_selected INTO ls_data.
        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.

        " --- Convert numeric/alpha fields ---
        DATA: lv_aufnr_out TYPE string.
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING input  = ls_data-aufnr
          IMPORTING output = lv_aufnr_out.

        APPEND '<tr>' TO pt_html.

        CONCATENATE '<td style="text-align: center;">' lv_counter_str
                    '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td style="font-weight: bold;">' lv_aufnr_out
                    '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td class="highlight">' ls_data-pn_tasklist
                    '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        " ... more <td> cells per column ...

        APPEND '</tr>' TO pt_html.
      ENDLOOP.

    WHEN 'LAST'.
      APPEND '</table><br>' TO pt_html.

      APPEND '<p><b>Summary:</b></p><ul>' TO pt_html.
      CONCATENATE '<li>Total items: <b>' lv_count_str '</b></li>'
                  INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Date: <b>' lv_date_str '</b></li>'
                  INTO htmltag.
      APPEND htmltag TO pt_html.
      APPEND '</ul><br>' TO pt_html.

      APPEND '<p>Thank you,</p>' TO pt_html.
      DATA: lv_uname TYPE string.
      lv_uname = sy-uname.
      CONCATENATE '<p><b>' lv_uname
                  '</b><br>PT Your Company</p>' INTO htmltag.
      APPEND htmltag TO pt_html.

      APPEND '<hr><p style="font-size: 10px; color: #888888;">' TO pt_html.
      APPEND 'Automated email - please do not reply.</p>' TO pt_html.
      APPEND '</body></html>' TO pt_html.
  ENDCASE.

ENDFORM.
```

### CSS Style Cheat Sheet (Email-Safe)

| Purpose | Style |
|---|---|
| Header highlight | `background-color: #FFD700;` (gold) |
| Highlighted cell | `background-color: #fff2cc;` (soft yellow) |
| Alternate rows | `tr:nth-child(even) { background-color: #F8F8F8; }` |
| Bold label | `font-weight: bold;` |
| Centered number | `style="text-align: center;"` |
| Title color | `color: #2E75B6;` (corporate blue) |

> **Warning:** Many email clients (Outlook especially) strip `<style>` tags or ignore CSS selectors. For maximum compatibility, use **inline styles** (`style="..."`) on critical elements like `<td>`.

---

## 7. Layer 4 — BCS Sender Template

```abap
FORM send_email_bcs TABLES  pt_email   LIKE gt_recipients
                    USING   p_subject  TYPE so_obj_des
                            p_html_tab TYPE bcsy_text
                    RAISING cx_bcs.

  CHECK NOT pt_email[] IS INITIAL.

  DATA: lv_subject         TYPE so_obj_des,
        lo_email           TYPE REF TO cl_bcs,
        lo_email_body      TYPE REF TO cl_document_bcs,
        lo_receiver        TYPE REF TO if_recipient_bcs,
        lx_exception       TYPE REF TO cx_bcs,
        lo_internet_sender TYPE REF TO if_sender_bcs,
        l_address          TYPE adr6-smtp_addr,
        lv_send_result     TYPE c.

  TRY.
      " --- 1. Create email container ---
      lo_email   = cl_bcs=>create_persistent( ).
      lv_subject = p_subject.

      " --- 2. Create HTML document body ---
      lo_email_body = cl_document_bcs=>create_document(
        i_type    = 'HTM'              " Must be 'HTM' for HTML
        i_text    = p_html_tab
        i_subject = lv_subject ).

      lo_email->set_document( lo_email_body ).

      " --- 3. Set custom sender (optional) ---
      lo_internet_sender = cl_cam_address_bcs=>create_internet_address(
        i_address_string = 'noreply@yourcompany.com'
        i_address_name   = 'Your Company System' ).
      lo_email->set_sender( i_sender = lo_internet_sender ).

      " --- 4. Add recipients ---
      LOOP AT pt_email.
        l_address   = pt_email-recipient.
        lo_receiver = cl_cam_address_bcs=>create_internet_address( l_address ).
        lo_email->add_recipient( i_recipient = lo_receiver
                                 i_express   = 'X' ).   " Express flag
      ENDLOOP.

      " --- 5. Send immediately (bypass SOST queue) ---
      lo_email->set_send_immediately( 'X' ).

      lo_email->send(
        EXPORTING i_with_error_screen = 'X'
        RECEIVING result              = lv_send_result ).

      IF lv_send_result = 'X'.
        MESSAGE s000(db) WITH 'Email has been sent'.
      ENDIF.
      COMMIT WORK.

    CATCH cx_bcs INTO lx_exception.
      MESSAGE s000(db) WITH 'Email has not been sent'.
      RAISE EXCEPTION lx_exception.
  ENDTRY.

ENDFORM.
```

### BCS API Reference

| Class / Method | Purpose |
|---|---|
| `cl_bcs=>create_persistent( )` | Creates email object persisted in DB |
| `cl_document_bcs=>create_document` | Creates body — `i_type = 'HTM' / 'RAW'` |
| `cl_cam_address_bcs=>create_internet_address` | Creates SMTP recipient/sender |
| `lo_email->set_document( )` | Attaches body to email |
| `lo_email->set_sender( )` | Override system default sender |
| `lo_email->add_recipient( )` | Add TO recipient; `i_express='X'` for priority |
| `lo_email->set_send_immediately( 'X' )` | Force immediate send (bypass SOST) |
| `lo_email->send( )` | Dispatch — returns `'X'` on success |

> **Critical:** Always `COMMIT WORK` after `send()`. Without it, the email stays in queue and will not leave SAP.

---

## 8. SBWP / SOST Monitoring

After sending, monitor email delivery in:

| T-Code | Purpose |
|---|---|
| **SBWP** | SAP Business Workplace — user inbox/outbox |
| **SOST** | SAPconnect send requests monitor — see queued/sent/failed emails |
| **SCOT** | SAPconnect admin — verify SMTP node is active & green |
| **SMICM** | ICM monitor — confirm HTTP/SMTP services running |

### SOST Status Codes
| Status | Meaning |
|---|---|
| 🟢 Sent | Delivered to SMTP gateway |
| 🟡 Waiting | In queue (run `SCOT` → Send Now, or wait for schedule) |
| 🔴 Error | Check Basis logs; usually SMTP relay misconfig |

---

## 9. Anti-Patterns to Avoid

```abap
" ❌ WRONG: Forgetting COMMIT WORK after send
lo_email->send( ... ).
" Missing COMMIT → email stuck in queue, never leaves SAP

" ❌ WRONG: Using 'RAW' for HTML content
lo_email_body = cl_document_bcs=>create_document(
  i_type = 'RAW'    " Should be 'HTM' for HTML rendering
  i_text = p_html_tab ).

" ❌ WRONG: Hardcoding recipient list inside program
APPEND 'user@company.com' TO lt_recipients.
" → Changes require transport. Use DLI (maintained by end users in SBWP).

" ❌ WRONG: No fallback when DLI doesn't exist
" Always try shared → personal, and gracefully skip if both fail

" ❌ WRONG: Sending one email with all recipients mixed across groups
" → Privacy/context issues. Loop per group = separate email per context.

" ❌ WRONG: Ignoring cx_bcs exception
lo_email->send( ).   " No TRY…CATCH → runtime dump on SMTP failure

" ❌ WRONG: Not checking gt_recipients IS INITIAL before send
" BCS raises cx_bcs if no recipients; check first, skip gracefully

" ✅ CORRECT PATTERN
CHECK NOT pt_email[] IS INITIAL.
TRY.
    " ... build and send ...
    COMMIT WORK.
  CATCH cx_bcs INTO DATA(lx).
    " Log + skip + continue
ENDTRY.
```

---

## 10. Reusability Checklist

```
[ ] Define ty_email_recipient structure (recipient + name)
[ ] Define grouping type (e.g., by plant/dept/region)
[ ] Implement 4 FORMs: orchestrator, DLI reader, HTML builder, BCS sender
[ ] Establish DLI naming convention (e.g., PREFIX_<key>)
[ ] Create DLIs in SBWP (shared) — hand maintenance to functional team
[ ] HTML builder uses FIRST/BODY/LAST split for modularity
[ ] Apply inline CSS for Outlook compatibility
[ ] Use CONVERSION_EXIT_ALPHA_OUTPUT for WO/Equipment numbers
[ ] Handle cx_bcs exception with TRY…CATCH
[ ] Call COMMIT WORK after send()
[ ] Use i_express = 'X' for priority delivery
[ ] Skip groups with empty DLI (do not fail entire batch)
[ ] Log sent / skipped counts in final user message
[ ] Test via SOST before going live
[ ] Verify SCOT SMTP node is active in target system
```

---

## 11. Variations & Extensions

### A. Add Attachment (PDF, Excel, CSV)

```abap
DATA: lt_binary_content TYPE solix_tab,
      lv_file_size      TYPE so_obj_len.

" Convert binary data (e.g., from XLSX skill or SMARTFORMS PDF)
lo_email_body->add_attachment(
  i_attachment_type    = 'PDF'
  i_attachment_subject = 'Report.pdf'
  i_attachment_size    = lv_file_size
  i_att_content_hex    = lt_binary_content ).
```

### B. CC / BCC Recipients

```abap
lo_email->add_recipient(
  i_recipient = lo_receiver
  i_copy      = 'X' ).     " CC

lo_email->add_recipient(
  i_recipient = lo_receiver
  i_blind_copy = 'X' ).    " BCC
```

### C. Priority Flag

```abap
lo_email->set_priority( priority = '1' ).   " 1=High, 5=Low, 9=Lowest
```

### D. Read Receipt Request

```abap
lo_email->set_status_attributes(
  i_requested_status = 'E'     " E=Delivery, R=Read
  i_status_mail      = 'E' ).
```

### E. Single Email, Multiple Groups (CC Summary)

Instead of one email per group, build one master email listing all groups — useful for executive summaries. Skip the outer `LOOP AT lt_groups` and build all rows into one HTML.

---

## 12. Key Takeaways

```
1. BCS (cl_bcs) is the modern, recommended API — do NOT use SO_NEW_DOCUMENT_*
2. HTML requires i_type = 'HTM' on create_document
3. DLI = SBWP Distribution List — lets users self-manage recipients
4. Always COMMIT WORK after send( )
5. FIRST/BODY/LAST HTML pattern = modular + reusable
6. Group-based loops = cleaner segregation (one email per plant/dept)
7. TRY…CATCH cx_bcs on every send — never let BCS errors dump
8. Monitor via SOST after each test; check SCOT for SMTP health
9. Inline CSS survives Outlook; <style> blocks often don't
10. Fallback shared DLI → personal DLI for robust recipient lookup
```

---

*End of Document — Reusable Skill: ABAP Send Email using SBWP (BCS)*
