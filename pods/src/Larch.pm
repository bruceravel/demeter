package Larch;

# require Exporter;
# @ISA = qw(Exporter);
# @EXPORT_OK = qw(dispose larch decode_data get_data get_messages
# 		get_larch_scalar put_larch_scalar
# 		get_larch_array put_larch_array
# 		create_larch_connection shutdown_larch_connection
# 		get_client_info set_client_info run_selftest);

use strict;
use warnings;
use Cwd;
use Demeter::Here;
use File::Which qw(which);
use RPC::XML::Client;
use Time::HiRes qw(usleep);

use Proc::Background;

use vars qw($larch_is_go $larchconn $larch_exe $larch_port);
$larch_exe = q{};

sub find_larch {
  # search for Python exe and larch_server script,
  # return command to run larch server
  my $osname = lc($^O);
  my $python_exe = "python";
  my $pyscript_dir = "";
  my @dirlist ;
  if (($osname eq 'mswin32') or ($osname eq 'cygwin')) {
    @dirlist = split /;/, $ENV{'PATH'};
    push @dirlist,  (File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda3'),
		     File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda2'),
		     File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda'),
		     File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda3'),
		     File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda2'),
		     File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda'),
		     'C:\Python27', 'C:\Python35');
    $python_exe = "python.exe";
    $pyscript_dir = "Scripts";
  } else {
    @dirlist = split /:/, $ENV{'PATH'};
    push @dirlist,  (File::Spec->catfile($ENV{HOME}, 'anaconda3', 'bin'),
		     File::Spec->catfile($ENV{HOME}, 'anaconda2', 'bin'),
		     File::Spec->catfile($ENV{HOME}, 'anaconda', 'bin'));

  }
  my $pyexe_ = which($python_exe);
  my $larch_ = which("larch_server");
  if (defined($pyexe_) && (-e $pyexe_) && defined($larch_) && (-e $larch_))  {
    $larch_exe = "$pyexe_ $larch_";
    return $larch_exe;
  }
  foreach my $d (@dirlist) {
    my $pyexe_ =  File::Spec->catfile($d, $python_exe);
    my $larch_ =  File::Spec->catfile($d, $pyscript_dir, 'larch_server');
    if ((-e $pyexe_) && (-e $larch_))  {
      $larch_exe = "$pyexe_ $larch_";
      last;
    }
  }
  return $larch_exe;
};

# find and return the next unused larch port, given executable
# (only works on local host...)
# this will avoid multiple clients using the same port
sub get_next_larch_port {
  # find next available port to run on
  my ($lexe) = @_;
  my $s = `$lexe -n`;
  $s =~ s/[^\d.]/ /g ;
  my @w = split /\s+/, $s;
  return $w[-1];
};

our $proc;
sub start_larch_server {
  $larch_port = -1;
  $larch_exe = find_larch();
  if (length $larch_exe > 10) {
    # find next available port to run on
    # print STDOUT "Larch exe $larch_exe\n";
    $larch_port = get_next_larch_port($larch_exe);
    # print STDOUT "Larch port $larch_port\n";
    if ($larch_port > 2000) {
      my $command = $larch_exe." -p ". $larch_port." start";
      print STDOUT "\nStarting Larch server: $command\n";
      $proc = system $command;
      # verify connnection to server
      my $addr = sprintf("http://%s:%d", 'localhost', $larch_port);
      my $conn = RPC::XML::Client->new($addr);
      usleep(250000);
      for (my $i=0; $i<20; $i++) {
	if ($conn->simple_request('system.listMethods')) {
	  my $m = $conn->simple_request('system.listMethods');
	  last;
	}
	usleep(250000);
      }
    }
  } else {
    print STDOUT "\nCould not find Larch Server";
  }
  return $larch_port;
};


sub create_larch_connection {
  $larch_port = start_larch_server();
  return $larch_port if ($larch_port < 0);
  sleep(1);

  my $addr = sprintf("http://127.0.0.1:%d", $larch_port);
  $larchconn = RPC::XML::Client->new($addr);
  $larchconn->send_request("larch", "cd('".cwd."')");
  $larch_is_go = 1;
  return $larchconn;
};

sub shutdown_larch_connection {
  print "Request Server to shut down\n";
  $larchconn->send_request("shutdown");
};

sub dispose {
  my ($text) = @_;
  return $larchconn->send_request("larch", $text);
};

sub larch {
  my ($text) = @_;
  return $larchconn->send_request("larch", $text);
};

sub decode_data {
  my ($dat) = @_;
  #my %dat;
  # print("DECODE: ", ref($dat), "\n");
  if (ref($dat) eq 'ARRAY') {
    return @$dat;
  } elsif (ref($dat) eq 'RPC::XML::nil') {
    return undef;
  } elsif (ref($dat) eq 'RPC::XML::string') {
    return $$dat;
  } elsif (ref($dat) eq 'RPC::XML::double') {
    return $$dat;
  } elsif (ref($dat) eq 'RPC::XML::struct') {
    my $class = $dat->{__class__};
    #print "STRUCT CLass " , $$class, "\n";
    if ($$class eq "HASH") {
      return %$dat;
    } elsif ($$class eq "Array"){
      my $value = $dat->{value};
      my $dtype = $dat->{__dtype__}->value;
      my $shape = @{$dat->{__shape__}->value};
      return $value->value;
    } elsif (($$class eq "List") or
	     ($$class eq "Tuple") or
	     ($$class eq "Complex")) {
      my $value = $dat->{value};
      # print "LIST/TUPLE ", $value, $value->value, "\n";
      return $value->value;
    } elsif (($$class eq "Dict") or
	     ($$class eq "Group")) {
      my %out;
      foreach my $key (keys %$dat) {
	if ($key ne '__class__') {
	  $out{$key} =  decode_data($$dat{$key});
	}
      }
      return \%out;
    } else {
      print "cannot decode data, unknown structure class: $$class \n";
    }
  } else {
    return $dat; # print "cannot decode data, unknown data type: ref($dat) \n";
  }
}

sub get_messages {
  return decode_data($larchconn->send_request("get_messages"));
};

sub set_client_info {
  my ($key, $val) = @_;
  return $larchconn->send_request("set_client_info", $key, $val);
};

sub get_client_info {
  my ($key, $val) = @_;
  return $larchconn->send_request("get_client_info");
};

sub get_data {
  my ($param) = @_;
  return $larchconn->send_request("get_data", $param);
};

sub get_larch_scalar {
  my ($param) = @_;
  return decode_data(get_data($param));
};

sub put_larch_scalar {
  my ($param, $value) = @_;
  return dispose("$param = $value");
};

sub get_larch_array {
  my ($param) = @_;
  my $tmp = decode_data(get_data($param));
  if (defined $tmp) {
    return @{$tmp} if ref($tmp) eq 'ARRAY';
    return %{$tmp} if ref($tmp) eq 'HASH';
  };
  return ();
};

sub put_larch_array {
  my ($param, $aref) = @_;
  return q{} if ($#{$aref} < 1);
  my $value = '[' . join(',', @$aref) . ']';
  return dispose("$param = array($value, dtype=float64)");
};

sub run_selftest {
  my $max_outerloop = 20;
  my $max_innerloop = 20;
  my @messages;
  my @array;
  my $ret;
  for (my $loop=0; $loop<$max_outerloop; $loop++) {
    print "# Simple Array Creation: loop: $loop / $max_outerloop \n";

    for (my $i=0; $i<$max_innerloop; $i++) {
      dispose("x$i =  linspace(0, $i+1, 11)");
      select(undef, undef, undef, 0.0005);
      if ($i % 5 == 0) {
	dispose("print 'hello $i ".localtime."' ");
	@messages = get_messages();
	print "Message # ", @messages;
      }
    }
    print "# Read XAFS Data, run autobk with different inputs\n";
    for (my $i=0; $i<$max_innerloop; $i++) {
      print "--> LOOP ($loop, $i) / ($max_outerloop, $max_innerloop)\n";
      my $rbkg = 0.5 + $i/(1.0*$max_innerloop);
      dispose("fc$i = read_ascii('fe3c_rt.xdi')");
      dispose("fc$i.mu = fc$i.mutrans");
      dispose("autobk(fc$i, rbkg=$rbkg)");

      @array = get_larch_array("fc$i.column_labels");
      print "Column Labels: ", join(', ', @array), "\n";

      @array = get_larch_array("fc$i.chi[:5]");
      print "Chi(k): ", join(', ', @array), "\n";
      dispose("show(fc$i)");
      #dispose("show(fc$i.autobk_details)");
      @messages = get_messages();
      print "Messages:\n ", @messages, "\n";
    }
  }
};


## if there is not already a connection,
## start server on next port create connection to it

if (!$larchconn) {
  create_larch_connection();
}

END {
  #my $action = ($ENV{DEMETER_LARCH_PERSIST}) ? 'status' : 'stop';
  system "$larch_exe -p $larch_port stop";
}

$larch_is_go;

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

=item C<shutdown_server>

stop the Larch Server.

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

Larch is copyright (c) 2017, Matthew Newville and Tom Trainor

=head1 SEE ALSO

L<Demeter::Get>, L<Ifeffit>

=cut
