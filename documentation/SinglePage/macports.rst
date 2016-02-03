
.. linebreak::

.. note:: Laila Al-Madhagi contributed the following notes gathered during an
	  installation of the :demeter:`demeter` package for MacPorts.



Additional notes on installing the MacPorts package
===================================================


#. Install Xcode and Xcode Command Line Tools: If using the latest
   operating system, then you will find Xcode in the :quoted:`App
   Store`. If using an older operating system, you will find Xcode and
   the Command Line Tools from the `Mac Developer
   <https://developer.apple.com/>`_ website

#. Open :program:`Terminal` and agree to Xcode license by typing 

   ::

      xcodebuild --licence

#. Install MacPorts for your version of Mac OS X from MacPorts website

#. Open :program:`Terminal` and type in:

   ::

      sudo port install xorg-server demeter

   My operating system is El Capitan (Mac OS X 10.11.1) and it took me
   a long time to install :demeter:`demeter` because MacPorts
   automated builder for El Capitan was not ready at the time of
   installation; hence, it took longer time to install Demeter.

#. Launch :demeter:`athena` by typing ``Athena`` in
   :program:`Terminal`. Do the same for :demeter:`artemis` and
   :demeter:`hephaestus`


Problems during installation
----------------------------

:quoted:`No destroot found`

     caused when installing a port (e.g. :file:`libpixman`) fails and
     an error message of :quoted:`no destroot found` occur. What you need to
     do is to clean the affected port and try again (example below is
     for libpixman port)

     ::

	sudo port clean libpixman

     Then

     ::

	sudo port install xorg-server demeter


Problems after installation
---------------------------

- After Launching :demeter:`athena` and whenever I tried to import
  data, I got a message saying that I need to install the ``Encoding::
  FixLatin::XS`` module. So, go to :program:`Terminal` and type

  ::

     sudo port install p5.22-encoding-fixlatin-xs

  At the beginning I could not launch :demeter:`artemis` and I would
  get the following message in :program:`Terminal`:

  ::

     Can’t locate Heap/Fibobacci... 

  So, go to :program:`Terminal` and type

  ::

     sudo port install p5.22-heap

- No plot window in Athena: the :configparam:`gnuplot,terminal` value
  should be ``wxt``. If no plot window appears, it is because
  :configparam:`gnuplot,terminal` is not ``wxt``. Launch
  :demeter:`athena`, Open :guilabel:`Preferences` from
  :demeter:`athena`'s main menu. Open :guilabel:`gnuplot`, choose
  :guilabel:`terminal`, then set the value to ``wxt``.

  ``aqua`` is another terminal choice that may work, although
  deglitching and the pluck buttons probably won't work with the
  ``aqua`` terminal.

Great help from Macports
------------------------

- Macports problem hotlist: `Macports problem hotlist
  <https://trac.macports.org/wiki/ProblemHotlist#nodestrootfound>`_

- Remember to browse through the older tickets `Macports ticket search
  <https://trac.macports.org/search?portsummarysearch=on>`_

- File new ticket `Macports new ticket
  <https://trac.macports.org/newticket>`_
