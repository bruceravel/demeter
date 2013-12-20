package Demeter::UI::Artemis::Import;

#use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Artemis::Project;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

## -------- convenience parameters
#use Const::Fast;
my $rdemeter = \$Demeter::UI::Artemis::demeter;
my $rframes  = \%Demeter::UI::Artemis::frames;
my $make_data_frame = \&Demeter::UI::Artemis::make_data_frame;
my $make_feff_frame = \&Demeter::UI::Artemis::make_feff_frame;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
local $Archive::Zip::UNICODE = 1;
use Carp;
use Chemistry::Elements qw(get_Z);
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw{any};

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Import prjrecord);


sub Import {
  my ($which, $fname, @args) = @_;
  my %args = @args;
  $args{postcrit} || Demeter->co->default('pathfinder', 'postcrit');
  my $retval = q{};
 SWITCH: {
    $retval = _prj($fname),                     last SWITCH if (($which eq 'prj') or ($which eq 'athena'));
    $retval = _old($fname),                     last SWITCH if  ($which eq 'old');
    $retval = _feff($fname),                    last SWITCH if  ($which eq 'feff');
    $retval = _external_feff($fname),           last SWITCH if  ($which eq 'external');
    $retval = _chi($fname),                     last SWITCH if  ($which eq 'chi');
    $retval = _dpj($fname, 0, $args{postcrit}), last SWITCH if  ($which eq 'dpj');
    $retval = _feffit($fname),                  last SWITCH if  ($which eq 'feffit');
  };
  $::app->heap_check;
  return $retval;
};


sub prjrecord {
  my ($fname, $choice) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Athena project", cwd, q{},
				  "Athena project (*.prj)|*.prj|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("Data import canceled.");
      return;
    };
    $file = $fd->GetPath;
  }
  $file = Demeter->follow_link($file);
  if (not $$rdemeter->is_prj($file)) {
    $rframes->{main}->status("$file is not an Athena project file.", 'error');
    return (q{}, q{}, -1);
  };
  ##
  my $selection = 0;
  $rframes->{prj} =  Demeter::UI::Artemis::Prj->new($rframes->{main}, $file, 'single', $choice);
  my $result = $rframes->{prj} -> ShowModal;

  if (
      ($result == wxID_CANCEL) or     # cancel button clicked
      ($rframes->{prj}->{record} == -1)  # import button without selecting a group
     ) {
    return (q{}, q{}, 0);
  };

  return ($file, $rframes->{prj}->{prj}, $rframes->{prj}->{record});
};

##############################################################################################################
## the "private" functions for specific import chores follow ...
##############################################################################################################

sub _prj {
  my ($fname) = @_;
  my $choice = 1;
  if ($fname =~ m{(\s+<(\d?)>)\z}) {
    $choice = $2;
    $fname =~ s{$1}{};
  };
  my ($file, $prj, $record) = prjrecord($fname, $choice);

  if (defined($record) and ($record < 0)) {
    return;
  };
  if ((not $prj) or (not $record)) {
    $rframes->{main}->status("Data import canceled.");
    return;
  };

  my $data = $prj->record($record);
  $data->frozen(0);
  my $ref;
  my $toss = $data->bkg_stan;
  if ($data->bkg_stan ne 'None') {
    foreach my $i (0 .. $#{$prj->entries}) {
      if ($prj->entries->[$i]->[1] eq $data->bkg_stan) {
	$ref = $prj->record($i+1);
	$data->bkg_stan($ref->group);
      };
    };
    ## clean up a few straggler arrays in Ifeffit/Larch and the spare Data object
    #$data->dispense('process', 'erase', {items=>"\@group $toss"});
    #$toss = Demeter->mo->fetch('Data', $toss);
    #$toss->DESTROY;
  };

  ## refuse to move forward for actinides above Am
  if (get_Z($data->bkg_z) > 95) {
    $prj->DESTROY;
    $rframes->{prj} -> Destroy;
    delete $rframes->{prj};
    my $error = Wx::MessageDialog->new($rframes->{main},
				       "The version of Feff you are using cannot calculate for absorbers above Z=95.",
				       "Error importing data",
				       wxOK|wxICON_EXCLAMATION);
    my $result = $error->ShowModal;
    $rframes->{main}->status("The version of Feff you are using cannot calculate for absorbers above Z=95.", 'alert');
    return 0;
  };

  my ($dnum, $idata) = &$make_data_frame($rframes->{main}, $data);
  $data->po->start_plot;
  $data->plot('k');
  $rframes->{$dnum} -> Show(1);
  $rframes->{main}->{$dnum}->SetValue(1);
  (my $lab = $rframes->{main}->{$dnum}->GetLabel) =~ s{Show}{Hide};
  $rframes->{main}->{$dnum}->SetLabel($lab);
  $prj->DESTROY;
  $rframes->{prj} -> Destroy;
  delete $rframes->{prj};
  $$rdemeter->push_mru("athena", $file, $record);
  autosave();
  chdir dirname($file);
  $rframes->{main}->status("Importing data \"" . $data->name . "\" from $file.");
};


sub _feff {
  my ($fname) = @_;
  ## also yaml data
  my $file = $fname;
  if (not $file) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import crystal data", cwd, q{},
				  "input and CIF files (*.inp;*.cif)|*.inp;*.cif|input file (*.inp)|*.inp|CIF file (*.cif)|*.cif|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("Crystal/Feff data import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };
  if (not -e $file) {
    $rframes->{main}->status("$file does not exist.");
    return;
  };
  if (not ($$rdemeter->is_feff($file) or $$rdemeter->is_atoms($file) or $$rdemeter->is_cif($file))) {
    $rframes->{main}->status("$file does not seem to be a Feff input file, an Atoms input file, or a CIF file", 'error');
    return;
  };

  my ($fnum, $ifeff) = &$make_feff_frame($rframes->{main}, $file);
  return if (not defined($fnum));
  $rframes->{$fnum} -> Show(1);
  autosave();
  $rframes->{$fnum}->status("Imported crystal data from " . basename($file));
  $rframes->{main}->{$fnum}->SetValue(1);
};


sub _chi {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import $CHI(k) data", cwd, q{},
				  "Chi data (*.chi)|*.chi|Data files (*.dat)|*.dat|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("$CHI(k) import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };
  if (not $$rdemeter->is_data($file)) {
    $rframes->{main}->status("$file is not a column data file.", 'error');
    return;
  };
  my $data = Demeter::Data->new(datatype=>'chi', file=>$file);
  $data->_update('data');
  my ($dnum, $idata) = &$make_data_frame($rframes->{main}, $data);
  $data->po->start_plot;
  $data->plot('k');
  $data->plot_window('k') if $data->po->plot_win;
  $rframes->{$dnum} -> Show(1);
  $rframes->{main}->{$dnum}->SetValue(1);
  $$rdemeter->push_mru("chik", $file);
  autosave();
  chdir dirname($file);
  $rframes->{main}->status("Imported $file as $CHI(k) data.");
};

sub _dpj {
  my ($fname, $nomru, $postcrit) = @_;
  my $file = $fname;
  $nomru ||= 0;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import a Demeter fit serialization file", cwd, q{},
				  "Fit serialization (*.dpj)|*.dpj|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status(".dpj file import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };
  $file = Demeter->follow_link($file);
  if (not $$rdemeter->is_zipproj($file,0, 'dpj')) {
    $rframes->{main}->status("$file is not a demeter fit serialization.", 'error');
    return;
  };
  if ($rframes->{main}->{modified}) {
    return if not close_project($rframes);
  };

  my $zip = Archive::Zip->new;
  if ($zip->read($file) != AZ_OK) {
    $rframes->{main}->status("$CHI(k) import canceled.");
    return;
  };
  if (not defined($zip->memberNamed('FIT.SERIALIZATION'))) {
    $rframes->{main}->status("$file is not a fit serialization.");
    return;
  };

  ## -------- make a new Fit object
  my $fit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  $rframes->{main}->{currentfit} = $fit;
  $rframes->{Plot}->{limits}->{fit}->SetValue(1);
  $fit->mo->currentfit(1);
  my $projfolder = $rframes->{main}->{project_folder};
  my $fitdir = File::Spec->catfile($projfolder, 'fits', $fit->group);
  mkpath($fitdir);

  foreach my $file ($zip->memberNames) {
  SWITCH: {
      ($file =~ m{([a-z]+)\.bin\z}) and do {
	#print "found feff $1\n";
	my $feffdir = File::Spec->catfile($rframes->{main}->{project_folder}, 'feff', $1);
	mkpath $feffdir;
	$zip->extractMember("$1.bin",   File::Spec->catfile($feffdir, "phase.bin"));
	$zip->extractMember("$1.files", File::Spec->catfile($feffdir, "files.dat"));
	$zip->extractMember("$1.yaml",  File::Spec->catfile($feffdir, "$1.yaml"));

	my $feffobject = Demeter::Feff->new(yaml=>File::Spec->catfile($feffdir, "$1.yaml"), group=>$1); # force group to be the same as before
	$feffobject -> workspace($feffdir);
	$feffobject -> postcrit($postcrit);
	$feffobject -> make_feffinp('full');
	my $feff = File::Spec->catfile($feffdir, "$1.inp");
	rename(File::Spec->catfile($feffdir, "feff.inp"), $feff);
	## import atoms.inp
	#my $atoms = File::Spec->catfile($projfolder, 'feff', $d, 'atoms.inp');
	my ($fnum, $ifeff) = &$make_feff_frame($rframes->{main}, q{}, $feffobject->name, $feffobject);

	## import feff.inp
	my $text = $feffobject->slurp($feff);
	$rframes->{$fnum}->make_page('Feff')  if not $rframes->{$fnum}->{Feff};
	$rframes->{$fnum}->make_page('Paths') if not $rframes->{$fnum}->{Paths};
	$rframes->{$fnum}->{Feff}->{feff}->SetValue($text);

	## make Feff frame
	$rframes->{$fnum}->{Feff}->{feffobject} = $feffobject;
	$rframes->{$fnum}->{Feff}->fill_intrp_page($feffobject);
	$rframes->{$fnum}->{notebook}->ChangeSelection(2);

	$rframes->{$fnum}->{Feff} ->{name}->SetValue($feffobject->name);
	$rframes->{$fnum}->{Paths}->{name}->SetValue($feffobject->name);
	$rframes->{$fnum}->status("Imported crystal and Feff data from ". basename($fname));
	my $label = $rframes->{main}->{$fnum}->GetLabel;
	$label =~ s{Hide}{Show};
	$rframes->{main}->{$fnum}->SetLabel($label);

	$rframes->{$fnum}->{Feff}->fill_ss_page($feffobject);
	last SWITCH;
      };
      (any {$file eq $_} (qw(plot.yaml vpaths.yaml paths.yaml fit.yaml gds.yaml log structure.yaml))) and do {
	$zip->extractMember($file,  File::Spec->catfile($fitdir, $file));
	last SWITCH;
      };
      ($file =~ m{([a-z]+)\.fit\z}) and do {
	$zip->extractMember("$1.fit",  File::Spec->catfile($fitdir, "$1.fit"));
	$zip->extractMember("$1.yaml", File::Spec->catfile($fitdir, "$1.yaml"));
      };
      ## skip Readme and FIT.SERIALIZATION
    };
  };
  $fit->deserialize(folder=>$fitdir, regenerate=>0); #$regen);
  my $import_problems .= Demeter::UI::Artemis::Project::restore_fit($rframes, $fit, $fit);
  if ($import_problems) {
    Wx::MessageDialog->new($rframes->{main}, $import_problems, "Warning!", wxOK|wxICON_WARNING) -> ShowModal;
  };
  if ($fit->fitted) {
    $rframes->{History}->{list}->AddData($fit->name, $fit);
      $rframes->{History}->add_plottool($fit);
    $rframes->{History}->{list}->SetSelection($rframes->{History}->{list}->GetCount-1);
    $rframes->{History}->OnSelect;
  };
  if (not $nomru) {
    $fit->push_mru("fit_serialization", $file) ;
    $rframes->{main}->{projectpath} = $file;
    $rframes->{main}->{projectname} = basename($file, '.dpj');
    $rframes->{main}->status("Imported fit serialization $file.");
  };
  my $newfit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  $rframes->{main} -> {currentfit} = $newfit;
  modified(0);

};


## need better reaction in case of absent phase.bin file.
sub _external_feff {
  my ($fname, $noshow) = @_;
  my $file = $fname;
  $noshow ||= 0;

  my $message = <<EOH
Importing an external Feff calculation is usually a
bad idea!

If your external Feff calculation was made using a
different version of Feff than that used by Artemis,
then importing a Feff calculation is likely to fail
in ways that may crash Artemis.

If you rerun Feff after importing an external Feff
calculation, your fits are likely to fail in surprising
ways.

Atoms or Feff input files are typically imported by
selecting "Import project or data" from the File
menu and the execution of Feff is managed by Artemis.

Think carefully about whether you want to continue.
EOH
    ;
  my $okcancel = Wx::MessageDialog->new($datapage,
					$message,
					"Caution!",
					wxYES_NO);
  if ($okcancel->ShowModal != wxID_YES) {
    $rframes->{main}->status("Not importing an external Feff calculation.");
    return;
  };


  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Atoms or Feff input file", cwd, q{},
				  "Atoms/Feff input (*.inp)|*.inp|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("$CHI(k) import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };

  my ($atoms_file, $feff_file) = (q{}, q{});
  ($atoms_file, $feff_file) = ($file, File::Spec->catfile(dirname($file), 'feff.inp')) if ($$rdemeter->is_atoms($file));
  ($atoms_file, $feff_file) = (q{}, $file)                                             if ($$rdemeter->is_feff($file));
  ($atoms_file = File::Spec->catfile(dirname($file), 'atoms.inp')) if ((not $atoms_file) and (-e File::Spec->catfile(dirname($file), 'atoms.inp')));

  if (not -e $feff_file) {
    my $message = <<EOH
Error importing external Feff calculation.

It is unclear which file is the Feff input file.
It is likely that you selected the Atoms input
file in the file selection dialog.  You should
select the Feff input file instead.

EOH
      ;
    my $error = Wx::MessageDialog->new($rframes->{main},
				       $message,
				       "Error importing Feff calculation",
				       wxOK|wxICON_ERROR);
    my $result = $error->ShowModal;
    $rframes->{main}->status("Importing external Feff calculation aborted.");
    return 0;
  };

  my ($filename, $pathto, $suffix) = fileparse($file, qr{\.inp});
  if (lc($filename) eq 'feff') {
    my @dirs = File::Spec->splitdir($pathto);
    $filename = $dirs[-1];
    $filename = $dirs[-2] if ($filename =~ m{\A\s*\z});
  };
  my $efeff = Demeter::Feff::External -> new(screen=>0, name=>$filename);
  my $destination = File::Spec->catfile($rframes->{main}->{project_folder}, 'feff', $efeff->group);
  $efeff->workspace($destination);
  $efeff->file($feff_file);
  if (not $efeff->is_complete) {
    my $message = "Error importing external Feff calculation:\n\n"
                . $efeff->problem
		. "\nTherefore $file cannot be imported as an external Feff calculation.\n";
    my $error = Wx::MessageDialog->new($rframes->{main},
				       $message,
				       "Error importing Feff calculation",
				       wxOK|wxICON_ERROR);
    my $result = $error->ShowModal;
    $rframes->{main}->status("Importing external Feff calculation aborted.");
    return 0;
  };


  copy($atoms_file, File::Spec->catfile($destination, 'atoms.inp')) if $atoms_file;
  copy($feff_file, File::Spec->catfile($destination, $efeff->group.'.inp'));
  $efeff->freeze(File::Spec->catfile($destination, $efeff->group.'.yaml'));

  ## import atoms.inp, create Feff frame
  my ($fnum, $ifeff) = &$make_feff_frame($rframes->{main}, $atoms_file, $efeff->name, $efeff);

  ## import feff.inp
  my $text = $efeff->slurp($feff_file);
  $rframes->{$fnum}->make_page('Feff')  if not $rframes->{$fnum}->{Feff};
  $rframes->{$fnum}->make_page('Paths') if not $rframes->{$fnum}->{Paths};
  $rframes->{$fnum}->{Feff}->{feff}->SetValue($text);

  ## fill in Feff frame
  $rframes->{$fnum}->{Feff}->{feffobject} = $efeff;
  $rframes->{$fnum}->{Feff}->fill_intrp_page($efeff);
  $rframes->{$fnum}->{notebook}->ChangeSelection(2);

  $rframes->{$fnum}->{Feff} ->{name}->SetValue($efeff->name);
  $rframes->{$fnum}->{Paths}->{name}->SetValue($efeff->name);

  $rframes->{$fnum} -> Show(not $noshow);
  $rframes->{main}->{$fnum}->SetValue(not $noshow);
  my $word = ($noshow) ? 'Show ' : 'Hide ';
  $rframes->{main}->{$fnum}->SetLabel($word.emph($efeff->name));

  ## disable atoms tab is not $atoms_file (how?)

  $$rdemeter->push_mru("externalfeff", $file);
  autosave();
  chdir dirname($file);
  modified(1);
  $rframes->{main}->status("Imported $file as a Feff calculation.");
  return $efeff;
};


sub _old {
  my ($file) = @_;
  $file ||= q{};
  if (not -e $file) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an old-style Artemis project", cwd, q{},
				  "old-style Artemis project (*.apj)|*.apj|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("old-style Artemis import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };
  $file = Demeter->follow_link($file);

  if (not $$rdemeter->is_zipproj($file,0, 'apj')) {
    $rframes->{main}->status("$file is not an old style fitting project file.", 'error');
    return;
  };

  my $busy = Wx::BusyCursor->new();
  $rframes->{main}->status("Converting old-style project to Demeter fit serialization", 'wait');

  my $tempfit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  my $dpj = File::Spec->catfile($tempfit->stash_folder, basename($file, '.apj').".dpj");
  my $journal = q{};
  my $result = $tempfit -> apj2dpj($file, $dpj, \$journal);
  $tempfit   -> DEMOLISH;

  if (ref($result) !~ m{Fit}) {
    $rframes->{main}->status($result, 'alert');
    undef $busy;
    return;
  };

  $rframes->{main}->status("Importing Demeter fit serialization", 'wait');
  Import('dpj', $dpj, postcrit=>0);
  unlink $dpj;

  $$rdemeter->push_mru("old_artemis", $file);
  $rframes->{main}->{projectpath} = $file;
  $rframes->{main}->{projectname} = basename($file, '.apj');
  $rframes->{Journal}->{journal} -> SetValue($journal);

  modified(1);
  $rframes->{main}->status("Imported old-style Artemis project $file");
  undef $busy;
};


sub _feffit {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import a Feffit input file", cwd, q{},
				  "Feffit input (*.inp)|*.inp|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->status("Feffit import canceled.");
      return;
    };
    $file = $fd->GetPath;
  };
  if (not -e $file) {
    $rframes->{main}->status("$file does not exist.");
    return;
  };
  if (not -r $file) {
    $rframes->{main}->status("$file cannot be read.");
    return;
  };
  $file = Demeter->follow_link($file);

  ## -------- want to skip autosave during the intermediate steps of the feffit import
  $Demeter::UI::Artemis::noautosave = 1;
  my $inp = Demeter::Fit::Feffit->new(file=>$file);
  my $fit = $inp -> convert;
  my $mds = 0;
  my %datae_id = (); # \ disentangle relations
  my %feffs = ();    # / between objects

  ## -------- figure out how many Feff calculations are involved
  my %folders_seen = ();
  foreach my $p (@ {$fit->paths} ) {
    ++$folders_seen{$p->folder};
  };

  ## -------- import each as an External::Feff
  foreach my $f (keys %folders_seen) {
    my $inp = File::Spec->catfile($f, 'feff.inp');
    if (not -e $inp) {
      $Demeter::UI::Artemis::noautosave = 0;
      $inp->DESTROY;
      $fit->DESTROY;
      my $error = Wx::MessageDialog->new($rframes->{main},
					 "Cannot import Feff calculation from $f. Could not find the 'feff.inp' file.",
					 "Error importing feffit file",
					 wxOK|wxICON_ERROR);
      my $result = $error->ShowModal;
      $rframes->{main}->status("Importing feffit.inp file aborted.");
      return 0;
    };
    my $ef = _external_feff($inp, 1);
    return 0 if not $ef;
    ## -------- check that external feff is complete
    $feffs{$f} = $ef;
  };

  ## -------- import the data and populate data windows
  foreach my $d (@ {$fit->data} ) {
    if (not -e $d->file) {
      $Demeter::UI::Artemis::noautosave = 0;
      $feffs{$_}->DESTROY foreach keys(%feffs);
      $inp->DESTROY;
      $fit->DESTROY;
      my $error = Wx::MessageDialog->new($rframes->{main},
					 "Cannot find data file ".$d->file,
					 "Error importing feffit.inp file",
					 wxOK|wxICON_ERROR);
      my $result = $error->ShowModal;
      $rframes->{main}->status("Importing feffit.inp file aborted.");
      return 0;
    };
    my ($dnum, $idata) = &$make_data_frame($rframes->{main}, $d);
    $d->_update('fft');
    $rframes->{$dnum} -> populate($d);
    my $show = ($mds) ? 0 : 1;
    $rframes->{$dnum} -> Show($show);
    $datae_id{$d->group} = $dnum;
    $rframes->{main}->{$dnum}->SetValue($show);
    ++$mds;
  };

  ## -------- reassign theory to each Path, blanking folder and file attributes, setting sp attribute
  foreach my $p (@ {$fit->paths} ) {
    my ($file, $folder) = ($p->file, $p->folder);
    my $thisnnnn = File::Spec->catfile($folder, $file);
    if (not -e $thisnnnn) {
      $Demeter::UI::Artemis::noautosave = 0;
      $feffs{$_}->DESTROY foreach keys(%feffs);
      $inp->DESTROY;
      $fit->DESTROY;
      my $error = Wx::MessageDialog->new($rframes->{main},
					 "Cannot find feffNNNN.dat file ".$thisnnnn,
					 "Error importing feffit.inp calculation file",
					 wxOK|wxICON_ERROR);
      my $result = $error->ShowModal;
      $rframes->{main}->status("Importing feffit.inp file aborted.");
      return 0;
    };
    $p -> set(file=>q{}, folder=>q{});
    $p -> parent($feffs{$folder});
    foreach my $sp (@{ $$rdemeter->mo->ScatteringPath }) {
      if ($sp->fromnnnn eq File::Spec->catfile($folder, $file)) {
	$p->sp($sp);
	last;
      };
    };
    ## -------- populate data frame with paths
    my $book = $rframes->{$datae_id{$p->data->group}}->{pathlist};
    $book->DeletePage(0) if ($rframes->{$datae_id{$p->data->group}}->{pathlist}->GetPage(0) =~ m{Panel});
    my $page = Demeter::UI::Artemis::Path->new($book, $p, $rframes->{$datae_id{$p->data->group}});
    $book->AddPage($page, $p->label, 1, 0);
    $page->include_label;
  };

  ## -------- populate the GDS window
  foreach my $thisgds (@ {$fit->gds} ) {
    $rframes->{GDS}->put_gds($thisgds);
    $rframes->{GDS}->{grid} -> {$thisgds->name} = $thisgds;
    $thisgds->push_ifeffit;
  };

  $rframes->{Journal}->{journal}->SetValue($file . ":\n\n" . $fit->slurp($file));

  ## -------- clean up and finish up
  $inp->DESTROY;
  $fit->DESTROY;
  $Demeter::UI::Artemis::noautosave = 0;
  autosave;
  $$rdemeter->push_mru("feffit", $file);
  chdir dirname($file);
  my $newfit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  $rframes->{main} -> {currentfit} = $newfit;
  ++$Demeter::UI::Artemis::fit_order{order}{current};
  modified(1);
  $rframes->{main}->status("Imported old-skool Feffit input: $file");
};

1;

=head1 NAME

Demeter::UI::Artemis::Import - Import various kinds of data into Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module exports the C<Import> method, which is used to import
various kinds of data into Artemis.

=head1 METHODS

=over 4

=item C<Import>

Import a specific data type.

  import($type, $filename);

If the filename is omitted, the user will be prompted for a file using
the file selection dialog.  The type can be one of:

=over 4

=item C<prj> or C<athena>

An Athena project file

=item C<chi>

A column data file containing chi(k) data.  If the data are on a
non-standard grid, they will be rebinned onto the proper grid.

=item C<dpj>

A serialization file from a Fit object.  This sort of file is
generated from a free-standing script using Demeter.

=item C<feff>

A F<feff.inp> file, an F<atoms.inp> file, or a CIF file.

=item C<external>

An entire Feff calculation.  Note that a F<feff.inp> file by itself can be imported using 

=item C<old>

An project file from the Tk version of Artemis.

=back

=item C<prjrecord>

Post a dialog prompting for a record in an Athena project file.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Not handling local parameters from feffit.inp files

=item *

While single-data-set fits with multiple k-weights does work
correctly, MDS+MKW fits will not be imported properly from a
feffit.inp file

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
