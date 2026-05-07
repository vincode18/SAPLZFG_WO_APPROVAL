*&---------------------------------------------------------------------*
*& Include  : LZFG_WO_APPROVALF03
*& Contains : Data Retrieval & Task List Comparison
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: load_wo_for_approval
*& Lock and read header for gv_aufnr. Validates WO exists and is open.
*&---------------------------------------------------------------------*
FORM load_wo_for_approval.

  DATA: ls_header  TYPE ztwoapprh,
        lv_lock_ok TYPE flag.

  " Lock WO object before read
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Read header
  SELECT SINGLE * FROM ztwoapprh
    INTO @ls_header
    WHERE aufnr = @gv_aufnr.
  IF sy-subrc <> 0.
    PERFORM unlock_wo.
    MESSAGE |Work Order { gv_aufnr } not found in approval system| TYPE 'E'.
    RETURN.
  ENDIF.

  gv_werks = ls_header-werks.

ENDFORM.

*&---------------------------------------------------------------------*
*& Bulk Comparison Pipeline (ported from report ZR_SVC_WO_APPROVAL_v8.5)
*&---------------------------------------------------------------------*
*&   fetch_component_data         RESB x VIAUFKS  -> gt_comp
*&   fetch_component_descriptions MAKT FOR ALL ENT -> gt_comp-maktx
*&   fetch_tasklist_data_bulk     PLMZ x STPO     -> gt_tasklist
*&   fetch_tasklist_descriptions  MAKT FOR ALL ENT -> gt_tasklist-maktx
*&   build_comparison_items       merge into gt_items_tc with binary search
*&   check_material_interchange   ZINCHG per row
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: fetch_component_data
*& Bulk RESB x VIAUFKS read for the s_aufnr range. Filters service orders
*& (autyp = '30') and excludes deletion-flagged components.
*&---------------------------------------------------------------------*
FORM fetch_component_data.

  CLEAR gt_comp.
  CHECK s_aufnr[] IS NOT INITIAL OR s_werks[] IS NOT INITIAL
     OR s_erdat[] IS NOT INITIAL OR s_aedat[] IS NOT INITIAL.

  IF s_aufnr[] IS INITIAL AND ( s_werks[] IS NOT INITIAL
      OR s_erdat[] IS NOT INITIAL OR s_aedat[] IS NOT INITIAL ).
    " Allow search by plant/date without explicit WO range
    SELECT r~aufnr,
           r~rsnum,
           r~rspos,
           r~matnr,
           r~bdmng,
           r~meins,
           v~plnnr,
           v~plnty,
           v~plnal,
           v~werks,
           a~sermat,
           c~erdat,
           c~aedat
      INTO CORRESPONDING FIELDS OF TABLE @gt_comp
      FROM resb AS r
      INNER JOIN viaufks AS v ON v~aufnr = r~aufnr
      INNER JOIN caufv   AS c ON c~aufnr = r~aufnr
      INNER JOIN afih    AS a ON a~aufnr = r~aufnr
      WHERE v~autyp  = '30'
        AND r~xloek  = @space
        AND v~werks  IN @s_werks
        AND c~erdat  IN @s_erdat
        AND c~aedat  IN @s_aedat.
  ELSEIF r_swerk IS INITIAL.
    SELECT r~aufnr,
           r~rsnum,
           r~rspos,
           r~matnr,
           r~bdmng,
           r~meins,
           v~plnnr,
           v~plnty,
           v~plnal,
           v~werks,
           a~sermat,
           c~erdat,
           c~aedat
      INTO CORRESPONDING FIELDS OF TABLE @gt_comp
      FROM resb AS r
      INNER JOIN viaufks AS v ON v~aufnr = r~aufnr
      INNER JOIN caufv   AS c ON c~aufnr = r~aufnr
      INNER JOIN afih    AS a ON a~aufnr = r~aufnr
      WHERE r~aufnr IN @s_aufnr
        AND v~autyp  = '30'
        AND r~xloek  = @space
        AND v~werks  IN @s_werks
        AND c~erdat  IN @s_erdat
        AND c~aedat  IN @s_aedat.
  ELSE.
    SELECT r~aufnr,
           r~rsnum,
           r~rspos,
           r~matnr,
           r~bdmng,
           r~meins,
           v~plnnr,
           v~plnty,
           v~plnal,
           v~werks,
           a~sermat,
           c~erdat,
           c~aedat
      INTO CORRESPONDING FIELDS OF TABLE @gt_comp
      FROM resb AS r
      INNER JOIN viaufks AS v ON v~aufnr = r~aufnr
      INNER JOIN caufv   AS c ON c~aufnr = r~aufnr
      INNER JOIN afih    AS a ON a~aufnr = r~aufnr
      WHERE r~aufnr IN @s_aufnr
        AND v~autyp  = '30'
        AND r~xloek  = @space
        AND v~werks  IN @r_swerk
        AND v~werks  IN @s_werks
        AND c~erdat  IN @s_erdat
        AND c~aedat  IN @s_aedat.
  ENDIF.

  IF gt_comp IS NOT INITIAL.
    PERFORM fetch_component_descriptions.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: fetch_component_descriptions
*& Enrich gt_comp with MAKTX from MAKT for all WO PNs in one shot.
*&---------------------------------------------------------------------*
FORM fetch_component_descriptions.

  TYPES: BEGIN OF lty_makt,
           matnr TYPE matnr,
           maktx TYPE maktx,
         END OF lty_makt.
  DATA: lt_makt TYPE TABLE OF lty_makt,
        ls_makt TYPE lty_makt.

  CHECK gt_comp IS NOT INITIAL.

  SELECT matnr, maktx
    INTO TABLE @lt_makt
    FROM makt
    FOR ALL ENTRIES IN @gt_comp
    WHERE matnr = @gt_comp-matnr
      AND spras = @sy-langu.

  LOOP AT gt_comp ASSIGNING FIELD-SYMBOL(<fs_comp>).
    READ TABLE lt_makt INTO ls_makt WITH KEY matnr = <fs_comp>-matnr.
    IF sy-subrc = 0.
      <fs_comp>-maktx = ls_makt-maktx.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: fetch_tasklist_data_bulk
*& Bulk PLMZ x STPO read for the tasklists referenced by gt_comp.
*& Path : VIAUFKS(PLNNR/PLNAL) -> PLMZ(STLNR) -> STPO(IDNRK)
*&---------------------------------------------------------------------*
FORM fetch_tasklist_data_bulk.

  CLEAR gt_tasklist.
  CHECK gt_comp IS NOT INITIAL.

  SELECT p~plnnr,
         p~plnal,
         p~stlnr,
         s~stlkn,
         s~idnrk,
         s~menge
    INTO CORRESPONDING FIELDS OF TABLE @gt_tasklist
    FROM plmz AS p
    INNER JOIN stpo AS s ON s~stlnr = p~stlnr
    FOR ALL ENTRIES IN @gt_comp
    WHERE p~plnnr = @gt_comp-plnnr
      AND p~plnal = @gt_comp-plnal
      AND s~lkenz <> 'X'.

  IF gt_tasklist IS NOT INITIAL.
    PERFORM fetch_tasklist_descriptions.
  ENDIF.

  " Sort for BINARY SEARCH in build_comparison_items
  SORT gt_tasklist BY plnnr plnal idnrk.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: fetch_tasklist_descriptions
*& Enrich gt_tasklist with MAKTX in one MAKT FOR ALL ENTRIES.
*&---------------------------------------------------------------------*
FORM fetch_tasklist_descriptions.

  TYPES: BEGIN OF lty_makt,
           matnr TYPE matnr,
           maktx TYPE maktx,
         END OF lty_makt.
  DATA: lt_makt TYPE TABLE OF lty_makt,
        ls_makt TYPE lty_makt.

  CHECK gt_tasklist IS NOT INITIAL.

  SELECT matnr, maktx
    INTO TABLE @lt_makt
    FROM makt
    FOR ALL ENTRIES IN @gt_tasklist
    WHERE matnr = @gt_tasklist-idnrk
      AND spras = @sy-langu.

  LOOP AT gt_tasklist ASSIGNING FIELD-SYMBOL(<fs_tl>).
    READ TABLE lt_makt INTO ls_makt WITH KEY matnr = <fs_tl>-idnrk.
    IF sy-subrc = 0.
      <fs_tl>-maktx = ls_makt-maktx.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: check_material_interchange
*& Look up ZINCHG (incode 018/016) for a row's WO PN.
*& Sets cs_item-interchange = 'Yes'/'No' and interchange_pn (SMATN).
*&---------------------------------------------------------------------*
FORM check_material_interchange CHANGING cs_item TYPE ty_items_tc.

  DATA lv_smatn TYPE matnr.

  SELECT SINGLE smatn
    INTO  @lv_smatn
    FROM  zinchg
    WHERE matwa  = @cs_item-matnr
      AND ( incode = '018' OR incode = '016' ).

  IF sy-subrc = 0.
    cs_item-interchange    = 'Yes'.
    cs_item-interchange_pn = lv_smatn.
  ELSE.
    cs_item-interchange    = 'No'.
    CLEAR cs_item-interchange_pn.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_comparison_items
*& Merge gt_comp + gt_tasklist into gt_items_tc using BINARY SEARCH on
*& (plnnr, plnal, idnrk). Sets comp_status / comp_match / is_mismatch and
*& restores any saved approval / reason data from ZTWOAPPR.
*& pv_mismatch returns the count of mismatches found.
*&---------------------------------------------------------------------*
FORM build_comparison_items
  CHANGING pv_mismatch TYPE i.

  DATA: ls_item TYPE ty_items_tc.

  pv_mismatch = 0.
  CLEAR gt_items_tc.

  CHECK gt_comp IS NOT INITIAL.

  " Pre-load ZTWOAPPR detail rows for all WOs in scope
  SELECT * FROM ztwoappr
    INTO TABLE @DATA(lt_appr)
    FOR ALL ENTRIES IN @gt_comp
    WHERE aufnr = @gt_comp-aufnr.

  LOOP AT gt_comp INTO gs_comp.
    CLEAR ls_item.

    " --- WO side ---
    ls_item-aufnr  = gs_comp-aufnr.
    ls_item-rsnum  = gs_comp-rsnum.
    ls_item-rspos  = gs_comp-rspos.
    ls_item-plnnr  = gs_comp-plnnr.
    ls_item-plnal  = gs_comp-plnal.
    ls_item-matnr  = gs_comp-matnr.
    ls_item-maktx  = gs_comp-maktx.
    ls_item-werks  = gs_comp-werks.
    ls_item-bdmng  = gs_comp-bdmng.
    ls_item-meins  = gs_comp-meins.
    ls_item-sermat = gs_comp-sermat.

    " --- TL side: binary-search match on (plnnr, plnal, idnrk = matnr) ---
    IF gs_comp-plnnr IS NOT INITIAL.
      READ TABLE gt_tasklist INTO gs_tasklist
        WITH KEY plnnr = gs_comp-plnnr
                 plnal = gs_comp-plnal
                 idnrk = gs_comp-matnr
        BINARY SEARCH.

      IF sy-subrc = 0.
        ls_item-comp_status   = 'X'.
        ls_item-comp_match    = 'Yes'.
        ls_item-pn_tasklist   = gs_tasklist-idnrk.
        ls_item-desc_tasklist = gs_tasklist-maktx.
        ls_item-menge_tl      = gs_tasklist-menge.
        ls_item-meins_tl      = gs_comp-meins.   " RESB UoM as ref
        ls_item-is_mismatch   = abap_false.
      ELSE.
        ls_item-comp_status = space.
        ls_item-comp_match  = 'No'.
        ls_item-is_mismatch = abap_true.
        pv_mismatch         = pv_mismatch + 1.
      ENDIF.
    ELSE.
      " No tasklist attached -> treat as mismatch
      ls_item-comp_status = space.
      ls_item-comp_match  = 'No'.
      ls_item-is_mismatch = abap_true.
      pv_mismatch         = pv_mismatch + 1.
    ENDIF.

    " --- Material interchange (ZINCHG) ---
    PERFORM check_material_interchange CHANGING ls_item.

    " --- Restore saved approval / reasons from ZTWOAPPR ---
    " Try exact-key match first (aufnr + matnr + change_id = rspos)
    READ TABLE lt_appr INTO DATA(ls_appr)
      WITH KEY aufnr     = gs_comp-aufnr
               matnr     = gs_comp-matnr
               change_id = gs_comp-rspos.
    IF sy-subrc = 0.
      ls_item-l1_approved   = ls_appr-approval_lvl1.
      ls_item-l3_approved   = ls_appr-approval_lvl3.
      ls_item-approval_stat = ls_appr-approval_stat.
      ls_item-reason_reject = ls_appr-reason_reject.
      ls_item-reason_change = ls_appr-reason_change.
    ENDIF.

    " Fallback: if no flags yet, scan for any approved row with same aufnr+matnr
    " (legacy records may have different/blank change_id but valid approval flags)
    IF ls_item-l1_approved = space AND ls_item-l3_approved = space.
      LOOP AT lt_appr INTO DATA(ls_appr2)
        WHERE aufnr = gs_comp-aufnr
          AND matnr = gs_comp-matnr
          AND ( approval_lvl1 = 'X' OR approval_lvl3 = 'X' ).
        ls_item-l1_approved   = ls_appr2-approval_lvl1.
        ls_item-l3_approved   = ls_appr2-approval_lvl3.
        ls_item-approval_stat = ls_appr2-approval_stat.
        IF ls_item-reason_reject IS INITIAL.
          ls_item-reason_reject = ls_appr2-reason_reject.
        ENDIF.
        IF ls_item-reason_change IS INITIAL.
          ls_item-reason_change = ls_appr2-reason_change.
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDIF.

    " appr_flag = 'X' if approved at any level (L1 both-live path OR L3 plant-only path)
    IF ls_item-l1_approved = 'X' OR ls_item-l3_approved = 'X'.
      ls_item-appr_flag = 'X'.
    ENDIF.

    APPEND ls_item TO gt_items_tc.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: compare_wo_vs_tasklist (compatibility wrapper)
*& Single-WO entrypoint kept for callers like load_items_for_email.
*& Builds an EQ range for one AUFNR and runs the bulk pipeline.
*& APPENDS into pt_items (does NOT clear) so the caller controls scope.
*&---------------------------------------------------------------------*
FORM compare_wo_vs_tasklist USING p_aufnr TYPE aufnr
                                  CHANGING pt_items TYPE STANDARD TABLE
                                           pv_mismatch TYPE i.

  DATA: lr_save       LIKE s_aufnr[],
        lr_save_werks LIKE s_werks[],
        lr_save_erdat LIKE s_erdat[],
        lr_save_aedat LIKE s_aedat[].

  " Preserve caller's filter ranges so this wrapper is reentrant
  lr_save       = s_aufnr[].
  lr_save_werks = s_werks[].
  lr_save_erdat = s_erdat[].
  lr_save_aedat = s_aedat[].

  " Set only the single WO 
  CLEAR s_aufnr.
  s_aufnr-sign = 'I'. s_aufnr-option = 'EQ'. s_aufnr-low = p_aufnr.
  APPEND s_aufnr TO s_aufnr.
  CLEAR: s_werks[], s_erdat[], s_aedat[].

  CLEAR gt_items_tc.
  PERFORM fetch_component_data.
  PERFORM fetch_tasklist_data_bulk.
  PERFORM build_comparison_items CHANGING pv_mismatch.
  " pt_items IS gt_items_tc (passed by reference) — build_comparison_items
  " already filled it directly; no APPEND needed.

  " Restore caller's range filters
  s_aufnr[]   = lr_save.
  s_werks[]   = lr_save_werks.
  s_erdat[]   = lr_save_erdat.
  s_aedat[]   = lr_save_aedat.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: open_selected_wo_pending
*& Called from Screen 0310 'Open WO' button (ok-code &SELECT / &IC1).
*& Reads the selected row from the ALV grid to resolve the AUFNR,
*& populates s_aufnr, sets gv_open_from_pending so STATUS_0300 PBO
*& will auto-trigger load_wo_range_for_approval, then navigates to 0300.
*&---------------------------------------------------------------------*
FORM open_selected_wo_pending USING pv_aufnr TYPE aufnr.
  DATA: lt_rows   TYPE lvc_t_row,
        ls_row    TYPE lvc_s_row,
        ls_wo     TYPE ztwoapprh,
        lv_aufnr  TYPE aufnr.

  " Resolve AUFNR: caller may pass it directly (double-click handler)
  " or leave it empty so we read the ALV selection (toolbar button).
  IF pv_aufnr IS NOT INITIAL.
    lv_aufnr = pv_aufnr.
  ELSE.
    IF gr_alv_0310 IS NOT BOUND.
      MESSAGE 'No pending list loaded. Please execute first.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    gr_alv_0310->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Please select a Work Order row first.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    READ TABLE lt_rows INTO ls_row INDEX 1.
    READ TABLE gt_pending_wo INTO ls_wo INDEX ls_row-index.
    IF sy-subrc <> 0.
      MESSAGE 'Selected row not found in pending list.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    lv_aufnr = ls_wo-aufnr.
  ENDIF.

  " Pad with leading zeros for internal format
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING  input  = lv_aufnr
    IMPORTING  output = lv_aufnr.

  " Populate s_aufnr for screen 0300 EXEC — wipe range table first
  CLEAR s_aufnr[].
  s_aufnr-sign   = 'I'.
  s_aufnr-option = 'EQ'.
  s_aufnr-low    = lv_aufnr.
  APPEND s_aufnr TO s_aufnr.

  " Clear previous WO data so stale table control rows do not persist
  CLEAR: gs_items_tc, gv_screen_locked, gv_aufnr, gv_werks.
  REFRESH gt_items_tc.

  " Signal PBO of 0300 to auto-load on first display
  gv_open_from_pending = abap_true.
  CLEAR gv_0300_initialized.

  SET SCREEN 0300. LEAVE SCREEN.
ENDFORM.