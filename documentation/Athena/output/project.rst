
Project files
=============

Preserving the state of your analysis project
---------------------------------------------

.. todo:: Save button, change indicator, update discussion of file
	  format.

.. todo:: document the new json-style project format
	  
The most important type of output file is the project file. A project
file contains all of the data you have imported, all of the parameters
associated with each data file, the content of the journal, and several
other collections of important data. All of this gets saved in a single,
easily transportable file.

The primary purpose of the project file is to save you work. When you
open a saved project file, all of the data and all of their parameters
are imported into :demeter:`athena`, returning :demeter:`athena` to
the state it was in when saved the project file. :demeter:`artemis`
(:demeter:`athena`'s sister program intended for analysis of EXAFS
data) can read these project files. Thus the project file is the best
way of moving your data between the two programs.

Even better, the project file is a form of collaboration. The format of
the file is platform independent. A project file written on one computer
can read on another computer, even if those computers use different
operating systems. A project file can be burned to a CD, placed on a web
site, or sent to a collaborator by email.

To save a project file, simply select one of the File menu options
highlighted in this figure.

.. _fig-exportproject:

.. figure:: ../../_images/export_project.png
   :target: ../_images/export_project.png
   :width: 65%
   :align: center

   Saving a project file.

The first two options saves the entire current state of
:demeter:`athena`. If the project has already been saved, the
:quoted:`Save project` option overwrites the previous file with the
new state of your project. Hitting :kbd:`Control`-:kbd:`s` does the
same thing. Clicking on the modified indicator -- the other
highlighted region in the screenshot -- also saves the project.
Alternately, you can select :quoted:`Save project as...` and you will
be prompted for a new file name for the project.

The final option will write only the marked groups to a project file.
You can think of this as a sort of :quoted:`sub-project` file. This is another
of the many ways that the group markings are used by :demeter:`athena`.

The :quoted:`Save` button at the top of the screen will save the current
project, prompting for a file name if needed. As you work with :demeter:`athena`.
this button turns increasingly red, reminding you of the need to save
your work early and often.

.. caution:: As with any software, you should save your work early and
	     often. :demeter:`athena` and :demeter:`ifeffit` have
	     their flaws. It would be a shame to discover one of them
	     after having done a lot of unsaved work.



The project file format and compatibility with older versions
-------------------------------------------------------------

The :demeter:`athena` project file is designed to be quick and easy
for :demeter:`athena` to read. Unfortunately, the file format is not
particularly human-friendly.  Most of the lines of the project file
are in the form written out by perl's `Data::Dumper
<http://cpan.uwinnipeg.ca/dist/Data-Dumper>`__ module. This freezes
:demeter:`athena`'s internal data structures into perl code.  When the
project file is imported, these lines of perl code are
evaluated. (This evaluation is performed in a `Safe
<https://metacpan.org/module/Safe>`__ compartment, i.e. a memory space
with restricted access to perl's system functionality. This provides a
certain level of protection against project files constructed with
malicious intent.)

The project file is written using compression in the format of the
popular `gzip <http://www.gzip.org/>`__ program using the highest
level of compression, albeit without the common ``.gz`` file
extension. Both :demeter:`athena` and :demeter:`artemis` use these
files.

