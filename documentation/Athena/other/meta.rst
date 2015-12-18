
File metadata
=============

Tracking the data about your data
---------------------------------

.. versionadded:: 0.9.21
   :demeter:`athena` has supported import and
   export of metadata using the `XAS Data Interchange (XDI) specification
   <https://github.com/XraySpectroscopy/XAS-Data-Interchange>`__.

When metadata can be gleaned from the file you import, it will be stored
in the :demeter:`athena` project file and used to make the header portion of any
output files written by :demeter:`athena`.

There are three categories of information displayed in
:demeter:`athena`'s metadata display tool. At the top is versioning
information about the XDI specification as well versioning information
for any data acquisition or analysis software that has touched the
data.

Below that is a tree of metadata grouped into families of sensible,
widely understood, semantic groupings of data. Some of these items are
defined in the XDI dictionary, while others are associated with the
software that has touched the data.

Finally, there is a section of user comments. This is any information
associated with the file that has meaning to the user but which does not
fit neatly into semantic groupings.

.. _fig-metadata:

.. figure:: ../../_images/metadata.png
   :target: ../_images/metadata.png
   :width: 65%
   :align: center

   The metadata display tool.

If the input data file is in the XDI format, all metadata and all user
comments will be stored by :demeter:`athena` and displayed in this tool.

Because XDI is a new standard that has not yet been widely adopted,
:demeter:`athena` provides a plugin mechanism whereby an input data
file can be parsed for metadata as it is imported. This parsing is a
beamline-specific chore, thus plugins are written which are tailored
to the data files written as particular beamlines. The selection of
beamline plugins is limited at this time. :demeter:`demeter` ships
with one plugin for several XAS beamlines at NSLS (many of the XAS
beamlines at NSLS use the same data acquisition software) and another
for the beamlines at Sector 10 at the APS.

The image above shows an example of the NSLS beamline plugin. The data
displayed in that image are from NSLS beamline X23A2. The metadata was
either gleaned from the data file or from a small database of facility
and beamline metadata that comes with :demeter:`demeter`.

Two pieces of metadata will always be displayed in the metadata viwewer,
``Element.symbol`` and ``Element.edge``. These are two pieces of
metadata that are required elements of the XDI specification. The
periodic table is replete with examples of atoms that have absorption
edges with very similar edge energies. For example, the tabulated values
of the Cr K edge and the Ba L\ :sub:`I` edge are both 5989 eV. Without
identification of the species of the absorbing atom and of the
absorption edge measured, some data cannot cannot be unambiguously
identified.

Since :demeter:`athena` always attempts to determine those two pieces of
information for any data, those two are always available for display in
the viewer.



Interacting with the metadata
-----------------------------

This tool is not particularly interactive. Metadata is typically
inserted into a file by a data acquisition or analysis program and is
not intended to be altered by the user. The one exception is the user
comments area. In :demeter:`athena`, this is a normal text editing
control into which you can type whatever you want. The contents of
this control will be saved as user comments when the :button:`Save
comments,light` button is pressed.



Beamline plugins
----------------

Metadata can extracted from any data file so long as a beamline plugin
has been written. The plugin is contained in a :file:`.pm` file in the
:file:`Plugins/Beamlines/` folder of the :demeter:`demeter`
installation. This is a piece of perl code which performs the
following chores:

#. Very quickly recognize whether a file comes from the
   beamline. Speed is essential as every file will be checked
   sequentially against every beamline plugin. If a beamline plugin is
   slow to determine this, then the use of :demeter:`athena` or other
   applications will be noticeably affected.

#. Recognize semantic content from the file header. Where possible, map
   this content onto defined XDI headers. Other semantic content is
   placed into extension headers. In the example above, metadata from
   the XDAC data acquisition program is placed into the XDAC family,
   which other metadata is placed into families defined in the XDI
   specification.

#. Add versioning information for the data acquisition program into the
   ``XDI extra_version`` attribute. In the example above, the data file was
   collected using version 1.4 of XDAC, so the string :quoted:`XDAC/1.4` is
   placed among the applications.

:demeter:`demeter` also has a small database of metadata related to
specific beamlines. This is found in the :file:`share/xdi/` folder of
the :demeter:`demeter` installation. Each of the files in that folder
is a short .ini file containined common information about facilities
and beamlines. Much of the metadata shown above actually came from the
.ini file for NSLS beamline X23A2.

To add new beamlines to this part of :demeter:`athena`, it is
necessary to write the plugin and the corresponding .ini file.

