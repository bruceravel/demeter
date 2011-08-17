package Demeter::UI::Athena::Group;

use strict;
use warnings;

#use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ChangeDatatype;

use Cwd;
use Chemistry::Elements qw(get_name);
use List::Util qw(min);
use Spreadsheet::WriteExcel;

use Wx qw(:everything);
use Wx::Event qw(EVT_CHAR);
use base qw( Exporter );
our @EXPORT = qw(Rename Copy Remove change_datatype tie_reference Report set_text_buffer OnChar);

sub Rename {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $name = $data->name;
  (my $realname = $name) =~ s{\A\s*(Ref\s+)}{};
  my $is_ref = $1;

  if (not $newname) {
    my $ted = Wx::TextEntryDialog->new($app->{main}, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    $app->set_text_buffer($ted, "rename");
    $ted->SetValue($name);
    if ($ted->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Renaming cancelled.");
      return;
    };
    $newname = $ted->GetValue;
  };
  $app->update_text_buffer("rename", $newname, 0);
  my $sel = $app->{main}->{list}->GetSelection;
  my $is_checked = $app->{main}->{list}->IsChecked($sel);

  my $prefix = ($is_ref) ? "  Ref " : q{};
  $data->name($prefix.$newname);
  $app->{main}->{list}->SetString($app->current_index, $prefix.$newname);
  if (($data->reference) and ($data->reference->name =~ m{\A\s*(?:Ref\s+)?$realname\s*\z})) {
    my $prefix = ($is_ref) ? q{} : "  Ref ";
    $data->reference->name($prefix.$newname);
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
      next if ($app->{main}->{list}->GetIndexedData($i) ne $data->reference);
      $app->{main}->{list}->SetString($i, $prefix.$newname);
    };
  };
  $app->OnGroupSelect(0,0,0);
  $app->{main}->{list}->Check($sel, $is_checked);
  $app->modified(1);
  $app->{main}->status("Renamed $name to $newname");
};

sub Copy {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $clone = $data->clone;
  $newname ||= "Copy of ".$data->name;
  $clone->name($newname);
  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($clone->name, $clone);
  } else {
    $app->{main}->{list}->InsertData($clone->name, $index+1, $clone);
  };
  $app->modified(1);
  $app->{main}->status("Copied ".$data->name);
  $app->heap_check(0);
  return $clone;
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
      $app->OnGroupSelect(0,0,0);
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
      $app->OnGroupSelect(0,0,0);
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
      my $this = $app->{main}->{list}->GetIndexedData($i);
      $this->dispose("erase \@group ".$this->group);
      $this->DEMOLISH;
    };
    $app->{main}->{list}->ClearAll;
    $app->{main}->{list}->{datalist} = [];
    $app->Clear;
    $app->{main}->{views}->SetSelection(0);
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
  my $data = $app->{main}->{list}->GetIndexedData($i);
  $data->dispose("erase \@group ".$data->group);
  $data->DEMOLISH;
  $app->{main}->{list}->DeleteData($i); # this calls the selection event on the new item
};


sub change_datatype {
  my ($app) = @_;
  if ($app->is_empty) {
    $app->{main}->status("No data!");
    return;
  };
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
  } elsif ($cdt->{how}->GetSelection == 1) {
    foreach my $j (0 .. $app->{main}->{list}->GetCount-1) {
      if ($app->{main}->{list}->IsChecked($j)) {
	$app->{main}->{list}->GetIndexedData($j)->datatype($newtype);
      };
    };
    $app->{main}->status("Changed all marked groups to data type $newtype");
  } else {
    foreach my $j (0 .. $app->{main}->{list}->GetCount-1) {
      $app->{main}->{list}->GetIndexedData($j)->datatype($newtype);
    };
    $app->{main}->status("Changed all groups to data type $newtype");
  };
  $app->modified(1);
  $app->{main}->{Main}->mode($app->current_data, 1, 0);
};

sub tie_reference {
  my ($app) = @_;
  my @marked = ();
  foreach my $j (0 .. $app->{main}->{list}->GetCount-1) {
    push(@marked, $app->{main}->{list}->GetIndexedData($j))
      if $app->{main}->{list}->IsChecked($j);
  };
  if ($#marked != 1) {
    $app->{main}->status("You must mark two and only two datagroups to tie as data and reference.");
    return;
  };
  if ($marked[0]->datatype !~ m{xanes|xmu}) {
    $app->{main}->status($marked[0]->name . " is not a $MU(E) datagroup");
    return;
  };
  if ($marked[1]->datatype !~ m{xanes|xmu}) {
    $app->{main}->status($marked[1]->name . " is not a $MU(E) datagroup");
    return;
  };
  $_->untie_reference foreach @marked;
  $marked[0]->reference($marked[1]);
  $app->OnGroupSelect(0,0,0);
  $app->{main}->status(sprintf("Tied %s and %s as data and reference", $marked[0]->name, $marked[1]->name));
};

sub Report {
  my ($app, $how, $fname) = @_;
  $how ||= 'all';

  if (not $fname) {
    my $fd = Wx::FileDialog->new( $app->{main}, "Save spreadsheet report", cwd, q{athena.xls},
				  "Athena project (*.xls)|*.xls|All files|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Saving report cancelled.");
      return;
    };
    $fname = $fd->GetPath;
    return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };

  my $workbook;
  {
    ## The evals in Spreadsheet::WriteExcel::Workbook::_get_checksum_method
    ## will set the eval error variable ($@) if any of Digest::XXX
    ## (XXX = MD4 | PERL::MD4 | MD5) are installed on the machine.
    ## This is not a problem -- crypto is not needed in the exported
    ## Excel file.  However, setting $@ will post a warning given that
    ## $SIG{__DIE__} is defined to use Wx::Perl::Carp.  So I need to
    ## locally undefine $SIG{__DIE__} to avoid having a completely
    ## pointless error message posted to the screen when the S::WE
    ## object is instantiated
    local $SIG{__DIE__} = undef;
    $workbook = Spreadsheet::WriteExcel->new($fname);
  };
  my $worksheet = $workbook->add_worksheet();

  header($workbook, $worksheet, 5);
  my $r = 7;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    row($workbook, $worksheet, $r, $app->{main}->{list}->GetIndexedData($i));
    ++$r;
  };
  $workbook->close;
  $app->{main}->status("Wrote spreadsheet report to ".$fname);
};


sub header {
  my ($workbook, $worksheet, $i) = @_;

  my $grouphead = $workbook->add_format();
  $grouphead -> set_bold;
  $grouphead -> set_bg_color('grey');
  $grouphead -> set_align('left');

  $worksheet->merge_range(1,  0, 1, 31, "Athena report -- ".$::app->current_data->identify, $grouphead);
  $worksheet->merge_range(2,  0, 2, 31, "This file created at ".$::app->current_data->now,  $grouphead);
  $worksheet->merge_range(3,  0, 3, 31, join(", ",
					     $::app->current_data->environment,
					     "Wx ".$Wx::VERSION,
					     "Spreadsheet::WriteExcel ".$Spreadsheet::WriteExcel::VERSION,
					    ),
			  $grouphead);


  $worksheet->merge_range($i,  6, $i, 18, "Background removal parameters",         $grouphead);
  $worksheet->merge_range($i, 20, $i, 24, "Forward Fourier transform parameters",  $grouphead);
  $worksheet->merge_range($i, 26, $i, 28, "Backward Fourier transform parameters", $grouphead);
  $worksheet->merge_range($i, 30, $i, 31, "Plotting  parameters",                  $grouphead);

  my $colhead = $workbook->add_format();
  $colhead -> set_bold;
  $colhead -> set_bg_color('grey');
  $colhead -> set_align('center');

  $worksheet->write($i+1, 0, "Group",               $colhead);
  $worksheet->write($i+1, 1, "Element",             $colhead);
  $worksheet->write($i+1, 2, "Edge",                $colhead);
  $worksheet->write($i+1, 3, "Importance",          $colhead);
  $worksheet->write($i+1, 4, "Edge shift",          $colhead);

  $worksheet->write($i+1, 6, "E0", $colhead);
  $worksheet->write($i+1, 7, "Algorithm",           $colhead);
  $worksheet->write($i+1, 8, "Rbkg",                $colhead);
  $worksheet->write($i+1, 9, "k-weight",            $colhead);
  $worksheet->write($i+1,10, "Normalization order", $colhead);
  $worksheet->write($i+1,11, "Pre-edge range",      $colhead);
  $worksheet->write($i+1,12, "Normalization range", $colhead);
  $worksheet->write($i+1,13, "Spline range (k)",    $colhead);
  $worksheet->write($i+1,14, "Spline range (E)",    $colhead);
  $worksheet->write($i+1,15, "Edge step",           $colhead);
  $worksheet->write($i+1,16, "Standard",            $colhead);
  $worksheet->write($i+1,17, "Lower clamp",         $colhead);
  $worksheet->write($i+1,18, "Upper clamp",         $colhead);

  $worksheet->write($i+1,20, "k-range",             $colhead);
  $worksheet->write($i+1,21, "dk",                  $colhead);
  $worksheet->write($i+1,22, "Window",              $colhead);
  $worksheet->write($i+1,23, "Arb. kw",             $colhead);
  $worksheet->write($i+1,24, "Phase correction",    $colhead);

  $worksheet->write($i+1,26, "R-range",             $colhead);
  $worksheet->write($i+1,27, "dR",                  $colhead);
  $worksheet->write($i+1,28, "Window",              $colhead);

  $worksheet->write($i+1,30, "Plot multiplier",     $colhead);
  $worksheet->write($i+1,31, "y offset",            $colhead);
};
sub row {
  my ($workbook, $worksheet, $i, $data) = @_;

  my $center = $workbook->add_format();
  $center -> set_align('center');
  my $number = $workbook->add_format();
  $number -> set_align('center');
  $number -> set_num_format('0.000');
  my $exponent = $workbook->add_format();
  $exponent -> set_align('center');
  $exponent -> set_num_format(0x0b);

  $worksheet->write($i, 0, sprintf(" %s", $data->name));
  $worksheet->write($i, 1, get_name($data->bkg_z),      $center);
  $worksheet->write($i, 2, ucfirst($data->fft_edge),    $center);
  $worksheet->write($i, 3, $data->importance,           $center);
  $worksheet->write($i, 4, $data->bkg_eshift,           $number);

  $worksheet->write($i, 6, $data->bkg_e0,               $number);
  $worksheet->write($i, 7, $data->bkg_algorithm,        $center);
  $worksheet->write($i, 8, $data->bkg_rbkg,             $number);
  $worksheet->write($i, 9, $data->bkg_kw,               $center);
  $worksheet->write($i,10, $data->bkg_nnorm,            $center);
  $worksheet->write($i,11, sprintf("[ %.3f : %.3f ]", $data->bkg_pre1,  $data->bkg_pre2 ), $center);
  $worksheet->write($i,12, sprintf("[ %.3f : %.3f ]", $data->bkg_nor1,  $data->bkg_nor2 ), $center);
  $worksheet->write($i,13, sprintf("[ %.3f : %.3f ]", $data->bkg_spl1,  $data->bkg_spl2 ), $center);
  $worksheet->write($i,14, sprintf("[ %.3f : %.3f ]", $data->bkg_spl1e, $data->bkg_spl2e), $center);
  $worksheet->write($i,15, $data->bkg_step,             $exponent);
  my $stan = ($data->bkg_stan ne 'None') ? $data->bkg_stan->name : 'None';
  $worksheet->write($i,16, $stan,                       $center);
  $worksheet->write($i,17, ucfirst($data->number2clamp($data->bkg_clamp1)), $center);
  $worksheet->write($i,18, ucfirst($data->number2clamp($data->bkg_clamp2)), $center);

  $worksheet->write($i,20, sprintf("[ %.3f : %.3f ]", $data->fft_kmin,  $data->fft_kmax ), $center);
  $worksheet->write($i,21, $data->fft_dk,               $number);
  $worksheet->write($i,22, $data->fft_kwindow,          $center);
  $worksheet->write($i,23, $data->fit_karb_value,       $center);
  $worksheet->write($i,24, $data->yesno($data->fft_pc), $center);

  $worksheet->write($i,26, sprintf("[ %.3f : %.3f ]", $data->bft_rmin,  $data->bft_rmax ), $center);
  $worksheet->write($i,27, $data->bft_dr,               $number);
  $worksheet->write($i,28, $data->bft_rwindow,          $center);

  $worksheet->write($i,30, $data->plot_multiplier,      $exponent);
  $worksheet->write($i,31, $data->y_offset,             $number);
};

1;
