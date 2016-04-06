package Larch;

use strict;
use warnings;
use Cwd;
use Demeter::Here;
use File::Spec;
use Time::HiRes qw(usleep);
use YAML::Tiny;


######################################################################
## ----- configure and start the Larch server
######################################################################
my $ini = File::Spec->catfile(Demeter->dot_folder, "larch_server.yaml");
$ini = File::Spec->catfile(Demeter::Here::here, 'share', 'ini', 'larch_server.ini') if (not -e ini);
my $rhash;
eval {local $SIG{__DIE__} = sub {}; $rhash = YAML::Tiny::LoadFile($ini)};
#print join("|", %$rhash), $/;

$rhash->{server}  ||= 'localhost';
$rhash->{port}    ||= 4966;
$rhash->{proxy}     = sprintf("http://%s:%d", $rhash->{server}, $rhash->{port});
$rhash->{timeout} ||= 3;
$rhash->{quiet}   ||= 0;
$rhash->{exe}       = (($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? $rhash->{windows} : 'larch_server';

my $command = $rhash->{quiet} ? $rhash->{exe}." -q start" : $rhash->{exe}." start";
my $ok = system $command;


######################################################################
## ----- contact the Larch server, trying repeatedly until contact is
##       established, eventually failing if contact cannot be made
######################################################################
use XMLRPC::Lite;
our $client;
$client = XMLRPC::Lite -> proxy($rhash->{proxy});
our $rpcdata;

use vars qw($larch_is_go);
$larch_is_go = 1;

eval {$client->larch(q{cd('} . cwd . q{')})};
my $count = 0;
while ($count < $rhash->{timeout}*5) {
  $larch_is_go = 0 if $@;
  eval {$client->larch(q{cd('} . cwd . q{')})};
  if (not $rhash->{quiet}) {print $@, $/};
  $larch_is_go = 1, last if not $@;
  ++$count;
  usleep(200000);
};

######################################################################
## ----- send a string to the server
######################################################################
sub dispose {
  my ($text) = @_;
  $rpcdata = $client -> larch($text);
  return $rpcdata;
};

sub get_messages {
  $rpcdata = $client -> get_messages();
  return $rpcdata->result;
};

######################################################################
## ----- put and get scalars and lists from the server
######################################################################

sub get_larch_array {
  my ($param) = @_;
  #Demeter->trace;
  #$rpcdata = $client -> get_data('_main.'.$param);

  $rpcdata = $client -> get_data($param);

  ## this is a mess and mixes cases relevant to the time before and after
  ## https://github.com/xraypy/xraylarch/issues/99
  return () if (not defined($rpcdata->result));
  if (ref($rpcdata->result) eq 'HASH') {
    my $ret = $rpcdata->result->{value};
    if ($param =~ m{correl}) {
      my %hash = %{$rpcdata->result};
      delete $hash{__class__};
      my @ret = %hash;
      return @ret;
    } elsif (ref($ret) eq 'ARRAY') {
      return @$ret;
    } elsif (not $ret) {
      return ();
    } else {
      return @{eval $ret};
    };
  } elsif ($rpcdata->result =~ m{\A\{}) {
    ## if the RPC client returns a stringification of a python
    ## dictionary.  the following converts that to a hash
    ## serialization, evals it into a hash, then returns it as an
    ## hash.  sigh....
    my $hash = $rpcdata->result;
    $hash =~ s{:}{=>}g;
    #print $hash, $/;
    $hash = eval $hash;
    #print $hash, $/;
    return %$hash;
    #return @{$hash->{value}};
  } else {
    my $ret = eval $rpcdata->result;
    return () if not $ret;
    #Demeter->trace;
    #print '>>>>>', ref($ret), $/;
    if (ref($ret) eq 'ARRAY') {
      return @$ret;
    # } elsif ($ret =~ m{\(array\(}) {
    #   $ret =~ s{\(array\(}{};
    #   chop($ret); chop($ret); chop($ret);
    #   $ret = eval($ret);
    #   return @$ret;
    } else {
      return ();
    }
  };
  #or not (defined($rpcdata->result->{value})));
};

sub put_larch_array {
  my ($param, $aref) = @_;
  my $value = '[' . join(',', @$aref) . ']';
  return dispose("$param = array($value, dtype=float64)");
};




sub get_larch_scalar {
  my ($param) = @_;
  $rpcdata = $client -> get_data($param);
  my $res = $rpcdata->result;

  #if ($param =~ m{demlcf}) {
  #  print $param, $/;
  #  print $res, $/;
  #};

  if (not defined($res)) {
    return 0;
  } elsif (ref($res) eq 'HASH') {
    $res = $res->{value};
    #print $res, $/;
  } elsif ($rpcdata->result =~ m{\A\{}) {
    ## the RPC client returns a stringification of a python
    ## dictionary.  the following converts that to a hash
    ## serialization, evals it into a hash, then returns it as an
    ## array.  sigh....
    my $hash = $rpcdata->result;
    $hash =~ s{:}{=>}g;
    $hash = eval $hash;
    if (defined $hash->{value}) {
      return $hash->{value};
    } else {
      return 0;
    };
  } else {
    #print "------------- $param ", $res, $/;
    $res =~ s{(\A\"|\"\z)}{}g;
  };
  return $res;
};

sub put_larch_scalar {
  my ($param, $value) = @_;
  return dispose("$param = $value");
};

1;

__END__

=head1 NAME

Larch - Perl interface to Larch

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides a perl interface to accessing data structures in Larch
and sending command strings to Larch via an XML-RPC framework.

=over 4

=item C<dispose>

Send a text string to the server for interpretation by Larch.

=item C<get_larch_scalar>

Fetch the value of a Larch scalar given a symbol.  This can be a
number or a string.  Care is taken not return 0 rather than a null
value.

=item C<put_larch_scalar>

Push a scalar to Larch given a symbol name.

=item C<get_larch_array>

Fetch the value of a Larch list given a symbol.  In fact, this can
fetch any kind of collection, including a numpy array.

=item C<put_larch_array>

Push a list to Larch given a symbol name.

=back

=head1 CONFIGURATION

See the file F<lib/Demeter/share/ini/larch_server.ini>.  The URL and
port used by the server can be configured, as can the length of the
timeout and the on-screen verbosity of the server.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

Larch is copyright (c) 2016, Matthew Newville and Tom Trainor

=head1 SEE ALSO

L<Demeter::Get>, L<Ifeffit>

=cut
