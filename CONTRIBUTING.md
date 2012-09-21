Contributing to Demeter
==========


I welcome contributions to Demeter.  There are a lot of areas where an
enterprising user can contribute in meaningful ways.  I will summarize
some of them here.

Discussing issues
----------

Discussions about Demeter should happen either on the
[Ifeffit mailing list](http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit)
or at the
[GitHub issue tracker](https://github.com/bruceravel/demeter/issues).



### Day to day contributions ###

* Answer a question on the mailing list.

* Report a bug or make a suggestion for improving the codes.  Do this
  on the
  [Ifeffit mailing list](http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit)
  or at the [GitHub issue tracker](https://github.com/bruceravel/demeter/issues)

### Documentation contributions ###

* Write a web page explaining something about XAS.

* Measure a library of reference materials for some element and share
  an Athena project file containing the processed data.

* Explain a data analysis problem in the form of a series of annotated
  project files.

* Make a video explaining how to do something with the software.

* Give a lecture at an XAS training course.  Post your presentation and
  any relevant data on http://xafs.org.

* Design a spiffy new web presence for Demeter.

* Help port the Athena Users' Guide for the new version of Athena, for
  example by making new images showing the new version of the code.

### Packaging contributions ###

* Update the horae Mac installer to use the new Demeter codes.

* Make, support, and keep up-to-date installer packages for Red Hat
  based systems, other Linux distributions, or BSD.

* Improve the Windows installer: add more XAS-related Start menu
  options, add more perl-related Start menu options, write a better
  README file for display upon installation, fix the problems with
  relocating the installation location, figure out how to dispense
  with the useless dosbox, etc.

* There is no Windows updater.  One has to download the entire package
  at each release.  Could something be done with git and automating
  the build process?

* Desktop functionality for Windows, Mac, KDE, GNOME/Unity, etc.  By
  this I mean things like looking inside an Athena project file (a la
  C<dlsprj>) and displaying that information in the file manager.  Or
  showing an image of the most recent fit when an Artemis project file
  is selected.


### Programming contributions ###

* Identify and fix a bug in the codes.  Submit a patch to Bruce or
  issue a pull request at https://github.com/bruceravel/demeter.

* Write a file type plugin for the weird data files from some weird
  beamline.

* Write an interesting and novel program using Demeter and share it
  with the world.  For example, something that processes a sequence of
  quick-XAS spectra or something that automates the application of a
  fitting model to an ensemble of data.

* I have long wanted to integrate
  [OpenBabel](http://openbabel.org/wiki/Main_Page) into Artemis.
  OpenBabel is a framework for converting between molecule file
  formats.  The F<feff.inp> format could be integrated into OpenBabel
  by writing a bit of C++.  With Feff integrated into OpenBabel,
  Demeter could use OpenBabel's
  [Perl interface](http://openbabel.org/wiki/Perl).  This means that
  any molecule format could be imported into Artemis and used as the
  basis of a Feff calculation.  Writing the OpenBabel interface and
  contributing it the OpenBabel project would be a most splendid
  contribution to Demeter while at the same time opening up Feff
  support to the many projects that use OpenBabel.
