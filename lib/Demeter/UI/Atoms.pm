package Demeter::UI::AtomsApp;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use File::Spec;

use Wx qw( :everything );
use base 'Wx::Frame';
use Wx::Event qw(EVT_NOTEBOOK_PAGE_CHANGED EVT_NOTEBOOK_PAGE_CHANGING);

my $icon_dimension = 30;

sub new {
  my $ref    = shift;
  my $width  = 100;
  my $self   = $ref->SUPER::new( undef,           # parent window
				 -1,              # ID -1 means any
				 'Atoms',         # title
				 wxDefaultPosition,
				 [580,700],
			       );
  my $nb = Wx::Notebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP );
  $self->{notebook} = $nb;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  my $statusbar = $self->CreateStatusBar;
  $statusbar -> SetStatusText("Welcome to Atoms (" . $Demeter::UI::Atoms::demeter->identify . ")");

  my @utilities = qw(Atoms Feff Paths Console Document Configure);

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', lc($utility).".png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };
  $nb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $nb->GetPageCount;
    my $page = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize);
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $page -> SetSizer($box);

    $self->{$utility}
      = ($utility eq 'Atoms')     ? Demeter::UI::Atoms::Xtal    -> new($page, $self, $statusbar)
      : ($utility eq 'Feff')      ? Demeter::UI::Atoms::Feff    -> new($page, $self, $statusbar)
      : ($utility eq 'Paths')     ? Demeter::UI::Atoms::Paths   -> new($page, $self, $statusbar)
      : ($utility eq 'Console')   ? Demeter::UI::Atoms::Console -> new($page, $self, $statusbar)
      : ($utility eq 'Document')  ? Demeter::UI::Atoms::Doc     -> new($page, $self, $statusbar)
      : ($utility eq 'Configure') ? Demeter::UI::Atoms::Config  -> new($page, $self, $statusbar)
      :                             0;

    my $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
    $hh  -> Add($self->{$utility}, 1, wxEXPAND|wxALL, 0);
    $box -> Add($hh, 1, wxEXPAND|wxALL, 0);


    $nb->AddPage($page, $utility, 0, $count);
  };

  $vbox -> Add($nb, 1, wxEXPAND|wxGROW, 0);
  #EVT_NOTEBOOK_PAGE_CHANGED( $self, $nb, sub{$echoarea->echo(q{})} );

  $self -> SetSizer($vbox);
  $vbox -> Fit($nb);
  $vbox -> SetSizeHints($nb);
  return $self;
};


package Demeter::UI::Atoms;

use Demeter;
use vars qw($demeter);
$demeter = Demeter->new;

use File::Basename;

use Wx qw(wxBITMAP_TYPE_ANY wxID_EXIT wxID_ABOUT);
use Wx::Event qw(EVT_MENU EVT_CLOSE);
use base 'Wx::App';

use Wx::Perl::Carp;
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
#$SIG{__DIE__}  = sub {Wx::Perl::Carp::croak($_[0])};

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($atoms_base $demeter $frame);
$atoms_base = identify_self();

sub OnInit {
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Atoms');
  $demeter -> plot_with($demeter->co->default(qw(feff plotwith)));

  foreach my $m (qw(Xtal Feff Config Paths Doc Console)) {
    next if $INC{"Demeter/UI/Atoms/$m.pm"};
    ##print "Demeter/UI/Atoms/$m.pm\n";
    require "Demeter/UI/Atoms/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frame = Demeter::UI::AtomsApp->new;
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Atoms.pm'}), 'Atoms', 'icons', "atoms.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frame -> SetIcon($icon);

  ## -------- Set up menubar
  my $bar = Wx::MenuBar->new;
  my $file = Wx::Menu->new;
  $file->Append( wxID_EXIT, "E&xit" );

  my $help = Wx::Menu->new;
  $help->Append( wxID_ABOUT, "&About..." );

  $bar->Append( $file, "&File" );
  $bar->Append( $help, "&Help" );
  $frame->SetMenuBar( $bar );
  EVT_MENU( $frame, wxID_ABOUT, \&on_about );
  EVT_MENU( $frame, wxID_EXIT, sub{shift->Close} );
  EVT_CLOSE( $frame,  \&on_close);

  ## -------- final adjustment to frame size
  #my @frameWH = $frame->GetSizeWH;
  #my @barWH = $bar->GetSizeWH;
  #my $framesize = Wx::Size->new($frameWH[0], $frameWH[1]+$barWH[1]);
  #$frame -> SetSize($framesize);
  $frame -> SetMinSize($frame->GetSize);
  $frame -> SetMaxSize($frame->GetSize);

  $frame -> Show( 1 );
}

sub on_close {
  my ($self) = @_;
  $self->Destroy;
};

sub on_about {
  my ($self) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Atoms' );
  #$info->SetVersion( $demeter->version );
  $info->SetDescription( "Crystallography for the X-ray absorption spectroscopist" );
  $info->SetCopyright( $demeter->identify );
  $info->SetWebSite( 'http://cars9.uchicago.edu/iffwiki/Demeter', 'The Demeter web site' );
  $info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n",
			] );
  $info->SetLicense( slurp(File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'data', "GPL.dem")) );
  my $artwork = <<'EOH'
The Atoms logo is a perovskite as rendered by a
ball-and-stick molecule viewer.

The Feff logo is taken from the Feff document wiki.

The template icon on the Feff page is the icon Ubuntu
uses for the game glpuzzle, leter called jigzo
http://www.resorama.com/glpuzzle/

All other icons icons are from the Kids icon set for
KDE by Everaldo Coelho, http://www.everaldo.com
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
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



1;


=head1 NAME

Demeter::UI::Atoms - Crystallography for the X-ray absorption spectroscopist

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

This short program launches the Wx interface to Atoms:

  use Wx;
  use Demeter::UI::Atoms;
  Wx::InitAllImageHandlers();
  my $window = Demeter::UI::Atoms->new;
  $window -> MainLoop;

=head1 DESCRIPTION

Atoms is a graphical interface to crystallography classes and classes
for interacting with Feff, as well as to tables of X-ray absorption
coefficients and elemental data.  The main purpose of Atoms is help
the user generate input data for Feff, run the Feff calculation, and
organize Feff's output for use in a fit to EXAFS data.

For more information see L<Demeter::Atoms>, L<Demeter::Feff>, and
L<Demeter::ScatteringPath>.

=head1 USE

Things to explain:

=over 4

=item *

how to use grid

=item *

statusbar

=item *

why Feff tab is so simple

=item *

how to use ListCtrl on paths tab

=item *

L<Demeter::UI::Wx::Config> for Configuration tab

=back

=head1 CONFIGURATION

Many aspects of Atoms and its UI are configurable using the
Configuration tab in the Wx application.

=head1 DEPENDENCIES

This is a Wx application.  Demeter's dependencies are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Config parameter for turning OK/Cancel dialogs off

=item *

cif

=item *

Croak when feff executable doesn't exist & when sanity checks fail in
read_inp

=item *

Correctly clean up Path gatherer in Mode object after a plot

=item *

How is plotting going to work when this is bolted onto Artemis?

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
