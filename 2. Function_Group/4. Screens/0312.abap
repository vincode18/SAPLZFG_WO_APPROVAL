*&---------------------------------------------------------------------*
*& Screen : 0312 — Subscreen: Plant / Work Order Filter for Screen 0310
*& Type   : Dynpro subscreen (SE51). Fields P_WK310, P_AU310, BT_EXEC_310.
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.

MODULE %_INIT_PBO_J.

MODULE %_PBO_REPORT.

MODULE %_PF_STATUS.

MODULE %_S_W310.

MODULE %_S_A310.

MODULE %_END_OF_PBO.

PROCESS AFTER INPUT.

  MODULE %_INIT_PAI_J.

CHAIN.
  FIELD  S_W310-LOW.
  FIELD  S_W310-HIGH.
  MODULE %_S_W310.
ENDCHAIN.

CHAIN.
  FIELD  S_A310-LOW.
  FIELD  S_A310-HIGH.
  MODULE %_S_A310.
ENDCHAIN.

CHAIN.
  FIELD  S_W310-LOW.
  FIELD  S_W310-HIGH.
  FIELD  S_A310-LOW.
  FIELD  S_A310-HIGH.
  MODULE %_END_OF_SCREEN.
  MODULE %_OK_CODE_1000.
ENDCHAIN.
