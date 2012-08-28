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

#[Run]
#Filename: "{tmp}\ModifyAutoexec.exe"; Parameters: """{app}"""

my $app = $ARGV[0] || 'C:\strawberry';
my $target = catfile($app, 'perl', 'site', 'bin');
my $perlexe = catfile($app, 'perl', 'bin', 'perl.exe');

print "Modifying bat files to explicitly call $perlexe\n";
print "\t\{app\} = $app\n";
print "\ttarget = $target\n";;

foreach my $b (@bats) {
  my $batfile = catfile($target, $b.'.bat');
  print "Modifying $batfile\n";

  #-- modify all ocurrences of 'HowTo' to 'how to'
  tie @lines, 'Tie::File', $batfile or die "Can't read file: $!\n";
  foreach ( @lines ) {
    s{\Aperl -x}{$perlexe -x}g;
  }
  untie @lines;
};
