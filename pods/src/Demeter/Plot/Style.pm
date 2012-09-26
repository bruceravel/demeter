package Demeter::Plot::Style;

use Moose;
extends 'Demeter';
use Demeter::StrTypes qw( MERIP );

has '+name' => (default => q{style});

has 'emin'      => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "emin")	  || -200});
has 'emax'      => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "emax")	  || 800});
# has 'e_mu'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_mu")	  || 1});
# has 'e_bkg'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_bkg")	  || 0});
# has 'e_pre'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_pre")	  || 0});
# has 'e_post'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_post")    || 0});
# has 'e_norm'	=> (is => 'rw', isa =>  'Bool',   alias => 'e_nor', default => sub{ shift->co->default("plot", "e_norm")    || 0});
# has 'e_der'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_der")	  || 0});
# has 'e_sec'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_sec")	  || 0});
# has 'e_i0'	  => (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_i0")	  || 0});
# has 'e_signal'  => (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_signal")  || 0});
# has 'e_markers' => (is => 'rw', isa =>  'Bool',   alias => 'e_marker', default => sub{ shift->co->default("plot", "e_markers") || 0});
# has 'e_smooth'  => (is => 'rw', isa =>  'Int',    default => sub{ shift->co->default("plot", "e_smooth")  || 0});
# has 'e_zero'	  => (is => 'rw', isa =>  'Bool',   default => 0);

has 'kmin'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "kmin") || 0});
has 'kmax'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "kmax") || 15});

has 'rmin'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "rmin") || 0});
has 'rmax'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "rmax") || 6});
#has 'r_pl'  => (is => 'rw', isa =>  MERIP,    default => sub{ shift->co->default("plot", "r_pl") || "m"});

has 'qmin'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "qmin") || 0});
has 'qmax'  => (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "qmax") || 15});
#has 'q_pl'  => (is => 'rw', isa =>  MERIP,    default => sub{ shift->co->default("plot", "q_pl") || "r"});

my @limits = qw(emin emax kmin kmax rmin rmax qmin qmax);
my @parts  = qw(r_pl q_pl e_mu e_bkg e_pre e_post e_norm e_der e_sec);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Style($self);
};

sub pull {
  my ($self) = @_;
  foreach my $att (@limits) {
    $self->$att($self->po->$att);
  };
  return $self;
};

sub apply {
  my ($self) = @_;
  foreach my $att (@limits) {
    $self->po->$att($self->$att);
  };
  return $self;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plot::Style - Simple management of plotting parameters

=head1 VERSION

This documentation refers to Demeter version 0.9.12.

=head1 SYNOPSIS

  my $xanes_style = Demeter::Plot::Style->new(name=>xanes,
                                              emin=>-30,
                                              emax=>50);
  my $exafs_style = Demeter::Plot::Style->new(name=>xanes,
                                              emin=>-200,
                                              emax=>900);
  $data -> po -> start_plot;
  $xanes_style->apply;
  $data -> plot('E');  # makes a XANES plot
  $data -> po -> start_plot;
  $exafs_style->apply;
  $data -> plot('E');  # makes a plot of the full spectrum

=head1 DESCRIPTION

This is an object for holding a subset of the attributes of the Plot
object.  The purpose is to maintain sets of xmin and xmax parameters
in the different plotting spaces suitable for plotting different
representations of data.  For example, you might keep a plotting style
for XANES plots and another for EXAFS plots, using this object's
C<apply> method to quickly and conveniently switch between the two.

This is implemented in Athena in one o fthe plot tabs at the bottom of
the plotting sidebar.

=head1 ATTRIBUTES

=over 4

=item C<emin>

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
There is an indicator group that can be adjusted to modify the default
behavior of this object.  It is in the F<ornaments.demeter_conf>
file.

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
