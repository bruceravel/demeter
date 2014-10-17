package  Demeter::UI::Artemis::Plot::Limits;


=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (http://bruceravel.github.io/home).
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

use Wx qw( :everything );
use base qw(Wx::Panel);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_CHOICE EVT_ENTER_WINDOW
		 EVT_LEAVE_WINDOW EVT_RADIOBOX EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

my @parts = ('Magnitude', 'Real', 'Imag.');

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $szr = Wx::BoxSizer->new( wxVERTICAL );

  ## -------- plotting part for chi(R)
  #if (Demeter->co->default('artemis', 'plot_phase')) {
  #  $this->{rpart} = Wx::RadioBox->new($this, -1, "Plot $CHI(R)", wxDefaultPosition, wxDefaultSize, [@parts, 'Phase', 'Der(Phase)'], 3, wxRA_SPECIFY_COLS);
  #} else {
  $this->{rpart} = Wx::RadioBox->new($this, -1, "Plot $CHI(R)", wxDefaultPosition, wxDefaultSize, \@parts, 1, wxRA_SPECIFY_ROWS);
  #};
  my $which = 0;
  ($which = 1) if (Demeter->co->default("plot", "r_pl") eq 'r');
  ($which = 2) if (Demeter->co->default("plot", "r_pl") eq 'i');
  $this->{rpart} -> SetSelection($which);
  $szr -> Add($this->{rpart}, 0, wxGROW|wxALL, 5);

  ## -------- plotting part for chi(q)
  $this->{qpart} = Wx::RadioBox->new($this, -1, "Plot $CHI(q)", wxDefaultPosition, wxDefaultSize, \@parts, 1, wxRA_SPECIFY_ROWS);
  my $which = 1;
  ($which = 0) if (Demeter->co->default("plot", "q_pl") eq 'm');
  ($which = 2) if (Demeter->co->default("plot", "q_pl") eq 'i');
  $this->{qpart} -> SetSelection($which);
  $szr -> Add($this->{qpart}, 0, wxGROW|wxALL, 5);

  Demeter->po->r_pl(Demeter->co->default("plot", "r_pl"));
  Demeter->po->q_pl(Demeter->co->default("plot", "q_pl"));
  EVT_RADIOBOX($this, $this->{rpart}, sub{OnChoice(@_, 'rpart', 'r_pl')});
  EVT_RADIOBOX($this, $this->{qpart}, sub{OnChoice(@_, 'qpart', 'q_pl')});
  $this->mouseover("rpart", "Choose the part of the complex $CHI(R) function to display when plotting the contents of the plotting list.");
  $this->mouseover("qpart", "Choose the part of the complex $CHI(q) function to display when plotting the contents of the plotting list.");

  ## -------- toggles for fit, win, bkg, res
  ##    after a fit: turn on fit toggle, bkg toggle is bkg refined
  my $gbs  =  Wx::GridBagSizer->new( 5,5 );
  $szr -> Add($gbs, 0, wxGROW|wxALL, 5);

  $this->{fit} = Wx::CheckBox->new($this, -1, "Plot fit");
  $gbs -> Add($this->{fit}, Wx::GBPosition->new(0,0));
  Demeter->po->plot_fit(0);
  $this->{background} = Wx::CheckBox->new($this, -1, "Plot bkg");
  $gbs -> Add($this->{background}, Wx::GBPosition->new(0,1));
  Demeter->po->plot_bkg(0);

  $this->{window} = Wx::CheckBox->new($this, -1, "Plot window");
  $gbs -> Add($this->{window}, Wx::GBPosition->new(1,0));
  $this->{window} -> SetValue(1);
  Demeter->po->plot_win(1);
  $this->{residual} = Wx::CheckBox->new($this, -1, "Plot residual");
  $gbs -> Add($this->{residual}, Wx::GBPosition->new(1,1));
  Demeter->po->plot_res(0);

  $this->{running} = Wx::CheckBox->new($this, -1, "Plot running R-factor");
  $gbs -> Add($this->{running}, Wx::GBPosition->new(2,0), Wx::GBSpan->new(1,2));
  Demeter->po->plot_run(0);

  EVT_CHECKBOX($this, $this->{fit},        sub{OnPlotToggle(@_, 'fit',        'plot_fit')});
  EVT_CHECKBOX($this, $this->{background}, sub{OnPlotToggle(@_, 'background', 'plot_bkg')});
  EVT_CHECKBOX($this, $this->{window},     sub{OnPlotToggle(@_, 'window',     'plot_win')});
  EVT_CHECKBOX($this, $this->{residual},   sub{OnPlotToggle(@_, 'residual',   'plot_res')});
  EVT_CHECKBOX($this, $this->{running},    sub{OnPlotToggle(@_, 'running',    'plot_run')});

  $this->mouseover("fit",        "Include the most recent fit when plotting a data set from the plotting list.");
  $this->mouseover("background", "Include the refined background when plotting a data set from the plotting list.");
  $this->mouseover("window",     "Include the most window function when making a plot from the plotting list.");
  $this->mouseover("residual",   "Include the residual of the most recent fit when plotting a data set from the plotting list.");
  $this->mouseover("running",    "Include the running R-factor of the most recent fit when plotting a data set from the plotting list.");


  $szr -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxLEFT|wxRIGHT, 10);

  ## -------- limits in k, R, and q
  $gbs  =  Wx::GridBagSizer->new( 10,5 );
  $szr -> Add($gbs, 0, wxGROW|wxALL, 5);
  my %po;

  $label    = Wx::StaticText->new($this, -1, "kmin");
  $this->{kmin} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "kmin"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(0,1));
  $gbs     -> Add($this->{kmin}, Wx::GBPosition->new(0,2));
  $label    = Wx::StaticText->new($this, -1, "kmax");
  $this->{kmax} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "kmax"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(0,3));
  $gbs     -> Add($this->{kmax}, Wx::GBPosition->new(0,4));

  $label    = Wx::StaticText->new($this, -1, "rmin");
  $this->{rmin} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "rmin"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(1,1));
  $gbs     -> Add($this->{rmin}, Wx::GBPosition->new(1,2));
  $label    = Wx::StaticText->new($this, -1, "rmax");
  $this->{rmax} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "rmax"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(1,3));
  $gbs     -> Add($this->{rmax}, Wx::GBPosition->new(1,4));

  $label    = Wx::StaticText->new($this, -1, "qmin");
  $this->{qmin} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "qmin"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(2,1));
  $gbs     -> Add($this->{qmin}, Wx::GBPosition->new(2,2));
  $label    = Wx::StaticText->new($this, -1, "qmax");
  $this->{qmax} = Wx::TextCtrl  ->new($this, -1, Demeter->co->default("plot", "qmax"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,    Wx::GBPosition->new(2,3));
  $gbs     -> Add($this->{qmax}, Wx::GBPosition->new(2,4));

  $this->{kmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{kmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{qmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{qmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $this->mouseover("kmin", "The lower bound of a plot of $CHI(k).");
  $this->mouseover("kmax", "The upper bound of a plot of $CHI(k).");
  $this->mouseover("rmin", "The lower bound of a plot of $CHI(r).");
  $this->mouseover("rmax", "The upper bound of a plot of $CHI(r).");
  $this->mouseover("qmin", "The lower bound of a plot of $CHI(q).");
  $this->mouseover("qmax", "The upper bound of a plot of $CHI(q).");

  EVT_TEXT_ENTER($this, $this->{kmin}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'k')});
  EVT_TEXT_ENTER($this, $this->{kmax}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'k')});
  EVT_TEXT_ENTER($this, $this->{rmin}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'r')});
  EVT_TEXT_ENTER($this, $this->{rmax}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'r')});
  EVT_TEXT_ENTER($this, $this->{qmin}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'q')});
  EVT_TEXT_ENTER($this, $this->{qmax}, sub{$Demeter::UI::Artemis::frames{Plot}->plot(q{}, 'q')});

  $this -> SetSizer($szr);
  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  my $sb = $Demeter::UI::Artemis::frames{main}->{statusbar};
  EVT_ENTER_WINDOW($self->{$widget}, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};


sub OnPlotToggle {
  my ($this, $event, $button, $accessor) = @_;
  Demeter->po->$accessor($this->{$button}->GetValue);
  my $plotframe = $Demeter::UI::Artemis::frames{Plot};
  $plotframe->plot($event, $plotframe->{last});
};
sub OnChoice {
  my ($this, $event, $choice, $accessor) = @_;
  Demeter->po->dphase(0);
  my $part = lc(substr($this->{$choice}->GetStringSelection, 0, 1));
  if ($part eq 'd') {
    Demeter->po->dphase(1);
    $part = 'p';
  };
  Demeter->po->$accessor($part);
  my $plotframe = $Demeter::UI::Artemis::frames{Plot};
  my $space = substr($choice, 0, 1);
  $plotframe->plot($event, $space);
};

1;

=head1 NAME

Demeter::UI::Artemis::Plot::Limits - plot space and limit controls

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides controls for plot space and plotting limits in
Artemis

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
