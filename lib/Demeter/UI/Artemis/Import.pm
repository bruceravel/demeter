package Demeter::UI::Artemis::Import;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Artemis::Project;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

## -------- convenience parameters
use Readonly;
Readonly my $rdemeter        => \$Demeter::UI::Artemis::demeter;
Readonly my $rframes         => \%Demeter::UI::Artemis::frames;
Readonly my $make_data_frame => \&Demeter::UI::Artemis::make_data_frame;
Readonly my $make_feff_frame => \&Demeter::UI::Artemis::make_feff_frame;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Import prjrecord);


sub Import {
  my ($which, $fname) = @_;
  my $retval = q{};
 SWITCH: {
    $retval = _prj($fname),           last SWITCH if (($which eq 'prj') or ($which eq 'athena'));
    $retval = _old($fname),           last SWITCH if  ($which eq 'old');
    $retval = _feff($fname),          last SWITCH if  ($which eq 'feff');
    $retval = _external_feff($fname), last SWITCH if  ($which eq 'external');
    $retval = _chi($fname),           last SWITCH if  ($which eq 'chi');
    $retval = _feffit($fname),        last SWITCH if  ($which eq 'feffit');
  };
  return $retval;
};


sub prjrecord {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Athena project", cwd, q{},
				  "Athena project (*.prj)|*.prj|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Data import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  }
  ##
  my $selection = 0;
  $rframes->{prj} =  Demeter::UI::Artemis::Prj->new($rframes->{main}, $file);
  my $result = $rframes->{prj} -> ShowModal;

  if (
      ($result == wxID_CANCEL) or     # cancel button clicked
      ($rframes->{prj}->{record} == -1)  # import button without selecting a group
     ) {
    return (q{}, q{});
  };

  return ($file, $rframes->{prj}->{prj}, $rframes->{prj}->{record});
};

##############################################################################################################
## the "private" functions for specific import chores follow ...
##############################################################################################################

sub _prj {
  my ($fname) = @_;
  my ($file, $prj, $record) = prjrecord($fname);

  if ((not $prj) or (not $record)) {
    $rframes->{main}->{statusbar}->SetStatusText("Data import cancelled.");
    return;
  };

  my $data = $prj->record($record);
  my ($dnum, $idata) = &$make_data_frame($rframes->{main}, $data);
  $data->po->start_plot;
  $data->plot('k');
  $rframes->{$dnum} -> Show(1);
  $rframes->{main}->{$dnum}->SetValue(1);
  $prj->DESTROY;
  delete $rframes->{prj};
  $$rdemeter->push_mru("athena", $file);
  autosave();
  chdir dirname($file);
  $rframes->{main}->{statusbar}->SetStatusText("Importing data \"" . $data->name . "\" from $file.");
};


sub _feff {
  my ($fname) = @_;
  ## also yaml data
  my $file = $fname;
  if (not $file) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import crystal data", cwd, q{},
				  "input and CIF files (*.inp;*.cif)|*.inp;*.cif|input file (*.inp)|*.inp|CIF file (*.cif)|*.cif|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Crystal/Feff data import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  if (not -e $file) {
    $rframes->{main}->{statusbar}->SetStatusText("$file does not exist.");
    return;
  };
  if (not ($$rdemeter->is_feff($file) or $$rdemeter->is_atoms($file) or $$rdemeter->is_cif($file))) {
    $rframes->{main}->{statusbar}->SetStatusText("$file does not seem to be a Feff input file, an Atoms input file, or a CIF file");
    return;
  };

  my ($fnum, $ifeff) = &$make_feff_frame($rframes->{main}, $file);
  $rframes->{$fnum} -> Show(1);
  autosave();
  $rframes->{$fnum}->{statusbar}->SetStatusText("Imported crystal data from " . basename($file));
  $rframes->{main}->{$fnum}->SetValue(1);
};


sub _chi {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import $CHI(k) data", cwd, q{},
				  "Chi data (*.chi)|*.chi|Data files (*.dat)|*.dat|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("$CHI(k) import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  my $data = Demeter::Data->new(file=>$file);
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
  $rframes->{main}->{statusbar}->SetStatusText("Imported $file as $CHI(k) data.");
};


## need better reaction in case of absent phase.bin file.
sub _external_feff {
  my ($fname, $noshow) = @_;
  my $file = $fname;
  $noshow ||= 0;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an Atoms or Feff input file", cwd, q{},
				  "Atoms/Feff input (*.inp)|*.inp|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("$CHI(k) import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
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
    $rframes->{main}->{statusbar}->SetStatusText("Importing external Feff calculation aborted.");
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
    $rframes->{main}->{statusbar}->SetStatusText("Importing external Feff calculation aborted.");
    return 0;
  };


  copy($atoms_file, File::Spec->catfile($destination, 'atoms.inp')) if $atoms_file;
  copy($feff_file, File::Spec->catfile($destination, $efeff->group.'.inp'));
  $efeff->freeze(File::Spec->catfile($destination, $efeff->group.'.yaml'));

  ## import atoms.inp, create Feff frame
  my ($fnum, $ifeff) = &$make_feff_frame($rframes->{main}, $atoms_file, $efeff->name, $efeff);

  ## import feff.inp
  my $text = $efeff->slurp($feff_file);
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
  $rframes->{main}->{statusbar}->SetStatusText("Imported $file as a Feff calculation.");
  return $efeff;
};


sub _old {
  my ($file) = @_;
  $file ||= q{};
  if (not -e $file) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import an old-style Artemis project", cwd, q{},
				  "old-style Artemis project (*.apj)|*.apj|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("old-style Artemis import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };

  ## -------- make a folder to unzip the old-style project and unzip it
  my $unzip = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, '_old_'.basename($file));
  rmtree $unzip if (-d $unzip);
  mkpath $unzip;
  my $zip = Archive::Zip->new();
  confess("Error reading old-style project file $file"), return 1 unless ($zip->read($file) == AZ_OK);
  $zip->extractTree("", $unzip.'/');
  undef $zip;

  my $cpt = new Safe;
  my $description = File::Spec->catfile($unzip, 'descriptions', 'artemis');
  my %datae = ();
  my %datae_id = ();
  my %feffs = ();
  my $mds = 0;

  ## -------- make a new Fit object
  my $fit = Demeter::Fit->new(interface=>"Artemis (Wx)");
  $rframes->{main}->{currentfit} = $fit;
  $rframes->{Plot}->{limits}->{fit}->SetValue(1);
  $fit->mo->currentfit(1);
  my $projfolder = $rframes->{main}->{project_folder};
  mkpath(File::Spec->catfile($projfolder, 'fits', $fit->group));

  ## -------- begin parsing the description file
  open(my $D, $description);
  while (<$D>) {
    next if (m{\A\s*\z});
    next if (m{\A\s*\#});
    next if (m{\A\s*\[record\]});

  SWITCH: {

      ## -------- this section contains data, feff, or path...
      (m{\A\$old_path}) and do {
	$ {$cpt->varglob('old_group')} = $cpt->reval( $_ );
	my $og = $ {$cpt->varglob('old_group')};
	## get args line
	my $line = <$D>;
	@ {$cpt->varglob('args')} = $cpt->reval( $line );
	my %args = @ {$cpt->varglob('args')};
	## get string line
	$line = <$D>;
	@ {$cpt->varglob('strings')} = $cpt->reval( $line );
	my @strings = @ {$cpt->varglob('strings')};

	## -------- this is data
	if ($og =~ m{\Adata\d+\z}) {
	  my $datafile = File::Spec->catfile($unzip, 'chi_data', basename($args{file}));
	  my $data = Demeter::Data->new(datatype       => 'chi',
					file	       => $datafile,
					name	       => $args{lab},
					bkg_rbkg       => $args{bkg_rbkg} || 0,
					fit_k1	       => $args{k1},
					fit_k2	       => $args{k2},
					fit_k3	       => $args{k3},
					fit_karb       => $args{karb},
					fit_karb_value => $args{karb_use},
					fft_kmin       => $args{kmin},
					fft_kmax       => $args{kmax},
					fft_dk	       => $args{dk},
					fft_kwindow    => $args{kwindow},
					bft_rmin       => $args{rmin},
					bft_rmax       => $args{rmax},
					bft_dr	       => $args{dr},
					bft_rwindow    => $args{rwindow},
					fit_space      => $args{fit_space},
					fit_epsilon    => $args{epsilon_k},
					fit_cormin     => $args{cormin},
					fit_include    => $args{include},
					provenance     => 'chi(k) data from an old-style artemis project file',
				       );
	  $datae{$og} = $data;
	  $data -> fit_do_bkg($data->onezero($args{do_bkg}));
	  $data -> titles(\@strings);
	  my ($dnum, $idata) = &$make_data_frame($rframes->{main}, $data);
	  $data->_update('fft');
	  $rframes->{$dnum} -> populate($data);
	  my $show = ($mds) ? 0 : 1;
	  $rframes->{$dnum} -> Show($show);
	  $datae_id{$og} = $dnum;
	  $rframes->{main}->{$dnum}->SetValue($show);
	  ++$mds;

	## -------- this is Feff
	} elsif ($og =~ m{feff\d+\z}) {
	  my $pathto = File::Spec->catfile($unzip, $og);
	  my $efeff = Demeter::Feff::External -> new(screen=>0, name=>$args{lab});
	  my $destination = File::Spec->catfile($projfolder, 'feff', $efeff->group);
	  $efeff->workspace($destination);

	  $efeff->file(File::Spec->catfile($pathto, 'feff.inp'));
	  copy(File::Spec->catfile($pathto, 'atoms.inp'), File::Spec->catfile($destination, 'atoms.inp')) 
	    if (-e File::Spec->catfile($pathto, 'atoms.inp'));
	  copy(File::Spec->catfile($pathto, 'feff.inp'), File::Spec->catfile($destination, $efeff->group.'.inp'));
	  $efeff->freeze(File::Spec->catfile($destination, $efeff->group.'.yaml'));

	  ## import atoms.inp
	  #if (-e File::Spec->catfile($pathto, 'atoms.inp')) {
	    my $atoms = File::Spec->catfile($pathto, 'atoms.inp');
	    my ($fnum, $ifeff) = Demeter::UI::Artemis::make_feff_frame($rframes->{main}, $atoms, $efeff->name, $efeff);
	  #};

	  ## import feff.inp
	  my $feff = File::Spec->catfile($pathto, 'feff.inp');
	  my $text = $efeff->slurp($feff);
	  $rframes->{$fnum}->{Feff}->{feff}->SetValue($text);

	  ## make Feff frame
	  $feffs{$og} = $efeff;
	  $rframes->{$fnum}->{Feff}->{feffobject} = $efeff;
	  $rframes->{$fnum}->{Feff}->fill_intrp_page($efeff);
	  $rframes->{$fnum}->{notebook}->ChangeSelection(2);

	  $rframes->{$fnum}->{Feff} ->{name}->SetValue($efeff->name);
	  $rframes->{$fnum}->{Paths}->{name}->SetValue($efeff->name);

	  #$rframes->{$fnum} -> Show(0);
	  #$rframes->{main}->{$fnum}->SetValue(0);

	## -------- this is a path  dataN.feffM.P
	} elsif ($og =~ m{feff\d+\.\d+\z}) {
	  my ($this_data, $this_feff, $pathid) = split(/\./, $og);
	  my $nnnn = $args{feff};
	  my $feff_group = join('.', $this_data, $this_feff);
	  my $path = Demeter::Path->new(data	=> $datae{$this_data},
					parent	=> $feffs{$feff_group},
					degen	=> $args{n} || $args{deg}, # which is right?
					s02	=> $args{s02},
					e0	=> $args{e0},
					delr	=> $args{delr},
					sigma2	=> $args{'sigma^2'},
					ei	=> $args{ei},
					third	=> $args{'3rd'},
					fourth	=> $args{'4th'},
					dphase	=> $args{dphase},
					include => $args{include},
				       );
	  $path -> sp($path->mo->fetch("ScatteringPath", $feffs{$feff_group}->get_nnnn($nnnn)));
	  my $label = $args{lab};
	  my $book = $rframes->{$datae_id{$this_data}}->{pathlist};
	  $book->DeletePage(0) if ($rframes->{$datae_id{$this_data}}->{pathlist}->GetPage(0) =~ m{Panel});
	  my $page = Demeter::UI::Artemis::Path->new($book, $path, $rframes->{$datae_id{$this_data}});
	  $book->AddPage($page, $label, 1, 0);
	  $page->include_label;
	};

	last SWITCH;
      };

      ## -------- this line defines a GDS parameter
      (m{\A\@parameter}) and do {
	@ {$cpt->varglob('parameter')} = $cpt->reval( $_ );
	my @parameter = @ {$cpt->varglob('parameter')};
 	my $thisgds = Demeter::GDS->new(gds     => $parameter[1],
 					name    => $parameter[0],
 					mathexp => $parameter[2],
 				       );
	$rframes->{GDS}->put_gds($thisgds);
 	$rframes->{GDS}->{grid} -> {$thisgds->name} = $thisgds;
	last SWITCH;
      };

      ## -------- this section contain the plotting parameters
      (m{\A\%plot_features}) and do {
	% {$cpt->varglob('plot_features')} = $cpt->reval( $_ );
	my %pf = % {$cpt->varglob('plot_features')};
	foreach my $p (qw(kmin kmax rmin rmax qmin qmax)) {
	  $rframes->{Plot}->{limits}->{$p}->SetValue($pf{$p});
	};
	$rframes->{Plot}->{kweight}->SetSelection($pf{kweight}) if ($pf{kweight} =~ m{[0123]});
	last SWITCH;
      };

      ## -------- indicators
      (m{\A\@extra}) and do {
	last SWITCH;
      };

      ## -------- project properties
      (m{\A\%props}) and do {
	% {$cpt->varglob('props')} = $cpt->reval( $_ );
	my %props = % {$cpt->varglob('props')};
	$rframes->{main}->{name}->SetValue($props{'Project title'});
	$rframes->{main}->{description}->SetValue($props{'Comment'});
	$rframes->{main}->{currentfit}->contact($props{Contact});
	$rframes->{main}->{currentfit}->prepared_by($props{'Prepared by'});
	$rframes->{main}->{currentfit}->started($props{Started});
	$rframes->{main}->{currentfit}->time_of_fit($props{'Last fit'});
	last SWITCH;
      };

    };
  };
  close $D;

  ## -------- finally, import the journal
  my $journal = File::Spec->catfile($unzip, 'descriptions', 'journal.artemis');
  $rframes->{Journal}->{journal}->SetValue($fit->slurp($journal));

  ## -------- clean up and finish
  rmtree $unzip if (-d $unzip);
  $rframes->{main}->{projectname} = basename($file, qw(.apj));
  autosave;
  $$rdemeter->push_mru("old_artemis", $file);
  chdir dirname($file);
  modified(1);
  $rframes->{main}->{statusbar}->SetStatusText("Imported old-style Artemis project $file");

};


sub _feffit {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $rframes->{main}, "Import a Feffit input file", cwd, q{},
				  "Feffit input (*.inp)|*.inp|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $rframes->{main}->{statusbar}->SetStatusText("Feffit import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  if (not -e $file) {
    $rframes->{main}->{statusbar}->SetStatusText("$file does not exist.");
    return;
  };
  if (not -r $file) {
    $rframes->{main}->{statusbar}->SetStatusText("$file cannot be read.");
    return;
  };

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
      $rframes->{main}->{statusbar}->SetStatusText("Importing feffit.inp file aborted.");
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
      $rframes->{main}->{statusbar}->SetStatusText("Importing feffit.inp file aborted.");
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
      $rframes->{main}->{statusbar}->SetStatusText("Importing feffit.inp file aborted.");
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
  modified(1);
  $rframes->{main}->{statusbar}->SetStatusText("Imported old-skool Feffit input: $file");
};

1;

=head1 NAME

Demeter::UI::Artemis::Import - Import various kinds of data into Artemis

=head1 VERSION

This documentation refers to Demeter version 0.4.

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

Not handling local parameters

=item *

While single-data-set fits with multiple k-weights does work
correctly, MDS+MKW fits will not be imported properly.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
