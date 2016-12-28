package Demeter::UI::Athena::Deconvolute;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Deconvolute data";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  $box->Add(Wx::StaticText->new($this, -1, "This part of Athena has not yet been implemented."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: deconvolution');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.deconv")});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

## yes, there is some overlap between what push_values and mode do.
## This separation was useful in Main.pm.  Some of the other tools
## make mode a null op.

1;


=head1 NAME

Demeter::UI::Athena::Deconvolute - A deconvolution tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
