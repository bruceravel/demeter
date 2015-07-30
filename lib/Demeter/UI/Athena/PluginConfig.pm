package Demeter::UI::Athena::PluginConfig;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Dialog);
use Demeter::UI::Wx::Config;
use Demeter::UI::Wx::Colours;

sub new {
  my ($class, $parent, $plugin, $group) = @_;
  my $this = $class->SUPER::new($parent, -1, $plugin." [Preferences]",
				wxDefaultPosition, [650,500],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  $this -> SetBackgroundColour( $wxBGC );
  EVT_CLOSE($this, \&on_close);

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  my $config = Demeter::UI::Wx::Config->new($this, \&target, $::app->{main});
  $config->populate($group);
  $config->{params}->Expand($config->{params}->GetRootItem);
  $box->Add($config, 1, wxGROW|wxALL, 5);

  my $close = Wx::Button->new($this, wxID_CANCEL, q{});
  $box->Add($close, 0, wxGROW|wxALL, 5);
  #EVT_BUTTON($this, $close, \&on_close);

  $this->SetSizer($box);
  return $this;
};


sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 # SWITCH: {
 #    ($param eq 'plotwith') and do {
 #      Demeter->plot_with($value);
 #      last SWITCH;
 #    };
 #  };

 #  ($save)
 #    ? $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param and an ini file was saved")
 #      : $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param");

  1;
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};


# use base qw(Wx::Dialog);
# my $box_font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 1;

# sub new {
#   my ($class, $parent, $cfg, $plugin) = @_;

#   my $this = $class->SUPER::new($parent, -1, "Athena: Configure a filetype plugin",
# 				wxDefaultPosition, [-1,400],
# 				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxSTAY_ON_TOP
# 			       );
#   my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

#   $this->{header} = Wx::StaticText->new($this, -1, "Configure the $plugin plugin");
#   $this->{header} -> SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize+2, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
#   $vbox->Add($this->{header}, 0, wxALL, 5);

#   $this->{window} = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
#   my $winbox  = Wx::BoxSizer->new( wxVERTICAL );
#   $this->{window} -> SetSizer($winbox);
#   $this->{window} -> SetScrollbars(0, 20, 0, 50);
#   $vbox->Add($this->{window}, 1, wxALL|wxGROW, 5);


#   my @sections = $cfg->Sections;
#   foreach my $s (@sections) {
#     #print join("|", $s, $cfg->Parameters($s)), $/;

#     my $box       = Wx::StaticBox->new($this->{window}, -1, "Section: $s", wxDefaultPosition, wxDefaultSize);
#     my $boxsizer  = Wx::StaticBoxSizer->new( $box, wxVERTICAL );
#     $box         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
#     $winbox      -> Add($boxsizer, 0, wxALL|wxGROW, 5);
#     my $gbs       = Wx::GridBagSizer->new( 5, 5 );
#     $boxsizer    -> Add($gbs, 0, wxALL|wxGROW, 5);

#     my $i = 0;
#     foreach my $p ($cfg->Parameters($s)) {
#       $gbs->Add(Wx::StaticText->new($this->{window}, -1, $p), Wx::GBPosition->new($i,0));
#       $this->{"$s.$p"} = Wx::TextCtrl->new($this->{window}, -1, $cfg->val($s, $p), wxDefaultPosition, [250,-1]);
#       $gbs->Add($this->{"$s.$p"}, Wx::GBPosition->new($i,1));
#       ++$i;
#     };
#   };
#   my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
#   $vbox -> Add($hbox, 0, wxALL|wxGROW, 5);
#   $this->{ok} = Wx::Button->new($this, wxID_OK, q{});
#   $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, q{});
#   $hbox -> Add($this->{ok}, 1, wxALL, 5);
#   $hbox -> Add($this->{cancel}, 1, wxALL, 5);

#   $this -> SetSizer( $vbox );
#   return $this;
# };


1;


=head1 NAME

Demeter::UI::Athena::Prefs - A preferences tool for Athena's filetype plugins

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This module wraps up L<Demeter::UI::Wx::Config> for use in Athena's
plugin registry.

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

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
