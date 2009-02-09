package Demeter::UI::Artemis;

use Demeter;
use vars qw($demeter);
$demeter = Demeter->new;

use File::Basename;
use File::Spec;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER);
use base 'Wx::App';

use Wx::Perl::Carp;
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
#$SIG{__DIE__}  = sub {Wx::Perl::Carp::croak($_[0])};

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($artemis_base $icon %frames);
$artemis_base = identify_self();

my %hints = (
	     gds => "Display the Guess/Def/Set dialog",
	     plot => "Display the plotting dialog",
	     fit => "Display the fit history dialog",
	    );

sub OnInit {
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Artemis');
  #$demeter -> plot_with($demeter->co->default(qw(feff plotwith)));

  ## -------- import all of Artemis' various parts
  foreach my $m (qw(GDS Plot History)) {
    next if $INC{"Demeter/UI/Artemis/$m.pm"};
    ##print "Demeter/UI/Artemis/$m.pm\n";
    require "Demeter/UI/Artemis/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frames{main} = Wx::Frame->new(undef, -1, 'Artemis: EXAFS data analysis',
				[0,0], # position -- along top of screen
				[Wx::SystemSettings::GetMetric(wxSYS_SCREEN_X), 170] # size -- entire width of screen
			       );
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Artemis.pm'}), 'Artemis', 'icons', "artemis.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frames{main} -> SetIcon($icon);

  ## -------- Set up menubar
  my $bar = Wx::MenuBar->new;
  my $file = Wx::Menu->new;
  $file->Append( wxID_EXIT, "E&xit" );

  my $help = Wx::Menu->new;
  $help->Append( wxID_ABOUT, "&About..." );

  $bar->Append( $file, "&File" );
  $bar->Append( $help, "&Help" );
  $frames{main}->SetMenuBar( $bar );
  EVT_MENU( $frames{main}, wxID_ABOUT, \&on_about );
  EVT_MENU( $frames{main}, wxID_EXIT, sub{shift->Close} );
  EVT_CLOSE( $frames{main},  \&on_close);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);

  ## -------- GDS and Plot toolbar
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $toolbar = Wx::ToolBar->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT);
  EVT_MENU( $toolbar, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $frames{main})} );
  $toolbar -> AddCheckTool(-1, "Show GDS",           icon("gds"),     wxNullBitmap, wxITEM_NORMAL, q{}, $hints{gds} );
  $toolbar -> AddCheckTool(-1, "  Show plot tools",  icon("plot"),    wxNullBitmap, wxITEM_NORMAL, q{}, $hints{plot} );
  $toolbar -> AddCheckTool(-1, "  Show fit history", icon("history"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{fit} );
  EVT_TOOL_ENTER( $frames{main}, $toolbar, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $toolbar -> Realize;
  $vbox -> Add($toolbar, 0, wxALL, 0);

  ## -------- Data box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $databox       = Wx::StaticBox->new($frames{main}, -1, 'Data sets', wxDefaultPosition, wxDefaultSize);
  my $databoxsizer  = Wx::StaticBoxSizer->new( $databox, wxVERTICAL );

  my $datalist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  $datalist->SetScrollbars(20, 20, 50, 50);
  my $datavbox = Wx::BoxSizer->new( wxVERTICAL );
  $datalist->SetSizer($datavbox);
  my $datatool = Wx::ToolBar->new($datalist, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT|wxTB_LEFT);
  my $thing = $datatool -> AddTool(-1, "New data", icon("add"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  #$thing -> SetFont(Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $datatool -> AddSeparator;
  $datatool -> AddCheckTool(-1, "Show data set 1", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> AddCheckTool(-1, "Show data set 2 blah blah", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> AddCheckTool(-1, "Show data set 3", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> AddCheckTool(-1, "Show data set 4", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> AddCheckTool(-1, "Show data set 5", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> AddCheckTool(-1, "Show data set 6", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> Realize;
  $datavbox     -> Add($datatool);
  $databoxsizer -> Add($datalist, 1, wxGROW|wxALL, 0);
  $hbox         -> Add($databoxsizer, 1, wxGROW|wxALL, 0);


  ## -------- Feff box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $feffbox       = Wx::StaticBox->new($frames{main}, -1, 'Feff calculations', wxDefaultPosition, wxDefaultSize);
  my $feffboxsizer  = Wx::StaticBoxSizer->new( $feffbox, wxVERTICAL );

  my $fefflist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  $fefflist->SetScrollbars(20, 20, 50, 50);
  my $feffvbox = Wx::BoxSizer->new( wxVERTICAL);
  $fefflist->SetSizer($feffvbox);
  my $fefftool = Wx::ToolBar->new($fefflist, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT|wxTB_LEFT);
  $fefftool -> AddTool(-1, "New Feff calculation", icon("add"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddSeparator;
  $fefftool -> AddCheckTool(-1, "Show feff calc 1", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddCheckTool(-1, "Show feff calc 2", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddCheckTool(-1, "Show feff calc 3", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddCheckTool(-1, "Show feff calc 4", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddCheckTool(-1, "Show feff calc 5", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> AddCheckTool(-1, "Show feff calc 6", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $fefftool -> Realize;
  $feffvbox     -> Add($fefftool);
  $feffboxsizer -> Add($fefflist, 1, wxGROW|wxALL, 0);
  $hbox         -> Add($feffboxsizer, 1, wxGROW|wxALL, 0);

  ## -------- Fit box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);

  my $fitbutton = Wx::Button->new($frames{main}, -1, "Fit", wxDefaultPosition, wxDefaultSize);
  $fitbutton -> SetForegroundColour(Wx::Colour->new("#ffffff"));
  $fitbutton -> SetBackgroundColour(Wx::Colour->new(0, 192, 0, 0));
  $fitbutton -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox->Add($fitbutton, 0, wxGROW|wxALL, 0);

  my $hfit = Wx::BoxSizer->new( wxHORIZONTAL);
  $vbox -> Add($hfit, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  my $label = Wx::StaticText->new($frames{main}, -1, "Name");
  my $name  = Wx::TextCtrl->new($frames{main}, -1, q{});
  $hfit -> Add($label, 0, wxALL, 5);
  $hfit -> Add($name, 1, wxALL, 2);

  my $descbox      = Wx::StaticBox->new($frames{main}, -1, 'Fit description', wxDefaultPosition, wxDefaultSize);
  my $descboxsizer = Wx::StaticBoxSizer->new( $descbox, wxVERTICAL );
  my $description  = Wx::TextCtrl->new($frames{main}, -1, q{}, wxDefaultPosition, [-1, 25], wxTE_MULTILINE);
  $descboxsizer   -> Add($description,  1, wxGROW|wxALL, 0);
  $vbox           -> Add($descboxsizer, 1, wxGROW|wxALL, 0);

  ## -------- status bar
  my $statusbar = $frames{main}->CreateStatusBar;
  $statusbar -> SetStatusText("Welcome to Artemis (" . $demeter->identify . ")");


  $frames{main} -> SetSizer($hbox);
  #$hbox  -> Fit($toolbar);
  #$hbox  -> SetSizeHints($toolbar);

  foreach my $part (qw(GDS Plot History)) {
    my $pp = "Demeter::UI::Artemis::".$part;
    $frames{$part} = $pp->new;
    $frames{$part} -> SetIcon($icon);
  };
  $frames{main} -> Show( 1 );
}

sub on_close {
  my ($self) = @_;
  foreach (values(%frames)) {$_->Destroy};
};

sub on_about {
  my ($self) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Artemis' );
  #$info->SetVersion( $demeter->version );
  $info->SetDescription( "EXAFS analysis using Feff and Ifeffit" );
  $info->SetCopyright( $demeter->identify );
  $info->SetWebSite( 'http://cars9.uchicago.edu/iffwiki/Demeter', 'The Demeter web site' );
  $info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n",
			 "Ifeffit is copyright © 1992-2009 Matt Newville"
			] );
  $info->SetLicense( slurp(File::Spec->catfile($artemis_base, 'Atoms', 'data', "GPL.dem")) );
  my $artwork = <<'EOH'
Blah blah blah

Some icons taken from the Fairytale icon set at Wikimedia commons,
http://commons.wikimedia.org/ and others from the Gartoon Redux icon
set from http:://www.gnome-look.org

All other icons icons are from the Kids icon set for
KDE by Everaldo Coelho, http://www.everaldo.com
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
};

sub button_label {
  my ($string) = @_;
  my $this =  sprintf("%-40s", $string);
  return $string;
};

sub icon {
  my ($which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Artemis::artemis_base, 'Artemis', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub slurp {
  my $file = shift;
  local $/;
  open(my $FH, $file);
  my $text = <$FH>;
  close $FH;
  return $text;
};

sub _doublewide {
  my ($widget) = @_;
  my ($w, $h) = $widget->GetSizeWH;
  $widget -> SetSizeWH(2*$w, $h);
};


sub OnToolEnter {
  1;
};
sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  my $which = (qw(GDS Plot History))[$toolbar->GetToolPos($event->GetId)];
  $frames{$which}->Show($toolbar->GetToolState($event->GetId));
};



1;


=head1 NAME

Demeter::UI::Artemis - EXAFS analysis using Feff and Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

This short program launches Artemis:

  use Wx;
  use Demeter::UI::Artemis;
  Wx::InitAllImageHandlers();
  my $window = Demeter::UI::Artemis->new;
  $window -> MainLoop;

=head1 DESCRIPTION

Artemis...

=head1 USE

Using ...

=head1 CONFIGURATION

Many aspects of Artemis and its UI are configurable using the
configuration ...

=head1 DEPENDENCIES

This is a Wx application.  Demeter's dependencies are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

blah blah

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
