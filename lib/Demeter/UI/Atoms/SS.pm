package Demeter::UI::Atoms::SS;

use Wx qw( :everything );
use Wx::DND;
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_RADIOBOX
		 EVT_LEFT_DOWN EVT_LIST_BEGIN_DRAG);

use List::MoreUtils qw(uniq);

sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $title = Wx::StaticText->new($self, -1, "Make a Single Scattering path of arbitrary length");
  $vbox  -> Add( $title, 0, wxALL, 10);
  $title -> SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($self, -1, "Name: "), 0, wxALL, 7);
  $self->{name} = Wx::TextCtrl->new($self, -1, q{});
  $hbox -> Add( $self->{name}, 1, wxGROW|wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($self, -1, "Distance: "), 0, wxALL, 7);
  $self->{reff} = Wx::TextCtrl->new($self, -1, q{3.0});
  $hbox -> Add( $self->{reff}, 0, wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $self->{ipot} = Wx::RadioBox->new($self, -1, ' Using ipot ', wxDefaultPosition, wxDefaultSize,
				    [q{},q{},q{},q{},q{},q{},q{}], 7, wxRA_SPECIFY_ROWS);
  $self->{ipot}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{ipot}, \&set_name);

  $vbox -> Add( $self->{ipot}, 0, wxLEFT|wxRIGHT, 25 );


  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(2, "Plot SS path",  $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $Demeter::UI::Atoms::Paths::hints{plot});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddRadioTool(4, 'chi(k)',     $self->icon("chik"),    wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chik});
  $self->{toolbar} -> AddRadioTool(5, '|chi(R)|',   $self->icon("chirmag"), wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_mag});
  $self->{toolbar} -> AddRadioTool(6, 'Re[chi(R)]', $self->icon("chirre"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_re});
  $self->{toolbar} -> AddRadioTool(7, 'Im[chi(R)]', $self->icon("chirim"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_im});
  $self->{toolbar} -> ToggleTool(5, 1);

  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxALL, 20);

  $self->{drag} = Demeter::UI::Atoms::SS::DragSource->new($self, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $vbox  -> Add( $self->{drag}, 0, wxALL, 20);
  $self->{drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{drag}->Enable(0);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub set_name {
  my ($self, $event) = @_;

  ## need to make a regular expression out of all elements in the potentials list ...
  my @pots = @{ $self->{parent}->{Feff}->{feffobject}->potentials };
  shift @pots;
  my @all_elems = uniq( map { $_ -> [2] } @pots );
  my $re = join("|", @all_elems);

  ## ... so I can reset the name if it has been left to its default.
  if ($self->{name}->GetValue =~ m{\A\s*$re\s+SS\z}) {
    my $label = $self->{ipot}->GetStringSelection;
    my $elem  = (split(/: /, $label))[1];
    $self->{name}->SetValue($elem.' SS');
  };
};

sub OnToolEnter {
  my ($self, $event, $which) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->SetStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->SetStatusText(q{});
  };
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv------order of toolbar on the screen-----vV
  my @callbacks = qw(plot noop set_plot set_plot set_plot set_plot);
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure($event->GetId);
};

sub noop {
  return 1;
};

sub set_plot {
  my ($self, $id) = @_;
  ## set plotting space
  my $space = ($id == 5) ? 'k' : 'r';
  $self->{parent}->{Feff}->{feffobject}->po->space($space);
  # set part of R space plot
  my %pl = (5 => q{}, 6 => 'm', 7 => 'r', 8 => 'i');
  $self->{parent}->{Feff}->{feffobject}->po->r_pl($pl{$id}) if $pl{$id};
  # sensible status bar message
  my %as = (5 => 'chi(k)', 6 => 'the magnitude of chi(R)', 7 => 'the real part of chi(R)', 8 => 'the imaginary part of chi(R)');
  $self->{statusbar}->SetStatusText("Plotting as $as{$id}");
  return $self;
};

sub plot {
  my ($self) = @_;
  my $save = $Demeter::UI::Atoms::demeter->po->title;

  ## make SSPath

  ## make plot

  ## destroy SSPath (since it will be created when dnd-ed

  $Demeter::UI::Atoms::demeter->po->title($save);
  undef $busy;
};



package Demeter::UI::Atoms::SS::DragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag single scattering path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $dragdata = ['SSPath',  	                                   # id
		  $parent->{Feff}->{feffobject}->group,  # feff object group
		  $parent->{SS}->{name}->GetValue,       # name
		  $parent->{SS}->{reff}->GetValue,       # reff
		  $parent->{SS}->{ipot}->GetSelection+1, # ipot
		 ];
  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};



1;

=head1 NAME

Demeter::UI::Atoms::SS - Create SSPath objects in Atoms

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 DESCRIPTION

This class is used to populate the SS tab in the Wx version of Atoms
as a component of Artemis.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
