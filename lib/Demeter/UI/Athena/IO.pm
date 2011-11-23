package Demeter::UI::Athena::IO;

use strict;
use warnings;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ColumnSelection;
use Demeter::UI::Artemis::Prj;
use Demeter::UI::Wx::PeriodicTableDialog;
my $XDI_exists = 0;#        = eval "require Xray::XDI";
#use Xray::XDI;

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::Util qw(max);
use List::MoreUtils qw(any none);
use Readonly;

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Import Export save_column save_marked save_each FPath);

sub Export {
  my ($app, $how, $fname) = @_;
  return if $app->is_empty;

  my @data;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and not $app->{main}->{list}->IsChecked($i));
    push @data, $app->{main}->{list}->GetIndexedData($i);
  };
  if (not @data) {
    $app->{main}->status("Saving marked groups to a project cancelled -- no marked groups.");
    return;
  };
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Save project file", cwd, q{athena.prj},
				  "Athena project (*.prj)|*.prj|All files|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, # wxFD_OVERWRITE_PROMPT|
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Saving project cancelled.");
      return;
    };
    $fname = $fd->GetPath; #File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
    return if $app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };

  my $busy = Wx::BusyCursor->new();
  #$app->{main}->{Main}->pull_values($app->current_data);
  $app->{main}->{Journal}->{object}->text($app->{main}->{Journal}->{journal}->GetValue);
  $data[0]->write_athena($fname, @data, $app->{main}->{Journal}->{object});
  if (dirname($fname) ne Demeter->stash_folder) {
    $data[0]->push_mru("xasdata", $fname);
    $data[0]->push_mru("athena", $fname);
    $app->set_mru;
    $app->{main}->{project}->SetLabel(basename($fname, '.prj'));
    $app->{main}->{currentproject} = $fname;
    $app->modified(0);
    my $extra = ($how eq 'marked') ? " with marked groups" : q{};
    $app->{main}->status("Saved project file $fname".$extra);
    unlink File::Spec->catfile(Demeter->stash_folder, 'Athena.autosave') if $how eq 'all';
  };
  undef $busy;
  return $fname;
};

sub Import {
  my ($app, $fname) = @_;
  my $retval = q{};

  $app->{main}->{views}->SetSelection(0);

  my @files = ($fname);
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Import data", cwd, q{},
				  "All files|*|Athena projects (*.prj)|*.prj|Data (*.dat)|*.dat",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW|wxFD_MULTIPLE,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Data import cancelled.");
      return;
    };
    @files = map {File::Spec->catfile($fd->GetDirectory, $_)} $fd->GetFilenames;
  };

  my $verbose = 0;
  ## also xmu.dat
  ## evkev?
  my $first = 1;
  foreach my $file (sort {$a cmp $b} @files) {
    ## check to see if this is a Windows shortcut, if so, resolve it
    ## bail out if it points to a file that is not -e or cannot -r
    if (not !Demeter->readable($file)) {
      Wx::MessageDialog->new($app->{main}, "$file is not readable", "Warning!", wxOK|wxICON_WARNING) -> ShowModal;
      next;
    };

    my $xdi = q{};
    if ($XDI_exists) {
      $xdi = Xray::XDI->new;
      $xdi->file($file);
      ## at this point, run a test against $xdi->applications and
      ## $xdi->labels to determine is this is a multichannel detector
      ## file from X23A2 or 10BM , if so, set is_xdi to false and let
      ## this fall through to the plugin
    };
    my ($plugin, $stashfile, @suggest, $type);
    if ($xdi and $xdi->is_xdi) {
      $type = 'xdi';
    } else {
      $plugin = test_plugins($app, $file);
      if ($plugin =~ m{\A\!}) {
	$app->{main}->status("There was an error reading that file as a " . (split(/::/, $plugin))[-1] . " file.  (Perhaps you do not have its plugin configured correctly?)");
	return;
      };
      $stashfile = ($plugin) ? $plugin->fixed : $file;
      @suggest = ($plugin) ? $plugin->suggest() : ();
      $type = ($plugin and ($plugin->output eq 'data'))                ? 'raw'
            : ($plugin and ($plugin->output eq 'project'))             ? 'prj'
            : ($Demeter::UI::Athena::demeter->is_prj($file,$verbose))  ? 'prj'
            : ($Demeter::UI::Athena::demeter->is_data($file,$verbose)) ? 'raw'
            :                                                            '???';
    }
    if ($type eq '???') {
      $app->{main}->status("Could not read \"$file\" as either data or as a project file. (Do you need to enable a plugin?)");
      return;
    };
    if ($plugin) {
      $app->{main}->status("$file appears to be from " . $plugin->description);
    };

  SWITCH: {
      $retval = _data($app, $stashfile, $xdi,  $first, []),        last SWITCH if ($type eq 'xdi');
      $retval = _prj ($app, $stashfile, $file, $first, $plugin),   last SWITCH if ($type eq 'prj');
      $retval = _data($app, $stashfile, $file, $first, \@suggest), last SWITCH if ($type eq 'raw');
    };
    undef $xdi;
    if ($plugin) {
      unlink $plugin->fixed;
      undef $plugin;
    };
    if ($retval == 0) {		# bail on a file sequence if one gets canceled
      return;
    };
    if ($retval == -1) {	# bail on a file sequence if something bad happens
      $app->{main}->status("Stopping file import.  $file could not be read correctly.", "error");
      return;
    };
    $first = 0;
    if ($app->current_data->mo->heap_used > 0.95) {
      $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
      $app->{main}->status("Stopping multiple file import.  You have used more than 95% of Ifeffit's memory.", "error");
      return;
    };
  };
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
  return;
};


sub test_plugins {
  my ($app, $file) = @_;
  foreach my $pl (@{$Demeter::UI::Athena::demeter->mo->Plugins}) {
    next if ($pl =~ m{FileType});
    next if (not $app->{main}->{PluginRegistry}->{$pl}->GetValue);
    my $this = $pl->new(file=>$file);
    if (not $this->is) {
      undef $this;
      next;
    };
    if ($this->time_consuming) {
      $app->{main}->status($this->working_message, "wait");
    };
    my $ok = eval {$this->fix};
    return '!'.$pl if $@;
    return '!'.$pl if not $ok;
    return $this;
  };
  return 0;
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
  my ($app, $file, $orig, $first, $suggest) = @_;

  my $busy = Wx::BusyCursor->new();
  my ($data, $displayfile);
  if (ref($orig) =~ m{Class::MOP}) {
    $displayfile = $orig->file;
    $data = Demeter::Data->new;
  } else {
    $displayfile = $orig;
    $data = Demeter::Data->new(file=>$file);
  };
  my %suggest = @$suggest;	# suggested columns from a plugin
  ## build suggestions from XDI attributes

  ## -------- import persistance file
  my $persist = File::Spec->catfile($data->dot_folder, "athena.column_selection");
  $data -> set(name	   => basename($displayfile),
	       is_col      => 1,
	       energy      => $suggest{energy}||'$1',
	       numerator   => $suggest{numerator}||1,
	       denominator => $suggest{denominator}||1,
	       ln          => $suggest{ln}||0,
	       inv         => $suggest{inv}||0,
	       display	   => 1);
  $data->update_data(1) if ($data->energy ne '$1');
  $data->_update('data');
  my $yaml;
  $yaml->{columns} = q{};
  my $do_guess = 0;
  if (-e $persist) {
    $yaml = YAML::Tiny::Load($data->slurp($persist));
    if ($data->columns eq $yaml->{columns}) {
      my $nnorm = ($yaml->{datatype} eq 'xanes') ? 2 : 3;
      $data -> set(energy      => $yaml->{energy}      || $suggest{energy}      || '$1',
		   numerator   => $yaml->{numerator}   || $suggest{numerator}   || '1',
		   denominator => $yaml->{denominator} || $suggest{denominator} || '1',
		   ln          => (defined($yaml->{ln}))  ? $yaml->{ln}  : $suggest{ln},
		   inv         => (defined($yaml->{inv})) ? $yaml->{inv} : $suggest{inv},
		   is_kev      => $yaml->{units},
		   bkg_nnorm   => $nnorm,
		  );
      $data->update_data(1) if ($data->energy ne '$1');;
      my $dt = $yaml->{datatype};
      if ($dt eq 'norm') {
	$data->datatype('xmu');
	$data->is_nor(1);
      } else {
	$data->datatype($dt);
	$data->is_nor(0);
      };
    } else {
      $yaml->{each} = 0;
      $do_guess = ($suggest) ? 0 : 1;
    };
  } else {
    $do_guess = 1;
  };
  $yaml->{energy} = $data->energy;
  my $untext = $data->guess_units;
  my $un = ($untext eq 'eV')     ? 0
         : ($untext eq 'keV')    ? 1
         : ($untext eq 'lambda') ? 2
	 :                         0;
  $yaml->{units} = $un;
  if ($untext eq 'keV') {
    $data->is_kev(1);
    $data->update_data(1);
    $data->_update('data');
  };

  ## for an XDI file, setting the xdi attribute has to be delayed
  ## until *after* the energy/numerator/denominator attributes are
  ## set.  then guess_columns can be called.
  $data->xdi($orig) if (ref($orig) =~ m{Class::MOP});
  $data->guess_columns if ($do_guess and (not $suggest));

  ## -------- display column selection dialog
  my $repeated = 1;
  my $colsel;
  my $med = $yaml->{each}; # this will be true is each channel of MED data is to be its own group
  if ($first or ($data->columns ne $yaml->{columns})) {
    $colsel = Demeter::UI::Athena::ColumnSelection->new($app->{main}, $app, $data);
    $colsel->{ok}->SetFocus;

    $colsel->{each}->SetValue($yaml->{each});
    $colsel->{units}->SetSelection($yaml->{units});

    $colsel->{datatype}->SetSelection(0);
    $colsel->{datatype}->SetSelection(1) if ($data->datatype eq 'xanes');
    $colsel->{datatype}->SetSelection(2) if (($data->datatype eq 'xanes') and $data->is_nor);
    $colsel->{datatype}->SetSelection(2) if ($data->is_nor);
    $colsel->{datatype}->SetSelection(3) if ($data->datatype eq 'chi');
    $colsel->{datatype}->SetSelection(4) if ($data->datatype eq 'xmudat');
    $colsel->OnDatatype(q{}, $colsel, $data);

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
    foreach my $w (qw(do_rebin emin emax pre xanes exafs)) { # abs
      my $key = ($w eq 'do_rebin') ? $w : 'rebin_'.$w;
      my $value;
      if ($w eq 'do_rebin') {
	$value = $yaml->{$key} || 0;
      } else {
	$value = $yaml->{$key} || $data->co->default('rebin', $w);
      };
      $colsel->{Rebin}->{$w}->SetValue($yaml->{$key});
      next if (any {$w eq $_} qw(do_rebin abs));
      $data->co->set_default('rebin', $w, $yaml->{$key});
    };
    if ($data->columns ne $yaml->{columns}) {
      $colsel->{Rebin}->{do_rebin}->SetValue(0)
    };
    $colsel->{Rebin}->EnableRebin(0, $data);

    ## set Preprocessing controls from yaml
    $colsel->{Preprocess}->{standard}->fill($app, 0, 0);
    my $found = -1;
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) { # make sure the persistance value is still in the list
      $yaml->{preproc_standard} ||= q{};
      if ($app->{main}->{list}->GetIndexedData($i)->name eq $yaml->{preproc_standard}) {
	$found = $i;
	last;
      };
    };
    $yaml->{preproc_standard} ||= 'None';
    ($yaml->{preproc_standard} eq 'None') ? $colsel->{Preprocess}->{standard}->SetSelection(0)
      : $colsel->{Preprocess}->{standard}->SetSelection($found+1);
    if ($colsel->{Preprocess}->{standard}->GetStringSelection =~ m{\A(?:None|)\z}) {
      $colsel->{Preprocess}->{align}-> Enable(0);
      $yaml->{preproc_align} = 0;
      $colsel->{Preprocess}->{set}-> Enable(0);
      $yaml->{preproc_set}   = 0;
    };
    foreach my $w (qw(mark align set)) {
      $colsel->{Preprocess}->{$w}->SetValue($yaml->{'preproc_'.$w});
    };


    my $result = $colsel -> ShowModal;
    if ($result == wxID_CANCEL) {
      $app->{main}->status("Cancelled column selection.");
      $data->dispose("erase \@group ".$data->group);
      $data->DEMOLISH;
      return 0;
    };
    $med = 1 if ($colsel->{each}->IsEnabled and $colsel->{each}->GetValue);
    $yaml->{each}  = $colsel->{each}->GetValue;
    $yaml->{units} = $colsel->{units}->GetSelection;
    $repeated = 0;
  };

  ## to write each MED channel to a group, loop over channels, calling
  ## this.  Set all eshifts the same and don't redo alignment
  my $dtp = ($colsel->{datatype}->GetSelection == 0) ? 'xmu'
          : ($colsel->{datatype}->GetSelection == 1) ? 'xanes'
          : ($colsel->{datatype}->GetSelection == 3) ? 'chi'
	  :                                            'xmu';
  my $message = q{};
  if ($med) {
    my $mc = Demeter::Data::MultiChannel->new(file=>$file, energy=>$data->energy);
    my $align = $yaml->{preproc_align};
    my $eshift = 0;
    my @cols = (q{}, split(" ", $data->columns));
    foreach my $ch (split(/\+/, $data->numerator)) {
      (my $cc = $ch) =~ s{\$}{};
      my $this = $mc->make_data(numerator   => $ch,
				denominator => $data->denominator,
				ln          => $data->ln,
				inv         => $data->inv,
				name        => join(" - ", basename($file), $cols[$cc]),
				datatype    => $dtp,
			       );
      _group($app, $colsel, $this, $yaml, $file, $orig, $repeated, $align);
      $eshift = $this->bkg_eshift if $align;
      $this->bkg_eshift($eshift)  if not $align;
      $repeated = 1 if (not $repeated);
      $align = 0;
    };
    $mc->discard;
  } else {
    $message = $data->name;
    _group($app, $colsel, $data, $yaml, $file, $orig, $repeated, 0);
  };

  $data->push_mru("xasdata", $displayfile);
  $app->set_mru;

  $app->{main}->status("Imported $message from $displayfile");

  ## -------- save persistance file
  my %persistence = (
		     columns	 => $data->columns,
		     energy	 => $data->energy,
		     numerator	 => $data->numerator,
		     denominator => $data->denominator,
		     ln		 => $data->ln,
		     inv	 => $data->inv,
		     each        => $yaml->{each},
		     datatype    => ($data->is_nor) ? 'norm' : $data->datatype,
		     units       => $data->is_kev,);
  ## reference
  $persistence{do_ref}      = (defined($colsel)) ? $colsel->{Reference}->{do_ref}->GetValue : $yaml->{do_ref};
  $persistence{ref_ln}      = (defined($colsel)) ? $colsel->{Reference}->{ln}->GetValue     : $yaml->{ref_ln};
  $persistence{ref_same}    = (defined($colsel)) ? $colsel->{Reference}->{same}->GetValue   : $yaml->{ref_same};
  $persistence{ref_numer}   = (defined($colsel)) ? $colsel->{Reference}->{numerator}        : $yaml->{ref_numer};
  $persistence{ref_denom}   = (defined($colsel)) ? $colsel->{Reference}->{denominator}      : $yaml->{ref_denom};
  ## rebin
  $persistence{do_rebin}    = (defined($colsel)) ? $colsel->{Rebin}->{do_rebin}->GetValue   : $yaml->{do_rebin};
  #$persistence{rebin_abs}   = (defined($colsel)) ? $colsel->{Rebin}->{abs}->GetValue        : $yaml->{rebin_abs};
  $persistence{rebin_emin}  = (defined($colsel)) ? $colsel->{Rebin}->{emin}->GetValue       : $yaml->{rebin_emin};
  $persistence{rebin_emax}  = (defined($colsel)) ? $colsel->{Rebin}->{emax}->GetValue       : $yaml->{rebin_emax};
  $persistence{rebin_pre}   = (defined($colsel)) ? $colsel->{Rebin}->{pre}->GetValue        : $yaml->{rebin_pre};
  $persistence{rebin_xanes} = (defined($colsel)) ? $colsel->{Rebin}->{xanes}->GetValue      : $yaml->{rebin_xanes};
  $persistence{rebin_exafs} = (defined($colsel)) ? $colsel->{Rebin}->{exafs}->GetValue      : $yaml->{rebin_exafs};
  ## preprocess
  $persistence{preproc_standard} = (defined($colsel)) ? $colsel->{Preprocess}->{standard}->GetStringSelection : $yaml->{preproc_standard};
  $persistence{preproc_mark}     = (defined($colsel)) ? $colsel->{Preprocess}->{mark} ->GetValue : $yaml->{preproc_mark};
  $persistence{preproc_align}    = (defined($colsel)) ? $colsel->{Preprocess}->{align}->GetValue : $yaml->{preproc_align};
  $persistence{preproc_set}      = (defined($colsel)) ? $colsel->{Preprocess}->{set}  ->GetValue : $yaml->{preproc_set};
  my $stan = q{};
  if (defined($colsel)) {
    if ($colsel->{Preprocess}->{standard}->GetStringSelection  !~ m{\A(?:None|)\z}) {
      $stan = $colsel->{Preprocess}->{standard}->GetClientData($colsel->{Preprocess}->{standard}->GetSelection)->group;
    };
  } else {
    $stan = $yaml->{preproc_stgroup};
  };
  $persistence{preproc_stgroup} = $stan;

  my $string .= YAML::Tiny::Dump(\%persistence);
  open(my $ORDER, '>'.$persist);
  print $ORDER $string;
  close $ORDER;

  ## -------- last chores before finishing
  $data->discard if $med;
  chdir dirname($orig);
  $app->modified(1);
  undef $busy;
  undef $colsel;
  undef $yaml;
  return 1;
};

## this argument list has grown icky over time:
# 1: Pointer to the Athena app, same as $::app
# 2: $colsel, Pointer to the column selection frame
# 3: $data, Pointer to the main Data object (as opposed to the refernece)
# 4: $yaml: the yaml containing the column selection persistence
# 5: $file: the actual file being read, stashfile for a pluhgin, original file otherwise
# 6: $orig: the fully resolved original file
# 7: $repeated: oddly, 1 if this is the first pass through, 0 for subsequent files in multiple file import
# 8: $noalign: doesn't seem to be used
sub _group {
  my ($app, $colsel, $data, $yaml, $file, $orig, $repeated, $noalign) = @_;
  my $displayfile = (ref($orig) =~ m{Class::MOP}) ? $orig->file : $orig;

  ## -------- import data group
  $app->{main}->status("Importing ". $data->name . " from $displayfile");
  $app->{main}->Update;
  $data->display(0);
  #$data->source($displayfile);
  my $do_rebin = (defined $colsel) ? ($colsel->{Rebin}->{do_rebin}->GetValue) : $yaml->{do_rebin};

  if ($do_rebin) {
    $app->{main}->status("Rebinning ". $data->name);
    my $rebin  = $data->rebin;
    foreach my $att (qw(energy numerator denominator ln name)) {
      $rebin->$att($data->$att);
    };
    $data->dispose("erase \@group ".$data->group);
    $data->DEMOLISH;
    $data = $rebin;
  };

  $data -> po -> e_markers(1);
  $data -> _update('all');
  $app->{main}->{list}->AddData($data->name, $data);

  if (not $repeated) {
    $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
    #$app->{selected} = $app->{main}->{list}->GetSelection;
    $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
    $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
    Import_plot($app, $data);
  };

  ## preprocessing

  ## the next line needs some explanation.  if this is the first in a
  ## sequence of data files being imported, then the value is taken
  ## from the widget.  when that one is done, its value is pushed into
  ## $yaml. for subsequent files, the value is taken from $yaml
  my $do_mark = (defined $colsel) ? ($colsel->{Preprocess}->{mark}->GetValue) : $yaml->{preproc_mark};
  if ($do_mark) {
    $app->mark($data);
  };
  my $stan = q{};
  if (defined($colsel)) {
    if ($colsel->{Preprocess}->{standard}->GetStringSelection  !~ m{\A(?:None|)\z}) {
      $stan = $colsel->{Preprocess}->{standard}->GetClientData($colsel->{Preprocess}->{standard}->GetSelection)->group;
      $stan = $data->mo->fetch("Data", $stan);
    };
  } else {
    $stan = $data->mo->fetch("Data", $yaml->{preproc_stgroup});
  };
  my $do_set  = (defined $colsel) ? ($colsel->{Preprocess}->{set}->GetValue)  : $yaml->{preproc_set};
  if ($do_set) {
    #my $stan = $colsel->{Preprocess}->{standard}->GetClientData($colsel->{Preprocess}->{standard}->GetSelection);
    $app->{main}->status("Constraining parameters for ". $data->name . " to " . $stan->name);
    constrain($app, $colsel, $data, $stan);
    $app->OnGroupSelect(0,0,0);
  };
  ## -------- import reference if reference channel is set
  my $do_ref = (defined $colsel) ? ($colsel->{Reference}->{do_ref}->GetValue) : $yaml->{do_ref};
  if ($do_ref) {
    $app->{main}->status("Importing reference for ". $data->name);
    $app->{main}->Update;
    my $ref = (defined $colsel) ? $colsel->{Reference}->{reference} : q{};
    if (not $ref) {
      $ref = Demeter::Data->new(file => $file);
    };
    $yaml -> {ref_numer} = (defined($colsel)) ? $colsel->{Reference}->{numerator}    : $yaml->{ref_numer};
    $yaml -> {ref_denom} = (defined($colsel)) ? $colsel->{Reference}->{denominator}  : $yaml->{ref_denom};
    $yaml -> {ref_ln}    = (defined($colsel)) ? $colsel->{Reference}->{ln}->GetValue : $yaml->{ref_ln};

    $ref -> set(name        => "  Ref " . $data->name,
		energy      => $yaml->{energy},
		numerator   => '$'.$yaml->{ref_numer},
		denominator => '$'.$yaml->{ref_denom},
		ln          => $yaml->{ref_ln},
		is_col      => 1,
		is_kev      => $data->is_kev,
		display     => 1,
		datatype    => $data->datatype);
    $ref->display(0);
    my $same_edge = (defined $colsel) ? $colsel->{Reference}->{same}->GetValue : $yaml->{ref_same};
    if ($same_edge) {
      $ref->bkg_z($data->bkg_z);
      $ref->fft_edge($data->fft_edge);
    };
    $ref -> _update('normalize');
    if (abs($data->bkg_e0 - $ref->bkg_e0) > $data->co->default('rebin', 'use_atomic')) {
      $ref->e0('atomic');
    };
    if ($do_rebin) {
      $app->{main}->status("Rebinning reference for ". $data->name);
      my $rebin  = $ref->rebin;
      foreach my $att (qw(energy numerator denominator ln name)) {
	$rebin->$att($ref->$att);
      };
      $ref->dispose("erase \@group ".$ref->group);
      $ref->DEMOLISH;
      $ref = $rebin;
    };
    $ref -> _update('fft');
    $app->{main}->{list}->AddData($ref->name, $ref);
    $app->{main}->{Main}->{bkg_eshift}-> SetBackgroundColour( Wx::Colour->new($ref->co->default("athena", "tied")) );
    $ref->reference($data);
  };

  my $do_align = (defined $colsel) ? ($colsel->{Preprocess}->{align}->GetValue) : $yaml->{preproc_align};
  if ($do_align) {
    #my $stan = $colsel->{Preprocess}->{standard}->GetClientData($colsel->{Preprocess}->{standard}->GetSelection);
    if ($data->reference and $stan->reference) {
      $app->{main}->status("Aligning ". $data->name . " to " . $stan->name . " using references");
      $stan->align_with_reference($data);
    } else {
      $app->{main}->status("Aligning ". $data->name . " to " . $stan->name);
      $stan->align($data);
    };
    $app->OnGroupSelect(0,0,0);
  };

};

Readonly my @all_group  => (qw(bkg_z fft_edge bkg_eshift importance));
Readonly my @all_bkg    => (qw(bkg_e0 bkg_rbkg bkg_flatten bkg_kw
			       bkg_fixstep bkg_nnorm bkg_pre1 bkg_pre2
			       bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2
			       bkg_spl1e bkg_spl2e bkg_stan bkg_clamp1
			       bkg_clamp2)); # bkg_algorithm bkg_step
Readonly my @all_fft    => (qw(fft_kmin fft_kmax fft_dk fft_kwindow fit_karb_value fft_pc));
Readonly my @all_bft    => (qw(bft_rmin bft_rmax bft_dr bft_rwindow));
Readonly my @all_plot   => (qw(plot_multiplier y_offset));

sub constrain {
  my ($app, $colsel, $data, $stan) = @_;
  return if not $stan;

  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    my $this = $app->{main}->{list}->GetIndexedData($i);
    foreach my $p (@all_group, @all_bkg, @all_fft, @all_bft, @all_plot) {
      #print join("|", '>>>', $data->name, $this->name, $p, $this->$p), $/;
      $data->$p($stan->$p);
      #print join("|", '<<<', $data->name, $this->name, $p, $this->$p), $/;
    };
  };
};


sub _prj {
  my ($app, $file, $orig, $first, $is_plugin) = @_;
  my $busy = Wx::BusyCursor->new();

  $app->{main}->{prj} =  Demeter::UI::Artemis::Prj->new($app->{main}, $file, 'multiple');
  $app->{main}->{prj}->{import}->SetFocus;
  my $result = $app->{main}->{prj} -> ShowModal;

  if ($result == wxID_CANCEL)  {
    $app->{main}->status("Canceled import from project file.");
    return 0;
  };

  my @selected = $app->{main}->{prj}->{grouplist}->GetSelections;
  @selected = (0 .. $app->{main}->{prj}->{grouplist}->GetCount-1) if not @selected;

  my @records = map {$_ + 1} @selected;
  my $prj = $app->{main}->{prj}->{prj};

  my $count = 0;
  my $data;
  foreach my $rec (@records) {
    $data = $prj->record($rec);
    next if not $data;
    ++$count;
    if ($data->prjrecord =~ m{,\s+(\d+)}) {
      $data->prjrecord($orig . ", $1");
    };
    $app->{main}->status("Importing ". $data->prjrecord, "nobuffer");
    $app->{main}->Update;
    $app->{main}->{list}->AddData($data->name, $data);
    if ($count == 1) {
      $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
      #$app->{selected} = $app->{main}->{list}->GetSelection;
      $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
      $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
      Import_plot($app, $data);
    };
  };
  return -1 if not $count;
  $app->{main}->{Journal}->{object}->text($prj->journal);
  $app->{main}->{Journal}->{journal}->SetValue($app->{main}->{Journal}->{object}->text);
  $app->{main}->{Main}->{bkg_stan}->fill($app, 1);

  $data->push_mru("xasdata", $orig);
  $data->push_mru("athena", $orig);
  $app->set_mru;
  if (not $is_plugin) {
    $app->{main}->{project}->SetLabel(basename($file, '.prj'));
    $app->{main}->{currentproject} = $file;
  };

  chdir dirname($orig);
  ($is_plugin) ? $app->modified(1) : $app->modified(0);
  $prj->DEMOLISH;
  $app->OnGroupSelect(0,0,0);
  undef $busy;
  $app->{main}->status("Imported data from project $orig");
  return 1;
};


sub save_column {
  my ($app, $how) = @_;
  return if $app->is_empty;

  my $data = $app->{main}->{list}->GetIndexedData($app->{main}->{list}->GetSelection);
  (my $base = $data->name) =~ s{[^-a-zA-Z0-9.+]+}{_}g;

  my ($desc, $suff, $out) = ($how eq 'mue')  ? ("$MU(E)",  '.xmu',  'xmu')
                          : ($how eq 'norm') ? ("norm(E)", '.nor',  'norm')
                          : ($how eq 'chik') ? ("$CHI(k)", '.chik', 'chi')
                          : ($how eq 'chir') ? ("$CHI(R)", '.chir', 'r')
                          : ($how eq 'chiq') ? ("$CHI(q)", '.chiq', 'q')
		          :                    ('???',     '.???',  '???');

  my $fd = Wx::FileDialog->new( $app->{main}, "Save $desc data", cwd, $base.$suff,
				"$desc data (*$suff)|*$suff|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving column data cancelled.");
    return;
  };
  my $fname = $fd->GetPath;
  return if $app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $data->save($out, $fname);
  $app->{main}->status("Saved $desc data to $fname");
};

sub save_marked {
  my ($app, $how) = @_;
  return if $app->is_empty;

  my @data = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@data, $app->{main}->{list}->GetIndexedData($i)) if $app->{main}->{list}->IsChecked($i);
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
                    : ($how eq 'dph')      ? ("Deriv(Pha[$CHI(R)])", '.dph')
                    : ($how eq 'chiq_mag') ? ("|$CHI(q)|",       '.chiq_mag')
                    : ($how eq 'chiq_re')  ? ("Re[$CHI(q)]",     '.chiq_re')
                    : ($how eq 'chiq_im')  ? ("Im[$CHI(q)]",     '.chiq_im')
                    : ($how eq 'chiq_pha') ? ("Pha[$CHI(q)]",    '.chiq_pha')
		    :                        ('???',             '.???');

  my $fd = Wx::FileDialog->new( $app->{main}, "Save $desc data for marked groups", cwd, 'marked'.$suff,
				"$desc data (*$suff)|*$suff|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving column data for marked groups cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  return if $app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $data[0]->save_many($fname, $how, @data);
  $app->{main}->status("Saved $desc data for marked groups to $fname");
};

sub save_each {
  my ($app, $how) = @_;
  return if $app->is_empty;
  my @data = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@data, $app->{main}->{list}->GetIndexedData($i)) if $app->{main}->{list}->IsChecked($i);
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

sub FPath {
  my ($app) = @_;
  return if $app->is_empty;

  if (none {$app->current_data->datatype eq $_} qw(xmu xanes)) {
    $app->{main}->status("You cannot make an empirical standard from this group.");
    return;
  };

  (my $base = $app->current_data->name) =~ s{[^-a-zA-Z0-9.+]+}{_}g;
  my $fd = Wx::FileDialog->new( $app->{main}, "Save current group as an empirical standard", cwd, $base.'.es',
				"epirical standards (*.es)|*.es|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Saving empirical standard from current group cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  return if $app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)

  my $scatterer = q{};
  $app->{main}->{popup}  = Demeter::UI::Wx::PeriodicTableDialog->new($app->{main}, -1, "Select scattering element", sub{$scatterer = $_[0]; $app->{main}->{popup}->Destroy;});
  $app->{main}->{popup} -> ShowModal;

  my $reff = 2.5;
  my $save = $app->current_data->fft_pc;
  $app->current_data->fft_pc(1);
  $app->current_data->_update('bft');
  my @r   = $app->current_data->get_array('r');
  my @mag = $app->current_data->get_array('chir_mag');
  my ($maxval, $imax) = (-1000, 0);
  foreach my $i (0 .. $#mag) {
    if ($mag[$i] > $maxval) {
      $maxval = $mag[$i];
      $imax   = $i;
    };
  };
  $reff = $r[$imax];
  $app->current_data->fft_pc($save);

  require Demeter::FPath;
  require Demeter::Atoms;
  require Demeter::Feff;
  my $fp = Demeter::FPath->new(absorber  => $app->current_data->bkg_z,
			       scatterer => $scatterer,
			       reff      => $reff,
			       source    => $app->current_data,
			       n         => 1,
			       delr      => 0.0,
			       s02       => 1,
			      );
  $fp->freeze($fname);
  $app->{main}->status(sprintf("Wrote a %s-%s empirical standard of length %.5f to %s",
			       $app->current_data->bkg_z, $scatterer, $reff, $fname));
};

1;
