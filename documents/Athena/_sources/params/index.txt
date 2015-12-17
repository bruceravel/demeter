
Setting parameters in ATHENA
============================

The interface for setting parameter values in the main window is quite
straight forward. For most parameters, you simply type values into the
appropriate text entry box. For others, you select a value from a
menu.  That's all fine and dandy, but imagine the situation where you
have several dozen data groups imported into :demeter:`athena` and you
decide that you need to change the value of the :procparam:`rbkg` parameter for
every group. It would be extremely tedious to manually change the
parameter value for each data group one by one. Fortunately there is a
better way.

In this chapter, we will see the various tools :demeter:`athena`
provides for constraining parameter values across data groups. We will
also look in detail at how the :procparam:`e0` parameter is determined
and how parameter defaults are set.

.. toctree::
   :maxdepth: 2

   constrain
   e0
   defaults

