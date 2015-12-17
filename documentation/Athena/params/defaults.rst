
Default parameter values
========================

When data is imported in :demeter:`athena`, all parameters are set to
their default values. For most data, these defaults are reasonable in
the sense that using them will result in a decent first stab at
background removal and Fourier transform. The sequence of choices
:demeter:`athena` makes in setting those defaults is somewhat
complicated and highly configurable. By understanding how the defaults
are chosen, you can tune :demeter:`athena` to do a good job processing
your more of your data without your intervention.

The choices of default values for each parameter is made by walking
through a hierarchy of decisions, each subsequent level overriding the
previous level. The first decision is made by consulting `the program
preferences <../other/prefs.html>`__. The program preferences are read
from two initialization files when :demeter:`athena` starts. The first
initialization file is a system-wide file that always contains
:demeter:`athena`'s fresh-out-of-the-box parameter defaults. The
second initialization file is your own personal collection of
preferences. These personal preferences are typically set using the
preferences tool, which is found in :guilabel:`Settings` menu. The
values found among the personal preferences will always override the
system-wide set.

Many of the parameter defaults which can be set in the preferences
tool have the option of being set to relative values rather than
absolute values. For example, the :configparam:`Fft,kmax` parameter
can be set to a value such as :quoted:`12`. It can also be set to a value like
:quoted:`-1`, which tells :demeter:`athena` to select the value 1 wavenumber
from the end of the data as the value for :configparam:`Fft,kmax`. All
of the range parameters can be set to values which are relative to the
extent of the actual measured data. These options are explained in the
parameter description in `the preferences tool
<../other/prefs.html>`__.
