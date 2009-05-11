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
use File::Basename;
use File::Spec;
use YAML;

use Wx qw(:everything);

require Exporter;

use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(save_project read_project);

use File::Basename;
use File::Spec;

sub save_project {
  my ($rframes, $fname) = @_;

  ## make sure we are fully up to date and serialised
  my ($abort, $rdata, $rpaths, $rgds) = Demeter::UI::Artemis::uptodate($rframes);
  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  ## get name, fom, and description + other properties
  $rframes->{main} -> {currentfit} -> set(data => \@data, paths => \@paths, gds => \@gds);
  $rframes->{main} -> {currentfit} -> serialize(tree     => File::Spec->catfile($rframes->{main}->{project_folder}, 'fits'),
						folder   => $rframes->{main}->{currentfit}->group,
						nozip    => 1,
						copyfeff => 0,
					       );

  foreach my $k (keys(%$rframes)) {
    next unless ($k =~ m{\Afeff});
    next if (ref($rframes->{$k}->{Feff}->{feffobject}) !~ m{Feff});
    my $file = File::Spec->catfile($rframes->{$k}->{Feff}->{feffobject}->workspace, 'atoms.inp');
    $rframes->{$k}->{Atoms}->save_file($file);
  };
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Save project file", cwd, q{artemis.fpj},
				  "Demeter fitting project (*.fpj)|*.fpj|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Saving project cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };



  my $zip = Archive::Zip->new();
  $zip->addTree( $rframes->{main}->{project_folder}, "",  sub{ not m{\.sp$} });
  carp('error writing zip-style project') unless ($zip->writeToFileNamed( $fname ) == AZ_OK);
  undef $zip;

  $rframes->{main}->{projectname} = basename($fname);
  $rframes->{main}->SetTitle('Artemis [EXAFS data analysis] ' . basename($fname, '.fpj'));
};

sub read_project {
  my ($rframes, $fname) = @_;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Artemis project", cwd, q{},
				  "Artemis project (*.fpj)|*.fpj|All files|*.*",
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

  my $projfolder = $rframes->{main}->{project_folder};

  %Demeter::UI::Artemis::fit_order = YAML::LoadFile(File::Spec->catfile($projfolder, 'order'));
  #use Data::Dumper;
  #print Data::Dumper->Dump([\%Demeter::UI::Artemis::fit_order]);

  ## -------- import feff calculations from the project file
  my %feffs;
  opendir(my $FEFF, File::Spec->catfile($projfolder, 'feff/'));
  my @dirs = grep { $_ =~ m{\A[a-z]} } readdir($FEFF);
  closedir $FEFF;
  foreach my $d (@dirs) {
    ## import feff yaml
    my $yaml = File::Spec->catfile($projfolder, 'feff', $d, $d.'.yaml');
    my $feffobject = Demeter::Feff->new(yaml=>$yaml, group=>$d); # force group to be the same as before

    ## import atoms.inp
    my $atoms = File::Spec->catfile($projfolder, 'feff', $d, 'atoms.inp');
    my ($fnum, $ifeff) = Demeter::UI::Artemis::make_feff_frame($rframes->{main}, $atoms, $feffobject->name, $feffobject);

    ## import feff.inp
    my $feff = File::Spec->catfile($projfolder, 'feff', $d, $d.'.inp');
    my $text = Demeter::UI::Artemis::slurp($feff);
    $rframes->{$fnum}->{Feff}->{feff}->SetValue($text);

    ## make Feff frame
    $feffobject -> workspace(File::Spec->catfile($projfolder, 'feff', $d));
    $feffs{$d} = $feffobject;
    $rframes->{$fnum}->{Feff}->{feffobject} = $feffobject;
    $rframes->{$fnum}->{Feff}->fill_intrp_page($feffobject);
    $rframes->{$fnum}->{notebook}->ChangeSelection(2);

    $rframes->{$fnum}->{Feff} ->{name}->SetValue($feffobject->name);
    $rframes->{$fnum}->{Paths}->{name}->SetValue($feffobject->name);

    $rframes->{$fnum}->{statusbar}->SetStatusText("Imported crystal and Feff data from ". basename($fname));
  };

  ## -------- import fit history from project file (currently only importing most recent)
  opendir(my $FITS, File::Spec->catfile($projfolder, 'fits/'));
  @dirs = grep { $_ =~ m{\A[a-z]} } readdir($FITS);
  closedir $FITS;
  my $current = $Demeter::UI::Artemis::fit_order{order}{current};
  $current = $Demeter::UI::Artemis::fit_order{order}{$current};
  my $fit;
  foreach my $d (@dirs) {
    next unless ($d eq $current);
    $fit = Demeter::Fit->new(group=>$d);
    $fit->deserialize(folder=> File::Spec->catfile($projfolder, 'fits', $d));
    $rframes->{main} -> {currentfit} = $fit;
  };

  ## -------- load up the GDS parameters
  my $grid  = $rframes->{GDS}->{grid};
  my $start = $rframes->{GDS}->find_next_empty_row;
  foreach my $g (@{$fit->gds}) {
    $grid->AppendRows(1,1) if ($start >= $grid->GetNumberRows);
    $grid -> SetCellValue($start, 0, $g->gds);
    $grid -> SetCellValue($start, 1, $g->name);
    $grid -> SetCellValue($start, 2, $g->mathexp);
    my $text = q{};
    if ($g->gds eq 'guess') {
      $text = sprintf("%.5f +/- %.5f", $g->bestfit, $g->error);
    } elsif ($g->gds =~ m{(?:after|def|penalty|restrain)}) {
      $text = sprintf("%.5f", $g->bestfit);
    } elsif ($g->gds =~ m{(?:lguess|merge|set|skip)}) {
      1;
    };
    $grid -> SetCellValue($start, 3, $text);
    $rframes->{GDS}->set_type($start);
    ++$start;
  };

  my $count = 0;
  foreach my $d (@{$fit->data}) {
    my ($dnum, $idata) = Demeter::UI::Artemis::make_data_frame($rframes->{main}, $d);
    $rframes->{$dnum}->{pathlist}->DeletePage(0) if $rframes->{$dnum}->{pathlist}->GetPage(0) =~ m{Panel};
    my $first = $rframes->{$dnum}->{pathlist}->GetPage(0);
    ($first->DeletePage(0)) if (ref($first) =~ m{Panel});
    foreach my $p (@{$fit->paths}) {
      $p->set(folder=>$feffs{$p->parentgroup}->workspace, file=>q{}, update_path=>1);
      next if ($p->data ne $d);
      $p->parent($feffs{$p->parentgroup});
      $p->sp(find_sp($p, \%feffs));
      my $page = Demeter::UI::Artemis::Path->new($rframes->{$dnum}->{pathlist}, $p, $rframes->{$dnum});
      $rframes->{$dnum}->{pathlist}->AddPage($page, $p->label, 1, 0);
      $page->include_label;
    };
    $rframes->{$dnum}->{pathlist}->SetSelection(0);
    if (not $count) {
      $rframes->{$dnum}->Show(1);
      $rframes->{main}->{datatool}->ToggleTool($idata,1);
    };
    ++$count;
  };


  $rframes->{main}->{projectname} = basename($fname);
  $rframes->{main}->SetTitle('Artemis [EXAFS data analysis] ' . basename($fname, '.fpj'));
};

sub find_sp {
  my ($path, $rfeffs) = @_;
  foreach my $f (values %$rfeffs) {
    foreach my $sp (@{ $f->pathlist }) {
      return $sp if ($path->spgroup eq $sp->group);
    };
  };
  return q{};
};


1;
