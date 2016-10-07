package LarchServer;

use strict;
use warnings;
use File::Spec;
use Time::HiRes qw(usleep);

use XMLRPC::Lite;

use vars qw($larch_is_go $larch_port $larch_exe);
$larch_is_go = 0;
$larch_port = 4966;
$larch_exe  = '';

######################################################################
## ----- configure and start the Larch server
######################################################################

sub find_larch {
  # search for Python exe and larch_server script,
  # return command to run larch server
  my $larchexec  = '';
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
  foreach my $d (@dirlist) {
    my $pyexe_ =  File::Spec->catfile($d, $python_exe);
    my $larch_ =  File::Spec->catfile($d, $pyscript_dir, 'larch_server');
    if ((-e $pyexe_) && (-e $larch_))  {
      $larchexec = "$pyexe_ $larch_";
      last;
    }
  }
  return $larchexec;
};


# test whether a host/port is a running larch server
sub test_larch_server {
  my ($host, $tport) = @_;
  usleep(50000);
  my $addr = sprintf("http://%s:%d", $host, $tport);
  my $server = XMLRPC::Lite -> proxy($addr);
  eval{$server->get_rawdata('_sys.config.user_larchdir')};
  return $@;
};

# find and return the next unused larch port,
# given a host and starting port number.
# this will avoid multiple clients using the same port
sub get_next_larch_port {
    my ($host, $port_start) = @_;
    for (my $i=0; $i<250; $i++) {
      my $thisport = $port_start + $i;
	if (test_larch_server($host, $thisport)) {
	    return $thisport;
	  }
    }
    return -1;
}

## look for python + larch_server
my $larch_exe = find_larch();

## If we found larch_server, start it
if (length $larch_exe > 16) {
  # find next available port to run on
  $larch_port  = get_next_larch_port('localhost', $larch_port);
  if ($larch_port > 1) {
    $larch_is_go = 1;
    my $command = $larch_exe." -p ". $larch_port." start";
    if (lc($^O) eq 'darwin') {$command = "$command &";}

    print STDOUT "Starting Larch server:  $command\n";
    my $ok = system $command;
    # wait until we can connnect to it...
    usleep(50000);
    for (my $i=0; $i<50; $i++) {
      if (!test_larch_server('localhost', $larch_port)) {
	last;
      }
    }
  }
} else {
  print STDOUT "Could not find Larch Server\n";
  $larch_is_go = 0;
}

$larch_is_go;

END {
  my $command = "$larch_exe  -p  $larch_port stop";
  if (lc($^O) eq 'darwin') {$command = "$command &";}
  my $ok = system $command;
}

__END__

=head1 NAME

LarchServer - Perl interface to Larch Server

=head1 SYNOPSIS

Importing LarchServer with

  use LarchServer;

will create and start a Larch server.

=head1 DESCRIPTION

This provides a perl interface to a Larch Server, ready to be sent Larch
commands from a Larch client (see Larch.pm).

It looks for and starts a Larch Server for XML-RPC coommunication on a
particular port (typically 4966 or higher).  It provides three variables to
report server configuration:

=over 4

==item C<larch_is_go>

this is set to 0 if a Larch Server could not be found or started.
It is set to 1 if a Larch Server was started.

==item C<larch_port>

this is the port number created by importing Larch Server.  It will
be a previously unused port.

==item C<larch_exe>

this is the full name of the executable used to start the server.  The
system command used to start the Larch server will be

   $larch_exe -p $larch_port start &

and will be ready for a XML-RPC client at the uri of

    http://localhost:$larch_port

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

L<Larch>, L<Demeter::Get>, L<Ifeffit>

=cut
