package Demeter::UI::Athena::Import;

use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ColumnSelection;
use Demeter::UI::Artemis::Prj;

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Import Export);

sub Export {
  my ($app, $how, $fname) = @_;

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

  my @data;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and not $app->{main}->{list}->IsSelected($i));
    push @data, $app->{main}->{list}->GetClientData($i);
  };
  if (not @data) {
    $app->{main}->status("Saving marked groups to a project cancelled -- no marked groups.");
    return;
  };
  $data[0]->write_athena($fname, @data);
  $data[0]->push_mru("xasdata", $fname);
  $app->set_mru;
  $app->{main}->status("Saved project file $fname");
  return $fname;
};

sub Import {
  my ($app, $fname) = @_;
  my $retval = q{};

  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Import data", cwd, q{},
				  "All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Data import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };

  my $verbose = 0;
  ## check for registerd filetypes here
  ## also xmu.dat
  ## evkev?
  my $type = ($Demeter::UI::Athena::demeter->is_prj($file,$verbose))  ? 'prj'
	   : ($Demeter::UI::Athena::demeter->is_data($file,$verbose)) ? 'raw'
	   :                                                            '???';
  if ($type eq '???') {
    $app->{main}->status("Could not read \"$file\" as either data or a project file.");
    return;
  };

 SWITCH: {
    $retval = _prj($app, $file),  last SWITCH if ($type eq 'prj');
    $retval = _data($app, $file), last SWITCH if ($type eq 'raw');
  };
  return $retval;
};

sub _data {
  my ($app, $file) = @_;

  my $busy = Wx::BusyCursor->new();
  my $data = Demeter::Data->new(file=>$file);
  my $persist = File::Spec->catfile($data->dot_folder, "athena.column_selection");
  $data -> set(name	   => basename($file),
	       is_col      => 1,
	       energy      => '$1',
	       numerator   => 1,
	       denominator => 1,
	       display	   => 1);
  $data->guess_columns;
  if (-e $persist) {
    my $yaml = YAML::Tiny::Load($data->slurp($persist));
    if ($data->columns eq $yaml->{columns}) {
      $data -> set(energy      => $yaml->{energy},
		   numerator   => $yaml->{numerator},
		   denominator => $yaml->{denominator},
		   ln          => $yaml->{ln},
		   ##is_kev      => $yaml->{units},
		   ##datatype
		  );
    };
    undef $yaml;
  };

  my $colsel = Demeter::UI::Athena::ColumnSelection->new($app->{main}, $app, $data);
  my $result = $colsel -> ShowModal;
  if ($result == wxID_CANCEL) {
    $app->{main}->status("Cancelled column selection.");
    $data->DEMOLISH;
    return;
  };

  $data -> display(0);
  $data -> po -> e_markers(1);
  $data -> _update('all');
  $app->{main}->{list}->Append($data->name, $data);
  $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
  #$app->{selected} = $app->{main}->{list}->GetSelection;
  $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection);
  $app->quadplot($data);
  $data->push_mru("xasdata", $file);
  $app->set_mru;

  my %persistence = (
		     columns	 => $data->columns,
		     energy	 => $data->energy,
		     numerator	 => $data->numerator,
		     denominator => $data->denominator,
		     ln		 => $data->ln,
		     each        => 0,
		     datatype    => $data->datatype,
		     units       => $data->is_kev,
		    );

  my $string .= YAML::Tiny::Dump(\%persistence);
  open(my $ORDER, '>'.$persist);
  print $ORDER $string;
  close $ORDER;


  chdir dirname($file);
  undef $busy;
  $app->{main}->status("Imported data from $file");
}

sub _prj {
  my ($app, $file) = @_;
  my $busy = Wx::BusyCursor->new();

  $app->{main}->{prj} =  Demeter::UI::Artemis::Prj->new($app->{main}, $file, 'Multiple');
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
    $app->{main}->{list}->Append($data->name, $data);
    if ($count == 1) {
      $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount - 1);
      #$app->{selected} = $app->{main}->{list}->GetSelection;
      $app->{main}->{Main}->mode($data, 1, 0) if ($app->{main}->{list}->GetCount == 1);
      $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection);
      $app->quadplot($data);
    };
    ++$count;
  };
  $data->push_mru("xasdata", $file);
  $app->set_mru;
  $app->{main}->{project}->SetLabel(basename($file, '.prj'));
  $app->{main}->{currentproject} = $file;

  chdir dirname($file);
  undef $busy;
  $app->{main}->status("Imported data from project $file");
};
