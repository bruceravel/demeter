package Demeter::UI::Athena::XDI;

use strict;
use warnings;
use Const::Fast;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT EVT_TEXT_ENTER EVT_TREE_ITEM_RIGHT_CLICK EVT_MENU);
use Demeter::UI::Athena::XDIAddParameter;
#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "File metadata";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  if (not exists $INC{'Xray/XDI.pm'}) {
    $box->Add(Wx::StaticText->new($this, -1, "File metadata is not enabled on this computer.\nThe most likely reason is that the perl module Xray::XDI is not available."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {

    ## versioning information
    my $versionbox       = Wx::StaticBox->new($this, -1, 'Versions', wxDefaultPosition, wxDefaultSize);
    my $versionboxsizer  = Wx::StaticBoxSizer->new( $versionbox, wxHORIZONTAL );
    $this->{sizer}      -> Add($versionboxsizer, 0, wxALL|wxGROW, 0);

    $this->{xdi}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [ 60,-1], wxTE_READONLY);
    $this->{apps} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [200,-1], wxTE_READONLY);
    $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "XDI version"),  0, wxALL, 5);
    $versionboxsizer -> Add($this->{xdi}, 0, wxALL|wxALIGN_CENTER, 5);
    $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "Applications"), 0, wxALL, 5);
    $versionboxsizer -> Add($this->{apps}, 1, wxALL|wxALIGN_CENTER, 5);


    ## Defined fields
    my $definedbox      = Wx::StaticBox->new($this, -1, 'Defined fields', wxDefaultPosition, wxDefaultSize);
    my $definedboxsizer = Wx::StaticBoxSizer->new( $definedbox, wxHORIZONTAL );
    $this->{sizer}     -> Add($definedboxsizer, 2, wxALL|wxGROW, 0);
    $this->{defined}    = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
    $definedboxsizer->Add($this->{defined}, 1, wxALL|wxGROW, 5);
    my $defbox  = Wx::BoxSizer->new( wxVERTICAL );
    $this->{defined} -> SetSizer($defbox);
    $this->{defined} -> SetScrollbars(0, 20, 0, 50);
    ## edit toggle

    $this->{tree} = Wx::TreeCtrl->new($this->{defined}, -1, wxDefaultPosition, wxDefaultSize,
				      wxTR_HIDE_ROOT|wxTR_SINGLE|wxTR_HAS_BUTTONS);
    $defbox -> Add($this->{tree}, 1, wxALL|wxGROW, 0);
    $this->{root} = $this->{tree}->AddRoot('Root');
    EVT_TREE_ITEM_RIGHT_CLICK($this, $this->{tree}, sub{OnRightClick(@_)});

    my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;

    ## extension fields
    my $extensionbox      = Wx::StaticBox->new($this, -1, 'Extension fields', wxDefaultPosition, wxDefaultSize);
    my $extensionboxsizer = Wx::StaticBoxSizer->new( $extensionbox, wxVERTICAL );
    $this->{sizer}       -> Add($extensionboxsizer, 1, wxALL|wxGROW, 0);
    $this->{extensions}   = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					      wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_RICH2);
    $this->{extensions}  -> SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    $extensionboxsizer->Add($this->{extensions}, 1, wxALL|wxGROW, 5);

    ## comments
    my $commentsbox      = Wx::StaticBox->new($this, -1, 'Comments', wxDefaultPosition, wxDefaultSize);
    my $commentsboxsizer = Wx::StaticBoxSizer->new( $commentsbox, wxVERTICAL );
    $this->{sizer}      -> Add($commentsboxsizer, 1, wxALL|wxGROW, 0);
    $this->{comments}    = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					     wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_RICH2);
    $this->{comments}   -> SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    $commentsboxsizer->Add($this->{comments}, 1, wxALL|wxGROW, 5);

  };

  $this->{document} = Wx::Button->new($this, -1, 'Document section: XAS metadata');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("xdi")});

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  return if (not exists $INC{'Xray/XDI.pm'});
  my @exttext  = split(/\n/, $this->{extensions}->GetValue);
  my @commtext = split(/\n/, $this->{comments}  ->GetValue);
  $data->xdi_extensions(\@exttext);
  $data->xdi_comments(\@commtext);
  return $this;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  return if (not exists $INC{'Xray/XDI.pm'});
  $this->{tree}->DeleteChildren($this->{root});
  foreach my $namespace ('beamline', 'scan', 'mono', 'facility', 'detector', 'sample') {
    my $leaf = $this->{tree}->AppendItem($this->{root}, ucfirst($namespace), 0, 1,
					Wx::TreeItemData->new( $namespace ));
    my $att = 'xdi_'.$namespace;
    foreach my $k (sort {$a cmp $b} keys %{$data->$att}) {
      my $label = sprintf("%s = %s", $k, $data->$att->{$k});
      my $child = $this->{tree}->AppendItem($leaf, $label, 0, 1,
					    Wx::TreeItemData->new( sprintf("%s.%s = %s",
									   $namespace, $k, $data->$att->{$k} ) ));
    };
    $this->{tree}->Expand($leaf);
  };
  $this->{xdi}->SetValue($data->xdi_version);
  $this->{apps}->SetValue($data->xdi_applications);
  $this->{extensions}->SetValue(join($/, @{$data->xdi_extensions}));
  $this->{comments}  ->SetValue(join($/, @{$data->xdi_comments  }));
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

const my $EDIT   => Wx::NewId();
const my $ADD    => Wx::NewId();
const my $DELETE => Wx::NewId();

sub OnRightClick {
  my ($tree, $event) = @_;
  my $text = $tree->{tree}->GetItemData($event->GetItem)->GetData;
  return if ($text !~ m{(\w+)\.(\w+) = (.+)});
  my ($namespace, $parameter, $value) = ($1, $2, $3);
  my $menu  = Wx::Menu->new(q{});
  $menu->Append($EDIT,   "Edit ".ucfirst($namespace).".$parameter");
  $menu->Append($ADD,    "Add a parameter to ".ucfirst($namespace)." namespace");
  $menu->Append($DELETE, "Delete ".ucfirst($namespace).".$parameter");
  EVT_MENU($menu, -1, sub{ $tree->DoContextMenu(@_, $namespace, $parameter, $value) });
  $tree -> PopupMenu($menu, $event->GetPoint);

  $event->Skip(1);
};

sub DoContextMenu {
  my ($xditool, $menu, $event, $namespace, $parameter, $value) = @_;
  my $data = $::app->current_data;
  if ($event->GetId == $EDIT) {
    my $method = "set_xdi_".$namespace;
    my $ted = Wx::TextEntryDialog->new($::app->{main}, "Enter a new value for \"$namespace.$parameter\":", "$namespace.$parameter",
				       $value, wxOK|wxCANCEL, Wx::GetMousePosition);
    #$::app->set_text_buffer($ted, "xdi");
    $ted->SetValue($value);
    if ($ted->ShowModal == wxID_CANCEL) {
      $::app->{main}->status("Resetting XDI parameter canceled.");
      return;
    };
    my $newvalue = $ted->GetValue;
    $data->$method($parameter, $newvalue);

  } elsif ($event->GetId == $ADD) {
    my $method = "set_xdi_".$namespace;
    my $addparam = Demeter::UI::Athena::XDIAddParameter->new($xditool, $data, $namespace);
    my $response = $addparam->ShowModal;
    if ($response eq wxID_CANCEL) {
      $::app->{main}->status("Adding metadata canceled");
      return;
    };
    return if ($addparam->{param}->GetValue =~ m{\A\s*\z});
    #print $addparam->{param}->GetValue, "  ", $addparam->{value}->GetValue, $/;
    $data->$method($addparam->{param}->GetValue, $addparam->{value}->GetValue);
    undef $addparam;

  } elsif ($event->GetId == $DELETE) {
    my $which = ucfirst($namespace).".$parameter";
    my $yesno = Wx::MessageDialog->new($::app->{main},
                                       "Really delete $which?",
                                       "Really delete $which?",
                                       wxYES_NO|wxNO_DEFAULT|wxICON_QUESTION|wxSTAY_ON_TOP);
    my $result = $yesno->ShowModal;
    if ($result == wxID_NO) {
      $::app->{main}->status("Not deleting $which");
      return 0;
    };
    my $method = "delete_from_xdi_".$namespace;
    $data->$method($parameter);
    $::app->{main}->status("Deleted $which");
  };
  $xditool->push_values($data);

};

sub OnParameter {
  my ($this, $param) = @_;
  my $data = $::app->current_data;
  my $att = 'xdi_'.$param;
  $data->$att($this->{$param}->GetValue)
};


1;


=head1 NAME

Demeter::UI::Athena::XDI - An XDI metadata displayer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

This module provides a simple, tree-based overview of XDI defined
metadata and textual interfaces to other kinds of metadata.  Metadata
can be edited, added, and deleted.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
