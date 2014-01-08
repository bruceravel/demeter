package Demeter::UI::Athena::Plot::Style;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_LISTBOX EVT_LISTBOX_DCLICK);
use Wx::Perl::TextValidator;

use File::Basename;
use File::Copy;
use File::Spec;
use YAML::Tiny;

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $this->{make} = Wx::Button->new($this, -1, "Save current");
  $box->Add($this->{make}, 0, wxALL|wxGROW, 1);
  EVT_BUTTON($this, $this->{make}, sub{make_style(@_, $app)});

  $this->{list} = Wx::ListBox->new($this, -1, wxDefaultPosition, wxDefaultSize, [], wxLB_SINGLE|wxLB_NEEDED_SB);
  $box->Add($this->{list}, 1, wxALL|wxGROW, 1);
  EVT_LISTBOX($this, $this->{list}, sub{restore_style(@_, $app)});
  EVT_LISTBOX_DCLICK($this, $this->{list}, sub{discard_style(@_, $app)});

  $this->SetSizerAndFit($box);

  my $yaml = File::Spec->catfile($Demeter::UI::Athena::demeter->dot_folder, 'athena.styles');
  if (not -e $yaml) {
    copy(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'ini', 'athena.styles.ini'), $yaml);
  };
  my @list = YAML::Tiny::LoadFile($yaml);
  foreach my $sty (@list) {
    my $style = Demeter::Plot::Style->new();
    foreach my $att (keys %$sty) {
      next if ($att eq 'group');
      $style->$att($sty->{$att});
    };
    $this->{list}->Append($style->name, $style);
  };
  return $this;
};

sub label {
  return 'Plotting styles';
};


sub make_style {
  my ($this, $event, $app) = @_;

  my $ted = Wx::TextEntryDialog->new($app->{main}, "Enter a name for this style", "Name this style", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  $app->set_text_buffer($ted, "style");
  if ($ted->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Making new style canceled.");
    $app->{style_pointer} = $#{$app->{style_buffer}}+1;
    return;
  };
  my $name = $ted->GetValue;
  $app->update_text_buffer("style", $name, 1);
  if ($name =~ m{\A\s*\z}) {
    $app->{main}->status("No name provided.  Making new style canceled.");
    $app->{style_pointer} = $#{$app->{style_buffer}}+1;
    return;
  };

  my $style = Demeter::Plot::Style->new(name=>$name);

  $style -> set(emin => $app->{main}->{PlotE}->{emin}->GetValue,
		emax => $app->{main}->{PlotE}->{emax}->GetValue,
	       );
  $style -> set(kmin => $app->{main}->{PlotK}->{kmin}->GetValue,
		kmax => $app->{main}->{PlotK}->{kmax}->GetValue,
	       );
  # my $val = ($app->{main}->{PlotR}->{mmag} -> GetValue) ? 'm'
  #         : ($app->{main}->{PlotR}->{mre}  -> GetValue) ? 'r'
  #         : ($app->{main}->{PlotR}->{mim}  -> GetValue) ? 'i'
  #         : ($app->{main}->{PlotR}->{mpha} -> GetValue) ? 'p'
  # 	  :                                              'm';
  $style -> set(rmin => $app->{main}->{PlotR}->{rmin}->GetValue,
		rmax => $app->{main}->{PlotR}->{rmax}->GetValue,
		##r_pl => $val,
	       );
  # $val = ($app->{main}->{PlotQ}->{mmag} -> GetValue) ? 'm'
  #      : ($app->{main}->{PlotQ}->{mre}  -> GetValue) ? 'r'
  #      : ($app->{main}->{PlotQ}->{mim}  -> GetValue) ? 'i'
  #      : ($app->{main}->{PlotQ}->{mpha} -> GetValue) ? 'p'
  #      :                                               'm';
  $style -> set(qmin => $app->{main}->{PlotQ}->{qmin}->GetValue,
		qmax => $app->{main}->{PlotQ}->{qmax}->GetValue,
		##q_pl => $val,
	       );

  $this->{list}->Append($style->name, $style);
  # local $|=1;
  # foreach my $i (0 .. $this->{list}->GetCount-1) {
  #   print $this->{list}->GetClientData($i)->serialization;
  # };
  $this->persist;
  $app->{main}->status("Saved plotting style ".$style->name);
};

sub restore_style {
  my ($this, $event, $app) = @_;
  my $style = $this->{list}->GetClientData($this->{list}->GetSelection);
  return if not defined $style;
  $app->{main}->{PlotE}->{emin}->SetValue($style->emin);
  $app->{main}->{PlotE}->{emax}->SetValue($style->emax);
  $app->{main}->{PlotK}->{kmin}->SetValue($style->kmin);
  $app->{main}->{PlotK}->{kmax}->SetValue($style->kmax);
  $app->{main}->{PlotR}->{rmin}->SetValue($style->rmin);
  $app->{main}->{PlotR}->{rmax}->SetValue($style->rmax);
  $app->{main}->{PlotQ}->{qmin}->SetValue($style->qmin);
  $app->{main}->{PlotQ}->{qmax}->SetValue($style->qmax);
  $app->{main}->status("Restored plotting style ".$style->name);
};

sub discard_style {
  my ($this, $event, $app) = @_;
  my $i = $this->{list}->GetSelection;
  my $style = $this->{list}->GetClientData($i);
  my $yesno = Demeter::UI::Wx::VerbDialog->new($this, -1,
					       "Really discard the \"".$style->name."\" plotting style?",
					       "Really discard?",
					       "Discard");
  if ($yesno->ShowModal == wxID_NO) {
    $app->{main}->status("Not discarding ".$style->name);
    return;
  };
  my $n = $this->{list}->GetCount;
  # if ($n > 1) {
  #   if ($i = $n) {
  #     $this->{list}->SetSelection($i-1);
  #     $this->restore_style(q{}, $app);
  #   } else {
  #     $this->{list}->SetSelection($i+1);
  #     $this->restore_style(q{}, $app);
  #   };
  # };
  $this->{list}->Delete($i);
  $style->DEMOLISH;
  $this->persist;
  $app->{main}->status("Discarded plotting style ".$style->name);
  $event->Skip();
};

sub persist {
  my ($this) = @_;
  my $text = q{};
  foreach my $i (0 .. $this->{list}->GetCount-1) {
    $text .= $this->{list}->GetClientData($i)->serialization;
  };
  open(my $YAML, '>', File::Spec->catfile($Demeter::UI::Athena::demeter->dot_folder, 'athena.styles'));
  print $YAML $text;
  close $YAML;
};

1;


=head1 NAME

Demeter::UI::Athena::Plot::Style - plotting style controls

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This module provides controls for plotting styles in Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
