package Demeter::UI::Athena::PluginRegistry;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_BUTTON EVT_RIGHT_DOWN EVT_MENU);
use autodie qw(open close);

use File::Basename;
use File::Spec;
use Pod::Text;
use Const::Fast;

use Demeter::UI::Athena::PluginConfig;

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Plugin registry";	# used in the Choicebox and in status bar messages to identify this tool

## right click to post plugin POD

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{window} = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  my $winbox  = Wx::BoxSizer->new( wxVERTICAL );
  $this->{window} -> SetSizer($winbox);
  $this->{window} -> SetScrollbars(0, 20, 0, 50);

  my $persist = File::Spec->catfile(Demeter->dot_folder, "athena.plugin_registry");
  my $state = (-e $persist) ? YAML::Tiny::Load(Demeter->slurp($persist)) : {};

  my @get_ini = ();
  foreach my $pl (sort @{Demeter->mo->Plugins}) {
    next if ($pl =~ m{FileType});
    my $obj = $pl->new;
    ## gather list of plugins that have a demeter_conf file associated with
    if ($obj->conffile =~ m{(\w+)\.demeter_conf}) {
      push @get_ini, $1;
    }
    my $label = sprintf("%s :  %s", (split(/::/, $pl))[2], $obj->description);
    $this->{$pl} = Wx::CheckBox->new($this->{window}, -1, $label);
    $winbox->Add($this->{$pl}, 0, wxALL|wxGROW, 3);
    undef $obj;
    $this->{$pl}->SetValue($state->{$pl});
    EVT_CHECKBOX($this, $this->{$pl}, sub{OnCheck(@_, $app)});
    EVT_RIGHT_DOWN($this->{$pl}, sub{OnRight(@_, $app)});
    EVT_MENU($this->{$pl}, -1, sub{ $this->DoContextMenu(@_, $app, $pl) });
  };
  # loading the plugin read the demeter_conf file, this overwrites default from demeter.ini
  foreach my $g (@get_ini) {
    Demeter->co->read_ini($g);
  };
  $box->Add($this->{window}, 1, wxALL|wxGROW, 5);
  #$box->Add(Wx::StaticText->new($this, -1, "(Right click on a plugin above to open the configuration dialog for that plugin.)"), 0, wxALIGN_CENTER_HORIZONTAL|wxALL|wxGROW, 5);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: plugin registry');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("other.plugin")});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnCheck {
  my ($this, $event, $app) = @_;
  my $persist = File::Spec->catfile(Demeter->dot_folder, "athena.plugin_registry");
  my %state = ();
  foreach my $pl (sort @{Demeter->mo->Plugins}) {
    next if ($pl =~ m{FileType});
    $state{$pl} = $this->{$pl}->GetValue;
  };
  my $string .= YAML::Tiny::Dump(\%state);
  open(my $STATE, '>'.$persist);
  print $STATE $string;
  close $STATE;
};

const my $DOCUMENT  => Wx::NewId();
const my $CONFIGURE => Wx::NewId();

sub OnRight {
  my ($this, $event, $app) = @_;
  my $plugin = (split(/\s*:\s*/, $this->GetLabel))[0];
  my $menu  = Wx::Menu->new(q{});
  $menu->Append($DOCUMENT, "Show documentation for the $plugin plugin");
  my $pl = "Demeter::Plugins::$plugin";
  my $obj = $pl->new;
  my $inifile = $obj->conffile;
  $menu->Append($CONFIGURE, "Configure the $plugin plugin")  if $inifile;
  my $here = ($event =~ m{Mouse}) ? $event->GetPosition : Wx::Point->new(10,10);
  $this -> PopupMenu($menu, $here);
};
sub DoContextMenu {
  #print join("|", @_), $/;
  my ($page, $this, $event, $app, $pl) = @_;
  my $id = $event->GetId;
 SWITCH: {
    ($id == $CONFIGURE) and do {
      $page->Configure($event, $app, $pl);
      last SWITCH;
    };
    ($id == $DOCUMENT) and do {
      $page->Document($event, $app, $pl);
      last SWITCH;
    };
  };

};

sub Configure {
  my ($this, $event, $app, $pl) = @_;
  my $plugin = (split(/::/, $pl))[-1];
  my $obj = $pl->new;
  my $inifile = $obj->conffile;
  if (not $inifile) {
    $::app->{main}->status("The $plugin plugin does not have any configuration parameters.");
    return;
  };
  #my $cfg = new Config::IniFiles( -file => $inifile );
  my $config = Demeter::UI::Athena::PluginConfig->new($this, $plugin, [lc($plugin)]);
  my $response = $config->ShowModal;
  if ($response eq wxID_CLOSE) {
    $::app->{main}->status("Canceled configuration of $plugin plugin");
    return;
  };

  # my @sections = $cfg->Sections;
  # foreach my $s (@sections) {
  #   foreach my $p ($cfg->Parameters($s)) {
  #     #printf "%s:%s = %s\n", $s, $p, $config->{"$s.$p"}->GetValue;
  #     my $temp = $pl->new;
  #     if ($temp->lower_case) {
  # 	$cfg->setval($s, $p, lc($config->{"$s.$p"}->GetValue));
  #     } else {
  # 	$cfg->setval($s, $p, $config->{"$s.$p"}->GetValue);
  #     };
  #     undef $temp;
  #   };
  # };
  # $cfg->WriteConfig($inifile);
  # $::app->{main}->status("Wrote $plugin configuration file: $inifile");
};

sub Document {
  my ($this, $event, $app, $pl) = @_;
  my $plugin = (split(/::/, $pl))[-1];
  my $parser = Pod::Text->new (sentence => 0, width => 78);
  my $podroot = dirname($INC{'Demeter.pm'});
  (my $module = $pl) =~ s{::}{/}g;
  my $tempfile = File::Spec->catfile(Demeter->stash_folder, Demeter->randomstring(8).'.txt');
  $parser->parse_from_file (File::Spec->catfile($podroot, $module).'.pm', $tempfile);

  my $dialog = Demeter::UI::Common::ShowText
    -> new($app->{main}, Demeter->slurp($tempfile), "Documentation for $plugin");
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog->SetSize(1.5*$w, $h);
  $dialog->Show;
  unlink $tempfile;
};

1;


=head1 NAME

Demeter::UI::Athena::PluginRegistry - Regstering plugins for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

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
