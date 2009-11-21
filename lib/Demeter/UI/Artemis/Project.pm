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
use Carp;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;
use File::Basename;
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
		import_old);

use File::Basename;
use File::Spec;

sub save_project {
  my ($rframes, $fname) = @_;

  ## make sure we are fully up to date and serialised
  my ($abort, $rdata, $rpaths) = Demeter::UI::Artemis::uptodate($rframes);
  my $rgds = $rframes->{GDS}->reset_all(1);
  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  ## get name, fom, and description + other properties

  $rframes->{main} -> {currentfit}  = Demeter::Fit->new(interface=>"Artemis (Wx)")
    if (not $rframes->{main} -> {currentfit});
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
    $rframes->{$k}->{Atoms}->save_file($file);
  };
  if ((not $fname) or ($fname =~ m{\<untitled\>})) {
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
    $rframes->{main}->{statusbar}->SetStatusText("Saved project as ".$rframes->{main}->{projectpath});
    modified(0);
  };
};

sub autosave {
  return if not $Demeter::UI::Artemis::demeter->co->default("artemis", "autosave");
  my $main = $Demeter::UI::Artemis::frames{main};
  $main->{statusbar}->SetStatusText("Performed autosave ...");
  unlink $main->{autosave_file};
  my $name = $_[0] || $main->{name}->GetValue;
  $name =~ s{\s+}{_}g;
  $main->{autosave_file} = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, $name.'.autosave');
  save_project(\%Demeter::UI::Artemis::frames, $main->{autosave_file});
  $main->{statusbar}->SetStatusText("Performed autosave ... done!");
};
sub clear_autosave {
  return if not $Demeter::UI::Artemis::demeter->co->default("artemis", "autosave");
  my $main = $Demeter::UI::Artemis::frames{main};
  unlink $main->{autosave_file};
  $main->{statusbar}->SetStatusText("Removed autosave file.");
};
sub autosave_exists {
  opendir(my $stash, $Demeter::UI::Artemis::demeter->stash_folder);
  my @list = readdir $stash;
  closedir $stash;
  return any {$_ =~ m{autosave\z}} @list;
};
sub import_autosave {
  my $dialog = Demeter::UI::Wx::AutoSave->new($Demeter::UI::Artemis::frames{main});
  $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText("There are no autosave files."), return
    if ($dialog == -1);
  $dialog->SetFocus;
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText("Autosave import cancelled.");
  } else {
    my $this = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, $dialog->GetStringSelection);
    read_project(\%Demeter::UI::Artemis::frames, $this);
    unlink $this;
    ## need to clean up the corresponding folder, if it has been left behind
  };

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

  %Demeter::UI::Artemis::fit_order = YAML::Tiny::LoadFile(File::Spec->catfile($projfolder, 'order'));
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

    if (not $feffobject->hidden) {
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
  };

  ## -------- import fit history from project file (currently only importing most recent)
  opendir(my $FITS, File::Spec->catfile($projfolder, 'fits/'));
  @dirs = grep { $_ =~ m{\A[a-z]} } readdir($FITS);
  closedir $FITS;
  my $current = $Demeter::UI::Artemis::fit_order{order}{current};
  $current = $Demeter::UI::Artemis::fit_order{order}{$current};
  $current ||= $dirs[0];
  my $fit;
  foreach my $d (@dirs) {
    next unless ($d eq $current);
    $fit = Demeter::Fit->new(group=>$d);
    $fit->deserialize(folder=> File::Spec->catfile($projfolder, 'fits', $d));
    $rframes->{main}->{currentfit} = $fit;
    $rframes->{Plot}->{limits}->{fit}->SetValue(1);
    my $current = $fit->number || 1;
    ++$current;
    $fit->mo->currentfit($current);
    my $name = ($fit->name =~ m{\A\s*Fit\s+\d+\z}) ? 'Fit '.$fit->mo->currentfit : $fit->name;
    $rframes->{main}->{name}->SetValue($name);
    $rframes->{main}->{description}->SetValue($fit->description);
  };

  ## -------- load up the GDS parameters
  my $grid  = $rframes->{GDS}->{grid};
  my $start = $rframes->{GDS}->find_next_empty_row;
  foreach my $g (@{$fit->gds}) {
    $grid->AppendRows(1,1) if ($start >= $grid->GetNumberRows);
    $grid -> SetCellValue($start, 0, $g->gds);
    $grid -> SetCellValue($start, 1, $g->name);
    $grid -> SetCellValue($start, 2, $g->mathexp);
    $grid -> {$g->name} = $g;
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
      my $feff = $feffs{$p->{parentgroup}} || $fit -> mo -> fetch('Feff', $p->{parentgroup});
      $p->set(folder=>$feff->workspace, file=>q{}, update_path=>1);
      next if ($p->data ne $d);
      $p->parent($feff);
      #my $this_sp = find_sp($p, \%feffs) || $fit->mo->fetch('ScatteringPath', $p->spgroup);
      #$p->sp($this_sp);
      my $page = Demeter::UI::Artemis::Path->new($rframes->{$dnum}->{pathlist}, $p, $rframes->{$dnum});
      my $n = $rframes->{$dnum}->{pathlist}->AddPage($page, $p->label, 1, 0);
      $page->include_label;
      $rframes->{$dnum}->{pathlist}->Check($n, $p->mark);
    };
    $rframes->{$dnum}->{pathlist}->SetSelection(0);
    if (not $count) {
      $rframes->{$dnum}->Show(1);
      $rframes->{main}->{datatool}->ToggleTool($idata,1);
    };
    ++$count;
  };

  my $py = File::Spec->catfile($rframes->{main}->{plot_folder}, 'plot.yaml');
  if (-e $py) {
    $Demeter::UI::Artemis::demeter->po->set(%{YAML::Tiny::LoadFile($py)});
    $rframes->{Plot}->populate;
  };
  my $iy = File::Spec->catfile($rframes->{main}->{plot_folder}, 'indicators.yaml');
  if (-e $iy) {
    my @list = YAML::Tiny::LoadFile($iy);
    $rframes->{Plot}->{indicators}->populate(@list);
  };

  my $journal = File::Spec->catfile($rframes->{main}->{project_folder}, 'journal');
  if (-e $journal) {
    $rframes->{Journal}->{journal}->SetValue($Demeter::UI::Artemis::demeter->slurp($journal));
  };

  $rframes->{Log}->{name} = $fit->name;
  $rframes->{Log}->put_log($fit->logtext, $fit->color);
  $rframes->{Log}->SetTitle("Artemis [Log] " . $fit->name);
  $rframes->{Log}->Show(0);
  $rframes->{main}->{log_toggle}->SetValue(0);
  Demeter::UI::Artemis::set_happiness_color($fit->color);

  $Demeter::UI::Artemis::demeter->push_mru("artemis", $fname);
  &Demeter::UI::Artemis::set_mru;
  $rframes->{main}->{projectpath} = $fname;
  $rframes->{main}->{projectname} = basename($fname, '.fpj');
  modified(0);
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
  $main->SetTitle($title);
};


sub close_project {
  my ($rframes) = @_;
  my $yesno = Wx::MessageDialog->new($rframes->{main},
				     "Save this project before closing?",
				     "Save project?",
				     wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
  my $result = $yesno->ShowModal;
  if ($result == wxID_CANCEL) {
    $rframes->{main}->{statusbar}->SetStatusText("Not closing project.");
    return 0;
  };
  save_project($rframes) if $result == wxID_YES;

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

  ## -------- clear Journal
  $rframes->{Journal}->{journal}->SetValue(q{});
  unlink File::Spec->catfile($rframes->{main}->{project_folder}, 'journal');

};


sub import_old {
  my ($rframes, $file) = @_;
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

  my $unzip = File::Spec->catfile($Demeter::UI::Artemis::demeter->stash_folder, '_old_'.basename($file));
  rmtree $unzip if (-d $unzip);
  mkpath $unzip;

  my $zip = Archive::Zip->new();
  carp("Error reading old-style project file $file"), return 1 unless ($zip->read($file) == AZ_OK);
  $zip->extractTree("", $unzip.'/');
  undef $zip;

  my $cpt = new Safe;
  my $description = File::Spec->catfile($unzip, 'descriptions', 'artemis');
  open(my $D, $description);
  while (<$D>) {
    next if (m{\A\s*\z});
    next if (m{\A\s*\#});
    next if (m{\A\s*\[record\]});

  SWITCH: {

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

	if ($og =~ m{\Adata\d+\z}) {
	  my $datafile = File::Spec->catfile($unzip, 'chi_data', basename($args{file}));
	  my $data = Demeter::Data->new(datatype       => 'chi',
					file	       => $datafile,
					name	       => $args{lab},
					bkg_rbkg       => $args{bkg_rbkg},
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
				       );
	  $data -> fit_do_bkg($data->onezero($args{do_bkg}));
	  $data -> titles(\@strings);
	  my ($dnum, $idata) = Demeter::UI::Artemis::make_data_frame($rframes->{main}, $data);
	  $rframes->{$dnum} -> Show(0);
	  $rframes->{main}->{datatool}->ToggleTool($idata,0);
	};

	## [record] line
	last SWITCH;
      };

      (m{\A\@parameter}) and do {
	last SWITCH;
      };

      (m{\A\%plot_features}) and do {
	last SWITCH;
      };

      (m{\A\@extra}) and do {
	last SWITCH;
      };

      (m{\A\%props}) and do {
	last SWITCH;
      };

    };
  };
  close $D;

};


1;
