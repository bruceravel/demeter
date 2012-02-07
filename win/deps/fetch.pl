#!/usr/bin/perl
######################################################################
## http://deps.cpantesters.org/?xml=1;module=Moose;perl=5.12.2;os=any%20OS;pureperl=0';
######################################################################

use strict;
use warnings;

use LWP::UserAgent;
use Term::Sk 0.07;

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy;

my $perl_version = '5.12.2';
my @missing;

my $counter = Term::Sk->new('fetching %k  (#%c) %8t', {base => 0, token=>'autodie'})
  or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";

foreach my $xml (<DATA>) {
  chomp $xml;
  $counter->token($xml);
  my $url = 'http://deps.cpantesters.org/?xml=1;module=' . $xml . ';perl=' . $perl_version . ';os=any%20OS;pureperl=0';
  my $response = $ua->get($url);
  my $out = $xml . '.xml';
  if ($response->is_success) {
    open(my $O, '>', $out);
    print $O $response->decoded_content;
    close $0;
  } else {
    push @missing, $xml;
    next;
  };
};
$counter->close;

rename('Wx.xml', 'zzzWx.xml') if (-e 'Wx.xml');

if (@missing) {
  print "Timed out: ", join(', ', @missing), $/;
} else {
  print "All done!\n";
};

__DATA__
Archive::Zip
Capture::Tiny
Chemistry::Elements
Config::IniFiles
Const::Fast
DateTime
Digest::SHA
ExtUtils::CBuilder
Graph
Heap
HTML::Entities
Image::Size
List::MoreUtils
Math::Combinatorics
Math::Derivative
Math::Round
Math::Spline
Moose
MooseX::Aliases
MooseX::AttributeHelpers
MooseX::StrictConstructor
MooseX::Singleton
MooseX::Types
PPI
PPI::HTML
Pod::POM
Regexp::Common
Regexp::Assemble
Spreadsheet::WriteExcel
Statistics::Descriptive
String::Random
Template
Text::Template
Tree::Simple
Want
YAML::Tiny
Wx
Win32::Console::ANSI
