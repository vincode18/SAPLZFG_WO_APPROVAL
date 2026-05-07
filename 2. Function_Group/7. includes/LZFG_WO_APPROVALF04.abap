*&---------------------------------------------------------------------*
*& Include  : LZFG_WO_APPROVALF04
*& Contains : WO Range Load & Table Control Support (v1.5 NEW)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: load_wo_range_for_approval
*& Load single or range of WOs into gt_items_tc.
*& v1.8: Pre-validate against ZTWOAPPRH — only WOs with APPR_STATUS
*&       submitted ('1') or approved ('2') are allowed. Typed single
*&       WOs not yet released via IW32 raise a user-friendly popup:
*&       "WO {aufnr}: Not yet submitted for approval. Please click Release in IW32 first."
*&---------------------------------------------------------------------*
FORM load_wo_range_for_approval.

  DATA: lv_mismatch_cnt TYPE i,
        lt_qualified    TYPE STANDARD TABLE OF aufnr,
        ls_qualified    TYPE aufnr,
        ls_aufnr_line   LIKE LINE OF s_aufnr,
        ls_aufnr_typed  LIKE LINE OF s_aufnr.

  IF s_aufnr[] IS INITIAL
    AND s_werks[] IS INITIAL
    AND s_erdat[] IS INITIAL
    AND s_aedat[] IS INITIAL.
    MESSAGE 'Enter at least a Work Order, Plant, Creation Date or Last Change Date' TYPE 'E'.
    RETURN.
  ENDIF.

  " v1.8: Pre-filter against ZTWOAPPRH — only process WOs already in the
  " approval pipeline (APPR_STATUS = submitted '1' or approved '2').
  IF r_swerk IS INITIAL.
    SELECT aufnr FROM ztwoapprh
      INTO TABLE @lt_qualified
      WHERE aufnr IN @s_aufnr
        AND werks IN @s_werks
        AND ( appr_status = @gc_appr_status-submitted
           OR appr_status = @gc_appr_status-approved ).
  ELSE.
    SELECT aufnr FROM ztwoapprh
      INTO TABLE @lt_qualified
      WHERE aufnr IN @s_aufnr
        AND werks IN @r_swerk
        AND werks IN @s_werks
        AND ( appr_status = @gc_appr_status-submitted
           OR appr_status = @gc_appr_status-approved ).
  ENDIF.

  DATA: lv_not_submitted TYPE string,
        lv_wo_display    TYPE char12,
        lv_wo_no_parts   TYPE string,
        lv_msg           TYPE string.
  LOOP AT s_aufnr INTO ls_aufnr_typed WHERE sign = 'I' AND option = 'EQ'.
    READ TABLE lt_qualified TRANSPORTING NO FIELDS
         WITH KEY table_line = ls_aufnr_typed-low.
    IF sy-subrc <> 0.
      lv_wo_display = ls_aufnr_typed-low.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = lv_wo_display
        IMPORTING
          output = lv_wo_display.

      IF lv_not_submitted IS INITIAL.
        lv_not_submitted = 'WO '.
        CONCATENATE lv_not_submitted lv_wo_display INTO lv_not_submitted
          SEPARATED BY space.
      ELSE.
        CONCATENATE lv_not_submitted ',' lv_wo_display INTO lv_not_submitted
          SEPARATED BY space.
      ENDIF.
    ENDIF.
  ENDLOOP.
  " Message for not submitted WO and still load qualified WO
  IF lv_not_submitted IS NOT INITIAL.
    CONCATENATE lv_not_submitted ': Not yet submitted for approval.'
                'Please click Release in IW32 first.'
                INTO lv_msg SEPARATED BY space.
    MESSAGE lv_msg TYPE 'I'.
*    CLEAR gt_items_tc.
*    RETURN.
  ENDIF.

  " Range / plant / date search with no explicit EQ single WOs
  IF lt_qualified IS INITIAL.
    CLEAR gt_items_tc.
    MESSAGE 'No submitted or approved WOs found for this selection' TYPE 'S'
            DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " Only the qualified WOs so the bulk pipeline
  CLEAR s_aufnr[].
  LOOP AT lt_qualified INTO ls_qualified.
    CLEAR ls_aufnr_line.
    ls_aufnr_line-sign   = 'I'.
    ls_aufnr_line-option = 'EQ'.
    ls_aufnr_line-low    = ls_qualified.
    APPEND ls_aufnr_line TO s_aufnr.
  ENDLOOP.

  " Bulk pipeline
  PERFORM fetch_component_data.

  IF gt_comp IS INITIAL.
    CLEAR gt_items_tc.
    LOOP AT s_aufnr INTO ls_aufnr_line WHERE sign = 'I' AND option = 'EQ'.
      lv_wo_display = ls_aufnr_line-low.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING  input  = lv_wo_display
        IMPORTING  output = lv_wo_display.
      IF lv_wo_no_parts IS INITIAL.
        lv_wo_no_parts = lv_wo_display.
      ELSE.
        CONCATENATE lv_wo_no_parts ', ' lv_wo_display INTO lv_wo_no_parts.
      ENDIF.
    ENDLOOP.
    IF lv_wo_no_parts IS NOT INITIAL.
      CONCATENATE 'No component parts (RESB) found for WO' lv_wo_no_parts
                  '— Ensure parts are assigned to the Work Order in IW32.'
                  INTO lv_msg SEPARATED BY space.
    ELSE.
      lv_msg = 'No component parts found for this selection. Ensure parts are assigned in IW32.'.
    ENDIF.
    MESSAGE lv_msg TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  PERFORM fetch_tasklist_data_bulk.
  PERFORM build_comparison_items CHANGING lv_mismatch_cnt.

  " Lock all WOs in scope (header lock per WO)
  SORT gt_comp BY aufnr.
  CLEAR gv_locked.
  DATA lv_lock_failed TYPE flag.
  CLEAR lv_lock_failed.
  LOOP AT gt_comp INTO gs_comp.
    AT NEW aufnr.
      gv_aufnr = gs_comp-aufnr.
      DATA(lv_lock_ok) = ''.
      PERFORM lock_wo_object CHANGING lv_lock_ok.
      IF lv_lock_ok = 'X'.
        gv_locked = 'X'.   " mark global so unlock_wo can DEQUEUE on BACK
      ELSE.
        lv_lock_failed = 'X'.
      ENDIF.
    ENDAT.
  ENDLOOP.

  " If any WO is locked by another session (e.g. open in IW32), abort the load
  IF lv_lock_failed = 'X'.
    PERFORM unlock_wo.   " release any partially held locks and clean state
    SET SCREEN 0310. 
    LEAVE SCREEN.
  ENDIF.

  " v1.5: L1 (BCSPPD) sees ONLY mismatch (red) rows
  IF gv_user_level = gc_user_lvl-l1.
    DELETE gt_items_tc WHERE is_mismatch = abap_false.
  ENDIF.

  IF gt_items_tc IS INITIAL.
    MESSAGE 'No items to display (L1: no mismatches found in range)' TYPE 'S'
            DISPLAY LIKE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_items_for_email
*& Load approved items for Screen 0330 email send.
*& Uses gv_aufnr set from p_wo_mail.
*&---------------------------------------------------------------------*
FORM load_items_for_email.

  DATA: lv_mismatch_cnt TYPE i.

  IF gv_aufnr IS INITIAL.
    MESSAGE 'Enter a Work Order number' TYPE 'E'.
    RETURN.
  ENDIF.

  CLEAR gt_items_tc.
  PERFORM compare_wo_vs_tasklist USING gv_aufnr CHANGING gt_items_tc lv_mismatch_cnt.

  " Pre-mark all rows for email
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls>).
    <ls>-mark = 'X'.
  ENDLOOP.

ENDFORM.