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

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;

use Wx qw(:everything);

require Exporter;

use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(save_project read_project);

use File::Spec;

sub save_project {
  my ($rframes, $fname) = @_;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Save project file", cwd, q{artemis.dfp},
				  "Demeter fitting project (*.dfp)|*.inp|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Saving project cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  Demeter::UI::Artemis::uptodate($rframes);

  print join(" ",
	     $rframes->{main}->{project_folder},
	     $fname,
	     ), $/;

  my $zip = Archive::Zip->new();
  $zip->addTree( $rframes->{main}->{project_folder}, "" );
  carp('error writing zip-style project') unless ($zip->writeToFileNamed( $fname ) == AZ_OK);
  undef $zip;
};

sub read_project {
  my ($rframes, $fname) = @_;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Artemis project", cwd, q{},
				  "Artemis project (*.dfp)|*.dfp|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Project import cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };

  my $zip = Archive::Zip->new();
  carp("Error reading project file $fname"), return 1 unless ($zip->read($fname) == AZ_OK);
  $zip->extractTree("", $rframes->{main}->{project_folder}.'/');
  undef $zip;

  1;
};


1;
