package  Demeter::UI::Artemis::Close;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

use Wx qw( :everything );

require Exporter;
use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(on_close);

sub on_close {
  my ($self, $event) = @_;
  #Demeter->trace;
  #print $event, $/;
  if (ref($event) =~ m{IconizeEvent}) {
    if (not $event->Iconized) {	# de-iconizing
      _toggle_button($self, 1);
    } else {			# iconizing
      _toggle_button($self, 0);
    };
  } else {
    $self->Show(0);
    _toggle_button($self, 0);
  };
};

sub _toggle_button {		# toggle the correct button
  my ($self, $onoff) = @_;

  ## toolbar entries
  if (ref($self) =~ m{GDS}) {
    $self->GetParent->{toolbar}->ToggleTool(1, $onoff);
  } elsif (ref($self) =~ m{Plot}) {
    $self->GetParent->{toolbar}->ToggleTool(2, $onoff);
  } elsif (ref($self) =~ m{History}) {
    $self->GetParent->{toolbar}->ToggleTool(3, $onoff);
  } elsif (ref($self) =~ m{Journal}) {
    $self->GetParent->{toolbar}->ToggleTool(4, $onoff);

  ## log frame
  } elsif (ref($self) =~ m{Log}) {
    $self->GetParent->{log_toggle}->SetValue($onoff);

  ## data or feff frame
  } elsif (ref($self) =~ m{Data}) {
    $self->{PARENT}->{$self->{dnum}}->SetValue($onoff);
    my $label = $self->{PARENT}->{$self->{dnum}}->GetLabel;
    if ($onoff) {
      $label =~ s{Show}{Hide};
    } else {
      $label =~ s{Hide}{Show};
    };
    $self->{PARENT}->{$self->{dnum}}->SetLabel($label);
  } elsif (ref($self) =~ m{AtomsApp}) {
    $::app->{main}->{$self->{fnum}}->SetValue($onoff);
    my $label = $::app->{main}->{$self->{fnum}}->GetLabel;
    if ($onoff) {
      $label =~ s{Show}{Hide};
    } else {
      $label =~ s{Hide}{Show};
    };
    $::app->{main}->{$self->{fnum}}->SetLabel($label);

 };
};


1;
