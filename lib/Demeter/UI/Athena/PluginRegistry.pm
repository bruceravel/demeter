package Demeter::UI::Athena::PluginRegistry;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_BUTTON);
use autodie qw(open close);

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

  my $persist = File::Spec->catfile($Demeter::UI::Athena::demeter->dot_folder, "athena.plugin_registry");
  my $state = (-e $persist) ? YAML::Tiny::Load($Demeter::UI::Athena::demeter->slurp($persist)) : {};

  foreach my $pl (sort @{$Demeter::UI::Athena::demeter->mo->Plugins}) {
    next if ($pl =~ m{FileType});
    my $obj = $pl->new;
    my $label = sprintf("%s :  %s", (split(/::/, $pl))[2], $obj->description);
    $this->{$pl} = Wx::CheckBox->new($this->{window}, -1, $label);
    $winbox->Add($this->{$pl}, 0, wxALL|wxGROW, 3);
    undef $obj;
    $this->{$pl}->SetValue($state->{$pl});
    EVT_CHECKBOX($this, $this->{$pl}, sub{OnCheck(@_, $app)});
  };
  $box->Add($this->{window}, 1, wxALL|wxGROW, 5);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: plugin registry');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("registry")});

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
  my $persist = File::Spec->catfile($Demeter::UI::Athena::demeter->dot_folder, "athena.plugin_registry");
  my %state = ();
  foreach my $pl (sort @{$Demeter::UI::Athena::demeter->mo->Plugins}) {
    next if ($pl =~ m{FileType});
    $state{$pl} = $this->{$pl}->GetValue;
  };
  my $string .= YAML::Tiny::Dump(\%state);
  open(my $STATE, '>'.$persist);
  print $STATE $string;
  close $STATE;
};


1;


=head1 NAME

Demeter::UI::Athena::PluginRegistry - Regstering plugins for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

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
