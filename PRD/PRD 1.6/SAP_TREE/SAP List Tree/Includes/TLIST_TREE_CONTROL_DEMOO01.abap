*-------------------------------------------------------------------
***INCLUDE list_tree_control_demoO01 .
*-------------------------------------------------------------------
*&---------------------------------------------------------------------*
*&      Module  PBO_0400  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE PBO_100 OUTPUT.
  SET PF-STATUS 'MAIN'.
  IF G_TREE IS INITIAL.
    " The Tree Control has not been created yet.
    " Create a Tree Control and insert nodes into it.
    PERFORM CREATE_AND_INIT_TREE.
  ENDIF.
ENDMODULE.                 " PBO_0100  OUTPUT
*** INCLUDE list_tree_control_demoO01