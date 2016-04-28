# NAME

Demeter - A comprehensive XAS data analysis system using Feff and Ifeffit or Larch

# VERSION

This documentation refers to Demeter version 0.9.25

# SYNOPSIS

Import Demeter components into your program:

    use Demeter;

This will import all Demeter components into your program.
Using Demeter automatically turns on [strict](https://metacpan.org/pod/strict) and [warnings](https://metacpan.org/pod/warnings).

# DESCRIPTION

This module provides an object oriented interface to the EXAFS data
analysis capabilities of the popular and powerful Ifeffit package and
its successor Larch.  Given that the Ifeffit and Larch APIs involve
streams of text commands, this package is, at heart, a code generator.
Many methods of this package return text.  All actual interaction with
Ifeffit or Larch is handled through a single method, `dispose`, which
is described below.  The internal structure of this package involves
accumulating text in a scalar variable through successive calls to the
various code generating methods.  This text is then disposed to
Ifeffit, to Larch, to a file, or elsewhere.  The outward looking
methods organize all of the complicated interactions of your data with
Ifeffit or Larch.

This package is aimed at many targets.  It can be the back-end of a
graphical data analysis program, providing the glue between the
on-screen representation of the fit and the actual command executed by
Ifeffit or Larch.  It can be used for one-off data analysis chores -- indeed
most of the examples that come with the package can be reworked into
useful one-off scripts.  It can also be the back-end to sophisticated
data analysis chores such as high-throughout data processing and
analysis or complex physical modeling.

Demeter is a parent class for the objects that are directly
manipulated in any real program using Demeter.  Each of these objects
is implemented using Moose, the amazing meta-object system for Perl.
Although Moose adds some overhead at start-up for any application
using Demeter, its benefits are legion.  See  [Moose](https://metacpan.org/pod/Moose) and
[http://moose.iinteractive.com](http://moose.iinteractive.com) for more information.

# IMPORT

Subsets of Demeter can be imported to shorten loading time.

- `:data`

    Import just enough of Demeter to perform data processing chores like
    those of Athena.

        use Demeter qw(:data)

- `:analysis`

    Import all the data processing chores as well as non-Feff data
    analysis modules for things like linear combination fitting and peak
    fitting.

        use Demeter qw(:analysis)

- `:hephaestus`

    Import a bare bones set of data processing modules. This will not
    allow much more than the plotting of mu(E) data.

        use Demeter qw(:hephaestus)

- `:xes`

    Import the XES processing and peak fitting modules.

        use Demeter qw(:xes)

- `:fit`

    Import everything needed to do data analysis with Feff.

        use Demeter qw(:fit)

# PRAGMATA

Demeter "pragmata" are ways of affecting the run-time behavior of a
Demeter program by specfying that behavior at compile-time.

      use Demeter qw(:plotwith=gnuplot)
    or
      use Demeter qw(:ui=screen)
    or
      use Demeter qw(:plotwith=gnuplot :ui=screen)

- `:p=XX` or `:plotwith=XX`

    Specify the plotting backend.  The default is `pgplot`.  The other
    option is `gnuplot`.  A `demeter` option will be available soon for
    generating perl scripts which plot.

    This can also be set during run-time using the `plot_with` method.

- `:ui=XX`

    Specify the user interface.  Currently the only option is `screen`.
    Setting the UI to screen does four things:

    1. Provides [Demeter::UI::Screen::Interview](https://metacpan.org/pod/Demeter::UI::Screen::Interview) as a role for the Fit
    object.  This imports the `interview` method for use with the Fit
    object, offering a CLI interface to the results of a fit.
    2. Uses [Term::Twiddle](https://metacpan.org/pod/Term::Twiddle) or [Term::Sk](https://metacpan.org/pod/Term::Sk) to provide some visual feedback
    on the screen while something time consuming is happening.
    3. Makes the CLI prompting tool from [Demeter::UI::Screen::Pause](https://metacpan.org/pod/Demeter::UI::Screen::Pause)
    available.
    4. Turns on colorization of output using [Term::ASCIIColor](https://metacpan.org/pod/Term::ASCIIColor).

    The interview method uses [Term::ReadLine](https://metacpan.org/pod/Term::ReadLine).  This is made into a
    pragmatic interaction in Demeter in case you want to use
    [Term::ReadLine](https://metacpan.org/pod/Term::ReadLine) in some other way in your program.  Not importing
    the interview method by default allows you to avoid this error message
    from Term::ReadLine when you are using it in some other capacity:
    `Cannot create second readline interface, falling back to dumb.`

    Also [Term::Twiddle](https://metacpan.org/pod/Term::Twiddle) is not imported until it is needed, allowing
    this dependeny to be relaxed from a requirement to a suggestion.

    Future UI options might include `tk`, `wx`, or `rpc`.

- `:t=XX` or `:template=XX`

    Specify the template set to use for data processing and fitting
    chores.  See [Demeter::templates](https://metacpan.org/pod/Demeter::templates).

    These can also be set during run-time using the `set_mode` method --
    see [Demeter::Mode](https://metacpan.org/pod/Demeter::Mode).

# METHODS

An object of this class represents a part of the problem of EXAFS data
processing and analysis.  That component might be data, a path from
Feff, a parameter, a fit, or a plot.  Moose provides a sane, solid,
and consistent way of interacting with these objects.

Not every method shown in the example above is described here.  You
need to see the subclass documentation for methods specific to those
subclasses.

## Main methods

These are the basic methods for constructing objects and accessing
their attributes.

- `new`

    This the constructor method.  It builds and initializes new objects.

        use Demeter;
        my $data_object = Demeter::Data -> new;
        my $path_object = Demeter::Path -> new;
        my $gds_object  = Demeter::GDS  -> new;
          ## and so on ...

    New can optionally take an array of attributes and values with the
    same syntax as the `set` method.

- `Clone`

    This method clones an object, returning the reference to the new object.

        $newobject = $oldobject->Clone(@new_arguments);

    Cloning returns the reference and sets all attributes of the new
    object to the values for the old object.  The optional argument is a
    reference to a hash of those attributes which you wish to change for
    the new object.  Passing this hash reference is equivalent to cloning
    the object, then calling the `set` method on the new object with that
    hash reference.

    Note the capital `C`, which distinguishes this method from the one
    provided by the [MooseX::Clone](https://metacpan.org/pod/MooseX::Clone) role.

- `set`

    This method sets object attributes.  This is a convenience wrapper
    around the accessors provided by [Moose](https://metacpan.org/pod/Moose).

        $data_object -> set(fft_kmin=>3.1, fft_kmax=>12.7);
        $path_object -> set(file=>'feff0123.dat', s0=>'amp');
        $gds_object  -> set(Type=>'set', name=>'foo', mathexp=>7);

    The set method of each subclass behaves slightly differently for each
    subclass in the sense that error checking is performed appropriately
    for each subclass.  Each subclass takes a hash reference as its
    argument, as shown above.  An exception is thrown is you attempt to
    `set` an undefined attribute for every subclass except for the Config
    subclass.

    The argument are simply a list (remember that the => symbol is
    sytactically equivalent to a comma in this context).  The following
    are equivalent:

          $data_object -> set(file => "my.data", kmin => 2.5);
        and
          @atts = (file => "my.data", kmin => 2.5);
          $data_object -> set(@atts);

    The sense in which this is a convenience wrapper is that the
    following are equivalent:

          $data_object -> set(fft_kmin=>3.1, fft_kmax=>12.7);
        and
          $data_object -> fft_kmin(3.1);
          $data_object -> fft_kmax(12.7);

    The latter two lines use the accessors auto-generated by Moose.  With
    Moose, accessors to attributes have names that are the same as the
    attributes.  The `set` method simply loops over its arguments, calling
    the appropriate accessor.

- `get`

    This is the accessor method.  It "does the right thing" in both scalar
    and list context.

        $kmin = $data_object -> get('fft_kmin');
        @window_params = $data_object -> get(qw(fft_kmin fft_kmax fft_dk fft_kwindow));

    See the documentation for each subclass for complete lists of what
    attributes are available for each subclass.  An exception is thrown if
    you attempt to `get` an undefined attribute for all subclasses except
    for the Config subclass, which is specifically intended to store
    user-defined parameters.

- `serialize`

    Write the serialization of an object to a file.  `freeze` is an alias
    for `serialize`.  More complex objects override this method.  For
    instance, see the Fit objects serialize method for complete details of
    serialization of a fitting model.

        $object -> freeze('save.yaml');

- `serialization`

    Returns the YAML serialization string for the object as text.

- `matches`

    This is a generalized way of testing to see if an attribute value
    matches a regular expression.  By default it tries to match the
    supplied regular expression against the `name` attribute.

        $is_match = $object->matches($regexp);

    You can supply a second argument to match against some other
    attribute.  For instance, to match the `group` attribute against a
    regular expression:

        $group_matches = $object->matches($regexp, 'group');

- `template`, `dispose`, `dispatch`, `chart`

    These methods generate data processing and plotting commands and send
    them off to their eventual destinations.  See the document page for
    [Demeter::Dispose](https://metacpan.org/pod/Demeter::Dispose) for complete details.

- `set_mode`

    This is the method used to set the attributes described in
    [Demeter::Dispose](https://metacpan.org/pod/Demeter::Dispose).  Any Demeter object can call this method.

        $object -> set_mode(backend => 1,
                            screen  => 1,
                            buffer  => \@buffer_array
                           );

- `get_mode`

    When called with no arguments, this method returns a hash of all attributes
    their values.  When called with an argument (which must be one of the
    attributes), it returns the value of that attribute.  Any Demeter object can
    call this method.

        %hash = $object -> get_mode;
        $value = $object -> get_mode("screen");

    See [Demeter:Dispose](Demeter:Dispose) for more details.

## Convenience methods

- `co`, `config`

    This returns the Config object.  This is a wrapper around `get_mode`
    and is intended to be used in a method call chain with any Demeter
    object.  The following are equivalent:

        my $config = Demeter->get_mode("params");
        $config -> set_default("clamp", "medium", 20);

    and

        Demeter -> co -> set_default("clamp", "medium", 20);

    The latter involves much less typing!

- `po`, `plot_object`

    This returns the Plot object.  Like the `co` method, this is a
    wrapper around `get_mode` and is intended to be used in a method call
    chain with any Demeter object.

        Demeter -> po -> set("c9", 'yellowchiffon3');

- `mo`, `mode_object`

    This returns the Mode object.  This is intended to be used in a method
    call chain with any Demeter object.

        print "on screen!" if (Demeter -> mo -> ui eq 'screen');

- `dd`, `data_default`

    This returns the default Data object.  When a Path object is created,
    if it is created without having its `data` attribute set to an
    existing Data object, a new Data object with sensible default values
    for all of its attributs is created and stored as the `datadefault`
    attribute of the Mode object.

    Path objects always rely on their associated Data objects for plotting
    and processing parameters.  So every Path object **must** have an
    associated Data object.  If the `data` attribute is not specified by
    the user, the default Data object will be used.

        print ref(Demeter->dd);
             ===prints===> Demeter::Data

- `fd`, `feff_default`

    This returns the default Feff object.

## Utility methods and common attribute accessors

Here are a number of methods used internally, but which are available
for your use.

- `hashes`

    This returns a string which can be used as a comment character in
    Ifeffit or Larch.  The idea is that every comment included in the
    commands generated by methods of this class use this string.  That
    provides a way of distinguishing comments generated by the methods of
    this class from other comment lines sent to Ifeffit or Larch.  This is
    a user interface convenience.

        print $object->hashes, "\n";
            ===prints===> ###___

- `group`

    This returns a unique five-character string for the object.  For Data
    and Path objects, this is used as the Ifeffit or Larch group name for
    this object.

- `name`

    This returns a short, user-supplied, string identifying the object.
    For a GDS object, this is the parameter name.  For Data, Path,
    Path-like objects, and other plottable objects this is the string that
    will be put in a plot legend.

- `data`

    Path and Path-like objects are associated with Data objects for chores
    like Fourier transforming.  That is, the Path or Path-like object will
    use the processing parameters of the associated Data object.  This
    method returns the reference to the associated Data object.  For Data
    objects, this returns a reference to itself.  For other object types
    this returns a false value.

- `plottable`

    This returns a true value if the object is one that can be plotted.
    Currently, Data, Path, the various Path-like objects, and objects
    associated with various analysis chores (peak fitting, difference
    spectra, etc) return a true value.  All others return false.

        $can_plot = $object -> plottable;

- `sentinal`

    This attribute is inherited by all Demeter objects and provides a
    completely generic way for interactivity to be built into any process
    that a Demeter program undertakes.  It is used, for example, in the
    [Demeter::LCF](https://metacpan.org/pod/Demeter::LCF) `combi` method and in several of the histogram
    processing methods.  This attribute takes a code reference.  At the
    beginning of each fit in the combinatorial sequence, this is
    dereference and called.  This allows a GUI to provide status updates
    during a potentially long-running process and in a manner that does
    not require Demeter to know what kind of UI is in use.

    The dereferencing and calling of the sentinal is handled by `call`

        $object -> call_sentinal;

Demeter provides a generic mechanism for reporting on errors in a
fitting model.  When using Demeter non-interactively, useful messages
about problems in the fitting model will be written to standard
output.  Critical problems in a non-interactive mode will be cause the
script to croak (see [Carp](https://metacpan.org/pod/Carp)).

In an interactive mode (such as with the Wx interface), the
`add_trouble` method is used to fill the `trouble` attribute, which
is inherited by all Demeter objects.  In the default, untroubled
state, an object will have the `trouble` attribute set to an empty
string (i.e. something logically false).  As problems are found in the
fitting model (see [Demeter::Fit::Sanity](https://metacpan.org/pod/Demeter::Fit::Sanity)), the `trouble` attribute
gets short text strings appended to it.  The list of problems an
object has are separated by pipe characters (`|`).

See [Demeter::Fit::Sanity](https://metacpan.org/pod/Demeter::Fit::Sanity) for a complete description of these
problem codes.  The Fit, Data, Path, and GDS objects each have their
own set of problem codes.

# CONFIGURATION AND ENVIRONMENT

See [Demeter::Config](https://metacpan.org/pod/Demeter::Config) for details about the configuration
system.

# DEPENDENCIES

The dependencies of the Demeter system are in the
`Build.PL` file.

# BUGS AND LIMITATIONS

- Template evaluation is a potential security hole in the sense that
someone could put something like `{system 'rm -rf *'}` in one of the
templates.  [Text::Template](https://metacpan.org/pod/Text::Template) supports using a [Safe](https://metacpan.org/pod/Safe) compartment.
- Serialization is incompletely implemented at this time.

Please report problems to the Ifeffit Mailing List
([http://cars9.uchicago.edu/mailman/listinfo/ifeffit/](http://cars9.uchicago.edu/mailman/listinfo/ifeffit/))

Patches are welcome.

# AUTHOR

Bruce Ravel ([http://bruceravel.github.io/home](http://bruceravel.github.io/home))

[http://bruceravel.github.io/demeter/](http://bruceravel.github.io/demeter/)

# LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel ([http://bruceravel.github.io/home](http://bruceravel.github.io/home)). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlgpl](https://metacpan.org/pod/perlgpl).

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
