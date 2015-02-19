package Demeter::UI::Hephaestus::Config;

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

use strict;
use warnings;
use Carp;

use Xray::Absorption;

use Wx qw( :everything );

use base 'Demeter::UI::Wx::Config';

sub new {
  my ($class, $page, $echoarea) = @_;
  my $top = $page->GetParent->GetParent; ## (really!)
  my $self = $class->SUPER::new($page, \&target, $top);
  $self->{echo} = $echoarea;
  $self->populate($top->{prefgroups});
  $self->{params}->Expand($self->{params}->GetRootItem);

  return $self;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($param eq 'plotwith') and do {
      Demeter->plot_with($value);
      last SWITCH;
    };
    ($param eq 'resource') and do {
      Xray::Absorption->load($value);
      last SWITCH;
    };
    ($param eq 'units') and do {
      1;
      last SWITCH;
    };
    ($param eq 'xsec') and do {
      1;
      last SWITCH;
    };
    ($param eq 'ion_pressureunits') and do {
      my %range = (torr => [1,2300], mbar => [1,3066], atm => [0.01,3]);
      my %conv  = (torr => 760, mbar => 1013.25, atm => 1);
      my $factor = $conv{$value} / $conv{Demeter->co->was($parent, $param)};
      $Demeter::UI::Hephaestus::frame->{ion}->{pressureunits}->SetLabel("Pressure ($value) ");
      $Demeter::UI::Hephaestus::frame->{ion}->{pressureunits}->Refresh;
      $Demeter::UI::Hephaestus::frame->{ion}->{pressure}->SetRange(@{$range{$value}});
      my $val = $Demeter::UI::Hephaestus::frame->{ion}->{pressure}->GetValue;
      $Demeter::UI::Hephaestus::frame->{ion}->{pressure}->SetValue(int($val*$factor));
      $Demeter::UI::Hephaestus::frame->{ion}->{pressure}->Refresh;
      last SWITCH;
    };
  };

  ($save)
    ? $self->{echo}->SetStatusText("Now using $value for $parent-->$param and an ini file was saved")
      : $self->{echo}->SetStatusText("Now using $value for $parent-->$param");

};


1;

=head1 NAME

Demeter::UI::Hephaestus::Config - Hephaestus' electronic transitions utility

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

The contents of Hephaestus' electronic transistions utility can be
added to any Wx application.

  my $page = Demeter::UI::Hephaestus::Config->new($parent,\&callback);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a method that does some
post-processing of the parameters after they are set.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents a diagram explaining the electronic transitions
associated with the various fluorescence lines.

=head1 CONFIGURATION


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
