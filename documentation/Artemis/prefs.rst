`The Artemis Users' Guide <./index.html>`__

+--------------------------------------+--------------------------------------+
| «\ `DEMETER <http://bruceravel.githu |
| b.io/demeter/>`__\ »                 |
|                                      |
| «\ `IFEFFIT <https://github.com/newv |
| ille/ifeffit>`__\ »                  |
|                                      |
| «\ `xafs.org <http://xafs.org>`__\ » |
|                                      |
| Back: `Monitoring                    |
| things <./monitor.html>`__           |
| Next: `Worked                        |
| examples <./examples/index.html>`__  |
+--------------------------------------+--------------------------------------+

| |[Artemis logo]|
|  `Home <./index.html>`__
|  `Introduction <./intro.html>`__
|  `Starting Artemis <./startup/index.html>`__
|  `The Data window <./data.html>`__
|  `The Atoms/Feff window <./feff/index.html>`__
|  `The Path page <./path/index.html>`__
|  `The GDS window <./gds.html>`__
|  `Running a fit <./fit/index.html>`__
|  `The Plot window <./plot/index.html>`__
|  `The Log & Journal windows <./logjournal.html>`__
|  `The History window <./history.html>`__
|  `Monitoring things <./monitor.html>`__
|  Managing preferences
|  `Worked examples <./examples/index.html>`__
|  `Crystallography for EXAFS <./atoms/index.html>`__
|  `Extended topics <./extended/index.html>`__

Managing preferences
====================

DEMETER has a mountain of preferences available for the user to tinker
with. This may, I suppose, be a problem. There is a school of thought in
user interface design that asserts that a program should be simple,
offering the user a small number of carefully considered configurable
options, all of which have sensible defaults. That sort of thing is
usually considered “user friendly”, while a dizzying array of
configrable options if conisdered to be hostile to the user.

I don't disagree with that. However, I am not so lucky as to have teams
dedicated to user interface design and product testing. I don't have the
luxury of testing design decisions to determine if they are successful.

Unfortunately, there are a lot of aspects of the software that need
sensible default values. In general, I have a good idea what a sensible
value might be, but I am rarely certain. My solution for any option or
parameter whose sensible default is open to interpretation is to make it
configurable. As a result, there are almost 300 aspects of DEMETER that
can be configured, ranging from default parameter values to the colors
of things that get plotted.

|prefsart.png| ARTEMIS presents all of DEMETER's configuration options
in the Preferences window, which can be displayed from the File Menu.
Shown here, the “artemis” group has been opened and the
♦Artemis → plot\_after\_fit option has been selected. Since it takes one
of predefined list of possible values, you are presented with an option
menu for selecting among the possibilities. The default value can be
restored by pressing the button labeled as DEMETER's default. In the
text area, the option is described. Once you change an option, you can
apply it to the current session or apply it and save its value to
DEMETER's initialization file.

Different configuration options take different kinds of values. For
example, some are filenames, strings, real numbers, integers, colors,
and so on. Controls appropriate to the value type will be provided when
the option is clicked on.

| 

--------------

--------------

| DEMETER is copyright © 2009-2015 Bruce Ravel — This document is
copyright © 2015 Bruce Ravel

|image2|    

| This document is licensed under `The Creative Commons
Attribution-ShareAlike
License <http://creativecommons.org/licenses/by-sa/3.0/>`__.
|  If DEMETER and this document are useful to you, please consider
`supporting The Creative
Commons <http://creativecommons.org/support/>`__.

.. |[Artemis logo]| image:: ./../images/Artemis_logo.jpg
   :target: ./diana.html
.. |prefsart.png| image:: ../images/prefsart.png
   :target: ../images/prefsart.png
.. |image2| image:: ../images/somerights20.png
   :target: http://creativecommons.org/licenses/by-sa/3.0/
