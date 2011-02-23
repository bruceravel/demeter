package Xray::XDI::Version1_0;

use Moose::Role;
use MooseX::Aliases;

use vars qw($debug);
$debug = 0;

has 'version'	         => (is => 'rw', isa => 'Str', default => q{1.0});

has 'applications'	 => (is => 'rw', isa => 'Str', default => q{});

has 'abscissa'   	 => (is => 'rw', isa => 'Str', default => q{});
has 'beamline'		 => (is => 'rw', isa => 'Str', default => q{});
has 'collimation'	 => (is => 'rw', isa => 'Str', default => q{});
has 'crystal'		 => (is => 'rw', isa => 'Str', default => q{});
has 'd_spacing'		 => (is => 'rw', isa => 'Str', default => q{});
has 'edge_energy'	 => (is => 'rw', isa => 'Str', default => q{});
has 'end_time'		 => (is => 'rw', isa => 'Str', default => q{});
has 'focusing'		 => (is => 'rw', isa => 'Str', default => q{});
has 'harmonic_rejection' => (is => 'rw', isa => 'Str', default => q{});
has 'mu_fluorescence'	 => (is => 'rw', isa => 'Str', default => q{});
has 'mu_reference'	 => (is => 'rw', isa => 'Str', default => q{});
has 'mu_transmission'	 => (is => 'rw', isa => 'Str', default => q{});
has 'ring_current'	 => (is => 'rw', isa => 'Str', default => q{});
has 'ring_energy'	 => (is => 'rw', isa => 'Str', default => q{});
has 'start_time'	 => (is => 'rw', isa => 'Str', default => q{});
has 'source'		 => (is => 'rw', isa => 'Str', default => q{});
#has 'step_offset'	 => (is => 'rw', isa => 'Str', default => q{});
#has 'step_scale'	 => (is => 'rw', isa => 'Str', default => q{});
has 'undulator_harmonic' => (is => 'rw', isa => 'Str', default => q{});

has 'comment_character'  => (is => 'rw', isa => 'Str', default => q{#},
			     traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
			     alias=>'cc');
has 'field_end'          => (is => 'rw', isa => 'Str', default => q{#}.'/' x 2,
			     traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
			     alias=>'fe');
has 'header_end'         => (is => 'rw', isa => 'Str', default => q{#}.'-' x 60,
			     traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
			     alias=>'he');
has 'record_separator'   => (is => 'rw', isa => 'Str', default => "\t",
			     traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
			     alias=>'rs');


has 'order' 	   => (is => 'rw', isa => 'ArrayRef',
		       default => sub{ ['applications',
					'beamline',
					'source',
					'undulator_harmonic',
					'ring_energy',
					'ring_current',
					'collimation',
					'crystal',
					'd_spacing',
					'focusing',
					'harmonic_rejection',
					'edge_energy',
					'start_time',
					'end_time',
					'abscissa',
					'mu_transmission',
					'mu_fluorescence',
					'mu_reference',
				       ] });


sub define_grammar {
  return <<'_EOGRAMMAR_';
XDI: <skip: qr/[ \t]*/> VERSION(?) FIELDS(?) COMMENTS(?) LABELS(?) DATA

UPALPHA:    /[A-Z]+/
LOALPHA:    /[a-z]+/
ALPHA:      /[a-zA-Z]+/
DIGIT:      /[0-9]/
WORD:       /[-a-zA-Z0-9_]+/
PROPERWORD: /[a-zA-Z][-a-zA-Z0-9_]+/
NOTDASH:    /^[#;][ \t]*(?!-+)/
## including # in ANY is problematic
ANY:        /[^\#; \t\n\r]+/
COMM:       /^[\#;]/

CR:         /\n/
LF:         /\r/
CRLF:       CR LF
#EOL:        CRLF | CR | LF
EOL:        /[\n\r]+/
SP:         / \t/
WS:         SP(s)
TEXT:       WORD
MATH:       /(?:ln)?[-+\*\$\/\(\)\d]+/
EXPRESSION: WORD | MATH | SP

#SIGN:       /[-+]/
INTEGER:    /\d+/
#EXPONENT:   /[eEdD]/  SIGN(?)  INTEGER
#NUMBER:     DIGIT(s)  ("."  DIGIT(s))(?)  EXPONENT(?)
#INF:        /inf/i
#NAN:        /nan/i
FLOAT:      /[+-]?\ *(\d+(\.\d*)?|\.\d+)([eEdD][+-]?\d+)?/  # see perlretut
## what about nan and inf?

FIELD_END:  COMM  /\/+/ EOL
HEADER_END: COMM  /-{2,}/ EOL

XDI_VERSION:   "XDI/"  INTEGER  "."  INTEGER 
## this action is not quite right, indeed specifying a version format is probably a bad idea
APPLICATIONS:  WORD  "/"   INTEGER  ("." INTEGER)(s) {
  	        $Xray::XDI::object->applications(join("", @item[1..3]).'.'.join('.', @{$item[4]}));
	        1;
	       }
VERSION: COMM XDI_VERSION  APPLICATIONS(s?) EOL

#CUT:            DIGIT(3)
REFLECTION:     /\d{3}/
MATERIAL:       ("Si" | "Ge" | "Diamond" | "YB66" | "InSb" | "Beryl" | "Multilayer")
DATETIME:       /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
HARMONIC_VALUE: /\d{1,2}/

ABSCISSA:    COMM  "Abscissa"    ":"  MATH {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->abscissa(join(" ", $item[4]));
            }

BEAMLINE:    COMM  "Beamline"           ":"  TEXT(s) {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->beamline(join(" ", @{$item[4]}));
            }

COLLIMATION: COMM  "Collimation"        ":"  TEXT(s) {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->collimation(join(" ", @{$item[4]}));
            }

CRYSTAL:     COMM  "Crystal"            ":"  MATERIAL REFLECTION {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->crystal(join(" ", $item[4], $item[5]));
            }

DSPACING:    COMM  "D_spacing"          ":"  FLOAT {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->d_spacing(join(" ", @{$item[4]}));
            }

EDGEENERGY:  COMM  "Edge_energy"        ":"  FLOAT {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->edge_energy(join(" ", $item[4]));
            }

ENDTIME:     COMM  "End_time"           ":"  DATETIME {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->end_time(join(" ", $item[4]));
            }

FOCUSING:    COMM  "Focusing"           ":"  TEXT(s) {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->focusing(join(" ", @{$item[4]}));
            }

HARMONIC:    COMM  "Undulator_harmonic" ":"  HARMONIC_VALUE {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->undulator_harmonic(join(" ", $item[4]));
            }

MUFLUOR:     COMM  "Mu_fluorescence"    ":"  MATH {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->mu_fluorescence(join(" ", $item[4]));
            }

MUREF:       COMM  "Mu_reference"       ":"  MATH {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->mu_reference(join(" ", $item[4]));
            }

MUTRANS:     COMM  "Mu_transmission"    ":"  MATH {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->mu_transmission(join(" ", $item[4]));
            }

REJECTION:   COMM  "Harmonic_rejection" ":"  TEXT(s) {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->harmonic_rejection(join(" ", @{$item[4]}));
            }

RINGCURRENT: COMM  "Ring_current"       ":"  FLOAT {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->ring_current(join(" ", $item[4]));
            }

RINGENERGY:  COMM  "Ring_energy"        ":"  FLOAT {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->ring_energy(join(" ", $item[4]));
            }

STARTTIME:   COMM  "Start_time"         ":"  DATETIME {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->start_time(join(" ", $item[4]));
            }

SOURCE:      COMM  "Source"             ":"  TEXT(s) {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
	     $Xray::XDI::object->source(join(" ", @{$item[4]}));
            }


EXT_FIELD_NAME:  PROPERWORD
EXT_FIELD:  COMM  EXT_FIELD_NAME  ":"  ANY(s?)  EOL {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
             $Xray::XDI::object->push_extension($item[2] . ': '. join(" ", @{$item[4]}));
            }

FIELD_LINE: DEFINEDFIELDS
DEFINEDFIELDS: (  ABSCISSA      | BEAMLINE    | CRYSTAL
                | COLLIMATION   | DSPACING    | EDGEENERGY
                | ENDTIME       | FOCUSING    | HARMONIC
                | REJECTION     | MUFLUOR     | MUREF
                | MUTRANS       | RINGCURRENT | RINGENERGY
                | STARTTIME     | SOURCE
               ) EOL

FIELDS:  (FIELD_LINE | EXT_FIELD)(s) FIELD_END

COMMENT_LINE: NOTDASH  ANY(s?) EOL {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
             $Xray::XDI::object->push_comment(join(" ", @{$item[2]}));
            }
COMMENTS:     COMMENT_LINE(s)  HEADER_END

LABEL:    ANY
LABELS:   COMM  LABEL(s) EOL {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
             $Xray::XDI::object->push_label(@{$item[2]});
            }

DATA_LINE: FLOAT(s) EOL {
             print(join("~", @item), $/) if $Xray::XDI::Version1_0::debug;
             $Xray::XDI::object->add_data_point(@{$item[1]})  if $#{$item[1]}>-1;
             #print join("~", "DATA_LINE", @{$item[2]}), $/;
            }
DATA:      DATA_LINE(s?)

_EOGRAMMAR_
}

1;

=head1 NAME

Xray::XDI::Version1_0 - XDI 1.0 grammer definition

=head1 VERSION

This role defined version 1.0 of the XAS Data Interchange grammer.

=head1 ATTRIBUTES

=head2 Defined fields

One attribute is provided for each defined field in the grammer.  Each
attribute is spelled exactly the same as it is expected in an XDI
header, except that XDI headers are specified to be first-letter
capitalized while attribute names are all lower case.

=head2 Attribute order

The C<order> attribute defines the recommended order of attributes in
an exported XDI file:

   applications
   beamline
   source
   undulator_harmonic
   ring_energy
   ring_current
   collimation
   crystal
   d_spacing
   focusing
   harmonic_rejection
   edge_energy
   start_time
   end_time
   abscissa
   mu_transmission
   mu_fluorescence
   mu_reference

=head2 Structural elements

The following attributes defines XDI-complient character sequences for
use in exported files.  Compliance means that the exported file can be
imported as an XDI-compliant file.

=over 4

=item C<comment_character> (alias: C<cc>)

The character or character sequence which begins an exported comment
line.  The default is C<#>.

=item C<field_end> (alias: C<fe>)

The character sequence which marks the end of the defined and
extension fields.  The default is C<#//>.

=item C<header_end> (alias: C<fe>)

The character sequence which marks the end of the header.  It follows
the user comment section.  The default is C<#> followed by 60 dashes
(C<->).

=item C<record_separator> (alias: C<rs>)

The white space which separates labels in the label line and numbers
in the data lines.  The default is a single tab.

=back

=head1 BNF GRAMMER

This grammer is expressed in BNF form as:

  blah blah

=head1 BUGS AND LIMITATIONS

=over 4

=item *

INF and NAN are not supported in this implementation

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


