package  Demeter::UI::Atoms::Paths;

use Demeter;
use Demeter::StrTypes qw( Element );

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

my %hints = (
	     save     => "Save this Feff calculation to a Demeter save file",
	     plot     => "Plot selected paths",
	     chik     => "Plot paths in k space",
	     chir_mag => "Plot paths as the magnitude of chi(R)",
	     chir_re  => "Plot paths as the real part of chi(R)",
	     chir_im  => "Plot paths as the imaginary part of chi(R)",
	    );

sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(1, "Save calc.",      $self->icon("save"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(3, "Plot selection",  $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{plot});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddRadioTool(5, 'chi(k)',     $self->icon("chik"),    wxNullBitmap, q{}, $hints{chik});
  $self->{toolbar} -> AddRadioTool(6, '|chi(R)|',   $self->icon("chirmag"), wxNullBitmap, q{}, $hints{chir_mag});
  $self->{toolbar} -> AddRadioTool(7, 'Re[chi(R)]', $self->icon("chirre"),  wxNullBitmap, q{}, $hints{chir_re});
  $self->{toolbar} -> AddRadioTool(8, 'Im[chi(R)]', $self->icon("chirim"),  wxNullBitmap, q{}, $hints{chir_im});
  $self->{toolbar} -> ToggleTool(6, 1);

  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxALL, 5);

  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hh, 0, wxEXPAND|wxALL, 0);
  my $label      = Wx::StaticText->new($self, -1, 'Name of this Feff calculation: ', wxDefaultPosition, [-1,-1]);
  $self->{name}  = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [70,-1], wxTE_READONLY);
  $hh->Add($label,        0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{name}, 1, wxEXPAND|wxALL, 5);


  $self->{headerbox}       = Wx::StaticBox->new($self, -1, 'Description', wxDefaultPosition, wxDefaultSize);
  $self->{headerboxsizer}  = Wx::StaticBoxSizer->new( $self->{headerbox}, wxVERTICAL );
  $self->{header}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
					       wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB|wxTE_READONLY);
  $self->{header}         -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{headerboxsizer} -> Add($self->{header}, 0, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{headerboxsizer}, 0, wxEXPAND|wxALL, 5);

  $self->{pathsbox}       = Wx::StaticBox->new($self, -1, 'Scattering Paths', wxDefaultPosition, wxDefaultSize);
  $self->{pathsboxsizer}  = Wx::StaticBoxSizer->new( $self->{pathsbox}, wxVERTICAL );
  $self->{paths} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES);
  $self->{paths}->InsertColumn( 0,  q{}		     );
  $self->{paths}->InsertColumn( 1, "Degen"	     );
  $self->{paths}->InsertColumn( 2, "Reff"	     );
  $self->{paths}->InsertColumn( 3, "Scattering path" );
  $self->{paths}->InsertColumn( 4, "Imp."	     );
  $self->{paths}->InsertColumn( 5, "Legs"	     );
  $self->{paths}->InsertColumn( 6, "Type"	     );

  $self->{paths}->SetColumnWidth( 0,  50 );
  $self->{paths}->SetColumnWidth( 1,  50 );
  $self->{paths}->SetColumnWidth( 2,  55 );
  $self->{paths}->SetColumnWidth( 3, 190 );
  $self->{paths}->SetColumnWidth( 4,  35 );
  $self->{paths}->SetColumnWidth( 5,  40 );
  $self->{paths}->SetColumnWidth( 6, 180 );

  $self->{pathsboxsizer} -> Add($self->{paths}, 1, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{pathsboxsizer}, 1, wxEXPAND|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
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
  ##                 Vv---------order of toolbar on the screen------------vV
  my @callbacks = qw(save noop plot noop set_plot set_plot set_plot set_plot);
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

#sub clear_all {
#  my ($self) = #
#
#};

sub save {
  my ($self) = @_;
  return if not $self->{paths}->GetItemCount;
  my $fd = Wx::FileDialog->new( $self, "Save Feff calculation", cwd, q{feff.yaml},
				"Feff calculations (*.yaml)|*.yaml|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $self->{statusbar}->SetStatusText("Saving Feff calculation aborted.")
  } else {
    my $yaml = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
    $self->{parent}->{Feff}->{feffobject}->freeze($yaml);
    #$self->{parent}->{Feff}->{feffobject}->push_mru("feffcalc", $yaml);
    $self->{statusbar}->SetStatusText("Saved Feff calculation to $yaml.")
  };
};

sub plot {
  my ($self) = @_;
  return if not $self->{paths}->GetItemCount;
  my $this = $self->{paths}->GetFirstSelected;
  $self->{statusbar}->SetStatusText("No paths are selected!") if ($this == -1);
  my $busy   = Wx::BusyCursor->new();
  $Demeter::UI::Atoms::demeter->po->start_plot;
  $Demeter::UI::Atoms::demeter->reset_path_indeces;
  my $save = $Demeter::UI::Atoms::demeter->po->title;
  $Demeter::UI::Atoms::demeter->po->title("Feff calculation");
  while ($this != -1) {
    my $i    = $self->{paths}->GetItemData($this);
    my $feff = $self->{parent}->{Feff}->{feffobject};
    my $sp   = $feff->pathlist->[$i]; # the ScatteringPath associated with this selected item
    my $space = $self->{parent}->{Feff}->{feffobject}->po->space;
    Demeter::Path -> new(parent=>$feff, sp=>$sp, name=>$sp->intrplist) -> plot($space);
    #my $path_object = Demeter::Path -> new(parent=>$feff_object, sp=>$sp);
    #$path_object -> plot("r");
    #undef $path_object;
    $this    = $self->{paths}->GetNextSelected($this);
  };
  $Demeter::UI::Atoms::demeter->po->title($save);
  undef $busy;
};


1;

=head1 NAME

Demeter::UI::Atoms::Paths - Atoms' path organizer utility

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 DESCRIPTION

This class is used to populate the Paths tab in the Wx version of Atoms.

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
