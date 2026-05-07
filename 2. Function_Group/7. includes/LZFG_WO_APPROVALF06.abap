*&---------------------------------------------------------------------*
*& Include  : LZFG_WO_APPROVALF06
*& Contains : HTML Builder (Layer 3) & BCS Sender (Layer 4)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: build_email_html   (LAYER 3)
*& FIRST/BODY/LAST pattern.
*& v1.5: Added Reason Rejection + Reason Change columns to table header/body.
*&---------------------------------------------------------------------*
FORM build_email_html
  USING    p_flag      TYPE string
           p_date_str  TYPE c
           p_count     TYPE i
           p_type      TYPE char2
           p_werks     TYPE werks_d
  CHANGING pt_html     TYPE bcsy_text.

  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_items_tc,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string,
        lv_bdmng_str   TYPE string,
        lv_menge_str   TYPE string,
        lv_matnr_out   TYPE string,
        lv_aufnr_out   TYPE string,
        lv_reason_rej  TYPE string,
        lv_reason_chg  TYPE string,
        lv_uname       TYPE string.

  lv_count_str = p_count.
  lv_date_str  = p_date_str.

  CASE p_flag.

    WHEN 'FIRST'.
      APPEND '<html>' TO pt_html.
      APPEND '<head><style type="text/css">' TO pt_html.
      APPEND 'body{font-family:Arial,sans-serif;font-size:12px;}' TO pt_html.
      APPEND 'table{border-collapse:collapse;width:100%;border:2px solid #000;}' TO pt_html.
      APPEND 'th,td{padding:8px;border:1px solid #ddd;text-align:left;}' TO pt_html.
      APPEND 'th{background-color:#003399;color:white;font-weight:bold;}' TO pt_html.
      APPEND 'tr:nth-child(even){background-color:#F8F8F8;}' TO pt_html.
      APPEND '.mismatch{background-color:#ffcccc;}' TO pt_html.
      APPEND '.match{background-color:#e6ffe6;}' TO pt_html.
      APPEND '</style></head><body>' TO pt_html.

      IF p_type = 'HO'.
        APPEND '<h2 style="color:#003399;">Work Order Approval Request</h2>' TO pt_html.
        APPEND '<p>Dear <b>BCSPPD HO Team</b>,</p>' TO pt_html.
        APPEND '<p>The following Work Order components require your review.</p>' TO pt_html.
      ELSE.
        APPEND '<h2 style="color:#009933;">Work Order Fully Approved</h2>' TO pt_html.
        APPEND '<p>Dear <b>Branch Team</b>,</p>' TO pt_html.
        APPEND '<p>The following Work Order has been fully approved.</p>' TO pt_html.
      ENDIF.

      CONCATENATE '<p><b>Plant:</b> ' p_werks
                  ' | <b>Date:</b> ' p_date_str
                  ' | <b>Items:</b> ' lv_count_str
                  '</p><br>' INTO htmltag.
      APPEND htmltag TO pt_html.

      " v1.5: Added Reason Rejection + Reason Change columns
      APPEND '<table><tr>' TO pt_html.
      APPEND '<th style="text-align:center;">No</th>' TO pt_html.
      APPEND '<th>Work Order</th>' TO pt_html.
      APPEND '<th style="text-align:center;">Plant</th>' TO pt_html.
      APPEND '<th style="min-width:110px;">Material</th>' TO pt_html.
      APPEND '<th style="min-width:150px;">Description</th>' TO pt_html.
      APPEND '<th style="text-align:right;">WO Qty</th>' TO pt_html.
      APPEND '<th style="text-align:right;">TL Qty</th>' TO pt_html.
      APPEND '<th style="text-align:center;">Status</th>' TO pt_html.
      APPEND '<th>Reason Rejection</th>' TO pt_html.
      APPEND '<th>Reason Change</th></tr>' TO pt_html.

    WHEN 'BODY'.
      CLEAR lv_counter.
      LOOP AT gt_selected INTO ls_data.
        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING input = gv_aufnr IMPORTING output = lv_aufnr_out.
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
          EXPORTING input = ls_data-matnr IMPORTING output = lv_matnr_out.

        lv_bdmng_str = ls_data-bdmng.
        lv_menge_str = ls_data-menge_tl.
        CONDENSE: lv_bdmng_str, lv_menge_str.

        IF ls_data-is_mismatch = abap_true.
          APPEND '<tr class="mismatch">' TO pt_html.
        ELSE.
          APPEND '<tr class="match">' TO pt_html.
        ENDIF.

        CONCATENATE '<td style="text-align:center;">' lv_counter_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="font-weight:bold;">' lv_aufnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="text-align:center;">' ls_data-werks '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' lv_matnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' ls_data-maktx '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="text-align:right;">' lv_bdmng_str ' ' ls_data-meins '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        IF ls_data-menge_tl IS INITIAL.
          APPEND '<td style="text-align:center;">-</td>' TO pt_html.
        ELSE.
          CONCATENATE '<td style="text-align:right;">' lv_menge_str ' ' ls_data-meins_tl '</td>' INTO htmltag.
          APPEND htmltag TO pt_html.
        ENDIF.

        IF ls_data-is_mismatch = abap_true.
          APPEND '<td style="color:red;text-align:center;"><b>MISMATCH</b></td>' TO pt_html.
        ELSE.
          APPEND '<td style="color:green;text-align:center;">MATCH</td>' TO pt_html.
        ENDIF.

        " v1.5: Reason Rejection column
        lv_reason_rej = COND #( WHEN ls_data-reason_reject IS NOT INITIAL
                                THEN ls_data-reason_reject
                                ELSE '-' ).
        CONCATENATE '<td>' lv_reason_rej '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        " v1.5: Reason Change column
        lv_reason_chg = COND #( WHEN ls_data-reason_change IS NOT INITIAL
                                THEN ls_data-reason_change
                                ELSE '-' ).
        CONCATENATE '<td>' lv_reason_chg '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        APPEND '</tr>' TO pt_html.
      ENDLOOP.

    WHEN 'LAST'.
      APPEND '</table><br>' TO pt_html.
      APPEND '<p><b>Summary:</b></p><ul>' TO pt_html.
      CONCATENATE '<li>Total items: <b>' lv_count_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Plant: <b>' p_werks '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Date: <b>' p_date_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      APPEND '</ul><br>' TO pt_html.

      IF p_type = 'HO'.
        APPEND '<p><b>Action:</b> Please review in transaction <b>ZWOAPP</b>.</p>' TO pt_html.
      ELSE.
        APPEND '<p>Please proceed with material issue and execution.</p>' TO pt_html.
      ENDIF.

      APPEND '<p>Thank you,</p>' TO pt_html.
      lv_uname = sy-uname.
      CONCATENATE '<p><b>' lv_uname '</b><br>WO Approval System</p>' INTO htmltag.
      APPEND htmltag TO pt_html.
      APPEND '<hr><p style="font-size:10px;color:#888;">Automated email — do not reply.</p>' TO pt_html.
      APPEND '</body></html>' TO pt_html.

  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_email_html_plant   (v1.7.2 — LAYER 3, L1→Branch direction)
*& FIRST/BODY/LAST pattern.
*& Used when gv_send_mode = 'BR': HO sends approval result to Branch.
*& Greeting: "Dear Tim Cabang" | Header: #009933 green | TH BG: #FFD700 gold.
*& Adapted from ZR_SVC_WO_APPROVAL_v8.5 — uses ty_items_tc (Function Group type).
*&---------------------------------------------------------------------*
FORM build_email_html_plant
  USING    p_flag     TYPE string
           p_date_str TYPE c
           p_count    TYPE i
  CHANGING pt_html    TYPE bcsy_text.

  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_items_tc,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string,
        lv_bdmng_str   TYPE string,
        lv_menge_str   TYPE string,
        lv_matnr_out   TYPE string,
        lv_aufnr_out   TYPE string,
        lv_reason_rej  TYPE string,
        lv_reason_chg  TYPE string.

  lv_count_str = p_count.
  lv_date_str  = p_date_str.

  CASE p_flag.

    WHEN 'FIRST'.
      APPEND '<html>' TO pt_html.
      APPEND '<head><style type="text/css">' TO pt_html.
      APPEND 'body { font-family: Arial, sans-serif; font-size: 12px; }' TO pt_html.
      APPEND 'table { border-collapse: collapse; font-family: Arial, sans-serif; width: 100%; border: 2px solid #000000; }' TO pt_html.
      APPEND 'th, td { padding: 8px; border: 1px solid #000000; text-align: left; word-break: break-word; }' TO pt_html.
      APPEND 'th { background-color: #FFD700; font-weight: bold; color: #000000; }' TO pt_html.
      APPEND 'tr:nth-child(even) { background-color: #FFFFFF; }' TO pt_html.
      APPEND 'tr:hover { background-color: #e8f4fc; }' TO pt_html.
      APPEND '.mismatch { background-color: #ffcccc; }' TO pt_html.
      APPEND '.match { background-color: #e6ffe6; }' TO pt_html.
      APPEND '</style></head><body>' TO pt_html.

      APPEND '<h2 style="color:#009933;">Service WO Component Approval</h2>' TO pt_html.
      APPEND '<p>Dear <b>Tim Cabang</b>,</p>' TO pt_html.
      APPEND '<p>Bersama ini kami sampaikan hasil review dan Approval PN yang tidak sesuai ' TO pt_html.
      APPEND 'dengan Bill Of Material Tasklist sebagai berikut:</p><br>' TO pt_html.

      APPEND '<table><tr>' TO pt_html.
      APPEND '<th style="text-align:center;">No</th>' TO pt_html.
      APPEND '<th>Work Order</th>' TO pt_html.
      APPEND '<th style="text-align:center;">Plant</th>' TO pt_html.
      APPEND '<th style="min-width:110px;">Material</th>' TO pt_html.
      APPEND '<th style="min-width:150px;">Description</th>' TO pt_html.
      APPEND '<th style="text-align:right;">WO Qty</th>' TO pt_html.
      APPEND '<th style="text-align:right;">TL Qty</th>' TO pt_html.
      APPEND '<th style="text-align:center;">Status</th>' TO pt_html.
      APPEND '<th>Reason Rejection</th>' TO pt_html.
      APPEND '<th>Reason Change</th></tr>' TO pt_html.

    WHEN 'BODY'.
      CLEAR lv_counter.
      LOOP AT gt_selected INTO ls_data.
        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING input = ls_data-aufnr IMPORTING output = lv_aufnr_out.
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
          EXPORTING input = ls_data-matnr IMPORTING output = lv_matnr_out.

        lv_bdmng_str = ls_data-bdmng.
        lv_menge_str = ls_data-menge_tl.
        CONDENSE: lv_bdmng_str, lv_menge_str.

        IF ls_data-is_mismatch = abap_true.
          APPEND '<tr class="mismatch">' TO pt_html.
        ELSE.
          APPEND '<tr class="match">' TO pt_html.
        ENDIF.

        CONCATENATE '<td style="text-align:center;">' lv_counter_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="font-weight:bold;">' lv_aufnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="text-align:center;">' ls_data-werks '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' lv_matnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' ls_data-maktx '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="text-align:right;">' lv_bdmng_str ' ' ls_data-meins '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        IF ls_data-menge_tl IS INITIAL.
          APPEND '<td style="text-align:center;">-</td>' TO pt_html.
        ELSE.
          CONCATENATE '<td style="text-align:right;">' lv_menge_str ' ' ls_data-meins_tl '</td>' INTO htmltag.
          APPEND htmltag TO pt_html.
        ENDIF.

        IF ls_data-is_mismatch = abap_true.
          APPEND '<td style="color:red;text-align:center;"><b>MISMATCH</b></td>' TO pt_html.
        ELSE.
          APPEND '<td style="color:green;text-align:center;">MATCH</td>' TO pt_html.
        ENDIF.

        lv_reason_rej = COND #( WHEN ls_data-reason_reject IS NOT INITIAL
                                THEN ls_data-reason_reject ELSE '-' ).
        CONCATENATE '<td>' lv_reason_rej '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        lv_reason_chg = COND #( WHEN ls_data-reason_change IS NOT INITIAL
                                THEN ls_data-reason_change ELSE '-' ).
        CONCATENATE '<td>' lv_reason_chg '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        APPEND '</tr>' TO pt_html.
      ENDLOOP.

    WHEN 'LAST'.
      APPEND '</table><br>' TO pt_html.
      APPEND '<p>Silahkan dilanjutkan untuk Approval berikutnya untuk WO yang sudah kami Approve.</p>' TO pt_html.
      APPEND '<p>Untuk WO Reject silakan ubah PN sesuai dengan BOM Tasklist nya.</p><br>' TO pt_html.

      APPEND '<p><b>Ringkasan:</b></p><ul>' TO pt_html.
      CONCATENATE '<li>Total item: <b>' lv_count_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Tanggal notifikasi: <b>' lv_date_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      APPEND '</ul><br>' TO pt_html.

      APPEND '<p>Best Regards,</p>' TO pt_html.
      APPEND '<p><b>BCSPPD HO Team</b></p><br><hr>' TO pt_html.
      APPEND '<p style="font-size:10px;color:#888888;">Automated email — do not reply.</p>' TO pt_html.
      APPEND '</body></html>' TO pt_html.

  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: send_email_bcs   (LAYER 4)
*& Send HTML email via CL_BCS. COMMIT WORK after send.
*&---------------------------------------------------------------------*
FORM send_email_bcs
  TABLES  pt_email   LIKE gt_recipients
  USING   p_subject  TYPE so_obj_des
          p_html_tab TYPE bcsy_text
  RAISING cx_bcs.

  CHECK NOT pt_email[] IS INITIAL.

  DATA: lo_email           TYPE REF TO cl_bcs,
        lo_email_body      TYPE REF TO cl_document_bcs,
        lo_receiver        TYPE REF TO if_recipient_bcs,
        lo_internet_sender TYPE REF TO if_sender_bcs,
        l_address          TYPE adr6-smtp_addr,
        lv_send_result     TYPE c.

  TRY.
      lo_email = cl_bcs=>create_persistent( ).

      lo_email_body = cl_document_bcs=>create_document(
        i_type    = 'HTM'
        i_text    = p_html_tab
        i_subject = p_subject ).

      lo_email->set_document( lo_email_body ).

      lo_internet_sender = cl_cam_address_bcs=>create_internet_address(
        i_address_string = 'mail_sap@unitedtractors.com'
        i_address_name   = 'PT. United Tractors Tbk' ).
      lo_email->set_sender( i_sender = lo_internet_sender ).

      LOOP AT pt_email.
        l_address   = pt_email-recipient.
        lo_receiver = cl_cam_address_bcs=>create_internet_address( l_address ).
        lo_email->add_recipient(
          i_recipient = lo_receiver
          i_express   = 'X' ).
      ENDLOOP.

      lo_email->set_send_immediately( 'X' ).

      lo_email->send(
        EXPORTING i_with_error_screen = 'X'
        RECEIVING result              = lv_send_result ).

      COMMIT WORK.

    CATCH cx_bcs INTO DATA(lx).
      RAISE EXCEPTION lx.
  ENDTRY.

ENDFORM.
