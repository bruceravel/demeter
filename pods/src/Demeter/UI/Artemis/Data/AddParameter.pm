package  Demeter::UI::Artemis::Data::AddParameter;

=for Copyright
 .
 Copyright (c) 2006-2018 Bruce Ravel (http://bruceravel.github.io/home).
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

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);
use Demeter::UI::Wx::SpecialCharacters qw(:all);

sub new {
  my ($class, $parent) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Edit a path parameter",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );
  #$vbox -> Add(Wx::StaticText->new($this, -1, "Edit a path parameter"), 0, wxALL, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);
  $hbox -> Add(Wx::StaticText->new($this, -1, "Parameter"), 0, wxALL, 5);
  $this->{paramlabel} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize, ['S02',$DELTA.'E0',$DELTA.'R', $SIGSQR,'Ei','3rd','4th', 'Label']);
  $hbox->Add($this->{paramlabel}, 1, wxGROW|wxALL, 2);
  EVT_CHOICE($this, $this->{paramlabel}, \&OnChoice);
  $this->{param} = 's02';

  my $box      = Wx::StaticBox->new($this, -1, ' Math expression ', wxDefaultPosition, wxDefaultSize);
  my $boxsizer = Wx::StaticBoxSizer->new( $box, wxHORIZONTAL );
  $this->{me}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,);
  $boxsizer   -> Add($this->{me}, 1, wxALL|wxGROW, 0);
  $vbox       -> Add($boxsizer, 0, wxALL|wxGROW, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);
  $this->{apply} = Wx::RadioBox->new($this, -1, ' Apply to ', wxDefaultPosition, wxDefaultSize,
				     [
				      'all paths in this Feff calculation',
				      'all paths in this data set',
				      'all paths in all data sets',
				      'all marked paths',
				     ],
				     4, wxRA_SPECIFY_ROWS);
  $this->{apply}->Enable(2,0);
  $hbox->Add($this->{apply}, 1, wxGROW|wxALL, 2);


  $this->{ok} = Wx::Button->new($this, wxID_OK, "Apply this parameter", wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);


  $this -> SetSizerAndFit( $vbox );
  return $this;
};


sub OnChoice {
  my ($dialog, $event) = @_;
  my $param = $dialog->{paramlabel}->GetStringSelection;
  $param = ($param =~ m{E0})                       ? 'e0'
         : ($param =~ m{R})                        ? 'delr'
         : ($param =~ m{3rd})                      ? 'third'
	 : ($param =~ m{4th})                      ? 'fourth'
	 : ($param =~ m{(?:S02|Ei|Label|Dphase)}i) ? $param
         :                                           'sigma2';
  $param = lc($param);
  $dialog->{param} = $param;
};

sub ShouldPreventAppExit {
  0
};

1;



=head1 NAME

Demeter::UI::Artemis::Data::AddParameter - Path parameter editing widget

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module provides a dialog for editing path parameter values.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2018 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
