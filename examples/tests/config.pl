#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This runs several tests of Demeter's configuration susbsystem.

=cut

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use warnings;
use strict;
use Smart::Comments;

use Ifeffit::Demeter;
### Testing the configuration system
Ifeffit::Demeter->set_mode({screen  => 0,
			    ifeffit => 1,
			   });
my $plot_features = Ifeffit::Demeter -> get_mode('plot');

my $config = Ifeffit::Demeter->get_mode("params");

### This is the full description of the "bkg" parameter group:
print $config -> describe_param("bkg"),
  "\nHit return for next test ";
my $toss = <STDIN>;
print "\n";

### This is the full description of the "bkg-->rbkg" parameter (number valued):
print $config -> describe_param("bkg", 'rbkg'),
  "\nHit return for next test ";
$toss = <STDIN>;
print "\n";

### This is the full description of the "bkg-->rbkg" parameter (number valued, width=60):
print $config -> describe_param("bkg", 'rbkg', 60),
  "\nHit return for next test ";
$toss = <STDIN>;
print "\n";

### This is the full description of the "fft-->kwindow" parameter (list valued)
print $config -> describe_param("fft", 'kwindow'),
  "\nHit return for next test ";
$toss = <STDIN>;
print "\n";

### Methods for configuration value attributes:
print "The current value of \"bkg-->flatten\":\t", $config->default("bkg", "flatten"), "\n",
  "The units for \"bkg-->pre1\":\t\t", $config->units("bkg", "pre1"), "\n",
  "Demeter's default for \"bkg-->pre1\":\t", $config->demeter("bkg", "pre1"), "\n",
  "The list options for \"bkg-->kwindow\":\t", $config->options("bkg", "kwindow"), "\n",
  "The description for \"fft-->kwindow\":\t", $config->description("fft", "kwindow"), "\n",
  "The description for the \"fft\" group:\t", $config->description("fft"), "\n",
  "\nHit return for next test ";
$toss = <STDIN>;
print "\n";

### Introspection methods:
print "All configuration groups:\n", join(", ", $config->groups), "\n",
  "\nAll parameters in the \"bkg\" group:\n", join(", ", $config->parameters('bkg')), "\n";
