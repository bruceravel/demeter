package  Demeter::UI::Artemis::Plot::VPaths;


=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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
use Wx::Help;
use Wx::Event qw(EVT_BUTTON EVT_RIGHT_DOWN EVT_MENU);

use base qw(Wx::Panel);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $box  = Wx::BoxSizer->new( wxVERTICAL );
  my $label = Wx::StaticText->new($this, -1, 'Virtual Paths');
  $label -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ));
  $box -> Add($label, 0, wxALIGN_CENTER_HORIZONTAL);
  $this->{vpathlist} = Wx::ListBox->new($this, -1, wxDefaultPosition, [-1,200], [ ], wxLB_SINGLE);
  $box -> Add($this->{vpathlist}, 1, wxGROW|wxALL, 5);
  EVT_RIGHT_DOWN($this->{vpathlist}, sub{OnRightDown(@_)});
  EVT_MENU($this->{vpathlist}, -1, sub{ $this->OnMenu(@_)    });

  $this->{transferall} = Wx::Button->new($this, -1, 'Transfer all');
  $box -> Add($this->{transferall}, 0, wxGROW|wxBOTTOM|wxLEFT|wxRIGHT, 5);
  EVT_BUTTON($this, $this->{transferall}, sub{TransferAll(@_)});

  $this -> SetSizer($box);
  return $this;
};

sub add_vpath {
  my ($self, @list) = @_;

  my $ted = Wx::TextEntryDialog->new( $self, "Enter a name for this virtual path", "Enter a VPath name", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    $Demeter::UI::Artemis::frames{main}->status("VPath creation canceled.");
    return;
  };
  my $name = $ted->GetValue;
  $self->add_named_vpath($name, @list);
};

sub add_named_vpath {
  my ($self, $name, @list) = @_;

  my $vpath = Demeter::VPath->new(name => $name);
  $vpath -> include(@list);
  my $help = join(", ", map { $_->label } @list);

  $self->{vpathlist}->Append($name, $vpath);
  my $this = $self->{vpathlist}->GetCount-1;
  ##$self->{vpathlist}->SetClientData($this, $vpath);
  $self->{vpathlist}->Select($this);
  $self->transfer($this);

  $Demeter::UI::Artemis::frames{Plot}->{notebook}->SetSelection(3);
  return $vpath;
};

use Const::Fast;
const my $VPATH_TRANSFER => Wx::NewId();
const my $VPATH_DESCRIBE => Wx::NewId();
const my $VPATH_RENAME   => Wx::NewId();
const my $VPATH_YAML     => Wx::NewId();
const my $VPATH_DISCARD  => Wx::NewId();

sub OnRightDown {
  my ($self, $event) = @_;
  my $sel  = $self->GetSelection;
  return if ($sel == wxNOT_FOUND);
  my $name = sprintf("\"%s\"", $self->GetString($sel));
  my $menu = Wx::Menu->new(q{});
  $menu->Append($VPATH_TRANSFER, "Transfer $name to plotting list");
  $menu->Append($VPATH_DESCRIBE, "Show contents of $name");
  $menu->Append($VPATH_RENAME,   "Rename $name");
  $menu->Append($VPATH_YAML,     "Show yaml for VPath $name") if (Demeter->co->default("artemis", "debug_menus"));
  $menu->AppendSeparator;
  $menu->Append($VPATH_DISCARD,  "Discard $name");
  $self->PopupMenu($menu, $event->GetPosition);
  $event->Skip;
};

sub OnMenu {
  my ($self, $listbox, $event) = @_;
  my $id  = $event->GetId;
  my $sel = $self->{vpathlist}->GetSelection;
 SWITCH: {

    ($id == $VPATH_TRANSFER) and do {
      $self->transfer($sel);
      last SWITCH;
    };

    ($id == $VPATH_DESCRIBE) and do {
      my $vpath = $listbox->GetClientData($sel);
      my $text = "\"" . $vpath->name . "\" contains: " . join(", ", map {$_->label} @{$vpath->paths});
      $Demeter::UI::Artemis::frames{main}->status($text);
      last SWITCH;
    };

    ($id == $VPATH_RENAME) and do {
      my $vp = $listbox->GetClientData($sel);
      my $name = $vp->name;
      my $ted = Wx::TextEntryDialog->new($self, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->status("VPath renaming canceled.");
	return;
      };
      my $newname = $ted->GetValue;
      if ($name eq $newname) {
	$self->status("VPath renaming canceled.");
	return;
      };
      $vp->name($newname);
      $listbox->SetString($sel, $newname);

      my $thisgroup = $vp->group;
      my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
      foreach my $i (0 .. $plotlist->GetCount - 1) {
	if ($thisgroup eq $plotlist->GetIndexedData($i)->group) {
	  $plotlist->SetString($i, "VPath: $newname");
	  $plotlist->Check($i,1);
	};
      };

      last SWITCH;
    };

    ($id == $VPATH_YAML) and do {
      my $vp = $listbox->GetClientData($sel);
      my $yaml = $vp->serialization;
      my $dialog = Demeter::UI::Artemis::ShowText->new($self, $yaml, 'YAML of ' . $vp->name)
	-> Show;
      last SWITCH;
    };

    ($id == $VPATH_DISCARD) and do {
      my $vpath = $listbox->GetClientData($sel);
      foreach my $i (0 .. $Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetCount-1) {
	if ($Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetIndexedData($i)->group eq $vpath->group) {
	  my $obj = $Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetIndexedData($i);
	  $Demeter::UI::Artemis::frames{Plot}->{plotlist}->DeleteData($i);
	  $obj -> DESTROY;
	  last;
	};
      };
      $listbox->Delete($sel);
      my $text = "Discarded \"" . $vpath->name . "\".";
      $Demeter::UI::Artemis::frames{main}->status($text);
      last SWITCH;
    };
  };
};

sub transfer {
  my ($self, $selection) = @_;
  my $vpath     = $self->{vpathlist}->GetClientData($selection);
  my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  my $name      = $vpath->name;
  my $found     = 0;
  my $thisgroup = $vpath->group;
  foreach my $i (0 .. $plotlist->GetCount - 1) {
    if ($thisgroup eq $plotlist->GetIndexedData($i)->group) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $Demeter::UI::Artemis::frames{main}->status("\"$name\" is already in the plotting list.");
    return;
  };
  $plotlist->AddData("VPath: $name", $vpath);
  my $i = $plotlist->GetCount - 1;
  #$plotlist->SetClientData($i, $vpath);
  $plotlist->Check($i,1);
  $Demeter::UI::Artemis::frames{main}->status("Transfered VPath \"$name\" to the plotting list.");
};

sub fetch_vpaths {
  my ($self) = @_;
  my @list = ();
  foreach my $i (0 .. $self->{vpathlist}->GetCount - 1) {
     push @list, $self->{vpathlist}->GetClientData($i);
  };
  return @list;
};

sub TransferAll {
  my ($self) = @_;
  my @list = ();
  foreach my $i (0 .. $self->{vpathlist}->GetCount - 1) {
     $self->transfer($i);
  };
  return @list;
};


1;

=head1 NAME

Demeter::UI::Artemis::Plot::VPaths - controls for managing VPaths

=head1 VERSION

This documentation refers to Demeter version 0.9.23.

=head1 SYNOPSIS

This module provides controls for managing VPaths in Artemis

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

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
