@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
%~dp0perl\bin\perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
%~dp0perl\bin\perl -x -S %0 %*
goto endofperl
@rem ';
#!perl

use Tie::File;
use File::Spec::Functions;
local $| = 1;

my @bats = qw(dathena dartemis datoms dhephaestus denergy denv
	      dfeff dfeffit dlsprj rdfit intrp standards);
#my @bats = "dathena";

my $app = $ARGV[0] || 'C:\strawberry';
my $target = catfile($app, 'perl', 'site', 'bin');

my (@not, @mingw);
foreach my $folder (split(/;/, $ENV{PATH})) {
  if ($folder =~ m{mingw}i) { push @mingw, $folder } else { push @not, $folder };
};
if (not @mingw) {
  print "Skipping ... no need to reorder PATH variable\n";
  exit;
};

my $reordered = join(";", @not, @mingw);

print "Modifying bat files to reorder PATH variable\n";

foreach my $b (@bats) {
  my $batfile = catfile($target, $b.'.bat');
  print "Modifying $batfile\n";

  tie @lines, 'Tie::File', $batfile or die "Can't read file: $!\n";
  my $n = 0;
  foreach ( @lines ) {
    last if ($_ =~ m{\A\@echo off});
    ++$n;
  }
  splice @lines, $n+1, 0, "SET PATH=$reordered";
  untie @lines;
};
