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

use Carp;
use File::Spec;

use Demeter;
use Demeter::UI::Wx::EchoArea;

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
				 [550,700],
			       );
  my $nb = Wx::Notebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP );
  #my $echoarea = Demeter::UI::Wx::EchoArea->new($self);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  my $statusbar = $self->CreateStatusBar;
  my $demeter = Demeter->new;
  $statusbar -> SetStatusText("Welcome to Atoms (" . $demeter->identify . ")");

  my @utilities = qw(Atoms Feff Paths Console Configure);

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', lc($utility).".png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };
  $nb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $nb->GetPageCount;
    #my $select = ($count) ? 0 : 1;
    my $page = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize);
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $page -> SetSizer($box);

    $self->{$utility}
      = ($utility eq 'Atoms')  ? Demeter::UI::Atoms::Xtal  -> new($page, $statusbar)
      :                          0;

    my $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
    $hh  -> Add($self->{$utility}, 1, wxSHAPED|wxALL, 0);
    $box -> Add($hh, 1, wxSHAPED|wxALL, 0);


    $nb->AddPage($page, $utility, 0, $count);
  };

  $vbox -> Add($nb, 1, wxEXPAND|wxGROW, 0);
  #$vbox -> Add($echoarea, 0, wxEXPAND|wxALL, 3);
  #EVT_NOTEBOOK_PAGE_CHANGED( $self, $nb, sub{$echoarea->echo(q{})} );

  #$echoarea -> echo(q{});
  $self -> SetSizer($vbox);
  $vbox -> Fit($nb);
  $vbox -> SetSizeHints($nb);
  return $self;
};


package Demeter::UI::Atoms;

use File::Basename;

use Wx qw(wxBITMAP_TYPE_XPM wxID_EXIT wxID_ABOUT);
use Wx::Event qw(EVT_MENU EVT_CLOSE);
use base 'Wx::App';

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($atoms_base $demeter $frame);
$atoms_base = identify_self();

sub OnInit {
#   $demeter = Demeter->new;
#   $demeter -> mo -> ui('Wx');
#   $demeter -> mo -> identity('Atoms');
#   ## read atoms' demeter_conf file
#   my $conffile = File::Spec->catfile(dirname($INC{'Demeter/UI/Atoms.pm'}), 'Atoms', 'data', "atoms.demeter_conf");
#   $demeter -> co -> read_config($conffile);
#   ## read ini file...
#   $demeter -> co -> read_ini('atoms');
#   $demeter -> plot_with($demeter->co->default(qw(atoms plotwith)));

  foreach my $m (qw(Xtal)) {
    next if $INC{"Demeter/UI/Atoms/$m.pm"};
    ##print "Demeter/UI/Atoms/$m.pm\n";
    require "Demeter/UI/Atoms/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frame = Demeter::UI::AtomsApp->new;
  #my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Atoms.pm'}), 'Atoms', 'icons', "atoms.xpm");
  #my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_XPM );
  #$frame -> SetIcon($icon);

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
  #$frame -> SetMaxSize($frame->GetSize);

  $frame -> Show( 1 );
}

sub on_close {
  my ($self) = @_;
  $self->Destroy;
};
sub on_about {
  my ($self) = @_;
  1;
};


1;
