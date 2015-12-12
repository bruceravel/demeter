
Marking groups
==============

As data are imported in :demeter:`athena`, they are listed in the Data groups list.
Each entry in the list includes the name of the data set, the text of
which acts something like a hyperlink in that clicking on that text will
insert the analysis parameters for that group into the main window. Each
entry also has a little check button which is used for *marking* the
group. Much of :demeter:`athena`'s functionality revolves around marked groups. For
example, the marked groups are the ones plotted when a purple plotting
button is pressed, merging is done on the set of marked groups and, many
of the data processing and data analysis chores use the marked groups.

:demeter:`athena` offers a number of simple tools for marking or unmarking groups.
These are found in the Mark menu, as shown below, and also have keyboard
bindings. Shift-a marks all groups, Shift-u unmarks all groups, and
Shift-i inverts the markings such that the marked groups become unmarked
and the unmarked ones become marked. The three buttons above the group
list also serve to make all, mark none, and invert the marks.

.. _fig-mark:

.. figure:: ../images/ui_mark.png
   :target: ../images/ui_mark.png
   :width: 65%
   :align: center

   The group marking options are found in the Mark menu. Making all
   groups, removing all marks, or inverting all marks can be done
   using the mark buttons at the top of the group list.


|Essential topic| Using regular expressions to mark groups
------------------------------------------------------------

There is one more tool which is considerably more powerful and flexible.
In the Mark menu, this last marking tool it is called *Mark regex* and
it is bound to Shift-r.

So, what does *regex* mean?

Regex is short for *regular expression*, which is a somewhat formal
way of saying :quoted:`pattern matching`. When you :quoted:`mark
regex`, you will be prompted for a string in the echo area at the
bottom of the :demeter:`athena` window. This prompt is exactly like
the one used `to rename groups
<glist.html#reorganizingthegrouplist>`__. This string is compared to
the names of all the groups in the Data groups list. Those which match
the string become marked and those which fail to match become
unmarked. Let me give you some examples. In a project file containing
various vanadium standards, the Data groups list includes

.. _fig-vstan:

.. figure:: ../images/ui_vstan.png
   :target: ../images/ui_vstan.png
   :width: 65%
   :align: center

   A project with several vanadium standards imported. The regular
   expression shown matches all strings with the number :quoted:`1` at the end.
   Thus all groups with the :quoted:`.1` extension will be marked.

These represent the various oxidation states of vanadium. The last item
is an unknown sample which can be interpreted as a linear combination of
the other five samples. There are two scans of each sample, as indicated
by the ``.1`` and ``.2``.

To make plots of arbitrary combinations of spectra, you can click the
appropriate mark buttons on and off. Using regular expression marking is
quicker and easier. I'll start with a couple simple examples. If you
want to mark only the vanadium foil spectra, hit Shift-r and then enter
foil. To mark the V2O3 and V2O5, but none of the others, hit Shift-r and
enter V2.

In fact, you get to use the entire power of perl's regular expression
language (see `the regular expression documentation at
CPAN <http://search.cpan.org/dist/perl/pod/perlre.pod>`__ for all the
details). This means you can use *metacharacters* -- symbols which
represent conceptual aspects of strings. Here are a few examples:

-  To mark only the V2O3 and VO2 data: ``O[23]``. That tells :demeter:`athena` to
   mark the groups whose names have the letter O followed by either 2 or
   3.

-  To mark only the first scans of each sample: ``1$``. The ``$``
   metacharacter represents the end of a word, thus this regular
   expression matches all groups whose name ends in the number 1.

-  To mark only the foil and unknown data: ``foil|unknown``. The ``|``
   metacharacter means :quoted:`or`, so this regular expression matches the
   groups with foil or unknown in the name. Actually this regular
   expression could have been much shorter, both ``[fu]`` and ``f|u``
   would have worked in this case, given this set of group names.

Regular expressions are a large and fascinating topic of study, but
beyond the scope of this document. Check out the link above read
Wikipedia's `excellent article on regular
expressions <http://en.wikipedia.org/wiki/Regular_expression>`__ for
more information. `Mastering Regular
Expressions <http://www.oreilly.com/catalog/regex3/>`__ by Jeffrey
Freidl is a superb book on the subject.

Any regular expression that works in perl will work for marking groups
in :demeter:`athena`. If you enter an invalid regular expression,
:demeter:`athena` will tell you. Regular expression marking is a
wonderful tool, especially for projects containing very many data
sets.

.. caution:: The regular expression is sent exactly as entered to
	     perl's regular expression engine. You thus have the
	     **full** power of perl's regular expression engine.  If
	     you know what ``(?{code})`` means and do
	     something ill-advised with it, you'll get no sympathy
	     from me!

