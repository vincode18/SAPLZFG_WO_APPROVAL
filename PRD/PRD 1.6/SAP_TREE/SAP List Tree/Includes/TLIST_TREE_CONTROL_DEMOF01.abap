*-------------------------------------------------------------------
***INCLUDE list_tree_control_demoF01 .
*-------------------------------------------------------------------

*&---------------------------------------------------------------------*
*&      Form  CREATE_AND_INIT_TREE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM CREATE_AND_INIT_TREE.
  DATA: NODE_TABLE TYPE TREEV_NTAB,
        ITEM_TABLE TYPE ITEM_TABLE_TYPE,
        EVENTS TYPE CNTL_SIMPLE_EVENTS,
        event type cntl_simple_event.

* create a container for the tree control
  CREATE OBJECT G_CUSTOM_CONTAINER
    EXPORTING      " the container is linked to the custom control with the
         " name 'TREE_CONTAINER' on the dynpro

      CONTAINER_NAME = 'TREE_CONTAINER'
    EXCEPTIONS
      CNTL_ERROR = 1
      CNTL_SYSTEM_ERROR = 2
      CREATE_ERROR = 3
      LIFETIME_ERROR = 4
      LIFETIME_DYNPRO_DYNPRO_LINK = 5.
  IF SY-SUBRC <> 0.
    MESSAGE A000.
  ENDIF.
* create a list tree
  CREATE OBJECT g_tree
    EXPORTING
      PARENT              = G_CUSTOM_CONTAINER
      NODE_SELECTION_MODE = CL_GUI_LIST_TREE=>NODE_SEL_MODE_SINGLE
      ITEM_SELECTION     = 'X'
      WITH_HEADERS       = ' '
    EXCEPTIONS
      CNTL_SYSTEM_ERROR           = 1
      CREATE_ERROR                = 2
      FAILED                      = 3
      ILLEGAL_NODE_SELECTION_MODE = 4
      LIFETIME_ERROR              = 5.
  IF SY-SUBRC <> 0.
    MESSAGE A000.
  ENDIF.

* define the events which will be passed to the backend
                                       " node double click
  event-eventid = CL_GUI_list_TREE=>EVENTID_NODE_DOUBLE_CLICK.
  event-appl_event = 'X'.                                   "
  append event to events.

                                       " item double click
  EVENT-EVENTID = CL_GUI_LIST_TREE=>EVENTID_ITEM_DOUBLE_CLICK.
  event-appl_event = 'X'.
  append event to events.

                                       " expand no children
  EVENT-EVENTID = CL_GUI_LIST_TREE=>EVENTID_EXPAND_NO_CHILDREN.
  event-appl_event = 'X'.
  append event to events.

                                       " link click
  EVENT-EVENTID = CL_GUI_LIST_TREE=>EVENTID_LINK_CLICK.
  event-appl_event = 'X'.
  append event to events.

                                       " button click
  EVENT-EVENTID = CL_GUI_LIST_TREE=>EVENTID_BUTTON_CLICK.
  event-appl_event = 'X'.
  append event to events.

                                       " checkbox change
  EVENT-EVENTID = CL_GUI_LIST_TREE=>EVENTID_CHECKBOX_CHANGE.
  event-appl_event = 'X'.
  append event to events.

  CALL METHOD G_TREE->SET_REGISTERED_EVENTS
    EXPORTING
      EVENTS = EVENTS
    EXCEPTIONS
      CNTL_ERROR                = 1
      CNTL_SYSTEM_ERROR         = 2
      ILLEGAL_EVENT_COMBINATION = 3.
  IF SY-SUBRC <> 0.
    MESSAGE A000.
  ENDIF.

* assign event handlers in the application class to each desired event
  SET HANDLER G_APPLICATION->HANDLE_NODE_DOUBLE_CLICK FOR G_TREE.
  SET HANDLER G_APPLICATION->HANDLE_ITEM_DOUBLE_CLICK FOR G_TREE.
  SET HANDLER G_APPLICATION->HANDLE_EXPAND_NO_CHILDREN FOR G_TREE.
  SET HANDLER G_APPLICATION->HANDLE_LINK_CLICK FOR G_TREE.
  SET HANDLER G_APPLICATION->HANDLE_BUTTON_CLICK FOR G_TREE.
  SET HANDLER G_APPLICATION->HANDLE_CHECKBOX_CHANGE FOR G_TREE.

* add some nodes to the tree control
* NOTE: the tree control does not store data at the backend. If an
* application wants to access tree data later, it must store the
* tree data itself.

  PERFORM BUILD_NODE_AND_ITEM_TABLE USING NODE_TABLE ITEM_TABLE.

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

ENDFORM.                               " CREATE_AND_INIT_TREE

*&---------------------------------------------------------------------*
*&      Form  build_node_and_item_table
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*

FORM BUILD_NODE_AND_ITEM_TABLE
  USING
    NODE_TABLE TYPE TREEV_NTAB
    ITEM_TABLE TYPE ITEM_TABLE_TYPE.

  DATA: NODE TYPE TREEV_NODE,
        ITEM TYPE MTREEITM.

* Build the node table.

* Caution: The nodes are inserted into the tree according to the order
* in which they occur in the table. In consequence, a node must not
* must not occur in the node table before its parent node.

* Node with key 'Root'
  node-node_key = c_nodekey-root.
                                       " Key of the node
  CLEAR NODE-RELATKEY.      " Special case: A root node has no parent
  CLEAR NODE-RELATSHIP.                " node.

  NODE-HIDDEN = ' '.                   " The node is visible,
  NODE-DISABLED = ' '.                 " selectable,
  NODE-ISFOLDER = 'X'.                 " a folder.
  CLEAR NODE-N_IMAGE.       " Folder-/ Leaf-Symbol in state "closed":
                                       " use default.
  CLEAR NODE-EXP_IMAGE.     " Folder-/ Leaf-Symbol in state "open":
                                       " use default
  CLEAR NODE-EXPANDER.                 " see below.
  " the width of the item is adjusted to its content (text)
  APPEND NODE TO NODE_TABLE.

* Node with key 'Child1'
  CLEAR NODE.
  node-node_key = c_nodekey-child1.
  " Key of the node
  " Node is inserted as child of the node with key 'Root'.
  node-relatkey = c_nodekey-root.
  NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
  NODE-ISFOLDER = 'X'.
  APPEND NODE TO NODE_TABLE.

* Node with key 'New1'
  CLEAR NODE.
  node-node_key = c_nodekey-new1.
  node-relatkey = c_nodekey-child1.
  NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
  APPEND NODE TO NODE_TABLE.

* Node with key 'New2'
  CLEAR NODE.
  node-node_key = c_nodekey-new2.
  node-relatkey = c_nodekey-child1.
  NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
  APPEND NODE TO NODE_TABLE.


* Node with key 'Child2'
  CLEAR NODE.
  node-node_key = c_nodekey-child2.
  node-relatkey = c_nodekey-root.
  NODE-RELATSHIP = CL_GUI_LIST_TREE=>RELAT_LAST_CHILD.
  NODE-ISFOLDER = 'X'.
  NODE-EXPANDER = 'X'. " The node is marked with a '+', although
                       " it has no children. When the user clicks on the
                       " + to open the node, the event expand_nc is
                       " fired. The programmerr can
                       " add the children of the
                       " node within the event handler of the expand_nc
                       " event  (see callback handle_expand_nc).
  APPEND NODE TO NODE_TABLE.

* The items of the nodes:

* Node with key 'Root'
  CLEAR ITEM.
  item-node_key = c_nodekey-root.
  ITEM-ITEM_NAME = '1'.                " Item with name '1'
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT. " Text Item
  " the with of the item is adjusted to its content (text)
  ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
  " use proportional font for the item
  ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
  item-text = 'Objekte'(003).
  APPEND ITEM TO ITEM_TABLE.


* Node with key 'Child1'
  CLEAR ITEM.
  item-node_key = c_nodekey-child1.
  ITEM-ITEM_NAME = '1'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
  ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
  item-text = 'Dynpros'(004).
  APPEND ITEM TO ITEM_TABLE.

* Node with key 'Child2'
  CLEAR ITEM.
  item-node_key = c_nodekey-child2.
  ITEM-ITEM_NAME = '1'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
  ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
  item-text = 'Programme'(005).
  APPEND ITEM TO ITEM_TABLE.

* Items of node with key 'New1'
  CLEAR ITEM.
  item-node_key = c_nodekey-new1.
  ITEM-ITEM_NAME = '1'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 4. " the width of the item is 4 characters
  ITEM-IGNOREIMAG = 'X'.               " see documentation of Structure
                                       " TREEV_ITEM
  ITEM-USEBGCOLOR = 'X'.               " item has light grey background
  ITEM-T_IMAGE = '@01@'.               " icon of the item
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new1.
  ITEM-ITEM_NAME = '2'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 4.
  ITEM-USEBGCOLOR = 'X'.
  ITEM-TEXT = '0100'.
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new1.
  ITEM-ITEM_NAME = '3'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 11.
  ITEM-USEBGCOLOR = 'X'.                                    "
  ITEM-TEXT = 'MUELLER'.
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new1.
  ITEM-ITEM_NAME = '4'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
  ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
  item-text = 'Kommentar zu Dynpro 100'(006).
  APPEND ITEM TO ITEM_TABLE.

* Items of node with key 'New2'
  CLEAR ITEM.
  item-node_key = c_nodekey-new2.
  ITEM-ITEM_NAME = '1'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 4. " the width of the item is 2 characters
  ITEM-IGNOREIMAG = 'X'.               " see documentation of Structure
                                       " TREEV_ITEM
  ITEM-USEBGCOLOR = 'X'.               " item has light grey background
  ITEM-T_IMAGE = '@02@'.               " icon of the item
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new2.
  ITEM-ITEM_NAME = '2'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 4.
  ITEM-USEBGCOLOR = 'X'.
  ITEM-TEXT = '0200'.
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new2.
  ITEM-ITEM_NAME = '3'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-LENGTH = 11.
  ITEM-USEBGCOLOR = 'X'.                                    "
  ITEM-TEXT = 'HARRYHIRSCH'.
  APPEND ITEM TO ITEM_TABLE.

  CLEAR ITEM.
  item-node_key = c_nodekey-new2.
  ITEM-ITEM_NAME = '4'.
  ITEM-CLASS = CL_GUI_LIST_TREE=>ITEM_CLASS_TEXT.
  ITEM-ALIGNMENT = CL_GUI_LIST_TREE=>ALIGN_AUTO.
  ITEM-FONT = CL_GUI_LIST_TREE=>ITEM_FONT_PROP.
  item-text = 'Kommentar zu Dynpro 200'(007).
  APPEND ITEM TO ITEM_TABLE.

ENDFORM.                               " build_node_and_item_table



*** INCLUDE tlist_tree_control_demoF01