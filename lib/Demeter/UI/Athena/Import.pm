package Demeter::UI::Athena::Import;

use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ColumnSelection;

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
  my ($app, $which, $fname) = @_;
  my $retval = q{};
 SWITCH: {
    $retval = _prj($app, $fname),           last SWITCH if (($which eq 'prj') or ($which eq 'athena'));
    $retval = _data($app, $fname),          last SWITCH if  ($which eq 'data');
  };
  return $retval;
};

sub _data {
  my ($app, $fname) = @_;
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

  my $busy = Wx::BusyCursor->new();
  my $data = Demeter::Data->new(file=>$file);
  $data -> set(energy	   => '$1',
	       numerator   => '$2',
	       denominator => '$3',
	       ln	   => 1,
	       name	   => basename($file),
	       display	   => 1);

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

  ##$data->po->start_plot;
  ##$data->plot('k');
  ##$data->plot_window('k') if $data->po->plot_win;
  ##$$rdemeter->push_mru("chik", $file);
  ##autosave();
  chdir dirname($file);
  undef $busy;
  $app->{main}->status("Imported data from $file");
}
