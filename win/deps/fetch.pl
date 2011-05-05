#!/usr/bin/perl -I.

use strict;
use warnings;

use LWP::UserAgent;
use Term::Sk;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $perl_version = '5.12.2';

my $counter = Term::Sk->new('fetching %k  (#%c) %8t', {freq => 's', base => 0, token=>'Archive::Zip'})
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
    die $response->status_line;
  };
};
$counter->close;

rename('Wx.xml', 'zzzWx.xml') if (-e 'Wx.xml');

__DATA__
autodie
Archive::Zip
Capture::Tiny
Chemistry::Elements
Config::IniFiles
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
Readonly
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
