package Demeter::UI::Hephaestus::F1F2;

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
use Cwd qw(cwd);
use File::Spec;

use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON EVT_KEY_DOWN EVT_RADIOBOX EVT_FILEPICKER_CHANGED);
use Wx::Perl::TextValidator;
use base 'Wx::Panel';

#use Demeter;
use Demeter::UI::Wx::PeriodicTable;

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $pt = Demeter::UI::Wx::PeriodicTable->new($self, sub{$self->f1f2_get_data($_[0])});
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($vbox);
  $vbox -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the rest of the controls
  $self->{gridbox} = Wx::StaticBox->new($self, -1, 'Energy grid', wxDefaultPosition, wxDefaultSize);
  $self->{gridboxsizer} = Wx::StaticBoxSizer->new( $self->{gridbox}, wxHORIZONTAL );

  $self->{startingenergy} = Demeter->co->default(qw(hephaestus f1f2_emin));
  $self->{endingenergy}   = Demeter->co->default(qw(hephaestus f1f2_emax));
  $self->{energygrid}     = Demeter->co->default(qw(hephaestus f1f2_grid));
  $self->{echo}           = $echoarea;

  my $label = Wx::StaticText->new($self, -1, 'Starting Energy', wxDefaultPosition, wxDefaultSize);
  $self->{gridboxsizer} -> Add($label, 0, wxALL, 5);
  $self->{start} = Wx::TextCtrl->new($self, -1, $self->{startingenergy}, wxDefaultPosition, wxDefaultSize, wxWANTS_CHARS);
  $self->{start}->SetValidator(numval());
  $self->{gridboxsizer} -> Add($self->{start}, 1, wxEXPAND|wxALL, 5);

  my $spacer = 40;
  $self->{gridboxsizer} -> Add( $spacer, 10, 0, wxGROW );

  $label = Wx::StaticText->new($self, -1, 'Ending Energy', wxDefaultPosition, wxDefaultSize);
  $self->{gridboxsizer} -> Add($label, 0, wxALL, 5);
  $self->{end} = Wx::TextCtrl->new($self, -1, $self->{endingenergy}, wxDefaultPosition, wxDefaultSize, wxWANTS_CHARS);
  $self->{end}->SetValidator(numval());
  $self->{gridboxsizer} -> Add($self->{end}, 1, wxEXPAND|wxALL, 5);

  $self->{gridboxsizer} -> Add( $spacer, 10, 0, wxGROW );

  $label = Wx::StaticText->new($self, -1, 'Energy Grid', wxDefaultPosition, wxDefaultSize);
  $self->{gridboxsizer} -> Add($label, 0, wxALL, 5);
  $self->{grid} = Wx::TextCtrl->new($self, -1, $self->{energygrid}, wxDefaultPosition, wxDefaultSize, wxWANTS_CHARS);
  $self->{grid}->SetValidator(numval());
  $self->{gridboxsizer} -> Add($self->{grid}, 1, wxEXPAND|wxALL, 5);

  $vbox -> Add($self->{gridboxsizer}, 0, wxALIGN_CENTER_HORIZONTAL|wxALL);

  #$vbox -> Add( 20, 10, 0, wxGROW );

  #$self->{convbox} = Wx::StaticBox->new($self, -1, 'Convolution', wxDefaultPosition, wxDefaultSize);
  #$self->{convboxsizer} = Wx::StaticBoxSizer->new( $self->{gridbox}, wxHORIZONTAL );

  $vbox -> Add( 20, 10, 0, wxGROW );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{howtoplot} = 'New plot';
  $self->{plot} = Wx::RadioBox->new( $self, -1, '', wxDefaultPosition, wxDefaultSize,
				     ['New plot', 'Overplot'], 1, wxRA_SPECIFY_COLS);
  #EVT_RADIOBOX( $self, $self->{plot}, \&search_edges );
  $hbox -> Add($self->{plot}, 0, wxALL, 5);

  $self->{plotpart} = 'New plot';
  $self->{part} = Wx::RadioBox->new( $self, -1, '', wxDefaultPosition, wxDefaultSize,
				     ["Plot both f' and f\"", "Plot just f'", 'Plot just f"'], 1, wxRA_SPECIFY_COLS);
  #EVT_RADIOBOX( $self, $self->{plot}, \&search_edges );
  $hbox -> Add($self->{part}, 0, wxALL, 5);

  $vbox -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL);

  $vbox -> Add( 20, 10, 0, wxGROW );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{save} = Wx::Button->new($self, -1, 'Save data', wxDefaultPosition, [120,-1]);
  $self->{save}->Enable(0);
  EVT_BUTTON( $self, $self->{save}, sub{save_f1f2_data(@_, $self)} );
  $hbox -> Add($self->{save}, 0, wxALL, 5);

  $vbox -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL);

  ## finish up
  $self -> SetSizerAndFit( $vbox );

  return $self;
};


sub numval {
  return Wx::Perl::TextValidator -> new('\d');
};

sub f1f2_get_data {
  my ($self, $el) = @_;
  local $| = 1;
  ##print join("|", $el, $self->{howplot}, $self->{fplot}, $self->{natural}->get_active, $self->{eminbox}->get_text), $/;

  $self->{element} = $el;
  $self->{save}->Enable(1);
  $self->{save}->SetLabel('Save ' . get_symbol($el) . ' data');

  ## -------- error checking
  if ($self->{start}->GetValue < 100) {
    $self->{echo}->SetStatusText('The starting energy is below 100 eV.  Plot canceled.');
    return;
  };
  if ($self->{end}->GetValue < 100) {
    $self->{echo}->SetStatusText('The ending energy is below 100 eV.  Plot canceled.');
    return;
  };
  if ($self->{start}->GetValue > $self->{end}->GetValue) {
    my ($start, $end) = ($self->{start}->GetValue, $self->{end}->GetValue);
    $self->{start}->SetValue($end);
    $self->{end}->SetValue($start);
    $self->{echo}->SetStatusText('The start and end values of the energy grid were out of order.');
  };
  if ($self->{grid}->GetValue < 1) {
    $self->{grid}->SetValue(1);
    $self->{echo}->SetStatusText('The energy grid size was too small and was reset to 1.');
  };

  my $busy    = Wx::BusyCursor->new();
  Demeter -> po -> start_plot if ($self->{plot}->GetStringSelection =~ m{New});
  Demeter -> co -> set(
		       f1f2_emin    => $self->{start}->GetValue,
		       f1f2_emax    => $self->{end}->GetValue,
		       f1f2_egrid   => $self->{grid}->GetValue,
		       f1f2_z       => $el,
		       f1f2_newplot => ($self->{plot}->GetStringSelection =~ m{New}) ? 1 : 0,
		       f1f2_width   => 0, # ($self->{natural}->get_active) ? 0 : $self->{widthbox}->get_text,
		       f1f2_file    => Demeter->po->tempfile,
		      );
  my $which = ($self->{part}->GetStringSelection =~ m{both}) ? 'f1f2'
            : ($self->{part}->GetStringSelection =~ m{f'\z}) ? 'f1'
	    :                                                  'f2';
  Demeter->dispense("plot", 'prep_f1f2');
  Demeter->chart("plot", $which);

  $self->{echo}->SetStatusText(sprintf("Plotted anomalous scattering factors for %s using the %s tables.",
			      get_name($el), 'Cromer-Liberman'));
  undef $busy;
  return 1;
};

sub save_f1f2_data {
  my ($self, $event, $parent) = @_;

  my $default = join('.', get_name($parent->{element}), 'f1f2');
  my $fd = Wx::FileDialog->new( $self, "Output File", cwd, $default,
				"f1f2 files (*.f1f2)|*.f1f2|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  return if ($fd->ShowModal == wxID_CANCEL);
  my $file = $fd->GetPath;
  # if (-e $file) {
  #   my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
  # 						 "Overwrite existing file \"$file\"?",
  # 						 "Overwrite file?",
  # 						 "Overwrite",
  # 						);
  #                                     ##Wx::GetMousePosition  how is this done?
  #   my $ok = $yesno->ShowModal;
  #   return if $ok == wxID_NO;
  # };
  Demeter -> co -> set(
		       f1f2_save => $file,
		      );
  undef($fd);
  Demeter->dispense("plot", 'save_f1f2');
};


1;

=head1 NAME

Demeter::UI::Hephaestus::F1F2 - Hephaestus' anomalous scattering utility

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

The contents of Hephaestus' anomalous scattering utility can be added
to any Wx application.

  my $page = Demeter::UI::Hephaestus::F1F2->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility uses a periodic table as the interface to anomalous
scattering factors for the elements.  Clicking on an element in the
periodic table will plot that elements anomalous scattering factors.
There are controls for setting the energy grid of the plot, deciding
which of f' and f" are plotted, and deciding whether to overplot or to
start a new plot.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Currently using natural line width.  Might want to allow the user to
specify a line width.

=item *

A diffkk interface for real data would be nice.

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
