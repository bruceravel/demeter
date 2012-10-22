package Demeter::UI::AtomsApp;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_NOTEBOOK_PAGE_CHANGED EVT_NOTEBOOK_PAGE_CHANGING EVT_MENU EVT_LEFT_DOWN);

use Demeter::UI::Artemis::Close qw(on_close);

my $icon_dimension = 30;

foreach my $m (qw(Xtal Feff Config Paths Doc Console SS)) {
  next if $INC{"Demeter/UI/Atoms/$m.pm"};
  #print "Demeter/UI/Atoms/$m.pm\n";
  require "Demeter/UI/Atoms/$m.pm";
};

use vars qw(@utilities);
@utilities = ();

sub new {
  my ($ref, $base, $feffobject, $component) = @_;
  my $width  = 100;
  my $self   = $ref->SUPER::new( undef,           # parent window
				 -1,              # ID -1 means any
				 ($component) ? 'Atoms' : 'Stand-alone Atoms',         # title
				 wxDefaultPosition,
				 [560,650],
			       );
  $self -> SetBackgroundColour( wxNullColour );

  my $nb = Wx::Notebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP );
  $nb -> SetBackgroundColour( wxNullColour );
  $self->{base} = $base;
  $self->{notebook} = $nb;
  $self->{feffobject} = $feffobject;
  $self->{component}  = $component;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);

  my $statusbar = $self->CreateStatusBar;
  $statusbar -> SetStatusText("Welcome to Atoms (" . $Demeter::UI::Atoms::demeter->identify . ")");
  $self->{statusbar} = $statusbar;

  if ($component) {
    $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT|wxTB_HORZ_LAYOUT);
    EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
    $self->{toolbar} -> AddTool(-1, " Rename this Feff calculation",     $self->icon("reset"),   wxNullBitmap, wxITEM_NORMAL, q{}, "Rename this Feff calculation" );
    $self->{toolbar} -> AddTool(-1, "Discard this Feff calculation",    $self->icon("discard"), wxNullBitmap, wxITEM_NORMAL, q{}, "Discard this Feff calculation" );
    $self->{toolbar} -> AddSeparator;
    $self->{toolbar} -> AddTool(-1, "About Feff", $self->icon("info"),    wxNullBitmap, wxITEM_NORMAL, q{}, "Show information about Feff's configuration in Artemis" );
    $self->{toolbar} -> Realize;
    $vbox -> Add($self->{toolbar}, 0, wxGROW|wxALL, 0);
    #$vbox -> Add(Wx::StaticLine->new($self, -1, wxDefaultPosition, [-1, 3], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);
  };


  eval "use Demeter::UI::Atoms::Status" if not $component;


  @utilities = ($component) ? qw(Atoms Feff Paths SS Console) : qw(Atoms Feff Paths Console Document Configure);

  my $imagelist = Wx::ImageList->new( $icon_dimension, $icon_dimension );
  foreach my $utility (@utilities) {
    my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', lc($utility).".png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };
  if ($component) {		# B&W ball-n-stick image for "disabling" the Atoms page
    my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "atoms_disabled.png");
    $imagelist->Add(  Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG));
  };
  $nb->AssignImageList( $imagelist );
  foreach my $utility (@utilities) {
    my $count = $nb->GetPageCount;
    my $page = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize);
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $self->{$utility."_page"} = $page;
    $self->{$utility."_sizer"} = $box;

    if (($utility eq 'Atoms') or ($utility eq 'SS')) {
      my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
      my $header = Wx::StaticText->new( $page, -1, q{}, wxDefaultPosition, wxDefaultSize );
      $hh -> Add($header, 1, wxGROW|wxLEFT, 5);
      $box -> Add($hh, 0);
      $page->Fit;

      $self->{$utility} = Demeter::UI::Atoms::Xtal -> new($page,$self) if ($utility eq 'Atoms');
      $self->{$utility} = Demeter::UI::Atoms::SS   -> new($page,$self) if ($utility eq 'SS');
    # $self->{$utility}
    #   = ($utility eq 'Atoms')     ? Demeter::UI::Atoms::Xtal    -> new($page, $self)
    #   : ($utility eq 'Feff')      ? Demeter::UI::Atoms::Feff    -> new($page, $self)
    #   : ($utility eq 'Paths')     ? Demeter::UI::Atoms::Paths   -> new($page, $self)
    #   : ($utility eq 'Console')   ? Demeter::UI::Atoms::Console -> new($page, $self)
    #   : ($utility eq 'Document')  ? Demeter::UI::Atoms::Doc     -> new($page, $self)
    #   : ($utility eq 'Configure') ? Demeter::UI::Atoms::Config  -> new($page, $self)
    #   : ($utility eq 'SS')        ? Demeter::UI::Atoms::SS      -> new($page, $self)
    #   :                             0;

      my $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
      $hh  -> Add($self->{$utility}, 1, wxGROW|wxEXPAND|wxALL, 0);
      $box -> Add($hh, 1, wxEXPAND|wxALL, 0);

      $page -> SetSizer($box);
    };

    my $label = ($utility eq 'SS') ? 'Path-like' : $utility;
    $nb  -> AddPage($page, $label, 0, $count);
  };

  $vbox -> Add($nb, 1, wxEXPAND|wxGROW, 0);
  #EVT_NOTEBOOK_PAGE_CHANGED( $self, $nb, sub{$echoarea->echo(q{})} );
  EVT_LEFT_DOWN($nb, sub { $_[0]->{last_pos} = $_[1]->GetPosition();
			   $_[1]->Skip(1);
			 });
  EVT_NOTEBOOK_PAGE_CHANGING( $self, $nb,
			      sub{ my($self, $event) = @_;
				   my $notebook = $event->GetEventObject;
				   my ($nbtab, $flags ) = $notebook->HitTest($notebook->{last_pos});
				   my $which = $utilities[$nbtab];
				   $self->make_page($which);
				   return;
				 }
			    );

#sub{make_page(@_)}); # postpone setting up pages until they are selected

  $self -> SetSizerAndFit($vbox);
  return $self;
};

sub make_page {
  my ($self, $which) = @_;
  return if exists $self->{$which};
#  print join("|", $which, caller), $/;
  my $busy = Wx::BusyCursor->new;
  my $pm = ($which eq 'Document')  ? 'Demeter::UI::Atoms::Doc'
         : ($which eq 'Configure') ? 'Demeter::UI::Atoms::Config'
         : ($which eq 'Atoms')     ? 'Demeter::UI::Atoms::Xtal'
	 :                           "Demeter::UI::Atoms::$which";
  $self->{$which} = $pm -> new($self->{$which."_page"},$self);
  $self->{$which}->SetSize($self->{"Atoms"}->GetSize);
#  print join("|", $which, caller, $self->{"Atoms_page"}->GetSizeWH), $/;
#  $self->{$which."_page"}->SetSize($self->{"Atoms_page"}->GetSize);

  my $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
  $hh  -> Add($self->{$which}, 1, wxGROW|wxALL, 0);
  $self->{$which."_sizer"} -> Add($hh, 1, wxGROW|wxALL, 0);
  $self->{$which."_page"} -> SetSizer(self->{$which."_sizer"});
  $self->Update;
  undef $busy;
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  my $position = $toolbar->GetToolPos($event->GetId);
  my @callbacks = qw(on_rename on_discard noop on_about);
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub on_rename {
  my ($self) = @_;
  my $ted = Wx::TextEntryDialog->new( $self, "Enter a name for this Feff calculation", "Enter a new name", q{},
				      wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    my $this = (exists $self->{Atoms}->{atomsobject}) ? $self->{Atoms}->{atomsobject}->name : $self->{Feff}->{feffobject}->name;
    $self->status("Renaming Feff calculation \"$this\" canceled.");
    return;
  };
  my $name = $ted->GetValue;
  if (exists $self->{Atoms}->{atomsobject}) {
    $self->{Atoms}->{atomsobject}->name($name);
  };
  if ((exists $self->{feffobject}) and (ref($self->{feffobject}) =~ m{Feff})) {
    $self->{feffobject}->name($name);
  };
  $self->make_page('Feff')  if not $self->{Feff};
  $self->make_page('Paths') if not $self->{Paths};
  if ((exists $self->{Feff}->{feffobject}) and (ref($self->{Feff}->{feffobject}) =~ m{Feff})) {
    $self->{Feff}->{feffobject}->name($name);
  };
  $self->{Atoms}->{name}->SetValue($name);
  $self->{Feff}->{name}->SetValue($name);
  $self->{Paths}->{name}->SetValue($name);
  my $fnum = $self->{fnum};
  $Demeter::UI::Artemis::frames{main}->{$fnum}->SetLabel("Hide $name");
};

sub on_discard {
  my ($self, $force) = @_;
  my ($self, $force) = @_;
  my $atomsobject = $self->{Atoms}->{atomsobject};
  my $feffobject  = $self->{Feff}->{feffobject};

  if (not $force) {
    my $yesno = Wx::MessageDialog->new($self, "Do you really wish to discard this Feff calculation?",
				       "Discard?", wxYES_NO);
    $self->status("Not discarding Feff calculation \"$this\".");
    return if ($yesno->ShowModal == wxID_NO);
  };

  ## remove paths & VPaths from the plot list


  ## discard all paths which come from this Feff calculation
  if ($feffobject) {
    foreach my $fr (keys %Demeter::UI::Artemis::frames) {
      next if ($fr !~ m{data});
      my $datapage = $Demeter::UI::Artemis::frames{$fr};
      $datapage->discard($feffobject);
    };
  };

  my $fnum = $self->{fnum};

  ## destroy Atoms and Feff objects
  $atomsobject->DEMOLISH if (ref($atomsobject) =~ m{Atoms});
  $feffobject->DEMOLISH  if (ref($feffobject)  =~ m{Feff});

  ## remove the frame with the datapage
  $Demeter::UI::Artemis::frames{$fnum}->Hide;
  $Demeter::UI::Artemis::frames{$fnum}->Destroy;
  delete $Demeter::UI::Artemis::frames{$fnum};

  ## remove the button from the feff tool bar
  $Demeter::UI::Artemis::frames{main}->{feffbox}->Hide($Demeter::UI::Artemis::frames{main}->{$fnum});
  $Demeter::UI::Artemis::frames{main}->{feffbox}->Detach($Demeter::UI::Artemis::frames{main}->{$fnum});
  $Demeter::UI::Artemis::frames{main}->{feffbox}->Layout;
  #$Demeter::UI::Artemis::frames{main}->{$fnum}->Destroy; ## this causes a segfaul .. why?

  $Demeter::UI::Artemis::frames{main}->status("Discarded Feff calculation.  Note that unused GDS parameters may remain.");
};

sub on_about {
  my ($self) = @_;
  my $text = sprintf("Feff executable: %s\n\n", Demeter->co->default(qw(feff executable)));
  $text   .= sprintf("Default feff.inp style: %s\n", Demeter->co->default(qw(atoms feff_version)));
  $text   .= sprintf("Default ipot style: %s\n", Demeter->co->default(qw(atoms ipot_style)));
  Demeter::UI::Artemis::ShowText->new($frames{main}, $text, 'Overview of Feff configuration') -> Show
};

sub noop {
  return 1;
};



package Demeter::UI::Atoms;

use Demeter qw(:atoms);
use vars qw($demeter);
$demeter = Demeter->new;

use File::Basename;

use Wx qw(wxACCEL_CTRL wxBITMAP_TYPE_ANY wxID_EXIT wxID_ABOUT);
use Wx::Event qw(EVT_MENU EVT_CLOSE);
use base 'Wx::App';

use Wx::Perl::Carp;
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
$SIG{__DIE__}  = sub {Wx::Perl::Carp::warn($_[0])};

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($atoms_base $demeter $frame);
$atoms_base = identify_self();

use Const::Fast;
const my $ATOMS   => Wx::NewId();
const my $FEFF    => Wx::NewId();
const my $PATHS   => Wx::NewId();
const my $CONSOLE => Wx::NewId();
const my $DOC     => Wx::NewId();
const my $CONFIG  => Wx::NewId();

sub OnInit {
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Atoms');
  $demeter -> plot_with($demeter->co->default(qw(plot plotwith)));

  ## -------- create a new frame and set icon
  $frame = Demeter::UI::AtomsApp->new;
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Atoms.pm'}), 'Atoms', 'icons', "atoms_nottransparent.png");
  my $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frame -> SetIcon($icon);


  ## -------- Set up menubar
  my $bar = Wx::MenuBar->new;
  my $file = Wx::Menu->new;
  $file->Append( $ATOMS,   "Atoms\tCtrl+1"     );
  $file->Append( $FEFF,    "Feff\tCtrl+2"      );
  $file->Append( $PATHS,   "Paths\tCtrl+3"     );
  $file->Append( $CONSOLE, "Console\tCtrl+4"   );
  $file->Append( $DOC,     "Document\tCtrl+5"  );
  $file->Append( $CONFIG,  "Configure\tCtrl+6" );
  $file->AppendSeparator;
  $file->Append( wxID_EXIT, "E&xit\tCtrl+q"    );

  my $help = Wx::Menu->new;
  $help->Append( wxID_ABOUT, "&About Atoms"    );

  $bar->Append( $file, "&File" );
  $bar->Append( $help, "&Help" );
  $frame->SetMenuBar( $bar );
  EVT_MENU( $frame, $ATOMS,   sub{ $frame->make_page('Atoms');     $frame->{notebook}->ChangeSelection(0); });
  EVT_MENU( $frame, $FEFF,    sub{ $frame->make_page('Feff');      $frame->{notebook}->ChangeSelection(1); });
  EVT_MENU( $frame, $PATHS,   sub{ $frame->make_page('Paths');     $frame->{notebook}->ChangeSelection(2); });
  EVT_MENU( $frame, $CONSOLE, sub{ $frame->make_page('Console');   $frame->{notebook}->ChangeSelection(3); });
  EVT_MENU( $frame, $DOC,     sub{ $frame->make_page('Document');  $frame->{notebook}->ChangeSelection(4); });
  EVT_MENU( $frame, $CONFIG,  sub{ $frame->make_page('Configure'); $frame->{notebook}->ChangeSelection(5); });
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
  $info->SetLicense( $demeter->slurp(File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'data', "GPL.dem")) );
  my $artwork = <<'EOH'
The Atoms logo is a perovskite as rendered by a
ball-and-stick molecule viewer.

The Feff logo is taken from the Feff document wiki.

The template icon on the Feff page is the icon Ubuntu
uses for the game glpuzzle, later called jigzo
http://www.resorama.com/glpuzzle/

All other icons icons are from the Kids icon set for
KDE by Everaldo Coelho, http://www.everaldo.com
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
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

This documentation refers to Demeter version 0.9.13.

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

=head2 Atoms tab

This section of this document explains a biut about the mechanics of
using the wx Atoms client.  This is not an explanation of the
algorithms used to convert crystal data to Feff input structures, nor
is this an explanation of crystallography in general.

Most of the Atoms tab is pretty straight forward.  Numbers should be
entered in the text controls for lattice constants, radial distances,
and the shift vector.  The shift vector coordinates can be written as
simple fractions -- things like C<1/2> or C<2/3>.  If any of these
cannot be interpreted as a number, a warning will be flagged and the
calculation will not proceed.

The space group symbol can be a Hermann-Maguin or Schoenflies symbol,
a number between 1 and 230 corresponding to the order of space groups
listed in the International Tables, or a common name like C<fcc> or
C<bcc>.  Atoms tries really hard to interpret what you write.  For
instance, white space is ignored and the super- and subscripts of a
Schoenflies symbol can come in either order.

The grid of unique sites should be fairly straightforward to use.
Simply enter a two letter element symbol in the second column, numbers
in the next three columns, and a string up to 10 characters long in
the last column.

The numbers for the site coordinates can be expressed as simple
fractions, such as C<1/2> or C<2/3>.  In fact, using fractions is
highly recommended as it obviates issues of precision for numbers like
1/3 and 2/3.

If an element symbol cannot be intepreted as such or a site
coordinate cannot be interpreted as a number, a warning will be
flagged and the calculation will be stopped.

To choose a site as the central atom, click on its check button.

You can copy, cut, and paste a site by right clicking anywhere on the
row containing that site and choosing from the popup menu.  When you
paste a site, it will be inserted into the grid above the site you
clicked on.

Empty rows will be ignored, as will rows with an empty string as the
atom symbol.

If you need more space, click on the "Add site" button just above the
grid.

=head2 Feff tab

This tab is quite simple.  The F<feff.inp> file is displayed in the
big text area.  In principle, the data that goes into the F<feff.inp>
file could be stuffed into various widgets, but that seems more
complicated than necessary to me.  If the user needs to modify the
F<feff.inp> file, it seems easiest to do so using a text editor rather
than having to click thorugh a buncg of controls.

=head2 Paths tab

The path list displays a summary of Feff calculation.  You can select
paths by left-clicking.  Holding the control key while left-clicking
adds to the selection, while holding the shift key while left-clicking
selects all paths between the current and previous selections.

Once paths are selected, they can be plotted as the magnitude of R
using k-weight of 2 and a reasonable set of Fourier transform
parameters.  Click the plot button in the tool bar to do so.

The save file for these data is Demeter's Feff serialization file.
See L<Demeter::Feff>.

=head2 Console tab

This tab displays the screen output of every Feff calculation as well
as some other information.

=head2 Configure tab

You can customize the behavior of many parts of Atoms, Feff, or the
path finder using this tab.

See L<Demeter::UI::Wx::Config> for instructions on using Demeter's
graphical configuration tool.

=head2 Tool bars

Much ofthe functionality of the various tabs is found on the tool
bars, which are the lines of colorful buttons at the top of some
tabs. Data appropriate to the tabs can be imported or saved using
these buttons and the major task of each tab (i.e. running Atoms,
running Feff, or plotting paths) is accomplished via the tool bars.

=head2 Status bar

The status bar is the narrow strip at the bottom of the screen which
is used to convey information to the user.  When the mouse passes over
many of the controls in the program, a short hint is displayed in the
status bar.  The status bar is also used to display messages at the
end of certain chores performed by the program.

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

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
