package Demeter::UI::Athena::GroupList;

use strict;
use warnings;

use Wx qw(:everything);
use Wx::Event qw(EVT_COMBOBOX);
use base 'Wx::ComboBox';

sub new {
  my ($class, $parent, $app, $exclude_self, $exclude_none) = @_;
  my $this = $class->SUPER::new($parent, -1, q{None}, wxDefaultPosition, [180,-1], ['None'], wxCB_READONLY );
  $this->fill($app, $exclude_self, $exclude_none);
  $this->SetSelection(0);
  $this->{callback} = sub{};
  EVT_COMBOBOX($parent, $this, sub{&{$this->{callback}}});
  return $this;
};

sub fill {
  my ($self, $app, $exclude_self, $exclude_none) = @_;
  return if not exists $app->{main};
  return if not exists $app->{main}->{list};
  return if not $app->{main}->{list}->GetCount;
  $self->Clear;
  $self->Append('None') if not $exclude_none;
  my $current = $app->current_data;
  my @groups = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    my $data = $app->{main}->{list}->GetIndexedData($i);
    next if ($exclude_self and ($current->group eq $data->group));
    my $index = $self->Append($data->name);
    $self->SetClientData($self->GetCount-1, $data);
    #print join("|", $self->GetCount-1, $data), $/;
  };
};

1;


=head1 NAME

Demeter::UI::Athena::GroupList - A group selection widget

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a group election widget based on a normal
Wx::ComboBox.  This provides a C<fill> method for populating the
ComboBox with the contents of the group list.  The method takes flags
for including or excluding the current group or an entry that says
"None".

=head1 DEPENDENCIES

Wx::ComboBox, obviously.

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
