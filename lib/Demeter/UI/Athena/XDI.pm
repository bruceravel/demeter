package Demeter::UI::Athena::XDI;

use strict;
use warnings;
use Const::Fast;
use File::Basename;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT EVT_TEXT_ENTER EVT_TREE_ITEM_RIGHT_CLICK EVT_MENU);
use Demeter::UI::Athena::XDIAddParameter;
#use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Wx::ColourDatabase;
my $cdb = Demeter::UI::Wx::ColourDatabase->new;

use vars qw($label);
$label = "File metadata";

my $tcsize = [60,-1];

my $icon = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "x.png");
my $not  = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);
$icon    = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "check.png");
my $ok   = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  if (not exists $INC{'Xray/XDI.pm'}) {
    $box->Add(Wx::StaticText->new($this, -1, "File metadata is not enabled on this computer.\nThe most likely reason is that the perl module Xray::XDI is not available."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {


    my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;

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


    my $rbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{rbox} = $rbox;
    $this->{sizer} -> Add($rbox, 0, wxALL|wxGROW, 0);
    $this->{required_lab} = Wx::StaticText->new($this, -1, q{Required metadata:});
    $rbox -> Add($this->{required_lab}, 0, wxALL, 5);
    $this->{required_ok}  = Wx::BitmapButton->new($this, -1, $ok);
    $this->{required_not} = Wx::BitmapButton->new($this, -1, $not);
    $rbox -> Add($this->{required_ok}, 0, wxALL, 0);
    $rbox -> Add($this->{required_not}, 0, wxALL, 0);
    $rbox -> AddSpacer(30);
    $this->{recommended_lab} = Wx::StaticText->new($this, -1, q{Recommended metadata:});
    $rbox -> Add($this->{recommended_lab}, 0, wxALL, 5);
    $this->{recommended_ok}  = Wx::BitmapButton->new($this, -1, $ok);
    $this->{recommended_not} = Wx::BitmapButton->new($this, -1, $not);
    $rbox -> Add($this->{recommended_ok}, 0, wxALL, 0);
    $rbox -> Add($this->{recommended_not}, 0, wxALL, 0);
    $this->{required_ok}->Hide;
    $this->{recommended_ok}->Hide;

    EVT_BUTTON($this, $this->{required_ok},     sub{ &rrmetadata(@_, 'required', 1) });
    EVT_BUTTON($this, $this->{required_not},    sub{ &rrmetadata(@_, 'required', 0) });
    EVT_BUTTON($this, $this->{recommended_ok},  sub{ &rrmetadata(@_, 'recommended', 1) });
    EVT_BUTTON($this, $this->{recommended_not}, sub{ &rrmetadata(@_, 'recommended', 0) });

    ## Defined fields
    my $definedbox      = Wx::StaticBox->new($this, -1, 'XDI Metadata', wxDefaultPosition, wxDefaultSize);
    my $definedboxsizer = Wx::StaticBoxSizer->new( $definedbox, wxVERTICAL );
    $this->{sizer}     -> Add($definedboxsizer, 2, wxALL|wxGROW, 0);

    $this->{tree} = Wx::TreeCtrl->new($this, -1, wxDefaultPosition, [-1,300],
				      wxTR_HIDE_ROOT|wxTR_SINGLE|wxTR_HAS_BUTTONS);
    $definedboxsizer -> Add($this->{tree}, 1, wxALL|wxGROW, 5);
    $this->{root} = $this->{tree}->AddRoot('Root');
    EVT_TREE_ITEM_RIGHT_CLICK($this, $this->{tree}, sub{OnRightClick(@_)});

    $this->{tree}->SetFont( Wx::Font->new( $size - 1, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );


    my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{expand}   = Wx::Button->new($this, -1, "Expand all");
    $this->{collapse} = Wx::Button->new($this, -1, "Collapse all");
    $this->{validate} = Wx::Button->new($this, -1, "Validate all");
    $definedboxsizer -> Add($hbox, 0, wxALL|wxGROW, 0);
    $hbox            -> Add($this->{expand},  1, wxALL|wxGROW, 5);
    $hbox            -> Add($this->{collapse}, 1, wxALL|wxGROW, 5);
    $hbox            -> Add($this->{validate}, 1, wxALL|wxGROW, 5);
    EVT_BUTTON($this, $this->{expand},   sub{$this->{tree}->ExpandAll});
    EVT_BUTTON($this, $this->{collapse}, sub{$this->{tree}->CollapseAll});
    EVT_BUTTON($this, $this->{validate}, sub{ValidateAll(@_)});

    ## comments
    my $commentsbox      = Wx::StaticBox->new($this, -1, 'Comments', wxDefaultPosition, wxDefaultSize);
    my $commentsboxsizer = Wx::StaticBoxSizer->new( $commentsbox, wxHORIZONTAL );
    $this->{sizer}      -> Add($commentsboxsizer, 1, wxALL|wxGROW, 0);
    $this->{comments}    = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [-1,100],
					     wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_RICH2);
    $this->{comments}   -> SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    $commentsboxsizer->Add($this->{comments}, 1, wxALL|wxGROW, 5);

    $this->{savecomm}   = Wx::Button->new($this, -1, "Save\ncomments");
    $commentsboxsizer->Add($this->{savecomm}, 0, wxALL|wxGROW, 5);
    EVT_BUTTON($this, $this->{savecomm}, sub{ &OnSaveComments });

    $this->{spare_xdi} = Xray::XDI->new(file=>File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}), 'Demeter', 'UI', 'Athena', 'share', 'spare.xdi'));

  };

  $this->{document} = Wx::Button->new($this, -1, 'Document section: XAS metadata');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("other.meta")});

  $this->{sizer}->Layout;
  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  return if ((not ($INC{'Xray/XDI.pm'}) or (not $data->xdi)));
  my @commtext = split(/\n/, $this->{comments}  ->GetValue);
  return $this;
};

use Capture::Tiny qw(capture);
my ($WHITE, $GRAY);
## some part of Wx is compiled with debug mode on my new Ubuntu 14.10
## machine, causing these color assignments so spew to stderr. so...
my @toss = capture {
  $WHITE = Wx::Colour->new($cdb->Find('WHITE'));
  $GRAY  = Wx::Colour->new($cdb->Find('LIGHT GREY'));
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  return if not $INC{'Xray/XDI.pm'};
  $this->{$_}->SetValue(q{}) foreach (qw(xdi apps comments));
  $this->{tree}->DeleteChildren($this->{root});
  return if not $data->xdi;
  my $outer_count = 0;
  foreach my $namespace ($data->xdi_families) {
    my $count = $outer_count++;
    next if ($namespace =~ m{athena|artemis}i);
    my $leaf = $this->{tree}->AppendItem($this->{root}, sprintf("%-72s", ucfirst($namespace)));
    $this->{tree} -> SetItemBackgroundColour($leaf,  ($count++ % 2) ? wxWHITE : wxLIGHT_GREY );
    foreach my $tag ($data->xdi_tags($namespace)) {
      my $value = $data->xdi_datum($namespace, $tag);
      my $string = sprintf("%-20s = %-47s", lc($tag), $value);
      my $item = $this->{tree}->AppendItem($leaf, $string);
      $this->{tree} -> SetItemBackgroundColour($item,  ($count++ % 2) ? wxWHITE : wxLIGHT_GREY );
    };
    $this->{tree}->Expand($leaf);
  };
  $this->{xdi}->SetValue($data->xdi_attribute('xdi_version'));
  $this->{apps}->SetValue($data->xdi_attribute('extra_version'));
  $this->{comments}  ->SetValue($data->xdi_attribute('comments'));

  my $req_ok = 1;
  foreach my $req ($data->xdi->required_list) {
    my ($namespace, $tag) = split(/\./, $req);
    $req_ok = 0 if ($data->xdi_datum($namespace, $tag) =~ m{does not exist}i);
    #Demeter->pjoin($req, $namespace, $tag, $data->xdi_datum($namespace, $tag), $req_ok);
  };
  if ($req_ok) {
     $this->{required_not} -> Hide;
     $this->{required_ok} -> Show(1);
     $this->{rbox} -> Layout();
  } else {
     $this->{required_ok} -> Hide;
     $this->{required_not} -> Show(1);
     $this->{rbox} -> Layout();
  };

  my $rec_ok = 1;
  foreach my $rec ($data->xdi->recommended_list) {
    my ($namespace, $tag) = split(/\./, $rec);
    $rec_ok = 0 if ($data->xdi_datum($namespace, $tag) =~ m{does not exist}i);
    #Demeter->pjoin($rec, $namespace, $tag, $data->xdi_datum($namespace, $tag), $rec_ok);
  };
  if ($rec_ok) {
     $this->{recommended_not} -> Hide;
     $this->{recommended_ok} -> Show(1);
     $this->{rbox} -> Layout();
  } else {
     $this->{recommended_ok} -> Hide;
     $this->{recommended_not} -> Show(1);
     $this->{rbox} -> Layout();
  };

  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub ValidateAll {
  my ($this, $event) = @_;

  my $data = $::app->current_data;
  my $text = q{};
  my $xdi;
  if ($data->xdi->xdifile) {    # there is an Xray::XDI object associated with this $data
    $xdi = $data->xdi;
  } else {
    $xdi = $this->{spare_xdi};	# use the spare Xray::XDI object
    $xdi->xdifile->_set_extra_version($data->xdi->extra_version);
  };

  my $root = $this->{tree}->GetRootItem;
  my ($famitem, $cookie) = $this->{tree}->GetFirstChild($root);
  #print $this->{tree}->GetItemText($famitem);
  while ($famitem->IsOk) {
    my $family = $this->{tree}->GetItemText($famitem);
    $family =~ s{\s+\z}{}; # trim leading and trailing whitespace

    my ($nameitem, $cookie2) = $this->{tree}->GetFirstChild($famitem);
    while ($nameitem->IsOk) {

      my ($name, $value) = split(/\s*=\s*/, $this->{tree}->GetItemText($nameitem));
      $name   =~ s{\s+\z}{};
      $value  =~ s{\s+\z}{};
      #Demeter->pjoin($family, $name, $value, '<');

      $xdi->validate($family, $name, $value);
      if ($xdi->errorcode) {
	$text .= sprintf("%s.%s: %s\n\t%s\n\n", $family, $name, $value, $xdi->errormessage);
      };

      ($nameitem, $cookie2) = $this->{tree}->GetNextChild($famitem, $cookie2);
    };
    ($famitem, $cookie) = $this->{tree}->GetNextChild($root, $cookie);
  };

  if ($text) {
    my $dialog = Demeter::UI::Artemis::ShowText->new($this, $text, 'Validation of metadata') -> Show;
  } else {
    $::app->{main}->status("All metadata are fine", 'normal');
  };

};

sub OnSaveComments {
  my ($this, $event) = @_;
  my $data = $::app->current_data;
  $data->xdi->comments($this->{comments}->GetValue);
  $::app->{main}->status("Saved changes to XDI comments.")
};

sub rrmetadata {
  my ($this, $event, $which, $ok) = @_;
  my $data = $::app->current_data;
  my $text = q{};
  my @list = ($which eq 'required') ? $data->xdi->required_list : $data->xdi->recommended_list;
  if ($ok) {
    $text  = "These data have all $which metadata:\n\t";
    $text .= join("\n\t", @list) . "\n";
  } else {
    $text  = ucfirst($which)." metadata:\n\n";
    foreach my $item (@list) {
      my ($namespace, $tag) = split(/\./, $item);
      my $status = ($data->xdi_datum($namespace, $tag) =~ m{does not exist}i) ? "missing" : "ok";
      $text .= sprintf("%27s:  %s\n", $item, $status);
    };
  };
  my $dialog = Demeter::UI::Artemis::ShowText->new($this, $text, ucfirst($which).' metadata') -> Show;
};

# const my $EDIT   => Wx::NewId();
# const my $ADD    => Wx::NewId();
# const my $DELETE => Wx::NewId();
const my $VALIDATE => Wx::NewId();

sub OnRightClick {
  my ($this, $event) = @_;
  my $family = $this->{tree}->GetItemText($this->{tree}->GetItemParent($event->GetItem));
  $family =~ s{\s+\z}{};
  return if ($family eq 'Root');
  my ($name, $value) = split(/\s+=\s+/, $this->{tree}->GetItemText($event->GetItem));

  my $menu  = Wx::Menu->new(q{});
  #$menu->Append($EDIT,   "Edit ".ucfirst($namespace).".$parameter");
  #$menu->Append($ADD,    "Add a parameter to ".ucfirst($namespace)." namespace");
  #$menu->Append($DELETE, "Delete ".ucfirst($namespace).".$parameter");
  $menu->Append($VALIDATE, "Validate ".ucfirst($family).".$name");
  EVT_MENU($menu, -1, sub{ $this->DoContextMenu(@_, $family, $name, $value) });
#  my $here = ($event =~ m{Mouse}) ? $event->GetPosition : Wx::Point->new(10,10);
  my $where = Wx::Point->new($event->GetPoint->x, $event->GetPoint->y+80);
  $this -> PopupMenu($menu, $where);

  $event->Skip(1);
};

sub DoContextMenu {
  my ($xditool, $menu, $event, $namespace, $parameter, $value) = @_;
  my $data = $::app->current_data;
  $namespace =~ s{\A\s*(\S+)\s+\z}{$1}; # trim leading and trailing whitespace
  $parameter =~ s{\A\s*(\S+)\s+\z}{$1};
  $value     =~ s{\A\s*(\S+)\s+\z}{$1};

  my $xdi;
  if ($data->xdi->xdifile) {		# there is an Xray::XDI object associated with this $data
    $xdi = $data->xdi;
  } else {
    $xdi = $xditool->{spare_xdi}; # use the spare Xray::XDI object
    $xdi->xdifile->_set_extra_version($data->xdi->extra_version);
  };

  if ($event->GetId == $VALIDATE) {
    $xdi->validate($namespace, $parameter, $value);
    #print $data->xdi->errorcode, $/;
    #print $data->xdi->errormessage, $/;
    if ($xdi->errorcode) {
      $::app->{main}->status($xdi->errormessage, 'alert');
    } else {
      $::app->{main}->status(sprintf("%s.%s is fine", ucfirst(lc($namespace)), lc($parameter)), 'normal');
    };
  };

};
#   if ($event->GetId == $EDIT) {
#     my $method = "set_xdi_".$namespace;
#     my $ted = Wx::TextEntryDialog->new($::app->{main}, "Enter a new value for \"$namespace.$parameter\":", "$namespace.$parameter",
# 				       $value, wxOK|wxCANCEL, Wx::GetMousePosition);
#     #$::app->set_text_buffer($ted, "xdi");
#     $ted->SetValue($value);
#     if ($ted->ShowModal == wxID_CANCEL) {
#       $::app->{main}->status("Resetting XDI parameter canceled.");
#       return;
#     };
#     my $newvalue = $ted->GetValue;
#     $data->$method($parameter, $newvalue);

#   } elsif ($event->GetId == $ADD) {
#     my $method = "set_xdi_".$namespace;
#     my $addparam = Demeter::UI::Athena::XDIAddParameter->new($xditool, $data, $namespace);
#     my $response = $addparam->ShowModal;
#     if ($response eq wxID_CANCEL) {
#       $::app->{main}->status("Adding metadata canceled");
#       return;
#     };
#     return if ($addparam->{param}->GetValue =~ m{\A\s*\z});
#     #print $addparam->{param}->GetValue, "  ", $addparam->{value}->GetValue, $/;
#     $data->$method($addparam->{param}->GetValue, $addparam->{value}->GetValue);
#     undef $addparam;

#   } elsif ($event->GetId == $DELETE) {
#     my $which = ucfirst($namespace).".$parameter";
#     my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
# 						 "Really delete $which?",
# 						 "Really delete $which?",
# 						 "Delete");
#     my $result = $yesno->ShowModal;
#     if ($result == wxID_NO) {
#       $::app->{main}->status("Not deleting $which");
#       return 0;
#     };
#     my $method = "delete_from_xdi_".$namespace;
#     $data->$method($parameter);
#     $::app->{main}->status("Deleted $which");
#   };
#   $xditool->push_values($data);

# };

# sub OnParameter {
#   my ($this, $param) = @_;
#   my $data = $::app->current_data;
#   my $att = 'xdi_'.$param;
#   $data->$att($this->{$param}->GetValue)
# };


1;


=head1 NAME

Demeter::UI::Athena::XDI - An XDI metadata displayer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This module provides a simple, tree-based overview of XDI defined and
extension metadata.  User comments can be altered.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
