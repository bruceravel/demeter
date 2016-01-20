
Special data types
==================

Some beamlines write out data in a form that :demeter:`ifeffit` is not
capable of reading without help. To address this problem,
:demeter:`demeter` offers a simple plugin architecture. A plugin is a
bit of perl code which transformed the problematic file into a form
that :demeter:`ifeffit` can handle. Plugins are small and hopefully
quick and easy to write.


Filetype plugins
----------------

NSLS beamline X15B uses an antiquated data acquisition system which
saves data in a quirky binary format. One of the plugins for file type
conversion that ships with :demeter:`demeter` knows how to interpret
this quirky format. Here is how data from that beamline are imported
into a :demeter:`demeter` program:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $filetype = Demeter::Plugins::X15B->new(file=>'file_from_x15b.001');
    if ($filetype->is) {
        my $converted = $filetype->fix;
        my $data = Demeter::Data->new(file => $converted,
                                      $filetype -> suggest("fluorescence")
                                     );
    };

At line 4, a new Plugin object is made and pointed at the problematic
file.  At line 4, a check is made to verify that the file actually is
of the X15B type. When recognized as such, the problematic file is
converted into an :demeter:`ifeffit` friendly form at line 6.  A normal
Data object is then created at line 7 and 8 using the converted file
and the Plugin's suggestion for how to form fluorescence data from the
columns in the converted file.

Every plugin must offer three methods:

``is``
    This method identifies a file as being of that type and returns a
    boolean value. It is quite important that this method be fast. A
    program might need to check a file against many different plugins.
    If this method is slow, than any program using it will seem
    unresponsive to the user.
``fix``
    This method transforms the file into a form easily imported by
    :demeter:`ifeffit` and writes the transformed data to a transitional file. This
    transitional file is usually placed in the stash directory (link to
    section explaining the stash directory), but that is not a strict
    requirement. The fully resolved name of the transitional file is
    returned. This method can use any tools available, ranging from
    straight perl to :demeter:`ifeffit` to serious math packages such as `the perl
    data language <https://metacpan.org/pod/PDL>`__ or `the Cephes
    library <https://metacpan.org/pod/distribution/Math-Cephes/lib/Math/Cephes.pod>`__.
``suggest``
    This method returns an array of suggestions for forming transmission
    or fluorescence data from the transformed file. Specifically, this
    returns an array containing the ``energy``, ``numerator``,
    ``denominator``, and ``ln`` attributes. See `the section on column
    data <columns.html>`__.

 

Plugins that ship with Demeter
------------------------------

This is an incomplete list.

**X10C**
    Convert files from NSLS beamline X10C. These files have headers
    which confuse :demeter:`ifeffit` and sometimes fail to have white space
    separating numbers among the data columns. The plugin comments out
    the headers and corrects the problem with white space between
    columns.

**X15B**
    Convert files from NSLS beamline X15B. This beamline uses an ancient
    data acquisition system which writes files in a cryptic binary
    format. This plugin converts these data to a simple column data
    file, saving only the scalars containing the XAS-relevant
    measurement channels.

**PFBL12C**
    Convert files from Photon Factory XAS beamlines. These files have
    headers which will confuse :demeter:`ifeffit`'s file import and store data as a
    function of monochromator angle. This plugin comments the header and
    converts mono angle to energy using information about the crystal
    type contained in the header. The plugin name makes specific
    reference to beamline 12C for historical reasons. It will actually
    work on XAS data from any Photon Factory beamline.

**SSRLB**
    Convert SSRL binary data file. Yes, SSRL does provide a program for
    converting these binary files to column ASCII data. This plugin does
    the same chore, yielding a file easily read by :demeter:`ifeffit`.

**SSRLA**
    Convert SSRL ASCII data file. Presumably, these ASCII files are the
    result of the SSRL conversion program. These ASCII files are
    unreadable by :demeter:`ifeffit`. This plugin, comments out the header lines,
    constructs a column label line out of the Data: section, moves the
    first column (real time clock) to the third column, and swaps the
    requested and acheived energy columns.

**SSRLmicro**
    Sam Webb's microprobe data acquisition program writes files with
    lots of columns and with a header structure that cannot be easily
    used by :demeter:`ifeffit`. This plugin massages that file format into a form
    more easily ready by :demeter:`ifeffit`, keeping only the ROI columns. (Note
    that this plugin could be modified quite easily to perform a simple
    ICR/OCR deadtime correction.)

**HXMA**
    Files from the HXMA beamline at the Canadian Light Source are
    readable by :demeter:`ifeffit`, but the columns are labeled in a way that
    :demeter:`ifeffit` is unable to use. This plugin restructures the header for
    :demeter:`ifeffit`'s convenience and keeps only the columns containing the ion
    chambers and the corrected (presumably by a simple ICR/OCR deadtime
    correction) ROI signals from the multi-element detector.

**CMC**
    Files from APS beamline 9BM (CMC-XOR) are single-record Spec files.
    As a result, these data files contain lots of useless column (for
    example, each file inexplicably saves h, k, and l values). This
    plugin discard all the useless columns, keeping only those from the
    ion chambers and the multi-element detector. It also discards the
    problematic :quoted:`logi0i1` column, which can result in ``NaN`` entries in the
    case of zero signal on the transmission detector.

**X23A2MED**
    Data measured using the Vortex silicon drift detector at NSLS X23A2
    are imported and deadtime corrected using the point-by-point
    iterative algorithm developed and implemented by Joe Woicik and
    Bruce Ravel and described in J. Woicik, et al.  The output data file contains columns
    for each corrected detector channel as well as columns for the
    various ion chambers. This is an example of a file type plugin which
    uses :demeter:`ifeffit` dirrectly.

    .. bibliography:: ../dpg.bib
       :filter: author % "Woicik"
       :list: bullet


**DUBBLE**
    Files from the DUBBLE beamline (BM26) at ESRF. This plugin converts
    monochromator angle into from millidegrees to energy and (as needed)
    disentangles the confusing layout of data from the multi-element
    detector, writing out a file that can easily be imported by Athena.

**Lytle**
    Import files from the Lytle database. This plugin imports those data
    that are recorded by encoder value and which have headers that start
    with the word NPTS and have the mono d-spacing and steps-per-degree
    in the second line. There is another common file format in the Lytle
    database (the header begins with CUEDGE and does not record the mono
    parameters) that is not handled by this plugin. See question 3 at
    http://cars9.uchicago.edu/ifeffit/FAQ/Data_Handling.

