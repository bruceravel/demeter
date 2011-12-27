package Demeter::Data::XDI;
use Moose::Role;
use File::Basename;

has 'xdi'                     => (is => 'rw', isa => 'Xray::XDI',
				  trigger => sub{my ($self, $new) = @_; $self->import_xdi($new);});

has 'xdi_version'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_applications'	      => (is => 'rw', isa => 'Str', default => q{});


has 'xdi_column'    => (metaclass => 'Collection::Hash',
			is        => 'rw',
			isa       => 'HashRef[Str]',
			default   => sub { {} },
			provides  => {
				      exists    => 'exists_in_xdi_column',
				      keys      => 'keys_in_xdi_column',
				      get       => 'get_xdi_column',
				      set       => 'set_xdi_column',
				     }
		       );
has 'xdi_scan'      => (metaclass => 'Collection::Hash',
			is        => 'rw',
			isa       => 'HashRef[Str]',
			default   => sub { {} },
			provides  => {
				      exists    => 'exists_in_xdi_scan',
				      keys      => 'keys_in_xdi_scan',
				      get       => 'get_xdi_scan',
				      set       => 'set_xdi_scan',
				     }
		       );
has 'xdi_mono'     => (metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[Str]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_xdi_mono',
				     keys      => 'keys_in_xdi_mono',
				     get       => 'get_xdi_mono',
				     set       => 'set_xdi_mono',
				    }
		      );
has 'xdi_beamline' => (metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[Str]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_xdi_beamline',
				     keys      => 'keys_in_xdi_beamline',
				     get       => 'get_xdi_beamline',
				     set       => 'set_xdi_beamline',
				    }
		      );
has 'xdi_facility' => (metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[Str]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_xdi_facility',
				     keys      => 'keys_in_xdi_facility',
				     get       => 'get_xdi_facility',
				     set       => 'set_xdi_facility',
				    }
		      );
has 'xdi_detector' => (metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[Str]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_xdi_detector',
				     keys      => 'keys_in_xdi_detector',
				     get       => 'get_xdi_detector',
				     set       => 'set_xdi_detector',
				    }
		      );
has 'xdi_sample'   => (metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[Str]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_xdi_sample',
				     keys      => 'keys_in_xdi_sample',
				     get       => 'get_xdi_sample',
				     set       => 'set_xdi_sample',
				    }
		      );


has 'xdi_extensions'   => (metaclass => 'Collection::Array',
			   is => 'rw', isa => 'ArrayRef[Str]',
			   default => sub{[]},
			   provides  => {
					 'push'  => 'push_xdi_extension',
					 'pop'   => 'pop_xdi_extension',
					 'clear' => 'clear_xdi_extensions',
					},
			  );

has 'xdi_comments'     => (
			   metaclass => 'Collection::Array',
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   provides  => {
					 'push'  => 'push_xdi_comment',
					 'pop'   => 'pop_xdi_comment',
					 'clear' => 'clear_xdi_comments',
					}
			  );
has 'xdi_labels'     => (
			   metaclass => 'Collection::Array',
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   provides  => {
					 'push'  => 'push_xdi_label',
					 'pop'   => 'pop_xdi_label',
					 'clear' => 'clear_xdi_labels',
					}
			  );

sub import_xdi {
  my ($self, $xdi) = @_;
  return $self if (ref($xdi) !~ m{XDI|Class::MOP});
  foreach my $f (qw(version applications
		    column scan mono beamline facility detector sample
		    extensions comments labels)) {
    my $att = 'xdi_' . $f;
    $self->$att($xdi->$f);
  };
  ## move data into Ifeffit arrays
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
  my $string = lc( join(" ", @{$xdi->labels}) );
  Ifeffit::put_string("column_label", $string);
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

sub configure_from_ini {
  my ($self, $inifile) = @_;
  return if not -e $inifile;
  return if not -r $inifile;
  tie my %ini, 'Config::IniFiles', ( -file => $inifile );
  foreach my $namespace (keys %ini) {
    next if ($namespace eq 'labels');
    foreach my $parameter (keys(%{$ini{$namespace}})) {
      my $method = "set_xdi_$namespace";
      $self->$method($parameter, $ini{$namespace}{$parameter});
    };
  };
  $self->labels([split(" ", $ini{labels}{labels})]) if exists $ini{labels};
};

1;


=head1 NAME

Demeter::Data::XDI - Import XDI objects into Demeter Data objects

=head1 VERSION

This documentation refers to Demeter version 0.5.

This is compliant with L<Xray::XDI> version 1.0.

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

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
