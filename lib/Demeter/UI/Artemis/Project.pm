package Demeter::UI::Artemis::Project;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

require Exporter;

use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(write_project zip_project);

use File::Spec;

sub write_project {
  my ($rframes, $fit) = @_;

  foreach my $k (keys %$rframes) {
    next if ($k =~ m{(?:History|Log|Plot)});

  SWITCH: {

      ($k =~ m{\Adata}) and do {
	last SWITCH;
      };

      ($k =~ m{\Afeff}) and do {
	last SWITCH;
      };

      ($k eq 'GDS') and do {
	my $gdsfile = File::Spec->catfile($rframes->{main}->{project_folder}, 'fits',
					  $fit->group . "_gds.yaml");
	open(my $GDS, '>', $gdsfile);
	foreach my $g (@{ $fit->gds }) {
	  print $GDS $g->serialization;
	};
	close $GDS;
	last SWITCH;
      };

    };


  };
  
};

sub zip_project {
  my ($self) = @_;
  1;
};


1;
