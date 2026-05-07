*&---------------------------------------------------------------------*
*& Report  RSDEMO_TABLE_CONTROL                                        *
*&                                                                     *
*&---------------------------------------------------------------------*
*&                                                                     *
*&                                                                     *
*&---------------------------------------------------------------------*

REPORT  RSDEMO_TABLE_CONTROL          .
CONTROLS TABLE_CONTROL TYPE TABLEVIEW USING SCREEN 100.
TABLES SDYN_SDW4.
DATA SDYN_ITAB LIKE STANDARD TABLE OF SDYN_SDW4.
DATA INIT.
DATA OK_CODE LIKE SY-UCOMM.
DATA SAVE_OK LIKE SY-UCOMM.
DATA MARK.
DATA  COL TYPE CXTAB_COLUMN.

CALL SCREEN 100.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE STATUS_0100 OUTPUT.
  SET PF-STATUS 'GRUND'.
  SET TITLEBAR '100'.
  IF INIT IS INITIAL.
* Datenbeschaffung
   SELECT CARRID CONNID CITYFROM AIRPFROM CITYTO DEPTIME ARRTIME
            FROM SPFLI
##TOO_MANY_ITAB_FIELDS
            INTO CORRESPONDING FIELDS OF TABLE SDYN_ITAB.
    DESCRIBE TABLE SDYN_ITAB LINES TABLE_CONTROL-LINES.
    INIT = 'X'.
  ENDIF.

ENDMODULE.                             " STATUS_0100  OUTPUT

*&---------------------------------------------------------------------*
*&      Module  FILL_TABLE_CONTROL  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
##NEEDED
MODULE CHANGE_SDYN_CONN OUTPUT.
* you can change the content of current table control line via
* sdyn_conn
*  READ TABLE sdyn_itab INTO sdyn_conn INDEX table_control-current_line.

ENDMODULE.                             " FILL_TABLE_CONTROL  OUTPUT
*&---------------------------------------------------------------------*
*&      Module  READ_TABLE_CONTROL  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE READ_TABLE_CONTROL INPUT.
* Check input values

  IF MARK = 'X' AND SAVE_OK = 'DELETE'.
    DELETE TABLE SDYN_ITAB FROM sdyn_sdw4.
    DESCRIBE TABLE SDYN_ITAB LINES TABLE_CONTROL-LINES.
  ENDIF.
ENDMODULE.                             " READ_TABLE_CONTROL  INPUT

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0100 INPUT.
  SAVE_OK = OK_CODE.
  CLEAR OK_CODE.
  CASE SAVE_OK.
    WHEN 'SORT'.
##NEEDED
      DATA: FLDNAME(100),HELP(100).

      READ TABLE TABLE_CONTROL-COLS INTO COL WITH KEY SELECTED = 'X'.
      SPLIT COL-SCREEN-NAME AT '-' INTO HELP FLDNAME.
      SORT SDYN_ITAB BY (FLDNAME).
  ENDCASE.

ENDMODULE.                             " USER_COMMAND_0100  INPUT

*&---------------------------------------------------------------------*
*&      Module  EXIT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE EXIT INPUT.
 LEAVE PROGRAM.
ENDMODULE.                 " EXIT  INPUT