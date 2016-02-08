package Demeter::UI::Athena::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PlotListDrag;

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new;

  my $data = Demeter::UI::Artemis::DND::PlotListDrag->new();
  $this->SetDataObject( $data );
  $this->{DATA} = $data;
  return $this;
};

sub OnData {
  my ($this, $x, $y, $def) = @_;

  my $list = $::app->{main}->{list};
  return 0 if not $list->GetCount;
  $this->GetData;		# this line is what transfers the data from the Source to the Target

  my $from = ${ $this->{DATA}->{Data} };
  my $from_object  = $list->GetIndexedData($from);
  my $from_label   = $list->GetString($from);
  my $from_checked = $list->IsChecked($from);
  my $point = Wx::Point->new($x, $y);
  my $to = $list->HitTest($point);
  my $to_label   = $list->GetString($to);

  return 0 if ($to == $from);	# either of these two would leave the list in the same state
#  return 0 if ($to == $from+1);

  my $message;
  $list -> DeleteData($from);
  if ($to == -1) {
    $list -> AddData($from_label, $from_object);
    $list -> Check($list->GetCount-1, $from_checked);
    $::app->{main}->{list}->SetSelection($from);
    $message = sprintf("Moved '%s' to the last position.", $from_label);
  } else {
    $message = sprintf("Moved '%s' above %s.", $from_label, $to_label);
    --$to if ($from < $to);
    $list -> InsertData($from_label, $to, $from_object);
    #$list -> SetClientData($to, $from_object);
    $list -> Check($to, $from_checked);
    $::app->{main}->{list}->SetSelection($to);
  };
  $::app->OnGroupSelect(q{}, scalar $::app->{main}->{list}->GetSelection, 0);
  $::app->modified(1);
  $::app->{main}->status($message);

  return $def;
};

1;

=head1 NAME

Demeter::UI::Athena::DropTarget - A drop target for rearranging Athena's group list

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides a way to process drag-n-drop events in Athena's
group list.  This will move a group I<above> the group on which it is
dropped.

This is unused as of 0.9.20.

=head1 DEPENDENCIES

Wx::DND.

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
