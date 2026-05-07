*&---------------------------------------------------------------------*
*& Screen : 0320 — Approval History  (v1.6 — adds SS_320 filter + ALV)
*& Flow Logic
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0320.
  CALL SUBSCREEN ss_320 INCLUDING sy-repid '0322'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_320.
  MODULE user_command_0320.
