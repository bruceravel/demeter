package Demeter::Data::XDI;
use Moose::Role;
use File::Basename;
use Demeter::IniReader;
use Demeter::StrTypes qw( Empty );
use List::MoreUtils qw(zip);

if ($INC{'Xray/XDI.pm'}) {
  has 'xdi' => (is => 'rw', isa => Empty.'|Xray::XDI', default=>q{},
		trigger => sub{my ($self, $new) = @_; $self->import_xdi($new);});
} else {
  has 'xdi' => (is => 'ro', isa => 'Str', default=>q{},);
};

has 'xdi_version'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_applications'	      => (is => 'rw', isa => 'Str', default => q{});


has 'xdi_column'    => (traits    => ['Hash'],
			is        => 'rw',
			isa       => 'HashRef',
			default   => sub { {} },
			handles   => {
				      'exists_in_xdi_column'   => 'exists',
				      'keys_in_xdi_column'     => 'keys',
				      'get_xdi_column'         => 'get',
				      'set_xdi_column'         => 'set',
				      'delete_from_xdi_column' => 'delete'
				     }
		       );
has 'xdi_scan'      => (traits    => ['Hash'],
			is        => 'rw',
			isa       => 'HashRef',
			default   => sub { {} },
			handles   => {
				      'exists_in_xdi_scan'   => 'exists',
				      'keys_in_xdi_scan'     => 'keys',
				      'get_xdi_scan'         => 'get',
				      'set_xdi_scan'         => 'set',
				      'delete_from_xdi_scan' => 'delete'
				     }
		       );
has 'xdi_mono'     => (traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_xdi_mono'   => 'exists',
				     'keys_in_xdi_mono'     => 'keys',
				     'get_xdi_mono'         => 'get',
				     'set_xdi_mono'         => 'set',
				     'delete_from_xdi_mono' => 'delete'
				    }
		      );
has 'xdi_beamline' => (traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_xdi_beamline'   => 'exists',
				     'keys_in_xdi_beamline'     => 'keys',
				     'get_xdi_beamline'         => 'get',
				     'set_xdi_beamline'         => 'set',
				     'delete_from_xdi_beamline' => 'delete'
				    }
		      );
has 'xdi_facility' => (traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_xdi_facility'   => 'exists',
				     'keys_in_xdi_facility'     => 'keys',
				     'get_xdi_facility'         => 'get',
				     'set_xdi_facility'         => 'set',
				     'delete_from_xdi_facility' => 'delete'
				    }
		      );
has 'xdi_detector' => (traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_xdi_detector'   => 'exists',
				     'keys_in_xdi_detector'     => 'keys',
				     'get_xdi_detector'         => 'get',
				     'set_xdi_detector'         => 'set',
				     'delete_from_xdi_detector' => 'delete'
				    }
		      );
has 'xdi_sample'   => (traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_xdi_sample'   => 'exists',
				     'keys_in_xdi_sample'     => 'keys',
				     'get_xdi_sample'         => 'get',
				     'set_xdi_sample'         => 'set',
				     'delete_from_xdi_sample' => 'delete'
				    }
		      );


has 'xdi_extensions'   => (traits    => ['Array'],
			   is => 'rw', isa => 'ArrayRef[Str]',
			   default => sub{[]},
			   handles   => {
					 'push_xdi_extension'  => 'push',
					 'pop_xdi_extension'   => 'pop',
					 'clear_xdi_extensions' => 'clear',
					},
			  );

has 'xdi_comments'     => (
			   traits    => ['Array'],
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   handles   => {
					 'push_xdi_comment'  => 'push',
					 'pop_xdi_comment'   => 'pop',
					 'clear_xdi_comments' => 'clear',
					}
			  );
has 'xdi_labels'     => (
			   traits    => ['Array'],
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   handles   => {
					 'push_xdi_label'  => 'push',
					 'pop_xdi_label'   => 'pop',
					 'clear_xdi_labels' => 'clear',
					}
			  );

sub import_xdi {
  my ($self, $xdi) = @_;
  return $self if not ($INC{'Xray/XDI.pm'});
  return $self if (ref($xdi) !~ m{XDI|Class::MOP|Moose::Meta::Class});
  foreach my $f (qw(version applications
		    column scan mono beamline facility detector sample
		    extensions comments labels)) {
    my $att = 'xdi_' . $f;
    $self->$att($xdi->$f);
  };
  ## move data into backend (Ifeffit/Larch) arrays
  my $ncol = $#{$xdi->labels};
  my $npts = $#{$xdi->data};
  my $data = $xdi->data;
  my $transposed = [];
  foreach my $i (0 .. $npts) {
    foreach my $j (0 .. $ncol) {
      $transposed->[$j]->[$i] = $data->[$i]->[$j]
    };
  };
  #use Data::Dumper;
  #print Data::Dumper->Dump([$transposed], [qw(*transposed)]);
  foreach my $i (0 .. $ncol) {
    $self->put_array($xdi->labels->[$i], $transposed->[$i]);
  };

  ## process the data in the manner of Demeter::Data::read_data
  $self->place_scalar("e0", 0);
  my $string = lc( join(" ", @{$xdi->labels}) );
  $self->place_string("column_label", $string);
  $self->columns(join(" ", $string));
  $self->provenance("XDI file ".$self->file);
  $self->is_col(1);
  $self->file($xdi->file);
  $self->update_data(0);
  $self->update_columns(0);
  $self->update_norm(1);
  $self->sort_data;
  $self->put_data;
  $self->resolve_defaults;

  my @x = $self->get_array('energy'); # set things for about dialog
  return $self if not @x;
  $self->npts($#x+1);
  $self->xmin($x[0]);
  $self->xmax($x[$#x]);
  $self->name(basename($self->file));
  return $self;

  ## use math expressions for making spectra
};

sub metadata_from_ini {
  my ($self, $inifile) = @_;
  return $self if not ($INC{'Xray/XDI.pm'});
  return if not -e $inifile;
  return if not -r $inifile;
  my $ini = Demeter::IniReader->read_file($inifile);
  #tie my %ini, 'Config::IniFiles', ( -file => $inifile );
  foreach my $namespace (keys %$ini) {
    next if ($namespace eq 'labels');
    foreach my $parameter (keys(%{$ini->{$namespace}})) {
      my $method = "set_xdi_$namespace";
      $self->$method($parameter, $ini->{$namespace}{$parameter});
    };
  };
  $self->labels([split(" ", $ini->{labels}{labels})]) if exists $ini->{labels};
};

sub xdi_defined {
  my ($self, $cc) = @_;
  return $self if not ($INC{'Xray/XDI.pm'});
  $cc ||= q{};
  $cc .= " " if ($cc and ($cc !~ m{ \z}));
  my $text = q{};
  foreach my $namespace (qw(beamline scan mono facility detector sample)) {
    my $method = 'xdi_'.$namespace;
    next if ($self->$method =~ m{\A\s*\z});
    foreach my $k (sort keys %{$self->$method}) {
      $text .= sprintf "%s%s.%s: %s$/", $cc, ucfirst($namespace), $k, $self->$method->{$k};
    };
  };
  return $text;
};

sub metadata {
  my ($self) = @_;
  my @keys = qw(xdi_version xdi_applications xdi_comments xdi_scan xdi_mono
		xdi_beamline xdi_facility xdi_detector xdi_sample xdi_extensions
		xdi_comments xdi_labels);
  my @values = $self->get(@keys);
  return zip @keys, @values;
};

1;


=head1 NAME

Demeter::Data::XDI - Import XDI objects into Demeter Data objects

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

This is compliant with L<Xray::XDI> 1.0.

=head1 METHODS

=over 4

=item C<import_xdi>

Turn an Xray::XDI object into a Demeter::Data object.

  $data  = Demeter::Data->new;
  $xdi   = Xray::XDI->new;
  $xdi  -> file($file);
  $data -> import_xdi($xdi);

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
