
Configuring Athena to work for you
----------------------------------

:demeter:`athena` allows you to set an enormous number of preferences. Many dozens
of things that could conceivably be configured can, in fact, be
configured using this tool. In any situation where is was not obvious to
me that there was a best, most proper value for a parameter, I chose a
default and made an entry for it in the preference tool. The preference
tool is shown here.

.. _fig-prefs:

.. figure:: ../../_images/prefs.png
   :target: ../../_images/prefs.png
   :width: 65%
   :align: center

   The preferences tool.

I am not going to explain this tool in great detail. I am trusting
that if you are sufficiently motivated to configure the behavior of
:demeter:`athena` to be something other than what comes out of the
box, you will also be sufficiently motivated to follow your nose
through the use of this tool.

The preference parameters are divided into related groups. For
example, there are groups for background removal parameters, alignment
parameters, colors, and so on.

To view a group of preferences, click on the little cross sign next to
the group's name in the list on the left side of the tool. This will
open a branch containing all the parameters in tat group. Click on one
of them and it will be displayed in the controls on the left.

Click on the default button to restore :demeter:`athena`'s default
value or use the control below the default button to set a new
value. That control will vary depending on the type of parameter. A
text or numeric parameter will offer an entry box. A color parameter
will offer a button which pops up a color selection dialog. A list
parameter will offer a menu with the choices. And so on.

The text area below these controls displays an explanation of the
function served by that preference. Underneath that are buttons for
setting or saving the parameters.

Various configuration files, including the master configuration file
demeter.ini and others, are stored in user space. On linux (and other
unixes) this is ``$HOME/.horae/``. On Windows this is
``%APPDATA%\\demeter``.

