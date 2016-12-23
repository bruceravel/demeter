package Demeter::UI::Athena::Journal;
use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT);

use Demeter::Journal;

use vars qw($label $tag);
$label = "Journal";
$tag = 'Journal';

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;

  $this->{object} = Demeter::Journal->new;
  $this->{journal} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_RICH2);
  $box->Add($this->{journal}, 1, wxGROW|wxALL, 5);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: journal');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("other.journal")});
  EVT_TEXT($this, $this->{journal}, \&OnEdit);
  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  1;
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnEdit {
  $::app->{modified} ||= 1;
  $::app->{main}->{save}->Enable(1);
  $::app->{main}->{token}->SetLabel(q{*});
};

1;

=head1 NAME

Demeter::UI::Athena::Journal - A journal tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This module provide a text box for displaying and editing a project
journal.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

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
