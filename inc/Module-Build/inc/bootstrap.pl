# bootstrap.pl
# bootstrap modules in inc/ for use during configuration with
# either Build.PL or Makefile.PL

my @exit_warn;

END {
  warn "\nThese additional prerequisites must be installed:\n  requires:\n"
    if @exit_warn;
  while( my $h = shift @exit_warn ) {
    my ($mod, $min) = @$h;
    warn "    ! $mod (we need version $min)\n";
  }
}

BEGIN {
  if ( ! eval "use Perl::OSType 1 (); 1" ) {
    print "*** BOOTSTRAPPING Perl::OSType ***\n";
    push @exit_warn, [ 'Perl::OSType', '1.00' ];
    delete $INC{'Perl/OSType.pm'};
    local @INC = @INC;
    push @INC, 'inc';
    eval "require Perl::OSType; 1"
      or die "BOOSTRAP FAIL: $@";
  }
  if ( ! eval "use version 0.87 (); 1" ) {
    print "*** BOOTSTRAPPING version ***\n";
    push @exit_warn, [ 'version', '0.87' ];
    delete $INC{'version.pm'};
    local @INC = @INC;
    push @INC, 'inc';
    eval "require MBVersion; 1"
      or die "BOOSTRAP FAIL: $@";
  }
  if ( ! eval "use Module::Metadata 1.000002 (); 1" ) {
    print "*** BOOTSTRAPPING Module::Metadata ***\n";
    push @exit_warn, [ 'Module::Metadata', '1.000002' ];
    delete $INC{'Module/Metadata.pm'};
    local @INC = @INC;
    push @INC, 'inc';
    eval "require Module::Metadata; 1"
      or die "BOOSTRAP FAIL: $@";
  }
}

1;

