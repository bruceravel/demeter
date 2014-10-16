package Demeter::UI::Hephaestus::Standards;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Cwd;
use Scalar::Util qw(looks_like_number);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_LISTBOX
		 EVT_BUTTON EVT_KEY_DOWN EVT_RADIOBOX EVT_FILEPICKER_CHANGED);

use Demeter::UI::Standards;
my $standards = Demeter::UI::Standards->new();
$standards -> ini(q{});

use Demeter::UI::Wx::PeriodicTable;
use Demeter::UI::Wx::SpecialCharacters qw($MU);
use Demeter::UI::Artemis::ShowText;

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  my $pt = Demeter::UI::Wx::PeriodicTable->new($self, sub{$self->standards_get_data($_[0])}, $echoarea);
  foreach my $i (1 .. 109) {
    my $el = get_symbol($i);
    $pt->{$el}->Disable if not $standards->element_exists($el);
  };
  $pt->{Mt}->Disable;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($vbox);
  $vbox -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the rest of the controls
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  $self->{databox}       = Wx::StaticBox      -> new($self, -1, 'Standards', wxDefaultPosition, wxDefaultSize);
  $self->{databoxsizer}  = Wx::StaticBoxSizer -> new( $self->{databox}, wxVERTICAL );
  $self->{data}          = Wx::ListBox        -> new($self, -1, wxDefaultPosition, wxDefaultSize,
						     [], wxLB_SINGLE|wxLB_ALWAYS_SB);
  $self->{databoxsizer} -> Add($self->{data}, 1, wxEXPAND|wxALL, 0);
  $hbox -> Add($self->{databoxsizer}, 2, wxEXPAND|wxALL, 5);
  EVT_LISTBOX( $self, $self->{data}, sub{echo_comment(@_, $self)} );

  my $controlbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($controlbox, 1, wxEXPAND|wxALL, 5);

  # $self->{howtoplot} = Wx::RadioBox->new( $self, -1, '', wxDefaultPosition, wxDefaultSize,
  # 				     ['Display XANES', 'Display derivative'], 1, wxRA_SPECIFY_COLS);
  # $controlbox -> Add($self->{howtoplot}, 0, wxEXPAND|wxALL, 5);

  $self->{plotbox} = Wx::StaticBox->new($self, -1, 'Plot', wxDefaultPosition, wxDefaultSize);
  $self->{plotboxsizer} = Wx::StaticBoxSizer->new( $self->{plotbox}, wxHORIZONTAL );
  $controlbox -> Add($self->{plotboxsizer}, 0, wxEXPAND|wxLEFT|wxRIGHT, 5);


  $self->{plot} = Wx::Button->new($self, -1, 'XANES', wxDefaultPosition, wxDefaultSize);
  EVT_BUTTON( $self, $self->{plot}, sub{make_standards_plot(@_, $self, 'mu')} );
  $self->{plot}->Disable;

  $self->{plotd} = Wx::Button->new($self, -1, 'Derivative', wxDefaultPosition, wxDefaultSize);
  EVT_BUTTON( $self, $self->{plotd}, sub{make_standards_plot(@_, $self, 'deriv')} );
  $self->{plotd}->Disable;

  $self->{plotboxsizer}->Add($self->{plot},  1, wxEXPAND|wxALL, 2);
  $self->{plotboxsizer}->Add($self->{plotd}, 1, wxEXPAND|wxALL, 2);

  $self->{save} = Wx::Button->new($self, -1, q{Save to a file}, wxDefaultPosition, [120,-1]);
  EVT_BUTTON( $self, $self->{save}, sub{save_standard(@_, $self)} );
  $controlbox -> Add($self->{save}, 0, wxEXPAND|wxALL, 5);
  $self->{save}->Disable;

  $self->{about} = Wx::Button->new($self, -1, q{Info about standard}, wxDefaultPosition, [120,-1]);
  EVT_BUTTON( $self, $self->{about}, sub{about(@_, $self)} );
  $controlbox -> Add($self->{about}, 0, wxEXPAND|wxLEFT|wxRIGHT, 5);
  $self->{about}->Disable;

  ## finish up
  $vbox -> Add($hbox, 1, wxEXPAND|wxALL);
  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub standards_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);

  my @choices;
  foreach my $data ($standards->material_list) {
    next if ($data eq 'config');
    next if (lc($el) ne $standards->get($data, 'element'));
    push @choices, $standards->get($data, 'name'); #ucfirst($data);
  };
  return 0 unless @choices;
  $self->{plot}  -> Enable;
  $self->{plotd} -> Enable;
  $self->{save}  -> Enable;
  $self->{about} -> Enable;
  $self->{data}  -> Set(\@choices);
  $self->{data}  -> SetSelection(0);
  my $comment = sprintf('%s : %s, measured by %s (%s) at %s',
			$standards->get(lc($choices[0]), 'tag'),
			$standards->get(lc($choices[0]), 'comment'),
			$standards->get(lc($choices[0]), 'people'),
			$standards->get(lc($choices[0]), 'date'),
			$standards->get(lc($choices[0]), 'location')
		       );
  $self->{echo}->SetStatusText($comment);
  return 1;
};

sub make_standards_plot {
  my ($self, $event, $parent, $which) = @_;
  my $busy    = Wx::BusyCursor->new();
  #my $which   = ($parent->{howtoplot}->GetStringSelection =~ m{XANES}) ? 'mu' : 'deriv';
  my $choice  = $parent->{data}->GetStringSelection;
  my $result  = $standards -> plot($choice, $which, 'plot');

  my $this = lc($parent->{data}->GetString($parent->{data}->GetSelection));
  $self->{echo}->SetStatusText(sprintf('%s : %s, measured by %s (%s) at %s',
				       $standards->get($this, 'tag'),
				       $standards->get($this, 'comment'),
				       $standards->get($this, 'people'),
				       $standards->get($this, 'date'),
				       $standards->get($this, 'location')
				      ));
  undef $busy;
  return 0 if ($result =~ m{Demeter});
  return 0 if (looks_like_number($result) and ($result == 0));
  $self->{echo}->SetStatusText($result);
  return 1;
};

sub save_standard {
  my ($self, $event, $parent) = @_;
  my $choice  = $parent->{data}->GetStringSelection;
  (my $cc = $choice) =~ s{\s+}{_}g;
  my $default = join('.', $cc, 'xmu');
  my $fd = Wx::FileDialog->new( $self, "$MU(E) file", cwd, $default,
				"data (*.dat,*.xmu)|*.data,*.xmu|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  return if ($fd->ShowModal == wxID_CANCEL);
  my $file = $fd->GetPath;
  # if (-e $file) {
  #   my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
  # 						 "Overwrite existing file \"$file\"?",
  # 						 "Overwrite file?",
  # 						 "Overwrite"
  # 						);
  #                                     ##Wx::GetMousePosition  how is this done?
  #   my $ok = $yesno->ShowModal;
  #   return if $ok == wxID_NO;
  # };
  my $ret = $standards->save($choice, $file);
  if ($ret =~ m{Demeter}) {
    $self->{echo}->SetStatusText("Saved $MU(E) for $choice to $file");
  } else {
    $self->{echo}->SetStatusText($ret);
  };
};

sub about {
  my ($self, $event, $parent) = @_;
  my $choice  = $parent->{data}->GetStringSelection;
  my $save = $Text::Wrap::columns;
  $Text::Wrap::columns = 60;
  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($parent, $standards->report($choice), "About $choice")
      -> Show;
  $Text::Wrap::columns = $save;
};
sub echo_comment {
  my ($self, $event, $parent) = @_;
  my $which = lc($event->GetString);
  return if not $which;
  my $comment = sprintf('%s : %s, measured by %s (%s) at %s',
				       $standards->get($which, 'tag'),
				       $standards->get($which, 'comment'),
				       $standards->get($which, 'people'),
				       $standards->get($which, 'date'),
				       $standards->get($which, 'location')
				      );
  $self->{echo}->SetStatusText($comment);
  return 1;
};

1;


=head1 NAME

Demeter::UI::Hephaestus::Standards - Hephaestus' XAS data standards utility

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

The contents of Hephaestus' absorption utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Standards->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility uses a periodic table as the interface to a collection of
XAS data standards.  Each element which has data in the collection
will have an enabled button on the periodic table.  When an element's
button is pressed, each data standard with that element as the central
atom will be placed in the standards list.  The standard selected from
the list can then be plotted as XANES or derivative data.  Energies of
peaks in the XANES or derivative spectra will be marked and their
energies placed on the plot as text.  In this way, data measured at a
beamline can be compared to data standards in the collection.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

It would be nice to save the standard(s) as files or as Athena
projects.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
