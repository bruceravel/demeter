package Demeter::UI::Athena::Summer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);

use Demeter::UI::Wx::SpecialCharacters qw($MU $CHI);

use vars qw($label);
$label = "Sum arbitrary combinations of data";

my $tcsize = [90,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $this->{n} = 0;
  $this->{nmax} = 8;

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $box -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{space} = Wx::RadioBox->new($this, -1, 'Space', wxDefaultPosition, wxDefaultSize,
					 ["$MU(E)", "normalized $MU(E)", "$CHI(k)"],
					 1, wxRA_SPECIFY_ROWS);
  $this->{space}->SetSelection(0);
  $this->{space}->Enable(2,0);
  $hbox         -> Add($this->{space}, 0, wxALL, 3);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox         -> Add($vbox, 0, wxGROW|wxALL, 3);

  $this->{plotdata} = Wx::CheckBox->new($this, -1, "Include components in plot");
  $vbox         -> Add($this->{plotdata}, 0, wxGROW|wxALL, 3);
  $this->{plotmarked} = Wx::CheckBox->new($this, -1, "Include marked groups in plot");
  $vbox         -> Add($this->{plotmarked}, 0, wxGROW|wxLEFT|wxRIGHT, 3);

  my $stanbox       = Wx::StaticBox->new($this, -1, 'Components', wxDefaultPosition, wxDefaultSize);
  my $stanboxsizer  = Wx::StaticBoxSizer->new( $stanbox, wxVERTICAL );
  $box             -> Add($stanboxsizer, 0, wxGROW|wxALL, 3);
  $this->{stanbox}  = $stanbox;
  $this->{stanboxsizer}  = $stanboxsizer;
  foreach my $i (1..$this->{nmax}) {
    $this->add_choice;
  };

  $this->{plot}     = Wx::Button->new($this, -1, 'Plot sum');
  $this->{plotwith} = Wx::Button->new($this, -1, 'Plot sum and individual data groups');
  $this->{make}     = Wx::Button->new($this, -1, 'Make data group from sum');
  #$this->{add}      = Wx::Button->new($this, -1, 'Add another group');
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 3) foreach qw(plot plotwith make); # add);
  #EVT_BUTTON($this, $this->{add}, sub{$this->add_choice});


  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: Summer');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("summer")});

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

sub add_choice {
  my ($this) = @_;
  ++$this->{n};

  my $box = Wx::BoxSizer->new( wxHORIZONTAL);
  $this->{stanboxsizer}->Add($box, 1, wxGROW|wxALL, 3);

  $box->Add(Wx::StaticText->new($this, -1, $this->{n}), 0, wxGROW|wxALL, 3);
  my $key = "standard".$this->{n};
  $this->{$key} = Demeter::UI::Athena::GroupList -> new($this, $::app, 1);
  $box->Add($this->{$key}, 1, wxGROW|wxALL, 0);
  $box->Add(Wx::StaticText->new($this, -1, "weight:"), 0, wxGROW|wxALL, 3);
  $key = "weight".$this->{n};
  $this->{$key} = Wx::TextCtrl->new($this, -1, 1, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $box->Add($this->{$key}, 0, wxALL, 0);
  $this->SetSizerAndFit($this->{sizer});
  $this->Update;
};


## yes, there is some overlap between what push_values and mode do.
## This separation was useful in Main.pm.  Some of the other tools
## make mode a null op.

1;


=head1 NAME

Demeter::UI::Athena::Summer - A data summer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

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

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
