
Frozen groups
=============

Avoiding mistakes with uneditable groups
----------------------------------------

There is a feature that :demeter:`athena` shares with almost any other
computer program -- not just analysis programs, but any program. Soon
after starting to use :demeter:`athena`, you will do something silly
and regrettable.  Often this is as simple as changing a parameter to
some bad value and forgetting what the good value was. To help
mitigate this sort of problem, :demeter:`athena` allows you to
*freeze* data groups.

A frozen group is one for which you cannot change its parameter values.
When a group is frozen, the entry boxes associated with parameters
become deactivated, which means that it is impossible to type in them.
Furthermore, any global action such as constraining parameters or using
the alignment tool, will have no effect on the frozen group.

The idea behind frozen groups is that, after working for a while to find
parameter values that you like, you can freeze the group to avoid
inadvertently altering its parameters. The various group freezing
functions can be found in the Freeze menu, as shown in the screenshot
below.

.. _fig-freeze:

.. figure:: ../../_images/ui_freeze.png
   :target: ../_images/ui_freeze.png
   :width: 65%
   :align: center

   Several visual cues indicate that a group is frozen, including the green
   highlighting the group list and the disabling of most controls.

The frozen state of the current group can be toggled using the :quoted:`Freeze`
button or by typing Shift-f. You can set the frozen state of multiple
groups using the items in the :quoted:`Freeze` menu. There you will find options
for freezing or unfreezing all groups, all marked groups, or groups
which match `regular
expressions <mark.html#usingregularexpressionstomarkgroups>`__.

There are various visual changes when a group is frozen. The highlight
color in the group list changes to light green and all the widgets on
the main window become disabled.

When a group is frozen, direct edits of parameter values are disallowed.
Frozen groups are skipped for algorithmic edits, such as parameter
constraints or alignment. You can, however, still remove a frozen group
from the project. Unfreezing a group is a simple as hitting Shift-f
again.
