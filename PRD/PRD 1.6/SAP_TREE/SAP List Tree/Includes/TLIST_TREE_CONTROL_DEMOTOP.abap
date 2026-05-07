*&---------------------------------------------------------------------*
*& Include  TLIST_TREE_CONTROL_DEMOTOP                                 *
*&                                                                     *
*&---------------------------------------------------------------------*

REPORT SAPTLIST_TREE_CONTROL_DEMO MESSAGE-ID TREE_CONTROL_MSG.

  CLASS LCL_APPLICATION DEFINITION DEFERRED.
  CLASS CL_GUI_CFW DEFINITION LOAD.

* CAUTION: MTREEITM is the name of the item structure which must
* be defined by the programmer. DO NOT USE MTREEITM!
  TYPES: ITEM_TABLE_TYPE LIKE STANDARD TABLE OF MTREEITM
         WITH DEFAULT KEY.

  DATA: G_APPLICATION TYPE REF TO LCL_APPLICATION,
        G_CUSTOM_CONTAINER TYPE REF TO CL_GUI_CUSTOM_CONTAINER,
        G_TREE TYPE REF TO CL_GUI_LIST_TREE,
        G_OK_CODE TYPE SY-UCOMM.

* Fields on Dynpro 100
  DATA: G_EVENT(30),
        G_NODE_KEY TYPE TV_NODEKEY,
        G_ITEM_NAME TYPE TV_ITMNAME.


CONSTANTS:
  BEGIN OF c_nodekey,
    root   TYPE tv_nodekey VALUE 'Root',                    "#EC NOTEXT
    child1 TYPE tv_nodekey VALUE 'Child1',                  "#EC NOTEXT
    child2 TYPE tv_nodekey VALUE 'Child2',                  "#EC NOTEXT
    new1   TYPE tv_nodekey VALUE 'New1',                    "#EC NOTEXT
    new2   TYPE tv_nodekey VALUE 'New2',                    "#EC NOTEXT
    new3   TYPE tv_nodekey VALUE 'New3',                    "#EC NOTEXT
    new4   TYPE tv_nodekey VALUE 'New4',                    "#EC NOTEXT
  END OF c_nodekey.

*** INCLUDE TLIST_TREE_CONTROL_DEMOTOP