*----------------------------------------------------------------------*
*   INCLUDE TLIST_TREE_CONTROL_DEMOCL1                                 *
*----------------------------------------------------------------------*

CLASS LCL_APPLICATION DEFINITION.
  PUBLIC SECTION.
   METHODS:
     HANDLE_NODE_DOUBLE_CLICK
       FOR EVENT NODE_DOUBLE_CLICK
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY,
     HANDLE_EXPAND_NO_CHILDREN
       FOR EVENT EXPAND_NO_CHILDREN
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY,
     HANDLE_ITEM_DOUBLE_CLICK
       FOR EVENT ITEM_DOUBLE_CLICK
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY ITEM_NAME,
     HANDLE_BUTTON_CLICK
       FOR EVENT BUTTON_CLICK
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY ITEM_NAME,
     HANDLE_LINK_CLICK
       FOR EVENT LINK_CLICK
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY ITEM_NAME,
     HANDLE_CHECKBOX_CHANGE
       FOR EVENT CHECKBOX_CHANGE
       OF CL_GUI_LIST_TREE
       IMPORTING NODE_KEY ITEM_NAME CHECKED.
ENDCLASS.                    "LCL_APPLICATION DEFINITION

*----------------------------------------------------------------------*
*       CLASS LCL_APPLICATION IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS LCL_APPLICATION IMPLEMENTATION.

  METHOD  HANDLE_NODE_DOUBLE_CLICK.
    " this method handles the node double click event of the tree
    " control instance

    " show the key of the double clicked node in a dynpro field
    G_EVENT = 'NODE_DOUBLE_CLICK'.
    G_NODE_KEY = NODE_KEY.
    clear g_item_name.
  ENDMETHOD.                    "HANDLE_NODE_DOUBLE_CLICK

  METHOD  HANDLE_ITEM_DOUBLE_CLICK.
    " this method handles the item double click event of the tree
    " control instance

    " show the key of the node and the name of the item
    " of the double clicked item in a dynpro field
    G_EVENT = 'ITEM_DOUBLE_CLICK'.
    G_NODE_KEY = NODE_KEY.
    G_ITEM_NAME = ITEM_NAME.
  ENDMETHOD.                    "HANDLE_ITEM_DOUBLE_CLICK

  METHOD  HANDLE_LINK_CLICK.
    " this method handles the link click event of the tree
    " control instance

    " show the key of the node and the name of the item
    " of the clicked link in a dynpro field
    G_EVENT = 'LINK_CLICK'.
    G_NODE_KEY = NODE_KEY.
    G_ITEM_NAME = ITEM_NAME.
  ENDMETHOD.                    "HANDLE_LINK_CLICK

  METHOD  HANDLE_BUTTON_CLICK.
    " this method handles the button click event of the tree
    " control instance

    " show the key of the node and the name of the item
    " of the clicked button in a dynpro field
    G_EVENT = 'BUTTON_CLICK'.
    G_NODE_KEY = NODE_KEY.
    G_ITEM_NAME = ITEM_NAME.
  ENDMETHOD.                    "HANDLE_BUTTON_CLICK

  METHOD  HANDLE_CHECKBOX_CHANGE.
    " this method handles the checkbox_change event of the tree
    " control instance

    " show the key of the node and the name of the item
    " of the clicked checkbox in a dynpro field
    G_EVENT = 'CHECKBOX_CHANGE'.
    G_NODE_KEY = NODE_KEY.
    G_ITEM_NAME = ITEM_NAME.
  ENDMETHOD.                    "HANDLE_CHECKBOX_CHANGE


  METHOD HANDLE_EXPAND_NO_CHILDREN.
    DATA: NODE_TABLE TYPE TREEV_NTAB,
          NODE TYPE TREEV_NODE,
          ITEM_TABLE TYPE ITEM_TABLE_TYPE,
          ITEM TYPE MTREEITM.

* show the key of the expanded node in a dynpro field
    G_EVENT = 'EXPAND_NO_CHILDREN'.
    G_NODE_KEY = NODE_KEY.

    IF node_key = c_nodekey-child2.
* add the children for node with key 'Child2'
* Node with key 'New3'
      CLEAR NODE.
      node-node_key = c_nodekey-new3.
      node-relatkey = c_nodekey-child2.
      NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
      APPEND NODE TO NODE_TABLE.

* Node with key 'New4'
      CLEAR NODE.
      node-node_key = c_nodekey-new4.
      node-relatkey = c_nodekey-child2.
      NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
      APPEND NODE TO NODE_TABLE.

* Items of node with key 'New3'
      CLEAR ITEM.
      item-node_key = c_nodekey-new3.
      ITEM-ITEM_NAME = '1'.
      ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
      ITEM-LENGTH = 11.
      ITEM-USEBGCOLOR = 'X'. "
      ITEM-TEXT = 'SAPTROX1'.
      APPEND ITEM TO ITEM_TABLE.

      CLEAR ITEM.
      item-node_key = c_nodekey-new3.
      ITEM-ITEM_NAME = '2'.
      ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
      ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
      ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
      item-text = 'Kommentar zu SAPTROX1'(001).
      APPEND ITEM TO ITEM_TABLE.

* Items of node with key 'New4'
      CLEAR ITEM.
      item-node_key = c_nodekey-new4.
      ITEM-ITEM_NAME = '1'.
      ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
      ITEM-LENGTH = 11.
      ITEM-USEBGCOLOR = 'X'. "
      ITEM-TEXT = 'SAPTRIXTROX'.
      APPEND ITEM TO ITEM_TABLE.

      CLEAR ITEM.
      item-node_key = c_nodekey-new4.
      ITEM-ITEM_NAME = '2'.
      ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
      ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
      ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
      item-text = 'Kommentar zu SAPTRIXTROX'(002).
      APPEND ITEM TO ITEM_TABLE.
    ENDIF.

    CALL METHOD G_TREE->ADD_NODES_AND_ITEMS
      EXPORTING
        NODE_TABLE = NODE_TABLE
        ITEM_TABLE = ITEM_TABLE
        ITEM_TABLE_STRUCTURE_NAME = 'MTREEITM'
      EXCEPTIONS
        FAILED = 1
        CNTL_SYSTEM_ERROR = 3
        ERROR_IN_TABLES = 4
        DP_ERROR = 5
        TABLE_STRUCTURE_NAME_NOT_FOUND = 6.
    IF SY-SUBRC <> 0.
      MESSAGE A000.
    ENDIF.
  ENDMETHOD.                    "HANDLE_EXPAND_NO_CHILDREN

ENDCLASS.                    "LCL_APPLICATION IMPLEMENTATION