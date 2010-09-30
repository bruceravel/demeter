package Demeter::UI::Athena::Group;

use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ChangeDatatype;

use Cwd;
use Chemistry::Elements qw(get_name);
use List::Util qw(min);
use Spreadsheet::WriteExcel;

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Rename Copy Remove change_datatype Report);

sub Rename {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $name = $data->name;
  (my $realname = $name) =~ s{\A\s*(Ref\s+)}{};
  my $is_ref = $1;

  if (not $newname) {
    my $ted = Wx::TextEntryDialog->new($app->{main}, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    $ted->SetValue($name);
    if ($ted->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Renaming cancelled.");
      return;
    };
    $newname = $ted->GetValue;
  };

  my $prefix = ($is_ref) ? "  Ref " : q{};
  $data->name($prefix.$newname);
  $app->{main}->{list}->SetString($app->current_index, $prefix.$newname);
  if (($data->reference) and ($data->reference->name =~ m{\A\s*(?:Ref\s+)?$realname\s*\z})) {
    my $prefix = ($is_ref) ? q{} : "  Ref ";
    $data->reference->name($prefix.$newname);
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
      next if ($app->{main}->{list}->GetClientData($i) ne $data->reference);
      $app->{main}->{list}->SetString($i, $prefix.$newname);
    };
  };
  $app->OnGroupSelect;
  $app->modified(1);
  $app->{main}->status("Renamed $name to $newname");
};

sub Copy {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $clone = $data->clone;
  $clone->name("Copy of ".$data->name);
  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->Append($clone->name, $clone);
  } else {
    $app->{main}->{list}->Insert($clone->name, $index+1, $clone);
  };
  $app->modified(1);
  $app->{main}->status("Copied ".$data->name);
};

sub Remove {
  my ($app, $how) = @_;
  $how ||= 'current';
  return if $app->is_empty;

  my $message = q{};
  my $i;
  if ($how eq 'current') {
    $i = $app->current_index;
    $message = "Removed ".$app->current_data->name;
    remove_one($app, $i);
    if ($app->{main}->{list}->GetCount > 0) {
      $i = min($i, $app->{main}->{list}->GetCount-1);
      $app->{main}->{list}->SetSelection($i);
      $app->OnGroupSelect(0,0);
    };
    $app->modified(1);
  } elsif ($how eq 'marked') {
    $i = $app->current_index;
    $message = "Removed marked groups";
    foreach my $j (reverse (0 .. $app->{main}->{list}->GetCount-1)) {
      if ($app->{main}->{list}->IsChecked($j)) {
	remove_one($app, $j);
	$i = $j;
      };
    };
    if ($app->{main}->{list}->GetCount > 0) {
      $i = min($i, $app->{main}->{list}->GetCount-1);
      $app->{main}->{list}->SetSelection($i);
      $app->OnGroupSelect(0,0);
    };
    $app->modified(1);
  } elsif ($how eq 'all') {
    $message = "Discarded entire project";
    if ($app->{modified}) {
      ## offer to save project....
      my $yesno = Wx::MessageDialog->new($app->{main},
					 "Save this project before exiting?",
					 "Save project?",
					 wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
      my $result = $yesno->ShowModal;
      if ($result == wxID_CANCEL) {
	$app->{main}->status("Not exiting Athena after all.");
	return 0;
      };
      $app -> Export('all', $app->{main}->{currentproject}) if $result == wxID_YES;
    };
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
      my $this = $app->{main}->{list}->GetClientData($i);
      $this->dispose("erase \@group ".$this->group);
      $this->DEMOLISH;
    };
    $app->{main}->{list}->Clear;
    $app->Clear;
  };

  if ($app->is_empty) {
    $app->{main}->{Main}->zero_values;
    $app->{main}->{Main}->mode(0,0,0);
    $app->{selected} = -1;
    $app->modified(0);
  };
  $app->{main}->status($message);
};

sub remove_one {
  my ($app, $i) = @_;
  my $data = $app->{main}->{list}->GetClientData($i);
  $data->dispose("erase \@group ".$data->group);
  $data->DEMOLISH;
  $app->{main}->{list}->Delete($i); # this calls the selection event on the new item
};


sub change_datatype {
  my ($app) = @_;
  my $cdt = Demeter::UI::Athena::ChangeDatatype->new($app->{main}, $app);
  my $result = $cdt -> ShowModal;
  if ($result == wxID_CANCEL) {
    $app->{main}->status("Not changing datatype.");
    return;
  };

  my $newtype = ($cdt->{to}->GetSelection == 0) ? 'xmu'
              : ($cdt->{to}->GetSelection == 1) ? 'xanes'
              : ($cdt->{to}->GetSelection == 2) ? 'norm'
              : ($cdt->{to}->GetSelection == 3) ? 'chi'
              : ($cdt->{to}->GetSelection == 4) ? 'xmudat'
	      :                                   'xmu';
  if ($cdt->{how}->GetSelection == 0) {
    $app->current_data->datatype($newtype);
    $app->{main}->status("Changed current group's data type to $newtype");
  } else {
    foreach my $j (0 .. $app->{main}->{list}->GetCount-1) {
      if ($app->{main}->{list}->IsChecked($j)) {
	$app->{main}->{list}->GetClientData($j)->datatype($newtype);
      };
    };
    $app->{main}->status("Changed all marked groups to data type $newtype");
  };
  $app->modified(1);
  $app->{main}->{Main}->mode($app->current_data, 1, 0);
};

sub Report {
  my ($app, $how, $fname) = @_;
  $how ||= 'all';

  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Save spreadsheet report", cwd, q{athena.xls},
				  "Athena project (*.xls)|*.xls|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Saving report cancelled.");
      return;
    };
    $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };

  my $workbook = Spreadsheet::WriteExcel->new($fname);
  my $worksheet = $workbook->add_worksheet();

  header($worksheet, 7);
  my $r = 8;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    row($worksheet, $r, $app->{main}->{list}->GetClientData($i));
    ++$r;
  };
#  $workbook->close;
  $app->{main}->status("Wrote report to ".$fname);
};


sub header {
  my ($worksheet, $i) = @_;
  $worksheet->write($i, 0, "Group");
  $worksheet->write($i, 1, "Element");
  $worksheet->write($i, 2, "Edge");
  $worksheet->write($i, 3, "Importance");
  $worksheet->write($i, 4, "Edge shift");

  $worksheet->write($i, 6, "E0");
  $worksheet->write($i, 7, "Algorithm");
  $worksheet->write($i, 8, "Rbkg");
  $worksheet->write($i, 9, "k-weight");
  $worksheet->write($i,10, "Normalization order");
  $worksheet->write($i,11, "Pre-edge range");
  $worksheet->write($i,12, "Normalization range");
  $worksheet->write($i,13, "Spline range (k)");
  $worksheet->write($i,14, "Spline range (E)");
  $worksheet->write($i,15, "Edge step");
  $worksheet->write($i,16, "Standard");
  $worksheet->write($i,17, "Lower clamp");
  $worksheet->write($i,18, "Upper clamp");

  $worksheet->write($i,20, "k-range");
  $worksheet->write($i,21, "dk");
  $worksheet->write($i,22, "Window");
  $worksheet->write($i,23, "Arb. kw");
  $worksheet->write($i,24, "Phase correction");

  $worksheet->write($i,26, "R-range");
  $worksheet->write($i,27, "dR");

  $worksheet->write($i,29, "Plot multiplier");
  $worksheet->write($i,30, "y offset");
};
sub row {
  my ($worksheet, $i, $data) = @_;

  $worksheet->write($i, 0, $data->name);
  $worksheet->write($i, 1, get_name($data->bkg_z));
  $worksheet->write($i, 2, $data->fft_edge);
  $worksheet->write($i, 3, $data->importance);
  $worksheet->write($i, 4, $data->bkg_eshift);

  $worksheet->write($i, 6, $data->bkg_e0);
  $worksheet->write($i, 7, $data->bkg_algorithm);
  $worksheet->write($i, 8, $data->bkg_rbkg);
  $worksheet->write($i, 9, $data->bkg_kw);
  $worksheet->write($i,10, $data->bkg_nnorm);
  $worksheet->write($i,11, sprintf("[%.3f:%.3f]", $data->bkg_pre1,  $data->bkg_pre2 ));
  $worksheet->write($i,12, sprintf("[%.3f:%.3f]", $data->bkg_nor1,  $data->bkg_nor2 ));
  $worksheet->write($i,13, sprintf("[%.3f:%.3f]", $data->bkg_spl1,  $data->bkg_spl2 ));
  $worksheet->write($i,14, sprintf("[%.3f:%.3f]", $data->bkg_spl1e, $data->bkg_spl2e));
  $worksheet->write($i,15, $data->bkg_step);
  my $stan = ($data->bkg_stan ne 'None') ? $data->bkg_stan->name : 'none';
  $worksheet->write($i,16, $stan);
  $worksheet->write($i,17, $data->number2clamp($data->bkg_clamp1));
  $worksheet->write($i,18, $data->number2clamp($data->bkg_clamp2));

  $worksheet->write($i,20, sprintf("[%.3f:%.3f]", $data->fft_kmin,  $data->fft_kmax ));
  $worksheet->write($i,21, $data->fft_dk);
  $worksheet->write($i,22, $data->fft_kwindow);
  $worksheet->write($i,23, $data->fit_karb_value);
  $worksheet->write($i,24, $data->yesno($data->fft_pc));

  $worksheet->write($i,26, sprintf("[%.3f:%.3f]", $data->bft_rmin,  $data->bft_rmax ));
  $worksheet->write($i,27, $data->bft_dr);

  $worksheet->write($i,29, $data->plot_multiplier);
  $worksheet->write($i,30, $data->y_offset);
};

1;
