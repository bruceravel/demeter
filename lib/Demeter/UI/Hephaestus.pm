package Demeter::UI::HephaestusApp;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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

use Wx::Perl::Carp;
use File::Spec;

use Demeter qw(:hephaestus);
use Demeter::UI::Hephaestus::Common qw(hversion);

use Wx qw( :everything );
use base 'Wx::Frame';
use Wx::Event qw(EVT_TOOLBOOK_PAGE_CHANGED EVT_TOOLBOOK_PAGE_CHANGING);

$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};

my $header_color = Wx::Colour->new(68, 31, 156);

my %note_of = (Absorption   => 'periodic table of edge and line energies',
	       Formulas     => 'compute total cross sections of materials',
	       Data	    => 'periodic table of physical and chemical data',
	       IonicRadii   => 'Shannon ionic radii of the elements',
	       Ion	    => 'optimize ion chamber gases',
	       Transitions  => 'electronic transitions for fluorescence lines',
	       EdgeFinder   => 'ordered list of absorption edge energies',
	       LineFinder   => 'ordered list of fluorescence line energies',
	       Standards    => 'periodic table of XAS data standards',
	       F1F2	    => 'periodic table of anomalous scattering',
	       Help	    => 'Hephaestus Users\' Guide',
	       Config       => 'control details of Hephaestus\' behavior',
	     );
my %label_of = (Absorption   => ' Absorption ',
		Formulas     => '  Formulas  ',
		Data	     => '    Data    ',
		IonicRadii   => 'Ionic Radii ',
		Ion	     => 'Ion chambers',
		Transitions  => ' Transitions',
		EdgeFinder   => ' Edge finder',
		LineFinder   => ' Line finder',
		Standards    => '  Standards ',
		F1F2	     => " F' and F\"  ",
		Help	     => '  Document  ',
		Config       => '  Configure ',
	       );
my $icon_dimension = 30;

use vars qw($periodic_table);

my @utilities = qw(Absorption Formulas Ion Data Transitions EdgeFinder LineFinder Standards F1F2 Config); # Help);
#my @utilities = qw(Absorption Formulas Ion Data Transitions EdgeFinder LineFinder Standards F1F2 Config Help);

sub new {
  my $ref    = shift;
  my $width  = 100;
  my $height = int(($#utilities+1) * $icon_dimension * 2.2); # + 2*($#utilities+1);
  my $self   = $ref->SUPER::new( undef,           # parent window
				 -1,              # ID -1 means any
				 'Hephaestus',    # title
				 wxDefaultPosition, [-1,$height],
			       );
  my $tb = Wx::Toolbook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT|wxTB_NO_TOOLTIPS );
  my $statusbar = $self->CreateStatusBar;
  $self->{book}      = $tb;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  #Demeter->set_mode('plotscreen'=>1);

  my @list = ('hephaestus', 'plot');
  push @list, 'gnuplot' if (Demeter->co->default(qw(plot plotwith)) eq 'gnuplot');
  push @list, 'larch'   if (Demeter->is_larch);
  $self->{prefgroups} = \@list;

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    my $icon = File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base, 'Hephaestus', 'icons', "$utility.png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };
  $tb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $tb->GetPageCount;
    #my $select = ($count) ? 0 : 1;
    my $page = Wx::Panel->new($tb, -1);
    $self->{$utility."_page"} = $page;
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $self->{$utility."_sizer"} = $box;

    ##$periodic_table = Demeter::UI::Wx::PeriodicTable->new($page, sub{$self->multiplex($_[0])}, $statusbar);

    if ($utility eq 'Absorption') {
      my $l = $label_of{$utility};
      $l =~ s{\A\s+}{};
      $l =~ s{\s+\z}{};
      my $label = $l.': '.$note_of{$utility};
      my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
      my $header = Wx::StaticText->new( $page, -1, $label, wxDefaultPosition, wxDefaultSize );
      $header->SetForegroundColour( $header_color );
      $header->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
      $hh -> Add($header, 0, wxLEFT, 5);
      $box -> Add($hh, 0);

      $self->{$utility} = Demeter::UI::Hephaestus::Absorption  -> new($page,$statusbar);
      $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
      $hh  -> Add($self->{$utility}, 1, wxGROW|wxEXPAND|wxALL, 0);
      $box -> Add($hh, 1, wxEXPAND|wxALL, 0);
      my $this_width = ($self->{$utility}->GetSizeWH)[0];
      my $this_height = ($self->{$utility}->GetSizeWH)[1];
      ($height = $this_height) if ($this_height > $height);
      ($width  = $this_width)  if ($this_width > $width);
      #print $utility, "  ", $this_height, "  ", $height, $/;

      $page -> SetSizer($box);

    };
    $tb->AddPage($page, sprintf("%11s", $label_of{$utility}), 0, $count);
    $height = ($tb->GetSizeWH)[1];
  };

  $vbox -> Add($tb, 1, wxEXPAND|wxALL, 0);
  EVT_TOOLBOOK_PAGE_CHANGED( $self, $tb, sub{$statusbar->SetStatusText(q{})} );
  EVT_TOOLBOOK_PAGE_CHANGING( $self, $tb, sub{make_page(@_)}); # postpone setting up pages until they are selected

  ##            largest utility + width of toolbar text + width of icons
  my $framesize = Wx::Size->new(1.05*$width+$icon_dimension+103,
				int($height*($#utilities+0.75)/$#utilities)
			       );
  $self -> SetSize($framesize);


  $self -> SetSizerAndFit($vbox);
  $vbox -> Fit($tb);
  $vbox -> SetSizeHints($tb);
  return $self;
};
    # $self->{$utility}
    #   = ($utility eq 'Absorption')  ? Demeter::UI::Hephaestus::Absorption  -> new($page,$statusbar)
    #   : ($utility eq 'Configure')   ? Demeter::UI::Hephaestus::Config      -> new($page,$statusbar)
    #   : ($utility eq 'Data')        ? Demeter::UI::Hephaestus::Data        -> new($page,$statusbar)
    #   : ($utility eq 'F1F2')        ? Demeter::UI::Hephaestus::F1F2        -> new($page,$statusbar)
    #   : ($utility eq 'EdgeFinder')  ? Demeter::UI::Hephaestus::EdgeFinder  -> new($page,$statusbar)
    #   : ($utility eq 'Formulas')    ? Demeter::UI::Hephaestus::Formulas    -> new($page,$statusbar)
    #   : ($utility eq 'Help')        ? Demeter::UI::Hephaestus::Help        -> new($page,$statusbar)
    #   : ($utility eq 'Ion')         ? Demeter::UI::Hephaestus::Ion         -> new($page,$statusbar)
    #   : ($utility eq 'LineFinder')  ? Demeter::UI::Hephaestus::LineFinder  -> new($page,$statusbar)
    #   : ($utility eq 'Standards')   ? Demeter::UI::Hephaestus::Standards   -> new($page,$statusbar)
    #   : ($utility eq 'Transitions') ? Demeter::UI::Hephaestus::Transitions -> new($page,$statusbar)
    #   :                               0;

sub do_the_size_dance {
  my ($top) = @_;
  my @size = $top->GetSizeWH;
  $top -> SetSize($size[0], $size[1]+1);
  $top -> SetSize($size[0], $size[1]);
};

sub make_page {
  my ($self, $event) = @_;
  my $i = $event->GetSelection;
  my $which = $utilities[$i];
  return if exists $self->{$which};
  my $busy = Wx::BusyCursor->new;

  my $l = $label_of{$which};
  $l =~ s{\A\s+}{};
  $l =~ s{\s+\z}{};
  my $label = $l.': '.$note_of{$which};
  #my $label = $label_of{$which}.': '.$note_of{$which};
  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  my $header = Wx::StaticText->new( $self->{$which."_page"}, -1, $label, wxDefaultPosition, wxDefaultSize );
  $header->SetForegroundColour( $header_color );
  $header->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hh -> Add($header, 0, wxLEFT, 5);
  $self->{$which."_sizer"} -> Add($hh, 0, wxGROW);

  my $pm = "Demeter::UI::Hephaestus::$which";
  $self->{$which} = $pm -> new($self->{$which."_page"},$self->{statusbar});
  $self->{$which."_page"}->SetSize($self->{"Absorption_page"}->GetSize);
  $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
  $hh  -> Add($self->{$which}, 1, wxGROW|wxALL, 0);
  $self->{$which."_sizer"} -> Add($hh, 1, wxGROW|wxALL, 0);

  $self->{$which."_page"} -> SetSizerAndFit($self->{$which."_sizer"});

  undef $busy;
};


package Demeter::UI::Hephaestus;
use File::Basename;

use Wx qw( :everything );
#use Wx qw(wxBITMAP_TYPE_XPM wxID_EXIT wxID_ABOUT wxDEFAULT wxSLANT wxNORMAL);
use Wx::Event qw(EVT_MENU EVT_CLOSE);
use base 'Wx::App';

use Cwd;

use Demeter qw(:hephaestus);
use Demeter::UI::Hephaestus::Common qw(hversion hcopyright hdescription);

use Const::Fast;
const my $CONFIG    => Wx::NewId();
const my $DOCUMENT  => Wx::NewId();
const my $BUG	    => Wx::NewId();
const my $QUESTION  => Wx::NewId();
const my $ABS	    => Wx::NewId();
const my $FORM	    => Wx::NewId();
const my $ION	    => Wx::NewId();
const my $DATA	    => Wx::NewId();
const my $RADII	    => Wx::NewId();
const my $TRAN	    => Wx::NewId();
const my $EDGE	    => Wx::NewId();
const my $LINE	    => Wx::NewId();
const my $STAN	    => Wx::NewId();
const my $FPPP	    => Wx::NewId();
const my $TERM_1    => Wx::NewId();
const my $TERM_2    => Wx::NewId();
const my $TERM_3    => Wx::NewId();
const my $TERM_4    => Wx::NewId();
const my $PLOT_PNG  => Wx::NewId();
const my $PLOT_GIF  => Wx::NewId();
const my $PLOT_JPG  => Wx::NewId();
const my $PLOT_PDF  => Wx::NewId();
const my $PLOT_XKCD => Wx::NewId();


sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($hephaestus_base $frame);
$hephaestus_base = identify_self();

sub OnInit {
  Demeter -> mo -> ui('Wx');
  Demeter -> mo -> identity('Hephaestus');
  Demeter -> plot_with(Demeter->co->default(qw(plot plotwith)));

  foreach my $m (qw(Absorption Formulas Ion Data IonicRadii Transitions EdgeFinder LineFinder
		    Standards F1F2 Config)) { # Help
    next if $INC{"Demeter/UI/Hephaestus/$m.pm"};
    ##print "Demeter/UI/Hephaestus/$m.pm\n";
    require "Demeter/UI/Hephaestus/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frame = Demeter::UI::HephaestusApp->new;
#  $frame -> do_the_size_dance;
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Hephaestus.pm'}), 'Hephaestus', 'icons', "vulcan.xpm");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_XPM );
  $frame -> SetIcon($icon);

  ## -------- Set up menubar
  my $bar = Wx::MenuBar->new;
  my $file = Wx::Menu->new;

  #my $tool = Wx::Menu->new;
  $file->Append( $ABS,      "&Absorption\tCtrl+1" );
  $file->Append( $FORM,     "F&ormulas\tCtrl+2" );
  $file->Append( $ION,      "&Ion Chambers\tCtrl+3" );
  $file->Append( $DATA,     "&Data\tCtrl+4" );
  $file->Append( $TRAN,     "&Transitions\tCtrl+5" );
  $file->Append( $EDGE,     "&Edge Finder\tCtrl+6" );
  $file->Append( $LINE,     "&Line Finder\tCtrl+7" );
  $file->Append( $STAN,     "&Standards\tCtrl+8" );
  $file->Append( $FPPP,     "&F' and F\"\tCtrl+9" );
  $file->Append( $CONFIG,   "&Configure\tCtrl+c" );
  ##$file->Append( $DOCUMENT, "Docu&ment\tCtrl+m" );
  $file->AppendSeparator;
  $file->Append( wxID_EXIT, "E&xit\tCtrl+q" );

  my $plot;
  if (Demeter->co->default('plot', 'plotwith') eq 'gnuplot') {
    $plot = Wx::Menu->new;
    $plot->AppendRadioItem($TERM_1, "Plot to terminal 1", "Plot to terminal 1");
    $plot->AppendRadioItem($TERM_2, "Plot to terminal 2", "Plot to terminal 2");
    $plot->AppendRadioItem($TERM_3, "Plot to terminal 3", "Plot to terminal 3");
    $plot->AppendRadioItem($TERM_4, "Plot to terminal 4", "Plot to terminal 4");
    #my $imagemenu = Wx::Menu->new;
    #$imagemenu->Append($PLOT_PNG, "PNG", "Send the last plot to a PNG file");
    #$imagemenu->Append($PLOT_PDF, "PDF", "Send the last plot to a PDF file");
    #$plot->AppendSeparator;
    #$plot->AppendSubMenu($imagemenu, "Save last plot as...", "Save the last plot as an image file");
    $plot->AppendSeparator;
    $plot->AppendCheckItem( $PLOT_XKCD, , 'Plot XKCD style', 'Plot more or less in the style of an XKCD cartoon');
  };

  my $help = Wx::Menu->new;
  $help->Append( $CONFIG,    "&Configure\tCtrl+c" );
  $help->Append( $DOCUMENT,  "Docu&ment\tCtrl+m" );
  $help->Append( $BUG,       "Report a bug",    "How to report a bug in Athena" );
  $help->Append( $QUESTION,  "Ask a question",  "How to ask a question about Athena" );
  $file->AppendSeparator;
  $help->Append( wxID_ABOUT, "&About Hephaestus" );

  $bar->Append( $file, "H&ephaestus" );
  $bar->Append( $plot, "&Plot" ) if (Demeter->co->default('plot', 'plotwith') eq 'gnuplot');
  $bar->Append( $help, "&Help" );
  $frame->SetMenuBar( $bar );

  EVT_MENU( $frame, $ABS,      sub{shift->{book}->SetSelection(0)});
  EVT_MENU( $frame, $FORM,     sub{shift->{book}->SetSelection(1)});
  EVT_MENU( $frame, $ION,      sub{shift->{book}->SetSelection(2)});
  EVT_MENU( $frame, $DATA,     sub{shift->{book}->SetSelection(3)});
  #EVT_MENU( $frame, $RADII,    sub{shift->{book}->SetSelection(4)});
  EVT_MENU( $frame, $TRAN,     sub{shift->{book}->SetSelection(4)});
  EVT_MENU( $frame, $EDGE,     sub{shift->{book}->SetSelection(5)});
  EVT_MENU( $frame, $LINE,     sub{shift->{book}->SetSelection(6)});
  EVT_MENU( $frame, $STAN,     sub{shift->{book}->SetSelection(7)});
  EVT_MENU( $frame, $FPPP,     sub{shift->{book}->SetSelection(8)});
  EVT_MENU( $frame, $CONFIG,   sub{shift->{book}->SetSelection(9)});
  #EVT_MENU( $frame, $DOCUMENT, sub{shift->{book}->SetSelection(10)});
  EVT_MENU( $frame, $DOCUMENT, \&document);
  EVT_MENU( $frame, $BUG,      sub{Wx::LaunchDefaultBrowser(q{http://bruceravel.github.io/demeter/documents/SinglePage/bugs.html})});
  EVT_MENU( $frame, $QUESTION, sub{Wx::LaunchDefaultBrowser(q{http://bruceravel.github.io/demeter/documents/SinglePage/help.html})});
  EVT_MENU( $frame, wxID_ABOUT, \&on_about );
  EVT_MENU( $frame, wxID_EXIT, sub{Demeter->stop_larch_server; shift->Close} );

  EVT_MENU( $frame, $TERM_1,    sub{Demeter->po->terminal_number(1)} );
  EVT_MENU( $frame, $TERM_2,    sub{Demeter->po->terminal_number(2)} );
  EVT_MENU( $frame, $TERM_3,    sub{Demeter->po->terminal_number(3)} );
  EVT_MENU( $frame, $TERM_4,    sub{Demeter->po->terminal_number(4)} );
  #EVT_MENU( $frame, $PLOT_PNG,  sub{$_[0]->image('png')} );
  EVT_MENU( $frame, $PLOT_XKCD,
	    sub{
	      if ($plot->IsChecked($PLOT_XKCD)) {
		Demeter->xkcd(1);
	      } else {
		Demeter->xkcd(0);
	      };
	    });

  EVT_CLOSE( $frame,  \&on_close);

  ## -------- fix up frame contents
#  $frame->{find}->adjust_column_width;
#  $frame->{line}->adjust_column_width;

  $frame -> Show( 1 );
};

sub multiplex {
  print join(" ", @_), $/;
};

sub on_close {
  my ($self) = @_;
  $self->Destroy;
};

sub document {
  my ($self) = @_;
  my @path = ('Demeter', 'share', 'documentation', 'Athena');
  my $url = Demeter->co->default('athena', 'doc_url') . '/hephaestus.html';
  my $fname = File::Spec->catfile(dirname($INC{'Demeter.pm'}), @path, 'hephaestus.html');
  if (-e $fname) {
    $fname  = 'file://'.$fname;
    #print $fname, $/;
    Wx::LaunchDefaultBrowser($fname);
  } else {
    #print $fname, $/;
    Wx::LaunchDefaultBrowser($url);
  };
};


sub on_about {
  my ($self) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Hephaestus' );
  $info->SetVersion( hversion() );
  $info->SetDescription( hdescription() );
  $info->SetCopyright( hcopyright() );
  $info->SetWebSite( 'http://bruceravel.github.io/demeter', 'The Demeter web site' );
  $info->SetDevelopers( ["Bruce Ravel (http://bruceravel.github.io/home)\n",
			 "See the document for literature references\nfor the data resources.\n\n",
			 "Core-hole lifetimes are from Keski-Rahkonen & Krause\nhttps://doi.org/10.1016/S0092-640X(74)80020-3\nand are the same as in Feff\n\n",
			 "Much of the data displayed in the Data\nutility was swiped from Kalzium\n(http://edu.kde.org/kalzium/)\n\n",
			 "Mossbauer data comes from http://mossbauer.org/\n(which does not seem to be about Mossbauer spectroscopy anymore)",
			 "Ionic radii data from Shannon (https://doi.org/10.1107/S0567739476001551)\nand David van Horn (http://v.web.umkc.edu/vanhornj/shannonradii.htm)",
			 "Neutron scattering lengths and cross sections from\nNeutron News, Vol. 3, No. 3, 1992, pp. 29-37 and\nhttps://www.ncnr.nist.gov/resources/n-lengths/list.html"
			] );
  $info->SetLicense( Demeter->slurp(File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base, 'Hephaestus', 'data', "GPL.dem")) );
  my $artwork = <<'EOH'
The logo and main icon is "Vulcan Forging 
Jupiter's Lightning Bolts" by Peter Paul
Rubens, from Wikimedia http://commons.wikimedia.org/

The edge finder and configure icons are from
the Kids icon set for KDE by Everaldo Coelho,
http://www.everaldo.com

The Absorption (gold), Formulas (mortar), Data
(chemical hazard), Document (book) icons taken
from Wikimedia http://commons.wikimedia.org
(search terms)

The F1F2 icon is adapted from an image at Matt's
diffkk homepage http://cars9.uchicago.edu/dafs/diffkk/

The ion chamber icon is taken from the ADC website
http://www.adc9001.com/index.php?src=synchrotron

I don't recall the provenance of the transitions
icon.

The line finder icon is from Fig 2, Ni panel at
http://alpha.asi.ualberta.com/ProjectAreas/XraySpec/xrayproj.htm

The standards icon is a photo of the EXAFS Materials
box of foils swiped from the APS XSD website.
http://www.aps.anl.gov/Xray_Science_Division/Beamline_Technical_Support/Equipment_Pool/Equipment_Information/3d_Metal_Foil_Set/
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
}


# The Ionic Radii icon is cropped from an image at
# from Wikimedia
# https://commons.wikimedia.org/wiki/File:Atomic_%26_ionic_radii.svg


1;

=head1 NAME

Demeter::UI::Hephaestus - A souped-up periodic table for XAS

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  use Demeter::UI::Hephaestus;
  my $window = Demeter::UI::Hephaestus->new;
  $window -> MainLoop;

=head1 DESCRIPTION

Hephaestus is a graphical interface to tables of X-ray absorption
coefficients and elemental data.  The utilities contained in
Hephaestus serve a wide variety of useful functions as you prepare for
and perform an XAS experiment.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Use a StatusBar.

=item *

Add and delete user materials for Formula utility using an ini file.

=item *

Configuration callback currently does nothing with units

=item *

Calculations not sensitive to units settings

=item *

There is a display problem with the pressure slider in the Ion utility

=item *

Consider SRS amplifiers in Ion utility

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
