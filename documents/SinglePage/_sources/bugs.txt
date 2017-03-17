..
   This document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Reporting bugs in Demeter
=========================

All software has bugs.  *This* software certainly has bugs.  This
document explains how to report problems with the software
effectively.  In this context :quoted:`effectively` means in a manner
such that I am likely to understand the problem and, therefore, likely
to fix it promptly.

The 2 rules of good bug reporting
---------------------------------

#. Use the `Ifeffit mailing list
   <http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit>`_.  The
   mailing list is always an appropriate place to report problems with
   the software.  You can also use :demeter:`demeter`'s `issue tracker
   at GitHub <https://github.com/bruceravel/demeter/issues>`_.

#. Provide enough information that your problem can be reproduced by
   someone else.  That may mean providing the data or project file that
   triggers the problem.  That may mean explaining step-by-step how to
   arrive at the problem.  That may mean taking a screenshot to
   demonstrate the appearance of the problem.  In any case, be
   explicit, be concise, and be precise.
 
.. caution:: If a problem cannot be reproduced on my computer, I
   cannot possibly solve it.

There are good reasons to use the mailing list:

- I read and respond to questions on the mailing list.  So do many
  other people, any whom may be able to help you with your problem.
 
- The problem and |nd| hopefully |nd| its solution will be archived.
  That means that someone else having the same problem might find that
  solution.
 


The corollaries to those two rules are


#. Don't send email directly to me.
 
#. Don't be vague.
 

If you send mail directly to me, the likely response will be a polite
request to use the mailing list.  If you are vague, the likely
response will be to ask you for more information.  If you send vague
mail directly to me, you may be ignored outright.

For another take on how and why to submit a good bug report, `check
this out
<https://www.lucidchart.com/blog/how-to-write-an-effective-bug-report-that-actually-gets-resolved-and-why-everyone-should>`_.
(Please note that Christensen is not associated in any way with
:demeter:`demeter` or :demeter:`ifeffit` nor should he be contacted
with questions about :demeter:`demeter` or :demeter:`ifeffit`.)

Capturing error messages
------------------------

When :demeter:`demeter` runs into a problem, it usually emits error
messages that are useful for understanding the cause of the bug.  Even
when :demeter:`athena` or :demeter:`artemis` crashes hard, some useful
information is usually provided.

A good bug report will include this information.  Don't edit this
information, regardless of how cryptic or repetitive it may seem.


**Windows**
  
   Each of the GUI programs (:demeter:`athena`, :demeter:`artemis`,
   and :demeter:`hephaestus`) writes its output messages to a log
   file.  This log file is in the :file:`%APPDATA%\\demeter` folder.
   On Windows 7, ``%APPDATA%`` is typically
 
   ::

      C:\Users\<username>\AppData\Roaming\
 
 
   where ``<username>`` is *your* login name.  For me, this ends up
   being :file:`C:\\Users\\bravel\\AppData\\Roaming\\`.  On Windows XP and
   Vista, ``%APPDATA%`` is typically
 
   ::

      C:\Documents and Settings\<username>\Application Data\
 
 
   This folder may normally be `hidden from view
   <http://www.blogtechnika.com/how-to-hide-files-and-folders-and-access-them-in-windows-7>`_.
 
   Each program writes its own log file.  :demeter:`athena`'s log file
   is :file:`%APPDATA%\\demeter\\dathena.log` and so on.
 
   This log file should be included in any bug report.
 
   Please note that this log file is overwritten *every* time you fire
   up the associated program.  When reporting a bug, be sure to use
   the log file you find *immediately* after encountering your problem
   and before you relaunch the program.
 


**Linux or other Unix systems**
 
   On Linux and other Unixes, the GUI programs do not record log files
   as described above.  Top capture the error message, you should
   start the program from the command line.  :demeter:`athena` is
   started by typing the command :command:`dathena`,
   :demeter:`artemis` by typing :command:`dartemis` and so on.  When
   the bug is encountered, the error messages will be written to the
   screen.  These can be copied and pasted into an email message.
 
   Alternatively, you can use the
   `tee <http://www.gnu.org/software/coreutils/manual/coreutils.html#tee-invocation>`_
   program to record the error messages.  Here is an example:
 
   ::

     dathena | tee screen_messages.txt
 
 
   The file :file:`screen_messages.txt` can then be appended to an
   email message.
 



The DOs of reporting bugs
-------------------------

- **DO** try downloading the latest version of the software.  Your
  problem may already be solved.
 
- **DO** subscribe to the `Ifeffit mailing list
  <http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit>`_ and
  **DO** try asking your question there.  Your problem may have been
  discussed there or it may be of interest to other users.
 
- **DO** say which program and which version number you are using.
 
- **DO** say what operating system you are using.
 
- **DO** provide the crystallographic data and a literature reference
  to the crystallographic data when reporting a problem with
  :demeter:`atoms`.
 
- **DO** explain clearly and concisely how to replicate the problem.
 
- **DO** send a project file that demonstrates a problem with
  :demeter:`athena`, or :demeter:`artemis`.  For a problem with
  :demeter:`athena`, you may also need to send raw data.
 
- **DO** send a screenshot of the program in action if that helps
  explain the problem. PNG is usually the best choice for a
  screenshot.  GIF is good also.  JPG and PDF are ok.  TIF sucks.
  Attach this image file to your mail message directly and **DON'T**
  embed it in a Word or PowerPoint file before attaching it.  Really,
  **DON'T** send me a Word or PowerPoint file that consists of a
  single image.  I frickin' *hate* that.

- **DO** send any output files that help explain the problem.  Bugs
  reports about :demeter:`atoms` almost always require the faulty
  :file:`feff.inp` file.
 
- **DO** use compressed archives if you must send large numbers of
  files.  :file:`.zip`, :file:`.tar.gz`, or :file:`.tar.bz2` are all
  acceptable formats for compressed archiving.
 
- **DO** send a follow-up email if a lot of time has passed without a
  response.  I may be on travel or may have set your prior email aside
  and forgotten to return to it (which would explain but not justify a
  period of silence).  I take bug reports very seriously, but
  sometimes I needs a reminder.
 



The DON'Ts of reporting bugs
----------------------------

- **DON'T** ask questions about compiling :demeter:`feff8` or
  :demeter:`feff9`. The only version of :demeter:`feff` that I support
  at that level is the version of :demeter:`feff6` that comes with
  :demeter:`ifeffit`.  For questions about :demeter:`feff8` or
  :demeter:`feff9`, contact someone from the :demeter:`feff` project.
 
- **DON'T** send any information in the form of a Word or PowerPoint
  document.  It is exceedingly rare that the information conveyed in a
  bug report requires formatting capabilities that exist in a word
  processor and that don't exist in plain text email.  RTF,
  LibreOffice, and the like are not an improvement on Word for the
  purpose of reporting a bug.  Indeed, there are situations where
  using a word processor makes it harder for me to troubleshoot the
  problem. For example, if I ask you to cut and paste some text
  displayed by one of the programs, a word processor will change where
  lines are broken in a way that is confusing for me.  On Windows, use
  NotePad rather than Word for such things.
 
- **DON'T** assume that others use the same email program as you.
  Specifically **DON'T** rely upon colored text or fonts in the email
  message to convey information |nd| your email may not display the
  same for me as it does for you.
 
- **DON'T** send large files (other than the suggestions above) that have
  not been requested.  If a large file is needed to understand the
  problem, you will be asked for it in a follow-up email.
 
- **DON'T** ever send anything by fax.  **DON'T** ever send anything
  by normal post or overnight express.  It *is* the 21\ :sup:`st`
  century, after all!
 
- **DON'T** send every file from a :demeter:`feff` run!  It is usually
  sufficient to send just the :file:`feff.inp` file.  If other files
  are needed from the :demeter:`feff` run, you will be asked for them
  in a follow-up email.
