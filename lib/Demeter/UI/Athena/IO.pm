package Demeter::UI::Athena::IO;

use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ColumnSelection;
use Demeter::UI::Artemis::Prj;

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw(any);

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Import Export save_column save_marked save_each);

sub Export {
  my ($app, $how, $fname) = @_;
  return if $app->is_empty;

  my @data;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and not $app->{main}->{list}->IsSelected($i));
    push @data, $app->{main}->{list}->GetClientData($i);
  };
  if (not @data) {
    $app->{main}->status("Saving marked groups to a project cancelled -- no marked groups.");
    return;
  };
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Save project file", cwd, q{athena.prj},
				  "Athena project (*.prj)|*.prj|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Saving project cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };

  #$app->{main}->{Main}->pull_values($app->current_data);
  $app->{main}->{Journal}->{object}->text($app->{main}->{Journal}->{journal}->GetValue);
  $data[0]->write_athena($fname, @data, $app->{main}->{Journal}->{object});
  $data[0]->push_mru("xasdata", $fname);
  $app->set_mru;
  $app->{main}->{project}->SetLabel(basename($fname, '.prj'));
  $app->{main}->{currentproject} = $fname;
  $app->modified(0);
  my $extra = ($how eq 'marked') ? " with marked groups" : q{};
  $app->{main}->status("Saved project file $fname".$extra);
  return $fname;
};

sub Import {
  my ($app, $fname) = @_;
  my $retval = q{};

  $app->{main}->{views}->SetSelection(0);

  my @files = ($fname);
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Import data", cwd, q{},
				  "All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW|wxFD_MULTIPLE,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Data import cancelled.");
      return;
    };
    @files = map {File::Spec->catfile($fd->GetDirectory, $_)} $fd->GetFilenames;
  };

  my $verbose = 0;
  ## check for registerd filetypes here
  ## also xmu.dat
  ## evkev?
  my $first = 1;
  foreach my $file (sort {$a cmp $b} @files) {
    my $type = ($Demeter::UI::Athena::demeter->is_prj($file,$verbose))  ? 'prj'
	     : ($Demeter::UI::Athena::demeter->is_data($file,$verbose)) ? 'raw'
	     :                                                            '???';
    if ($type eq '???') {
      $app->{main}->status("Could not read \"$file\" as either data or a project file.");
      return;
    };

  SWITCH: {
      $retval = _prj($app, $file, $first),  last SWITCH if ($type eq 'prj');
      $retval = _data($app, $file, $first), last SWITCH if ($type eq 'raw');
    };
    $first = 0;
  };
  return;
};

sub Import_plot {
  my ($app, $data) = @_;
  my $how = lc($data->co->default('athena', 'import_plot'));
  $data->po->start_plot;
  if ($how eq 'quad') {
    $app->quadplot($data);
  } elsif ($how eq 'k123') {
    $app->{main}->{PlotK}->pull_single_values;
    $data->plot('k123');
  } elsif ($how eq 'r123') {
    $app->{main}->{PlotR}->pull_single_values;
    $data->plot('k123');
  } elsif ($how =~ m{\A[ekrq]\z}) {
    $app->plot(0, 0, $how, 'single');
  }; # else $how is none
  return;
};

sub _data {
  my ($app, $file, $first) = @_;

  my $busy = Wx::BusyCursor->new();
  my $data = Demeter::Data->new(file=>$file);

  ## -------- import persistance file
  my $persist = File::Spec->catfile($data->dot_folder, "athena.column_selection");
  $data -> set(name	   => basename($file),
	       is_col      => 1,
	       energy      => '$1',
	       numerator   => 1,
	       denominator => 1,
	       display	   => 1);
  $data->guess_columns;
  my $yaml;
  $yaml->{columns} = q{};
  if (-e $persist) {
    $yaml = YAML::Tiny::Load($data->slurp($persist));
    if ($data->columns eq $yaml->{columns}) {
      $data -> set(energy      => $yaml->{energy}||'$1',
		   numerator   => $yaml->{numerator}||'1',
		   denominator => $yaml->{denominator}||'1',
		   ln          => $yaml->{ln},
		   ##is_kev      => $yaml->{units},
		   ##datatype
		  );
    };
  };

  ## -------- display column selection dialog
  my $repeated = 1;
  my $colsel;
  if ($first or ($data->columns ne $yaml->{columns})) {
    $colsel = Demeter::UI::Athena::ColumnSelection->new($app->{main}, $app, $data);
    $colsel->{ok}->SetFocus;
    ## set Reference controls from yaml
    if ($data->columns eq $yaml->{columns}) {
      $colsel->{Reference}->{do_ref}->SetValue($yaml->{do_ref});
      $colsel->{Reference}->{ln}    ->SetValue($yaml->{ref_ln});
      $colsel->{Reference}->{same}  ->SetValue($yaml->{ref_same});
      if (($yaml->{ref_numer}) and exists($colsel->{Reference}->{'n'.$yaml->{ref_numer}}))  {
	$colsel->{Reference}->{'n'.$yaml->{ref_numer}}->SetValue(1);
	$colsel->{Reference}->{numerator}   = $yaml->{ref_numer};
      };
      if (($yaml->{ref_denom}) and exists($colsel->{Reference}->{'d'.$yaml->{ref_denom}})) {
	$colsel->{Reference}->{'d'.$yaml->{ref_denom}}->SetValue(1);
	$colsel->{Reference}->{denominator} = $yaml->{ref_denom};
      };
      $colsel->{Reference}->EnableReference(0, $data);
    };
    ## set Rebinning controls from yaml
    foreach my $w (qw(do_rebin abs emin emax pre xanes exafs)) {
      my $key = ($w eq 'do_rebin') ? $w : 'rebin_'.$w;
      $colsel->{Rebin}->{$w}->SetValue($yaml->{$key});
      last if (any {$w eq $_} qw(do_rebin abs));
      $data->co->set_default('rebin', $w);
    };
    if ($data->columns ne $yaml->{columns}) {
      $colsel->{Rebin}->{do_rebin}->SetValue(0)
    };
    $colsel->{Rebin}->EnableRebin(0, $data);
    ## set Preprocessing controls from yaml

    my $result = $colsel -> ShowModal;
    if ($result == wxID_CANCEL) {
      $app->{main}->status("Cancelled column selection.");
      $data->dispose("erase \@group ".$data->group);
      $data->DEMOLISH;
      return;
    };
    $repeated = 0;
  };

  ## -------- import data group
  $app->{main}->status("Importing ". $data->name . " from $file");
  $app->{main}->Update;
  $data -> display(0);
  my $do_rebin = (defined $colsel) ? ($colsel->{Rebin}->{do_rebin}->GetValue) : $yaml->{do_rebin};
  if ($yaml->{do_rebin}) {
    my $rebin  = $data->rebin;
    foreach my $att (qw(energy numerator denominator ln )) {
      $rebin->$att($data->$att);
    };
    $data->dispose("erase \@group ".$data->group);
    $data->DEMOLISH;
    $data = $rebin;
  };
  $data -> po -> e_markers(1);
  $data -> _update('all');
  $app->{main}->{list}->Append($data->name, $data);
  if (not $repeated) {
    $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
    #$app->{selected} = $app->{main}->{list}->GetSelection;
    $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
    $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection);
    Import_plot($app, $data);
  };
  $data->push_mru("xasdata", $file);
  $app->set_mru;

  ## -------- import reference if reference channel is set
  my $do_ref = (defined $colsel) ? ($colsel->{Reference}->{do_ref}->GetValue) : $yaml->{do_ref};
  if ($do_ref) {
    $app->{main}->status("Importing reference for ". $data->name);
    $app->{main}->Update;
    my $ref = $colsel->{Reference}->{reference};
    $ref->display(0);
    if ($colsel->{Rebin}->{do_rebin}->GetValue) {
      my $rebin  = $ref->rebin;
      foreach my $att (qw(energy numerator denominator ln )) {
	$rebin->$att($ref->$att);
      };
      $ref->dispose("erase \@group ".$ref->group);
      $ref->DEMOLISH;
      $ref = $rebin;
    };
    $ref -> _update('fft');
    $app->{main}->{list}->Append($ref->name, $ref);
    $app->{main}->{Main}->{bkg_eshift}-> SetBackgroundColour( Wx::Colour->new($ref->co->default("athena", "tied")) );
    $ref->reference($data);
    if ($colsel->{Reference}->{same}) {
      $ref->bkg_z($data->bkg_z);
      $ref->fft_edge($data->fft_edge);
    };
  };

  ## -------- save persistance file
  my %persistence = (
		     columns	 => $data->columns,
		     energy	 => $data->energy,
		     numerator	 => $data->numerator,
		     denominator => $data->denominator,
		     ln		 => $data->ln,
		     each        => 0,
		     datatype    => $data->datatype,
		     units       => $data->is_kev,);
  ## reference
  $persistence{do_ref}      = (defined($colsel)) ? $colsel->{Reference}->{do_ref}->GetValue : $yaml->{do_ref};
  $persistence{ref_ln}      = (defined($colsel)) ? $colsel->{Reference}->{ln}->GetValue     : $yaml->{ref_ln};
  $persistence{ref_same}    = (defined($colsel)) ? $colsel->{Reference}->{same}->GetValue   : $yaml->{ref_same};
  $persistence{ref_numer}   = (defined($colsel)) ? $colsel->{Reference}->{numerator}        : $yaml->{ref_numer};
  $persistence{ref_denom}   = (defined($colsel)) ? $colsel->{Reference}->{denominator}      : $yaml->{ref_denom};
  ## rebin
  $persistence{do_rebin}    = (defined($colsel)) ? $colsel->{Rebin}->{do_rebin}->GetValue   : $yaml->{do_rebin};
  $persistence{rebin_abs}   = (defined($colsel)) ? $colsel->{Rebin}->{abs}->GetValue        : $yaml->{rebin_abs};
  $persistence{rebin_emin}  = (defined($colsel)) ? $colsel->{Rebin}->{emin}->GetValue       : $yaml->{rebin_emin};
  $persistence{rebin_emax}  = (defined($colsel)) ? $colsel->{Rebin}->{emax}->GetValue       : $yaml->{rebin_emax};
  $persistence{rebin_pre}   = (defined($colsel)) ? $colsel->{Rebin}->{pre}->GetValue        : $yaml->{rebin_pre};
  $persistence{rebin_xanes} = (defined($colsel)) ? $colsel->{Rebin}->{xanes}->GetValue      : $yaml->{rebin_xanes};
  $persistence{rebin_exafs} = (defined($colsel)) ? $colsel->{Rebin}->{exafs}->GetValue      : $yaml->{rebin_exafs};

  my $string .= YAML::Tiny::Dump(\%persistence);
  open(my $ORDER, '>'.$persist);
  print $ORDER $string;
  close $ORDER;

  ## -------- last chores before finishing
  chdir dirname($file);
  $app->modified(1);
  undef $busy;
  undef $colsel;
  undef $yaml;
}

sub _prj {
  my ($app, $file, $first) = @_;
  my $busy = Wx::BusyCursor->new();

  $app->{main}->{prj} =  Demeter::UI::Artemis::Prj->new($app->{main}, $file, 'Multiple');
  $app->{main}->{prj}->{import}->SetFocus;
  my $result = $app->{main}->{prj} -> ShowModal;

  if ($result == wxID_CANCEL)  {
    $app->{main}->status("Canceled import from project file.");
    return;
  };

  my @selected = $app->{main}->{prj}->{grouplist}->GetSelections;
  @selected = (0 .. $app->{main}->{prj}->{grouplist}->GetCount-1) if not @selected;

  my @records = map {$_ + 1} @selected;
  my $prj = $app->{main}->{prj}->{prj};

  my $count = 1;
  my $data;
  foreach my $rec (@records) {
    $data = $prj->record($rec);
    $app->{main}->status("Importing ". $data->prjrecord, "nobuffer");
    $app->{main}->Update;
    $app->{main}->{list}->Append($data->name, $data);
    if ($count == 1) {
      $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
      #$app->{selected} = $app->{main}->{list}->GetSelection;
      $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
      $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection);
      Import_plot($app, $data);
    };
    ++$count;
  };
  $app->{main}->{Journal}->{object}->text($prj->journal);
  $app->{main}->{Journal}->{journal}->SetValue($app->{main}->{Journal}->{object}->text);

  $data->push_mru("xasdata", $file);
  $app->set_mru;
  $app->{main}->{project}->SetLabel(basename($file, '.prj'));
  $app->{main}->{currentproject} = $file;

  chdir dirname($file);
  $app->modified(0);
  undef $busy;
  $app->{main}->status("Imported data from project $file");
};


sub save_column {
  my ($app, $how) = @_;
  return if $app->is_empty;

  my $data = $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
  (my $base = $data->name) =~ s{[^-a-zA-Z0-9.+]+}{_}g;

  my ($desc, $suff, $out) = ($how eq 'mue')  ? ("$MU(E)",  '.xmu',  'xmu')
                          : ($how eq 'norm') ? ("norm(E)", '.nor',  'norm')
                          : ($how eq 'chik') ? ("$CHI(k)", '.chik', 'chi')
                          : ($how eq 'chir') ? ("$CHI(R)", '.chir', 'r')
                          : ($how eq 'chiq') ? ("$CHI(q)", '.chiq', 'q')
		          :                    ('???',     '.???',  '???');

  my $fd = Wx::FileDialog->new( $app->{main}, "Save $desc data", cwd, $base.$suff,
				"$desc data (*$suff)|*$suff|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving column data cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $data->save($out, $fname);
  $app->{main}->status("Saved $desc data to $fname");
};

sub save_marked {
  my ($app, $how) = @_;
  return if $app->is_empty;

  my @data = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@data, $app->{main}->{list}->GetClientData($i)) if $app->{main}->{list}->IsChecked($i);
  };
  if (not @data) {
    $app->{main}->status("Saving marked cancelled. There are no marked groups.");
    return;
  };

  my ($desc, $suff) = ($how eq 'xmu')      ? ("$MU(E)",          '.xmu')
                    : ($how eq 'norm')     ? ("norm(E)",         '.nor')
                    : ($how eq 'der')      ? ("deriv($MU(E))",   '.nor')
                    : ($how eq 'nder')     ? ("deriv(norm(E))",  '.nor')
                    : ($how eq 'sec')      ? ("second($MU(E))",  '.nor')
                    : ($how eq 'nsec')     ? ("second(norm(E))", '.nor')
                    : ($how eq 'chi')      ? ("$CHI(k)",         '.chi')
                    : ($how eq 'chik')     ? ("k$CHI(k)",        '.chik')
                    : ($how eq 'chik2')    ? ("k$TWO$CHI(k)",    '.chik2')
                    : ($how eq 'chik3')    ? ("k$THR$CHI(k)",    '.chik3')
                    : ($how eq 'chir_mag') ? ("|$CHI(R)|",       '.chir_mag')
                    : ($how eq 'chir_re')  ? ("Re[$CHI(R)]",     '.chir_re')
                    : ($how eq 'chir_im')  ? ("Im[$CHI(R)]",     '.chir_im')
                    : ($how eq 'chir_pha') ? ("Pha[$CHI(R)]",    '.chir_pha')
                    : ($how eq 'chiq_mag') ? ("|$CHI(q)|",       '.chiq_mag')
                    : ($how eq 'chiq_re')  ? ("Re[$CHI(q)]",     '.chiq_re')
                    : ($how eq 'chiq_im')  ? ("Im[$CHI(q)]",     '.chiq_im')
                    : ($how eq 'chiq_pha') ? ("Pha[$CHI(q)]",    '.chiq_pha')
		    :                        ('???',             '.???');

  my $fd = Wx::FileDialog->new( $app->{main}, "Save $desc data for marked groups", cwd, 'marked'.$suff,
				"$desc data (*$suff)|*$suff|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving column data for marked groups cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $data[0]->save_many($fname, $how, @data);
  $app->{main}->status("Saved $desc data for marked groups to $fname");
};

sub save_each {
  my ($app, $how) = @_;
  return if not $app->{main}->{list}->GetCount;
  my @data = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@data, $app->{main}->{list}->GetClientData($i)) if $app->{main}->{list}->IsChecked($i);
  };
  if (not @data) {
    $app->{main}->status("Saving each cancelled. There are no marked groups.");
    return;
  };

  my ($desc, $suff, $out) = ($how eq 'mue')  ? ("$MU(E)",  '.xmu',  'xmu')
                          : ($how eq 'norm') ? ("norm(E)", '.nor',  'norm')
                          : ($how eq 'chik') ? ("$CHI(k)", '.chik', 'chi')
                          : ($how eq 'chir') ? ("$CHI(R)", '.chir', 'r')
                          : ($how eq 'chiq') ? ("$CHI(q)", '.chiq', 'q')
		          :                    ('???',     '.???',  '???');
  my $dd = Wx::DirDialog->new( $app->{main}, "Save $desc data for each marked group",
			       cwd, wxDD_DEFAULT_STYLE|wxDD_CHANGE_DIR);
  if ($dd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving column data for each marked group cancelled.");
    return;
  };
  my $busy = Wx::BusyCursor->new();
  my $dir  = $dd->GetPath;
  foreach my $d (@data) {
    (my $base = $d->name) =~ s{[^-a-zA-Z0-9.+]+}{_}g;
    my $fname = File::Spec->catfile($dir, $base.$suff);
    $d->save($out, $fname);
  };
  undef $busy;
  $app->{main}->status("Saved $desc data for each marked group to $dir");
};

1;
