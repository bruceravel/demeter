#! /usr/bin/perl

use Test::More tests => 6;

use Ifeffit qw(ifeffit
	       get_scalar get_string get_array
	       put_scalar put_string put_array
	       get_echo);

$i = ifeffit( "x = 1.234500");
ok( ($i eq 0), "show");

my ($file, $type, $kweight)  = ("a.xmu", "xmu", 1);
my $read_data =<<"END";
              set (kmin = 0., kweight = $kweight, rbkg = 1.2)
              read_data(file = $file,  prefix = my, type = $type)
END

$i = ifeffit($read_data);
ok( ($i eq 0), "show arrays: ");

## -------- need to test get_echo
#Ifeffit::ifeffit("\&screen_echo = 0\n");
#ifeffit(" show  my.energy, my.xmu");
#my $str = get_echo();
#ok( (($str =~ m{my\.energy}) and ($str =~ m{my\.xmu})), "get_echo");

my $x = get_scalar("x");
ok( ($x == 1.2345), "get_scalar");

my $phi = put_scalar("phi", 1.605);
ok( (get_scalar("phi") == 1.605), 'put scalar');

put_string("\$filename", "my.xmu");
ok( get_string("filename") eq "my.xmu", "put/get_string: ");

for ($i = 0; $i< 5; $i++ ) { $z[$i] = sin($i * 799 + 99.111);}
$i =  put_array("my.test", \@z);

@arr = get_array("my.test");
$ok = ( ($arr[0] + 0.988646491563589 < 0.001) and
	($arr[1] + 0.375094695653461 < 0.001) and
	($arr[2] - 0.605955984630199 < 0.001) and
	($arr[3] - 0.993321521104809 < 0.001) and
	($arr[4] - 0.40748067780344  < 0.001) );
ok( $ok, "put/get_array:");
