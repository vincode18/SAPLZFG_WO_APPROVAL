*&---------------------------------------------------------------------*
*& Include  : LZFG_WO_APPROVALF05
*& Contains : Email Orchestration — LAYER 1 (Manual trigger from 0330)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: process_send_email
*& Layer 1 — Orchestrator.
*& Groups marked items by plant, reads DLI per plant, builds & sends HTML.
*& pv_email_type: 'HO' = BCSPPD HO recipients, 'BR' = Branch recipients.
*&---------------------------------------------------------------------*
FORM process_send_email USING pv_email_type TYPE char2.

  TYPES: BEGIN OF ty_group,
           werks TYPE werks_d,
         END OF ty_group.

  DATA: lt_groups     TYPE STANDARD TABLE OF ty_group,
        ls_group      TYPE ty_group,
        lt_html       TYPE bcsy_text,
        lv_subject    TYPE so_obj_des,
        lv_date_str   TYPE char10,
        lv_item_count TYPE i,
        lv_total_sent TYPE i,
        lv_skip_count TYPE i,
        lt_save_sel   TYPE STANDARD TABLE OF ty_items_tc,
        lv_dli_name   TYPE so_recname,
        lv_werks3     TYPE char3.

  " Work on marked rows only
  gt_selected = gt_items_tc.
  DELETE gt_selected WHERE mark <> 'X'.

  IF gt_selected IS INITIAL.
    MESSAGE 'No items selected for email. Mark at least one row.' TYPE 'E'.
    RETURN.
  ENDIF.

  lt_save_sel = gt_selected.

  " Group by WERKS
  LOOP AT gt_selected INTO DATA(ls_item).
    READ TABLE lt_groups INTO ls_group WITH KEY werks = ls_item-werks.
    IF sy-subrc <> 0.
      ls_group-werks = ls_item-werks.
      APPEND ls_group TO lt_groups.
    ENDIF.
  ENDLOOP.

  lv_date_str = |{ sy-datum DATE = USER }|.

  LOOP AT lt_groups INTO ls_group.

    gt_selected = lt_save_sel.
    DELETE gt_selected WHERE werks <> ls_group-werks.
    DESCRIBE TABLE gt_selected LINES lv_item_count.

    " Build DLI name: APPR_<WERKS3>_<HO|BR>
    lv_werks3  = ls_group-werks+1(3).   " e.g. plant '1000' -> '000' or use right 3 chars
    lv_werks3  = ls_group-werks.         " use full WERKS if 4-char e.g. '1000'
    CONDENSE lv_werks3.
    lv_dli_name = |APPR_{ lv_werks3 }_{ pv_email_type }|.

    " Layer 2 — Read DLI
    PERFORM get_email_from_dli USING lv_dli_name.

    IF gt_recipients IS INITIAL.
      MESSAGE |No DLI found: { lv_dli_name } — skipping plant { ls_group-werks }|
              TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " Email subject
    IF pv_email_type = 'HO'.
      lv_subject = |WO Approval Request — Plant { ls_group-werks } ({ lv_date_str })|.
    ELSE.
      lv_subject = |WO Approved — Plant { ls_group-werks } ({ lv_date_str })|.
    ENDIF.

    " Layer 3 — Build HTML
    CLEAR lt_html.
    PERFORM build_email_html USING 'FIRST' lv_date_str lv_item_count
                                          pv_email_type ls_group-werks
                               CHANGING lt_html.
    PERFORM build_email_html USING 'BODY'  lv_date_str lv_item_count
                                          pv_email_type ls_group-werks
                               CHANGING lt_html.
    PERFORM build_email_html USING 'LAST'  lv_date_str lv_item_count
                                          pv_email_type ls_group-werks
                               CHANGING lt_html.

    " Layer 4 — Send
    TRY.
        PERFORM send_email_bcs TABLES gt_recipients
                               USING  lv_subject lt_html.
        lv_total_sent = lv_total_sent + 1.
      CATCH cx_bcs INTO DATA(lx_bcs).
        MESSAGE |Send error for { ls_group-werks }: { lx_bcs->get_text( ) }|
                TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_count = lv_skip_count + 1.
    ENDTRY.

  ENDLOOP.

  gt_selected = lt_save_sel.

  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } plant(s)|.
    IF lv_skip_count > 0.
      lv_msg = lv_msg && |, { lv_skip_count } skipped — check SBWP DLI|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent — verify SBWP Distribution Lists (APPR_<WERKS>_HO/BR)'
            TYPE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: get_email_from_dli   (LAYER 2)
*& Try Shared DLI first, then Personal DLI. Fills gt_recipients.
*&---------------------------------------------------------------------*
FORM get_email_from_dli USING p_dli_name TYPE so_recname.

  DATA: dli_entries          LIKE sodlienti1 OCCURS 0 WITH HEADER LINE,
        ls_recipient         TYPE ty_email_recipient,
        lv_dli_name_internal LIKE soobjinfi1-obj_name.

  CLEAR gt_recipients.
  lv_dli_name_internal = p_dli_name.

  " Try SHARED DLI first
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

  " Fallback to PERSONAL DLI
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
    RETURN.   " gt_recipients stays empty
  ENDIF.

  LOOP AT dli_entries.
    IF dli_entries-member_adr IS NOT INITIAL.
      CLEAR ls_recipient.
      ls_recipient-recipient = dli_entries-member_adr.
      ls_recipient-name      = dli_entries-member_nam.
      APPEND ls_recipient TO gt_recipients.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: process_send_email_grouped   (v1.6)
*&
*& Subject lines (mirroring report ZR_SVC_WO_APPROVAL):
*&   HO mode -> "Service WO Approval - <n> Item(s)
*&   BR mode -> "Service WO Approval - <n> Item(s)
*&
*& DLI naming convention:
*&   APPR_<WERKS>_HO  - HO recipients (Branch -> HO emails)
*&   APPR_<WERKS>_BR  - Branch recipients (HO -> Branch emails)
*&---------------------------------------------------------------------*
FORM process_send_email_grouped USING pv_email_type TYPE char2.

  TYPES: BEGIN OF lty_group,
           werks TYPE werks_d,
         END OF lty_group.

  DATA: lt_groups     TYPE STANDARD TABLE OF lty_group,
        ls_group      TYPE lty_group,
        lt_plant_wos  TYPE STANDARD TABLE OF ty_appr_ready,
        lt_html       TYPE bcsy_text,
        lv_subject    TYPE so_obj_des,
        lv_dli_name   TYPE so_recname,
        lv_date_str   TYPE char10,
        lv_item_count TYPE i,
        lv_total_sent TYPE i,
        lv_skip_count TYPE i,
        lv_save_aufnr TYPE aufnr,
        lt_marked     TYPE STANDARD TABLE OF ty_appr_ready.

  " 1. Sanity: any selected WOs?
  CLEAR lt_marked.
  LOOP AT gt_appr_ready INTO DATA(ls_row) WHERE mark = 'X'.
    APPEND ls_row TO lt_marked.
  ENDLOOP.

  IF lt_marked IS INITIAL.
    MESSAGE 'Please mark at least one WO row before pressing Send' TYPE 'E'.
    RETURN.
  ENDIF.

  " 2. Build distinct plant list
  LOOP AT lt_marked INTO ls_row.
    READ TABLE lt_groups WITH KEY werks = ls_row-werks TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_group-werks = ls_row-werks.
      APPEND ls_group TO lt_groups.
    ENDIF.
  ENDLOOP.

  WRITE sy-datum TO lv_date_str DD/MM/YYYY.
  lv_save_aufnr = gv_aufnr.

  " 3. Send one email per plant
  LOOP AT lt_groups INTO ls_group.

    " 3a. Collect WOs for this plant
    CLEAR lt_plant_wos.
    LOOP AT lt_marked INTO ls_row WHERE werks = ls_group-werks.
      APPEND ls_row TO lt_plant_wos.
    ENDLOOP.
    DESCRIBE TABLE lt_plant_wos LINES lv_item_count.
    CHECK lv_item_count > 0.

    " 3b. Materialize per-component detail for ALL WOs of this plant
    "     into gt_selected. The HTML builder reads gt_selected.
    CLEAR gt_selected.
    LOOP AT lt_plant_wos INTO ls_row.
      gv_aufnr = ls_row-aufnr.
      PERFORM load_items_for_email.            " existing 
      APPEND LINES OF gt_items_tc TO gt_selected.
    ENDLOOP.

    " 3c. Resolve recipients via shared SBWP DLI
    " HO  = single shared DLI  : APPR_HO
    " Branch = per-plant DLI   : APPR_{WERKS}
    IF pv_email_type = gc_send_mode-ho.
      lv_dli_name = 'APPR_HO'.
    ELSE.
      CONCATENATE 'APPR_' ls_group-werks INTO lv_dli_name.
    ENDIF.
    PERFORM get_email_from_dli USING lv_dli_name.

    IF gt_recipients IS INITIAL.
      MESSAGE |No DLI { lv_dli_name } - plant { ls_group-werks } skipped|
              TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " 3d. Subject Email
    IF pv_email_type = gc_send_mode-ho.
      lv_subject = |Approval WO - From { ls_group-werks }|.
    ELSE.
      lv_subject = |Review Approval WO From HO|.
    ENDIF.

    " 3e. Build HTML body
    CLEAR lt_html.
    IF pv_email_type = gc_send_mode-br.
      " L1 BCSPPD to Branch: approval result notification
      PERFORM build_email_html_plant USING 'FIRST' lv_date_str lv_item_count
                                     CHANGING lt_html.
      PERFORM build_email_html_plant USING 'BODY'  lv_date_str lv_item_count
                                     CHANGING lt_html.
      PERFORM build_email_html_plant USING 'LAST'  lv_date_str lv_item_count
                                     CHANGING lt_html.
    ELSE.
      " L4(BRANCH) to BCSPPD HO: review request
      PERFORM build_email_html USING 'FIRST' lv_date_str lv_item_count
                                     pv_email_type ls_group-werks
                              CHANGING lt_html.
      PERFORM build_email_html USING 'BODY'  lv_date_str lv_item_count
                                     pv_email_type ls_group-werks
                              CHANGING lt_html.
      PERFORM build_email_html USING 'LAST'  lv_date_str lv_item_count
                                     pv_email_type ls_group-werks
                              CHANGING lt_html.
    ENDIF.

    " 3f. Send
    TRY.
        PERFORM send_email_bcs TABLES gt_recipients
                               USING lv_subject lt_html.
        lv_total_sent = lv_total_sent + 1.
      CATCH cx_bcs INTO DATA(lx).
        MESSAGE |Send error for plant { ls_group-werks }: { lx->get_text( ) }|
                TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_count = lv_skip_count + 1.
    ENDTRY.

  ENDLOOP.

  gv_aufnr = lv_save_aufnr.

  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } plant(s)|.
    IF lv_skip_count > 0.
      lv_msg = lv_msg && |, { lv_skip_count } skipped|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent — verify SBWP Distribution Lists' TYPE 'W'.
  ENDIF.

ENDFORM.