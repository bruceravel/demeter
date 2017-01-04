package Demeter::UI::Athena::Plot::Other;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_TOGGLEBUTTON EVT_CHECKBOX EVT_RADIOBOX EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $titlebox       = Wx::StaticBox->new($this, -1, 'Title for marked group plot', wxDefaultPosition, wxDefaultSize);
  my $titleboxsizer  = Wx::StaticBoxSizer->new( $titlebox, wxHORIZONTAL );
  $box              -> Add($titleboxsizer, 0, wxGROW|wxALL, 2);
  $this->{title}     = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $titleboxsizer    -> Add($this->{title}, 1, wxALL|wxGROW, 0);
  EVT_TEXT_ENTER($this, $this->{title}, sub{
		   $app->plot(q{}, q{}, @{$app->{lastplot}});
		 });

  $this->{location}  = Wx::RadioBox->new($this, -1, 'Legend location', wxDefaultPosition, wxDefaultSize,
					 ["top left", "top right", "bottom left", "bottom right"], 2, wxRA_SPECIFY_COLS);
  $this->{location}  -> SetStringSelection($app->current_data->co->default('gnuplot', 'keylocation'));
  EVT_RADIOBOX($this, $this->{location}, sub{location(@_,$app)});
  $box               -> Add($this->{location},   0, wxGROW|wxLEFT|wxRIGHT, 2);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box    -> Add($hbox,   0, wxGROW|wxALL, 0);
  $this->{nokey}      = Wx::CheckBox->new($this, -1, "Suppress legend");
  $hbox              -> Add($this->{nokey},       0, wxGROW|wxALL, 2);
  $this->{outside}    = Wx::CheckBox->new($this, -1, "Outside");
  $hbox              -> Add($this->{outside},     0, wxGROW|wxALL, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox   -> Add(Wx::StaticText->new($this, -1, "Marked plot pause (ms)"), 0, wxALL|wxTOP|wxRIGHT, 3);
  $this->{pause} = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox   -> Add($this->{pause}, 0, wxGROW|wxALL, 0);
  $box    -> Add($hbox,   0, wxGROW|wxALL, 0);
  $this->{pause} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9]) ) );

  $this->{singlefile} = Wx::ToggleButton->new($this, -1, "Save next plot to a file");
  $box    -> Add($this->{singlefile}, 0, wxGROW|wxALL, 2);

  EVT_CHECKBOX($this, $this->{nokey}, sub{
		 $app->current_data->po->showlegend(not $_[0]->{nokey}->IsChecked);
		 $app->plot(q{}, q{}, @{$app->{lastplot}});
	       });
  EVT_CHECKBOX($this, $this->{outside}, sub{
		 $app->current_data->po->legendoutside($_[0]->{outside}->IsChecked);
		 $app->plot(q{}, q{}, @{$app->{lastplot}});
	       });
  $app->mouseover($this->{title},      "Specify a title for a marked group plot.");
  $app->mouseover($this->{nokey},      "Turn off the legend in subsequent plots.");
  $app->mouseover($this->{outside},    "Place the legend outside of the plot frame.");
  $app->mouseover($this->{singlefile}, "Write the next plot to a column data file.  (Does not yet work for quad, stddev, or variance plots.)");
  $app->mouseover($this->{pause},      "Specify a pause in miliseconds between groups in a marked group plot.");

  $this->SetSizerAndFit($box);
  return $this;
};

sub location {
  my ($this, $event, $app) = @_;
  $app->current_data->co->set_default('gnuplot', 'keylocation', $this->{location}->GetStringSelection);
  $app->plot(q{}, q{}, @{$app->{lastplot}});
};

sub label {
  return 'Title, legend, single file';
};

1;


=head1 NAME

Demeter::UI::Athena::Plot::Other - miscellaneous plotting controls

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module provides miscellaneous plotting controls for Athena

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

Copyright (c) 2006-2017 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
