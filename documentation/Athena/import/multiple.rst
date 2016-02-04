..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. _multiple_selection_sec:

Multiple data set import
========================

You can import multiple data sets in the same manner that was
explained in the last section. Select :menuselection:`File --> Import data` or
type :button:`Control`-:button:`o`. When the file selection dialog opens,
you can select more than one data file by clicking on file names while
holding down the :button:`Control` key. On my Linux computer, it looks
like this.

.. _fig-multiple:
.. figure:: ../../_images/import_multiple.png
   :target: ../_images/import_multiple.png
   :align: center

   Importing multiple data sets with the file selection dialog.

Note that three files are highlighted in the file listing and that
those three files are listed below in the :guilabel:`File name`
box. Another way of selecting multiple files is to click on a file in
the listing then click on another file while holding down the
:button:`Shift` key. When you do this, all files between the two you
clicked on will be selected.

When you click the :button:`Open,light` button, all of the selected files
will be imported. If all of the files are of the same type,
:demeter:`athena` will import them all with only one interaction of
the column selection dialog. Thus, if you select several files that
were measured one after the other, they will all be imported using the
same column selections as well as the same parameters for the
reference channel, rebinning, and preprocessing (all of which will be
described in the following sections). If, however, a file is found
that appears to be of a different format, the column selection dialog
will reappear as needed. :demeter:`athena` considers two files to be
the same if they have the same number of columns and those columns
have the same labels.

Each file imported in this way will be listed in the group list, shown
here

.. _fig-multipleimported:
.. figure:: ../../_images/import_multipleimported.png
   :target: ../_images/import_multipleimported.png
   :align: center

   After importing multiple data sets.

When you import multiple project files, the `project selection
dialog <../import/projsel.html>`__ will appear for the first one in the
list. If you import the entire contents of the project file, then the
entire contents of all remaining project files will also be imported.
If, however, you import only a subset, the project selection dialog will
appear for the next project file. As soon as you import an entire
project, all subsequent projects will be imported without having to
interact with the dialog.
