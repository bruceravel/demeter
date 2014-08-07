package Demeter::Data::XDI;
use Moose::Role;
use MooseX::Aliases;
use File::Basename;
use Demeter::IniReader;
use Demeter::StrTypes qw( Empty );
use List::MoreUtils qw(zip);

if ($INC{'Xray/XDI.pm'}) {
  has xdifile => (is => 'rw', isa => 'Str', default=>q{},
		  trigger => sub{my ($self, $new) = @_; $self->_import_xdi($new);});
  has xdi     => (is => 'rw', isa => Empty.'|Xray::XDI', default=>q{},);
} else {
  has xdifile => (is => 'ro', isa => 'Str', default=>q{},);
  has xdi     => (is => 'ro', isa => 'Str', default=>q{},);
};

sub xdi_allattributes {
  my ($self) = @_;
  return [qw(ok warning errorcode error filename xdi_libversion xdi_version
	     extra_version element edge dspacing comments nmetadata npts
	     narrays narray_labels array_labels array_units metadata data)];
};


sub _import_xdi {
  my ($self, $xdifile) = @_;
  return $self if not $INC{'Xray/XDI.pm'};
  return $self if not -e $xdifile;
  my $xdi   = Xray::XDI->new;
  $xdi  -> file($xdifile);
  $self -> xdi($xdi);
  return $self;
};


##### metadata ########################################

sub xdi_families {
  my ($self) = @_;
  return () if ((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi)));
  return sort keys %{$self->xdi->metadata};
};
alias xdi_namespaces => 'xdi_families';

sub xdi_keys {
  my ($self, $family) = @_;
  return () if ((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi)));
  return () if not defined $self->xdi->metadata->{$family};
  return sort keys %{$self->xdi->metadata->{$family}};
};
alias xdi_keywords => 'xdi_keys';
alias xdi_tags => 'xdi_keys';


sub xdi_datum {
  my ($self, $family, $key) = @_;
  return q{} if ((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi)));
  return "family $family does not exist"      if not defined $self->xdi->metadata->{$family};
  return "key $key does not exist in $family" if not defined $self->xdi->metadata->{$family}->{$key};
  return $self->xdi->metadata->{$family}->{$key};
};
alias xdi_item => 'xdi_datum';

sub xdi_metadata {
  my ($self) = @_;
  return () if ((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi)));
  return %{$self->xdi->metadata};
};


sub xdi_set_columns {
  my ($self, $hash) = @_;
  my $metadata = $self->xdi->metadata;
  $metadata->{Column} = $hash;
  $self->xdi->metadata($metadata);
  return $self;
};


##### data table ######################################

sub xdi_data {
  my ($self) = @_;
  return () if ((((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi))) or (not $self->xdi)));
  return %{$self->xdi->{data}};
};

sub xdi_get_array {
  my ($self, $label) = @_;
  my $i = 0;
  foreach my $lab ($self->xdi->array_labels) {
    last if (lc($label) eq lc($lab));
    ++$i;
  };
  return () if not $self->xdi->data->{$label};
  return @{$self->xdi->data->{$label}};
};
sub xdi_get_iarray {
  my ($self, $i) = @_;
  return () if ($i > $self->xdi->narrays);
  return () if ($i < 1);
  return @{$self->xdi->data->{$self->xdi->array_labels->[$i-1]}};
};



##### Moosish attributes ##############################

sub xdi_attribute {
  my ($self, @which) = @_;
  return () if ((not ($INC{'Xray/XDI.pm'}) or (not $self->xdi)));
  my $regex = join("|",@{$self->xdi_allattributes});
  if (wantarray) {
    my @list = map {($_ =~ m{$regex}o) ? $self->xdi->$_ : q{}} @which;
    return @list;
  } else {
    my $att = $which[0];
    return $self->xdi->$att || q{};
  };
};
alias xdi_attributes => 'xdi_attribute';





sub metadata_from_ini {
  my ($self, $inifile) = @_;
  return $self if not exists($INC{'Xray/XDI.pm'});
  return if not -e $inifile;
  return if not -r $inifile;
  $self->xdi(Xray::XDI->new()) if (not $self->xdi);
  my $ini = Demeter::IniReader->read_file($inifile);
  #tie my %ini, 'Config::IniFiles', ( -file => $inifile );
  foreach my $namespace (keys %$ini) {
    next if ($namespace eq 'labels');
    foreach my $parameter (keys(%{$ini->{$namespace}})) {
      $self->xdi->set_item(ucfirst($namespace), $parameter, $ini->{$namespace}{$parameter});
    };
  };
  $self->labels([split(" ", $ini->{labels}{labels})]) if exists $ini->{labels};
};

# sub xdi_defined {
#   my ($self, $cc) = @_;
#   return $self if not ($INC{'Xray/XDI.pm'});
#   $cc ||= q{};
#   $cc .= " " if ($cc and ($cc !~ m{ \z}));
#   my $text = q{};
#   foreach my $namespace (qw(beamline scan mono facility detector sample)) {
#     my $method = 'xdi_'.$namespace;
#     next if ($self->$method =~ m{\A\s*\z});
#     foreach my $k (sort keys %{$self->$method}) {
#       $text .= sprintf "%s%s.%s: %s$/", $cc, ucfirst($namespace), $k, $self->$method->{$k};
#     };
#   };
#   return $text;
# };

##### utilities #######################################

sub xdi_output_header {
  my ($self, $datafit, $text) = @_;

  $self->clear_ifeffit_titles('dem_data');
  my $apps   = join(" ", "XDI/1.0", $self->data->xdi_attribute('extra_version'), "Athena/$Demeter::VERSION");
  my $report = q{};
  if ($datafit eq 'xdi') {
    foreach my $f ('Element', 'Column') {
      foreach my $t ($self->data->xdi_keys($f)) {
	$report .= sprintf("%-30s %s\n", $f . '.' . $t . ': ',  $self->data->xdi->get_item($f, $t));
      };
    };
  } elsif ($datafit eq 'fit') {
    $report = $self->data->fit_parameter_report;
  } else {
    $report = $self->data->data_parameter_report;
  };
  my $xdic   = $self->data->xdi_attribute('comments') || q{};
  my @blank  = ($xdic =~ m{\A\s*\z}) ? () : ($/);
  @blank     = () if $text =~ m{\A\s*\z};

  my @all = ($apps,		   # version line
	     split(/\n/, $report), # XDI + Athena metadata
	     "///",
	     split(/\n/, $xdic),   # XDI comments
	     @blank,
	     split(/\n/, $text)	   # output specific text
	    );

  $self->header_strings(@all);	   # see Demeter::Get
  return $self;
};



1;


=head1 NAME

Demeter::Data::XDI - Import XDI objects into Demeter Data objects

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

This is compliant with L<Xray::XDI> 1.0.

=head1 SYNOPSIS

Demeter wrapper around L<Xray::XDI>, also providing fallback
functionality when L<Xray::XDI> is not available.

=head1 METHODS

=over 4

=item C<_import_xdi>

Called when the C<xdifile> attribute is set.  Associates an Xray::XDI
object with a Demeter::Data object.

  $data  = Demeter::Data->new;
  $data -> xdifile($file);

=item C<xdi_output_header>

Organize all the various forms of metadata and comments into a
sensible header for an XDI file written be either Ifeffit or Larch.

=back

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
