package Demeter::UI::Athena::PCA;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_COMBOBOX EVT_RADIOBOX EVT_LIST_ITEM_SELECTED EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Cwd;
use File::Basename;
use File::Spec;
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Principle components analysis";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize   = [50,-1];
my $demeter  = $Demeter::UI::Athena::demeter;
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  if (not exists $INC{'Demeter/PCA.pm'}) {
    $box->Add(Wx::StaticText->new($this, -1, "PCA is not enabled on this computer.\nThe most likely reason is that the perl modules PDL and/or PDL::Stats are not available."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {

    $this->{PCA} = Demeter::PCA->new(space=>'x', emin=>-20, emax=>80);
    $this->{xmin} = $demeter->co->default('pca', 'emin');
    $this->{xmax} = $demeter->co->default('pca', 'emax');

    ## -------- analysis range and space
    my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $box->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
    $hbox->Add(Wx::StaticText->new($this, -1, 'Analysis range:'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
    $this->{xmin} = Wx::TextCtrl->new($this, -1, $this->{xmin}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
    $hbox->Add($this->{xmin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
    $this->{xmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
    $hbox->Add($this->{xmin_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

    $hbox->Add(Wx::StaticText->new($this, -1, 'to'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
    $this->{xmax} = Wx::TextCtrl->new($this, -1, $this->{xmax}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
    $hbox->Add($this->{xmax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
    $this->{xmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
    $hbox->Add($this->{xmax_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

    $this->{space} = Wx::RadioBox->new($this, -1, 'Analysis space', wxDefaultPosition, wxDefaultSize,
				       ["norm $MU(E)", "deriv $MU(E)", "$CHI(k)"],
				       1, wxRA_SPECIFY_ROWS);
    $hbox->Add($this->{space}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
    $this->{space}->SetSelection(0);
    EVT_RADIOBOX($this, $this->{space}, sub{OnSpace(@_)});
    $this->{xmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
    $this->{xmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
    #EVT_TEXT_ENTER($this, $this->{xmin}, sub{plot(@_)});
    #EVT_TEXT_ENTER($this, $this->{xmax}, sub{plot(@_)});

    ## -------- big button
    $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $box->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
    $this->{do_pca} = Wx::Button->new($this, -1, "Perform PCA");
    $hbox->Add($this->{do_pca}, 1, wxALL, 0);
    EVT_BUTTON($this, $this->{do_pca}, sub{pca(@_)});

    ## -------- report on PCA
    $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $box->Add($hbox, 2, wxGROW|wxLEFT|wxRIGHT, 5);
    $this->{result} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
    my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
    $this->{result}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    $hbox->Add($this->{result}, 1, wxGROW|wxALL, 5);

    $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $box->Add($hbox, 3, wxGROW|wxLEFT|wxRIGHT, 5);
    my $plotbox       = Wx::StaticBox->new($this, -1, 'Plots', wxDefaultPosition, wxDefaultSize);
    my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxVERTICAL );
    $hbox -> Add($plotboxsizer, 1, wxGROW|wxALL, 5);
    $this->{screebox}   = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{scree}      = Wx::Button->new($this, -1, 'Scree');
    $this->{logscree}   = Wx::CheckBox->new($this, -1, 'Log');
    $this->{cumvar}     = Wx::Button->new($this, -1, 'Cumulative variance');
    $this->{stack}      = Wx::Button->new($this, -1, 'Data stack');
    $this->{frombox}    = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{ncomptext}  = Wx::StaticText->new($this, -1, "from");
    $this->{ncomp}      = Wx::SpinCtrl->new($this, -1, 1, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 1, 100);
    $this->{components} = Wx::Button->new($this, -1, 'Components');

    $this->{screebox} -> Add($this->{scree}, 1, wxRIGHT, 5);
    $this->{screebox} -> Add($this->{logscree}, 0, wxTOP, 2);
    $this->{frombox}  -> Add($this->{components}, 1, wxALL, 0);
    $this->{frombox}  -> Add($this->{ncomptext}, 0, wxRIGHT|wxLEFT|wxTOP, 4);
    $this->{frombox}  -> Add($this->{ncomp}, 0, wxGROW|wxALL, 0);

    my $clusterbox       = Wx::StaticBox->new($this, -1, 'Cluster analysis', wxDefaultPosition, wxDefaultSize);
    my $clusterboxsizer  = Wx::StaticBoxSizer->new( $clusterbox, wxVERTICAL );
    $this->{clusbox}     = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{cluster1}    = Wx::SpinCtrl->new($this, -1, 1, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 1, 100);
    $this->{cluster2}    = Wx::SpinCtrl->new($this, -1, 2, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 1, 100);
    $this->{clusvs}      = Wx::StaticText->new($this, -1, "vs");
    $this->{clusbox}    -> Add(1,1,1);
    $this->{clusbox}    -> Add($this->{cluster1}, 0, wxALL, 0);
    $this->{clusbox}    -> Add($this->{clusvs},   0, wxLEFT|wxRIGHT|wxTOP, 3);
    $this->{clusbox}    -> Add($this->{cluster2}, 0, wxALL, 0);
    $this->{clusbox}    -> Add(1,1,1);
    $clusterboxsizer    -> Add($this->{clusbox},  1, wxGROW|wxTOP, 3);
    $this->{clusplot}    = Wx::Button->new($this, -1, "Cluster plot");
    $clusterboxsizer    -> Add($this->{clusplot},  1, wxGROW|wxALL, 0);

    foreach my $w (qw(frombox stack screebox cumvar)) {
      $plotboxsizer->Add($this->{$w}, 0, wxGROW|wxALL, 0);
    };
    $plotboxsizer -> Add($clusterboxsizer, 0, wxGROW|wxALL, 0);
    foreach my $w (qw(scree logscree cumvar stack components ncomptext ncomp cluster1 cluster2 clusvs clusplot)) {
      $this->{$w}->Enable(0);
    };
    EVT_BUTTON($this, $this->{scree},      sub{plot_scree(@_)});
    EVT_BUTTON($this, $this->{cumvar},     sub{plot_cumvar(@_)});
    EVT_BUTTON($this, $this->{stack},      sub{plot_stack(@_)});
    EVT_BUTTON($this, $this->{components}, sub{plot_components(@_)});
    EVT_BUTTON($this, $this->{clusplot},   sub{plot_cluster(@_)});


    my $actionsbox       = Wx::StaticBox->new($this, -1, 'Actions', wxDefaultPosition, wxDefaultSize);
    my $actionsboxsizer  = Wx::StaticBoxSizer->new( $actionsbox, wxVERTICAL );
    $hbox -> Add($actionsboxsizer, 1, wxGROW|wxALL, 5);
    $this->{nrecbox}     = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{rectext}     = Wx::StaticText->new($this, -1, "with");
    $this->{nrecon}      = Wx::SpinCtrl->new($this, -1, 2, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 1, 100);
    $this->{reconstruct} = Wx::Button->new($this, -1, 'Reconstruct data');
    $this->{tt}          = Wx::Button->new($this, -1, 'Target transform');

    my $ttbox       = Wx::StaticBox->new($this, -1, 'TT coefficients', wxDefaultPosition, wxDefaultSize);
    my $ttboxsizer  = Wx::StaticBoxSizer->new( $ttbox, wxVERTICAL );

    $this->{transform} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					 wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
    $this->{transform}->SetFont( Wx::Font->new( $size-1, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

    $this->{nrecbox} -> Add($this->{reconstruct}, 1, wxALL, 0);
    $this->{nrecbox} -> Add($this->{rectext}, 0, wxRIGHT|wxLEFT|wxTOP, 4);
    $this->{nrecbox} -> Add($this->{nrecon}, 0, wxGROW|wxALL, 0);
    foreach my $w (qw(nrecbox tt)) {
      $actionsboxsizer->Add($this->{$w}, 0, wxGROW|wxALL, 0);
    };
    $ttboxsizer->Add($this->{transform}, 1, wxGROW|wxALL, 0);
    $actionsboxsizer -> Add($ttboxsizer, 1, wxGROW|wxALL, 0);
    foreach my $w (qw(rectext nrecon reconstruct tt)) {
      $this->{$w}->Enable(0);
    };
    EVT_BUTTON($this, $this->{reconstruct}, sub{reconstruct(@_)});
    EVT_BUTTON($this, $this->{tt},          sub{tt(@_)});
    EVT_BUTTON($this, $this->{savecomp},    sub{save_components(@_)});
    EVT_BUTTON($this, $this->{savestack},   sub{save_stack(@_)});

    my $savebox       = Wx::StaticBox->new($this, -1, 'Save things to files', wxDefaultPosition, wxDefaultSize);
    my $saveboxsizer  = Wx::StaticBoxSizer->new( $savebox, wxHORIZONTAL );
    $box -> Add($saveboxsizer, 0, wxGROW|wxALL, 2);
    $this->{savecomp}    = Wx::Button->new($this, -1, 'Components');
    $this->{savestack}   = Wx::Button->new($this, -1, 'Data stack');
    $this->{saverecon}   = Wx::Button->new($this, -1, 'Data reconstruction');
    $this->{savett}      = Wx::Button->new($this, -1, 'Target transform');
    $saveboxsizer -> Add($this->{savecomp},  1, wxGROW|wxALL, 0);
    $saveboxsizer -> Add($this->{savestack}, 1, wxGROW|wxALL, 0);
    $saveboxsizer -> Add($this->{saverecon}, 1, wxGROW|wxALL, 0);
    $saveboxsizer -> Add($this->{savett},    1, wxGROW|wxALL, 0);

    EVT_BUTTON($this, $this->{savecomp},  sub{save_components(@_)});
    EVT_BUTTON($this, $this->{savestack}, sub{save_stack(@_)});
    EVT_BUTTON($this, $this->{saverecon}, sub{save_reconstruction(@_)});
    EVT_BUTTON($this, $this->{savett},    sub{save_tt(@_)});
    foreach my $w (qw(savecomp savestack saverecon savett)) {
      $this->{$w}->Enable(0);
    };
  };

  $this->{document} = Wx::Button->new($this, -1, 'Document section: principle components analysis');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("pca")});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  return if (not exists $INC{'Demeter/PCA.pm'});
  my $enable = not $this->{PCA}->update_pca;
  if ($::app->{main}->{list}->IsChecked($::app->current_index)) {
    $this->{$_} -> Enable($enable) foreach qw(reconstruct rectext nrecon);
    $this->{tt} -> Enable(0);
  } else {
    $this->{$_} -> Enable(0) foreach qw(reconstruct rectext nrecon);
    $this->{tt} -> Enable($enable);
  };
  $this->{saverecon}->Enable(0);
  $this->{savett}->Enable(0);
};

sub OnSpace {
  my ($this, $event) = @_;
  $this->{result}->Clear;
  $this->{transform}->Clear;
  $this->disable;
  if ($this->{space}->GetSelection == 2) {
    $this->{PCA}->space('k');
    $this->{xmin}->SetValue($this->{PCA}->kmin);
    $this->{xmax}->SetValue($this->{PCA}->kmax);
  } else {
    if ($this->{space}->GetSelection == 1) {
      $this->{PCA}->space('d');
    } else {
      $this->{PCA}->space('x');
    };
    $this->{xmin}->SetValue($this->{PCA}->emin);
    $this->{xmax}->SetValue($this->{PCA}->emax);
  };
};

sub tilt {
  my ($this, $text, $no_result) = @_;
  $this->{result}->SetValue($text) if not $no_result;
  $::app->{main}->status($text, 'error');
  return 0;
};

sub disable {
  my ($this) = @_;
  foreach my $w (qw(scree logscree cumvar stack components ncomptext ncomp savecomp savestack saverecon savett
		    reconstruct rectext nrecon tt)) {
    $this->{$w}->Enable(0);
  };
  $this->{result}->Clear;
  $this->{transform}->Clear;
  $this->{PCA}->clear_stack;
};

sub pca {
  my ($this, $event) = @_;

  my $busy = Wx::BusyCursor->new();
  $::app->{main}->status("Performing principle components analysis ...", 'wait');
  $this->disable;
  if (not looks_like_number($this->{xmin}->GetValue)) {
    my $letter = ($this->{space}->GetSelection == 2) ? 'k' : 'E';
    return $this->tilt("Your ${letter}min value is not a number");
  };
  if (not looks_like_number($this->{xmax}->GetValue)) {
    my $letter = ($this->{space}->GetSelection == 2) ? 'k' : 'E';
    return $this->tilt("Your ${letter}max value is not a number");
  };
  if ($this->{space}->GetSelection == 2) { # chi(k)
    $this->{PCA}->kmin($this->{xmin}->GetValue);
    $this->{PCA}->kmax($this->{xmax}->GetValue);
    $this->{PCA}->xmin($this->{xmin}->GetValue);
    $this->{PCA}->xmax($this->{xmax}->GetValue);
  } else {				   # xmu(E) or deriv(E)
    $this->{PCA}->emin($this->{xmin}->GetValue);
    $this->{PCA}->emax($this->{xmax}->GetValue);
    $this->{PCA}->xmin($this->{xmin}->GetValue);
    $this->{PCA}->xmax($this->{xmax}->GetValue);
  };
  my $count = 0;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    next if not $::app->{main}->{list}->IsChecked($i);
    ++$count;
    $this->{PCA}->add($::app->{main}->{list}->GetIndexedData($i));
  };
  if ($count < 3) {
    $this->tilt("Your data set is not large enough.  You must mark at least 3 data groups");
    return;
  };
  $this->{PCA}->do_pca;
  if ($this->{PCA}->undersampled) {
    $this->tilt("Your problem is undersampled, try increasing the analysis range");
    return;
  };
  $::app->{main}->status(sprintf("Performed principle components analysis on %d data groups with %d observations",
				 $this->{PCA}->ndata, $this->{PCA}->observations));
  foreach my $w (qw(scree logscree cumvar stack components ncomptext ncomp savecomp savestack
		    cluster1 cluster2 clusvs clusplot)) {
    $this->{$w}->Enable(1);
  };
  $this->{$_} ->SetRange(1, $this->{PCA}->ndata) foreach qw(ncomp nrecon cluster1 cluster2);

  if ($::app->{main}->{list}->IsChecked($::app->current_index)) {
    $this->{$_} -> Enable(1) foreach qw(reconstruct rectext nrecon);
  } else {
    $this->{tt}->Enable(1);
  };

  $this->{result}->SetValue($this->{PCA}->report);
  $this->plot_components;
  undef $busy;
};

sub plot_scree {
  my ($this, $event) = @_;
  $this->{PCA}->plot_scree($this->{logscree}->GetValue);
};
sub plot_cumvar {
  my ($this, $event) = @_;
  $this->{PCA}->plot_variance;
};
sub plot_stack {
  my ($this, $event) = @_;
  $this->{PCA}->plot_stack;
};
sub plot_components {
  my ($this, $event) = @_;
  $this->{PCA}->plot_components($this->{ncomp}->GetValue-1 .. $this->{PCA}->ndata-1);
};

sub plot_cluster {
  my ($this, $event) = @_;
  $this->tilt("Cluster analysis (not yet implemented) ...", 1);
};


sub tt {
  my ($this, $event) = @_;
  $this->{transform}->Clear;
  my $target = $::app->current_data;
  $this->{PCA}->tt($target);
  $this->{PCA}->plot_tt($target);
  $this->{transform}->SetValue($this->{PCA}->tt_report($target));
  $this->{savett}->Enable(1);
  $::app->{main}->status(sprintf("Made target transform of %s", $::app->current_data->name));
};

sub reconstruct {
  my ($this, $event) = @_;
  $this->{PCA}->reconstruct($this->{nrecon}->GetValue);
  my $data_index = 0;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    ++$data_index if $::app->{main}->{list}->IsChecked($i);
    last if ($data_index = $::app->current_index);
  };
  $this->{PCA}->plot_reconstruction($data_index);
  $this->{saverecon}->Enable(1);
  $::app->{main}->status(sprintf("Made reconstruction of %s with %d components", $::app->current_data->name, $this->{nrecon}->GetValue));
};

sub get_filename {
  my ($this, $suff, $given) = @_;
  $given ||= q{};
  my %defname = ( pca=>'components', stack=>'datastack', recon=>'reconstruction', tt=>'targettransform' );
  my %descr   = ( pca=>'components', stack=>'data stack', recon=>'reconstruction', tt=>'target transform' );
  my $name = $given || basename($::app->{main}->{currentproject}, '.prj') || $defname{$suff};
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save PCA $descr{$suff} to a file", cwd, join(".", $name, $suff),
				uc($suff)." (*.$suff)|*.$suff|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving PCA $descr{$suff} to a file has been cancelled.");
    return 0;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  return 0 if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $::app->{main}->status("Wrote PCA $descr{$suff} to $fname");
  return $fname;
};

sub save_components {
  my ($this, $event) = @_;
  my $fname = $this->get_filename('pca');
  return if not $fname;
  $this->{PCA}->save_components($fname);
};

sub save_stack {
  my ($this, $event) = @_;
  my $fname = $this->get_filename('stack');
  return if not $fname;
  $this->{PCA}->save_stack($fname);
};

sub save_reconstruction {
  my ($this, $event) = @_;
  my $data = $::app->current_data;
  (my $name = $data->name) =~ s{\s+}{_}g;
  my $fname = $this->get_filename('recon', $name);
  return if not $fname;
  my $data_index = 0;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    ++$data_index if $::app->{main}->{list}->IsChecked($i);
    last if ($data_index = $::app->current_index);
  };
  $this->{PCA}->save_reconstruction($data_index, $fname);
};

sub save_tt {
  my ($this, $event) = @_;
  my $target = $::app->current_data;
  (my $name = $target->name) =~ s{\s+}{_}g;
  my $fname = $this->get_filename('tt', $name);
  return if not $fname;
  $this->{PCA}->save_tt($target, $fname);
};

1;


=head1 NAME

Demeter::UI::Athena::PCA - A principle components analysis tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.5.

=head1 SYNOPSIS

This module provides a

See L<http://mailman.jach.hawaii.edu/pipermail/perldl/2006-August/000588.html>

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
