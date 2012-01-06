package Demeter::UI::Artemis::Project;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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
use Carp;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Compress::Zlib;
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw(any);
use YAML::Tiny;
use Safe;

use Wx qw(:everything);
use Demeter::UI::Wx::AutoSave;

require Exporter;

use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(save_project read_project modified close_project
		autosave clear_autosave autosave_exists import_autosave
	      );

use File::Basename;
use File::Spec;

sub save_project {
  my ($rframes, $fname) = @_;

  ## make sure we are fully up to date and serialised
  my ($abort, $rdata, $rpaths) = Demeter::UI::Artemis::uptodate($rframes);
  my $rgds = $rframes->{GDS}->reset_all(1,0);
  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  ## get name, fom, and description + other properties

  $rframes->{main} -> {currentfit}  = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)")
    if (not $rframes->{main} -> {currentfit});
  Demeter::UI::Artemis::update_order_file();

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
    mkpath $rframes->{$k}->{Feff}->{feffobject}->workspace if (! -d $rframes->{$k}->{Feff}->{feffobject}->workspace);
    $rframes->{$k}->{Atoms}->save_file($file) if $rframes->{$k}->{Atoms}->{used};
  };
  if ((not $fname) or ($fname =~ m{\<untitled\>})) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Save project file", cwd, q{artemis.fpj},
				  "Artemis project (*.fpj)|*.fpj|All files|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR); #|wxFD_OVERWRITE_PROMPT
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("Saving project cancelled.");
      return;
    };
    $fname = $fd->GetPath;
    return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };

  my $po = $rframes->{main} -> {currentfit}->po;
  $po -> serialize(File::Spec->catfile($rframes->{main}->{plot_folder}, 'plot.yaml'));
  open(my $IN, '>'.File::Spec->catfile($rframes->{main}->{plot_folder}, 'indicators.yaml'));
  foreach my $j (1..5) {
    my $this = $rframes->{Plot}->{indicators}->{'group'.$j};
    my $found = $Demeter::UI::Artemis::demeter->mo->fetch('Indicator', $this);
    print($IN $found -> serialization) if $found;
  };
  close $IN;
  open(my $JO, '>'.File::Spec->catfile($rframes->{main}->{project_folder}, 'journal'));
  print $JO $rframes->{Journal}->{journal}->GetValue;
  close $JO;

  my $zip = Archive::Zip->new();
  $zip->addTree( $rframes->{main}->{project_folder}, "",  sub{ not m{\.sp$} }); #and not m{_dem_\w{8}\z}
  carp('error writing zip-style project') unless ($zip->writeToFileNamed( $fname ) == AZ_OK);
  undef $zip;

  if ($fname !~ m{autosave\z}) {
    clear_autosave();
    $Demeter::UI::Artemis::demeter->push_mru("artemis", File::Spec->rel2abs($fname));
    &Demeter::UI::Artemis::set_mru;
    $rframes->{main}->{projectname} = basename($fname, '.fpj');
    $rframes->{main}->{projectpath} = File::Spec->rel2abs($fname);
    $rframes->{main}->status("Saved project as ".$rframes->{main}->{projectpath});
    modified(0);
  };
};

sub autosave {
  return if $Demeter::UI::Artemis::noautosave;
  return if not $Demeter::UI::Artemis::demeter->co->default("artemis", "autosave");
  my $main = $Demeter::UI::Artemis::frames{main};
  $main->status("Performing autosave ...", 'wait');
  unlink $main->{autosave_file};
  my $name = $_[0] || $main->{name}->GetValue;
  $name =~ s{\s+}{_}g;
  $name ||= "artemis";
  $main->{autosave_file} = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, $name.'.autosave');
  save_project(\%Demeter::UI::Artemis::frames, $main->{autosave_file});
  $main->status("Autosave done!");
};
sub clear_autosave {
  return if not $Demeter::UI::Artemis::demeter->co->default("artemis", "autosave");
  my $main = $Demeter::UI::Artemis::frames{main};
  unlink $main->{autosave_file};
  $main->status("Removed autosave file.");
};
sub autosave_exists {
  opendir(my $stash, $Demeter::UI::Artemis::demeter->stash_folder);
  my @list = readdir $stash;
  closedir $stash;
  return any {$_ =~ m{autosave\z} and $_ !~ m{\AAthena}} @list;
};
sub import_autosave {
  my $dialog = Demeter::UI::Wx::AutoSave->new($Demeter::UI::Artemis::frames{main});
  $Demeter::UI::Artemis::frames{main}->status("There are no autosave files."), return
    if ($dialog == -1);
  $dialog->SetFocus;
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $Demeter::UI::Artemis::frames{main}->status("Autosave import cancelled.");
  } else {
    my $this = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, $dialog->GetStringSelection);
    read_project(\%Demeter::UI::Artemis::frames, $this);
    unlink $this;
    ## need to clean up the corresponding folder, if it has been left behind
  };

};


## other data types:
##  * empirical standard
##  * structural unit
##  * molecule

sub read_project {
  my ($rframes, $fname) = @_;
  my $debug = 0;
  my $statustype = ($debug) ? 'wait' : 'wait|nobuffer';
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Artemis project or data", cwd, q{},
				  "Artemis project or data (*.fpj;*.prj;*.inp;*.cif)|*.fpj;*.prj;*.inp;*.cif|" .
				  "Artemis project (*.fpj)|*.fpj|" .
				  "Athena project (*.prj)|*.prj|".
				  "old-style Artemis project (*.apj)|*.apj|".
				  "Demeter serializations (*.dpj)|*.dpj|".
				  "Feff or crystal data (*.inp;*.cif)|*.inp;*.cif|".
				  "chi(k) column data (*.chi;*.dat)|*.chi;*.dat|".
				  "All files|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("Project import cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  $fname = Demeter->follow_link($fname);

  if (not Demeter->is_zipproj($fname,0, 'any')) {
    if (project_started($rframes)) {
      my $yesno = Wx::MessageDialog->new($rframes->{main},
					 "Save current project before opening a new one?",
					 "Save project?",
					 wxYES_NO|wxYES_DEFAULT|wxICON_QUESTION);
      my $result = $yesno->ShowModal;
      save_project($rframes) if $result == wxID_YES;
      close_project($rframes, 1);
    };
  };

  if (not Demeter->is_zipproj($fname,0, 'fpj')) {
    Demeter::UI::Artemis::Import('old',  $fname), return if (Demeter->is_zipproj($fname,0,'apj'));
    Demeter::UI::Artemis::Import('prj',  $fname), return if (Demeter->is_prj($fname));
    Demeter::UI::Artemis::Import('chi',  $fname), return if (Demeter->is_data($fname));
    Demeter::UI::Artemis::Import('feff', $fname), return if (Demeter->is_feff($fname) or Demeter->is_atoms($fname) or Demeter->is_cif($fname));
    Demeter::UI::Artemis::Import('dpj',  $fname), return if (Demeter->is_zipproj($fname,0,'dpj'));
    $rframes->{main}->status("$fname is not recognized as any kind of input data for Artemis", 'error');
    return;
  };

  my $busy = Wx::BusyCursor->new();
  $rframes->{main}->status("Importing project (please be patient, it may take a while...)", "wait");

#  my ($volume,$directories,$fl) = File::Spec->splitpath( $rframes->{main}->{project_folder} );
#  $directories =~ s{\\}{/}g;
#  $directories .= $fl.'/';
#  print join("|", $volume,$directories), $/;
  my $wasdir = cwd;
  my $projfolder = $rframes->{main}->{project_folder};
  chdir $projfolder;

  $rframes->{main}->status("Opening project file $fname.", $statustype);
  my $zip = Archive::Zip->new();
  carp("Error reading project file $fname"), return 1 unless ($zip->read($fname) == AZ_OK);
  foreach my $f ($zip->members) {
    $zip->extractMember($f);
  };
  chdir($wasdir);

#  ##print join($/, $zip->memberNames), $/;
#  (my $pf = $rframes->{main}->{project_folder}) =~ s{\\}{/}g;
#  $zip->extractTree(".", $rframes->{main}->{project_folder});
#  print $zip->extractTree(".", $directories, $volume), $/;
#  undef $zip;

  my $import_problems = q{};

  %Demeter::UI::Artemis::fit_order = YAML::Tiny::LoadFile(File::Spec->catfile($projfolder, 'order'));
  #use Data::Dumper;
  #print Data::Dumper->Dump([\%Demeter::UI::Artemis::fit_order]);

  ## -------- import feff calculations from the project file
  my %feffs;
  my $feffdir = File::Spec->catfile($projfolder, 'feff/');
  my @dirs = ();
  if (-d $feffdir) {
    opendir(my $FEFF, $feffdir);
    @dirs = grep { $_ =~ m{\A[a-z]} } readdir($FEFF);
    closedir $FEFF;
  };
  foreach my $d (@dirs) {
    ## import feff yaml
    my $yaml = File::Spec->catfile($projfolder, 'feff', $d, $d.'.yaml');
    my $feffobject = Demeter::Feff->new(group=>$d); # force group to be the same as before.
    my $where = Cwd::realpath(File::Spec->catfile($feffdir, $d));
    if (-e $yaml) {
      my $gz = gzopen($yaml, 'rb');
      my ($yy, $buffer);
      $yy .= $buffer while $gz->gzreadline($buffer) > 0 ;
      my @refs = YAML::Tiny::Load($yy);
      $feffobject->read_yaml(\@refs, $where);
    };
    $rframes->{main}->status("Unpacking Feff calculation: ".$feffobject->name, $statustype);

    if (not $feffobject->hidden) {
      ## import atoms.inp
      my $atoms = File::Spec->catfile($projfolder, 'feff', $d, 'atoms.inp');
      my ($fnum, $ifeff) = Demeter::UI::Artemis::make_feff_frame($rframes->{main}, $atoms, $feffobject->name, $feffobject);

      if (-e $yaml) {
	## import feff.inp
	my $feff = File::Spec->catfile($projfolder, 'feff', $d, $d.'.inp');
	my $text = $feffobject->slurp($feff);
	$rframes->{$fnum}->{Feff}->{feff}->SetValue($text);

	## make Feff frame
	$feffobject -> workspace(File::Spec->catfile($projfolder, 'feff', $d));
	$feffs{$d} = $feffobject;
	$rframes->{$fnum}->{Feff}->{feffobject} = $feffobject;
	$rframes->{$fnum}->{Feff}->fill_intrp_page($feffobject);
	$rframes->{$fnum}->{notebook}->ChangeSelection(2);

	$rframes->{$fnum}->{Feff}->fill_ss_page($feffobject);

	$rframes->{$fnum}->{Feff} ->{name}->SetValue($feffobject->name);
	$rframes->{$fnum}->{Paths}->{name}->SetValue($feffobject->name);
	$rframes->{$fnum}->status("Imported crystal and Feff data from ". basename($fname));
      };
      my $label = $rframes->{main}->{$fnum}->GetLabel;
      $label =~ s{Hide}{Show};
      $rframes->{main}->{$fnum}->SetLabel($label)
    };
  };

  ## -------- import fit history from project file (currently only importing most recent)
  #opendir(my $FITS, File::Spec->catfile($projfolder, 'fits/'));
  #@dirs = grep { $_ =~ m{\A[a-z]} } readdir($FITS);
  #closedir $FITS;
  @dirs = ();			# need to retrieve in historical order for fit history
  foreach my $d (sort {$a<=>$b} grep {$_ =~ m{\A\d+\z}} keys(%{$Demeter::UI::Artemis::fit_order{order}})) {
    next if $d eq 'current';
    push @dirs, $Demeter::UI::Artemis::fit_order{order}{$d};
  };
  my $current = $Demeter::UI::Artemis::fit_order{order}{current};
  $current = $Demeter::UI::Artemis::fit_order{order}{$current};
  $current ||= $dirs[0];
  ##print join("|", $current, @dirs), $/;
  my $currentfit;
  my @fits;

  ## explanation:
  ## the list of fits in a project file includes some that have been fitted and some
  ## that have not.  it is likely the one marked as the current fit has not been
  ## fitted.  all unfitted fits are destroyed except for the current.  all fitted
  ## fits are pushed onto the history and the current fit (fitted or not) is restored

  my $count = 1;
  my $folder;
  foreach my $d (@dirs) {
    my $fit = Demeter::Fit->new(group=>$d, interface=>"Artemis (Wx $Wx::VERSION)");
    $rframes->{main}->status("Importing fit #$count into history", $statustype) if not $count % 5;
    my $regen = ($d eq $current) ? 0 : 1;
    next if (not -d File::Spec->catfile($projfolder, 'fits', $d));
    $fit->grab(folder=> File::Spec->catfile($projfolder, 'fits', $d), regenerate=>0); #$regen);
    #$fit->deserialize(folder=> File::Spec->catfile($projfolder, 'fits', $d), regenerate=>0); #$regen);
    if (($d ne $current) and (not $fit->fitted)) { # discard the ones that don't actually involve a performed fit
      $fit->DEMOLISH;
      next;
    };
    $folder = File::Spec->catfile($projfolder, 'fits', $d);
    ++$count;
    push @fits, $fit;
  };
  if (@fits) {		# found some actual fits
    $rframes->{main}->status("Found fit history, creating history window", $statustype);
    my $found = 0;
    foreach my $fit (@fits) {	# take care that the one labeled as current actually exists, if not use the latest
      ++$found, last if ($fit->group eq $current);
    };
    $current = $fits[-1]->group if not $found;
    foreach my $fit (@fits) {
      if ($fit->fitted) {
	$rframes->{History}->{list}->AddData($fit->name, $fit);
	$rframes->{History}->add_plottool($fit);
      } elsif ($fit->group ne $current) {
	foreach my $g ( @{ $fit->gds }) {
	  $g->DEMOLISH;
	};
      };
      next unless ($fit->group eq $current);
      $currentfit = $fit;
      $rframes->{main}->status("Unpacking current fit", $statustype);
      $currentfit->deserialize(folder=> $folder, regenerate=>0); #$regen);
      #$rframes->{History}->{list}->SetSelection($rframes->{History}->{list}->GetCount-1);
      #$rframes->{History}->OnSelect;
      $rframes->{main}->{currentfit} = $fit;
      $rframes->{Plot}->{limits}->{fit}->SetValue(1);
      my $current = $fit->number || 1;
      #++$current;
    };
  };

  ## -------- plot and indicator yamls, journal
  $rframes->{main}->status('Setting plot parameters, indicators, & journal', $statustype);
  my $py = File::Spec->catfile($rframes->{main}->{plot_folder}, 'plot.yaml');
  if (-e $py) {
    my %hash = %{YAML::Tiny::LoadFile($py)};
    delete $hash{nindicators};
    $Demeter::UI::Artemis::demeter->po->set(%hash);
    $rframes->{Plot}->populate;
  };
  my $iy = File::Spec->catfile($rframes->{main}->{plot_folder}, 'indicators.yaml');
  if (-e $iy) {
    my @list = YAML::Tiny::LoadFile($iy);
    $rframes->{Plot}->{indicators}->populate(@list);
  };
  my $journal = File::Spec->catfile($rframes->{main}->{project_folder}, 'journal');
  if (-e $journal) {
    $rframes->{Journal}->{journal}->SetValue(Demeter->slurp($journal));
  };

  $import_problems .= restore_fit($rframes, $currentfit);

  ## when each fit is deserialized, new GDS objects are instantiated
  ## for each one.  for many projects, this means that many GDS
  ## objects then have the same name.  the simplest solution to this
  ## problem is to just destroy all the GDS parameters and
  ## re-instantiate the ones from the current fit which was just
  ## restored.  this is a bit wasteful, but GDS objects are small and
  ## quick to work with.
  # foreach my $g (reverse @{ $currentfit->mo->GDS }) {
  #   delete($rframes->{GDS}->{grid}->{$g->name}) if exists($rframes->{GDS}->{grid}->{$g->name});
  #   $g->DEMOLISH;
  # };
  # $currentfit->gds( $rframes->{GDS}->reset_all );

  if ($import_problems) {
    Wx::MessageDialog->new($Demeter::UI::Artemis::frames{main}, $import_problems, "Warning!", wxOK|wxICON_WARNING) -> ShowModal;
  };

  $Demeter::UI::Artemis::demeter->push_mru("artemis", $fname);
  &Demeter::UI::Artemis::set_mru;
  $rframes->{main}->{projectpath} = $fname;
  $rframes->{main}->{projectname} = basename($fname, '.fpj');
  $rframes->{main}->status("Imported project $fname.");

  my $newfit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  $rframes->{main} -> {currentfit} = $newfit;
  #++$Demeter::UI::Artemis::fit_order{order}{current};

  modified(0);
  undef $busy;
};

sub restore_fit {
  my ($rframes, $fit) = @_;
  my $import_problems = q{};

  ## -------- load up the GDS parameters
  my $grid  = $rframes->{GDS}->{grid};
  my $start = $rframes->{GDS}->find_next_empty_row;
  foreach my $g (@{$fit->gds}) {
    $grid -> AppendRows(1,1) if ($start >= $grid->GetNumberRows);
    $grid -> SetCellValue($start, 0, $g->gds);
    $grid -> SetCellValue($start, 1, $g->name);
    if ($g->gds eq 'guess') {
      $grid -> SetCellValue($start, 2, $rframes->{GDS}->display_value($g->bestfit || $g->mathexp));
    } else {
      $grid -> SetCellValue($start, 2, $rframes->{GDS}->display_value($g->mathexp));
    };
    $grid -> {$g->name} = $g;
    my $text = q{};
    if ($g->bestfit or $g->error) {
      if ($g->gds eq 'guess') {
	$text = sprintf("%.5f +/- %.5f", $g->bestfit, $g->error);
      } elsif ($g->gds =~ m{(?:after|def|penalty|restrain)}) {
	$text = sprintf("%.5f", $g->bestfit);
      } elsif ($g->gds =~ m{(?:lguess|merge|set|skip)}) {
	1;
      };
    };
    $grid -> SetCellValue($start, 3, $text);
    $rframes->{GDS}->set_type($start);
    ++$start;
  };
  $fit->mo->currentfit($fit->fom+1);
  my $name = ($fit->name =~ m{\A\s*Fit\s+\d+\z}) ? 'Fit '.$fit->mo->currentfit : $fit->name;
  $rframes->{main}->{name}->SetValue($name);
  $rframes->{main}->{description}->SetValue($fit->description);

  ## -------- Data and Paths
  my $count = 0;
  foreach my $d (@{$fit->data}) {
    my ($dnum, $idata) = Demeter::UI::Artemis::make_data_frame($rframes->{main}, $d);
    $rframes->{$dnum}->{pathlist}->DeletePage(0) if (($rframes->{$dnum}->{pathlist}->GetPage(0) =~ m{Panel})
						     and # take care in case of a project with data but no paths
						     (@{$fit->paths}));
    #my $first = $rframes->{$dnum}->{pathlist}->GetPage(0);
    #($first->DeletePage(0)) if (ref($first) =~ m{Panel});
    my $datapaths = 0;
    foreach my $p (@{$fit->paths}) {
#      if (not $p->sp) {
#	$import_problems .= sprintf("The path named \"%s\" from data set \"%s\" was malformed.  It was discarded.\n", $p->name, $d->name);
#	next;
#      };
      #my $feff = $feffs{$p->{parentgroup}} || $fit -> mo -> fetch('Feff', $p->{parentgroup});
      my $feff = (ref($p) =~ m{FPath}) ? $p : $fit -> mo -> fetch('Feff', $p->{parentgroup});
      $p->set(file=>q{}, update_path=>1);
      $p->set(folder=>$feff->workspace) if (ref($p) !~ m{FPath});
      next if ($p->data ne $d);
      ++$datapaths;
      $p->parent($feff);
      #my $this_sp = find_sp($p, \%feffs) || $fit->mo->fetch('ScatteringPath', $p->spgroup);
      #$p->sp($this_sp);
      my $page = Demeter::UI::Artemis::Path->new($rframes->{$dnum}->{pathlist}, $p, $rframes->{$dnum});
      my $n = $rframes->{$dnum}->{pathlist}->AddPage($page, $p->label, 1, 0);
      $page->include_label;
      $rframes->{$dnum}->{pathlist}->Check($n, $p->mark);
    };
    $rframes->{$dnum}->{pathlist}->SetSelection(0) if $datapaths; #($#{$fit->paths} > -1);
    $rframes->{$dnum}->Show(0);
    $rframes->{main}->{$dnum}->SetValue(0);
    if (not $count) {
      $rframes->{$dnum}->Show(1);
      $rframes->{main}->{$dnum}->SetValue(1);
    };
    ++$count;
  };

  ## -------- labels and suchlike
  $rframes->{Log}->{name} = $fit->name;
  $rframes->{Log}->put_log($fit);
  $rframes->{Log}->SetTitle("Artemis [Log] " . $fit->name);
  $rframes->{Log}->Show(0);
  $rframes->{main}->{log_toggle}->SetValue(0);
  if ($fit->happiness) {
    Demeter::UI::Artemis::set_happiness_color($fit->color);
  } else {
    $rframes->{main}->{fitbutton} -> SetBackgroundColour(Wx::Colour->new($fit->co->default("happiness", "average_color")));
  };

  return $import_problems;
};


sub discard_fit {
  my ($rframes) = @_;
  $rframes->{GDS}->discard_all(1);
  foreach my $d (keys %$rframes) {
    next if $d !~ m{data};
    $rframes->{$d}->discard_data(1);
  };
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


sub modified {
  my ($is_modified) = @_;
  my $main = $Demeter::UI::Artemis::frames{main};
  my $title = ($is_modified)
    ? 'Artemis [EXAFS data analysis] *' . $main->{projectname} . '*'
      : 'Artemis [EXAFS data analysis] ' . $main->{projectname};
  $main->{modified} = ($is_modified);
  $main->SetTitle($title);
};


sub close_project {
  my ($rframes, $force) = @_;
  if (not $force) {
    my $yesno = Wx::MessageDialog->new($rframes->{main},
				       "Save this project before closing?",
				       "Save project?",
				       wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
    my $result = $yesno->ShowModal;
    if ($result == wxID_CANCEL) {
      $rframes->{main}->status("Not closing project.");
      return 0;
    };
    save_project($rframes) if $result == wxID_YES;
  };

  Demeter::UI::Artemis::set_happiness_color($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color"))
      if (exists $rframes->{main} -> {currentfit});

  ## -------- clear GDS
  $rframes->{GDS}->discard_all(1);
  $rframes->{GDS}->Show(0);
  $rframes->{main}->{toolbar}->ToggleTool(1,0);

  ## -------- clear Log
  $rframes->{Log}->{text}->SetValue(q{});
  $rframes->{Log}->Show(0);
  $rframes->{main}->{log_toggle}->SetValue(0);

  ## -------- clear all Data
  foreach my $k (keys %$rframes) {
    next unless ($k =~ m{data});
    $rframes->{$k}->discard_data(1);
  };

  ## -------- clear all Feff
  foreach my $k (keys %$rframes) {
    next unless ($k =~ m{feff});
    Demeter::UI::Artemis::discard_feff($k, 1);
  };

  ## -------- clear all Paths
  my @list = @{$Demeter::UI::Artemis::demeter->mo->Path};
  foreach my $p (@list) {
    $p->DEMOLISH;
  };
  $Demeter::UI::Artemis::demeter->mo->reset_path_index;

  ## -------- clear all Fits
  @list = @{$Demeter::UI::Artemis::demeter->mo->Fit};
  foreach my $f (@list) {
    $f->DEMOLISH;
  };

  ## -------- clear history
  $rframes->{History}->{list}->ClearAll;
  $rframes->{History}->{log}->Clear;
  $rframes->{History}->{params}->Clear;
  $rframes->{History}->{params}->Append("Statistcal parameters");
  $rframes->{History}->{params}->Select(0);
  $rframes->{History}->{report}->Clear;

  my $plottoolbox  = Wx::BoxSizer->new( wxVERTICAL );
  $rframes->{History}->{plottool} -> DestroyChildren;
  $rframes->{History}->{plottool} -> SetSizer($plottoolbox, 1);
  $rframes->{History}->{plottool} -> SetScrollbars(20, 20, 50, 50);
  $rframes->{History}->{scrollbox} = $plottoolbox;


  ## -------- clear Journal
  $rframes->{Journal}->{journal}->SetValue(q{});
  unlink File::Spec->catfile($rframes->{main}->{project_folder}, 'journal');

  ## -------- clear Fit text boxes
  $rframes->{main}->{name}->SetValue(q{});
  $rframes->{main}->{description}->SetValue(q{});
  $rframes->{main}->{fitspace}->[1]->SetValue(1);
  $rframes->{main}->{cvcount} = 0;

  return 1;
};

sub project_started {
  my ($rframes) = @_;
  my ($ndata, $nfeff, $ngds) = (0,0,0);
  foreach my $f (keys %$rframes) {
    ++$ndata if ($f =~ m{data});
    ++$nfeff if ($f =~ m{feff});
  };
  my $grid = $rframes->{GDS}->{grid};
  foreach my $row (0 .. $grid->GetNumberRows-1) {
    ++$ngds if ($grid->GetCellValue($row, 1) !~ m{\A\s*\z});
  };
  return $ndata || $nfeff || $ngds;
};

1;

=head1 NAME

Demeter::UI::Artemis::Project - Import and export Artemis project files

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 SYNOPSIS

Import and export Artemis project files.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
