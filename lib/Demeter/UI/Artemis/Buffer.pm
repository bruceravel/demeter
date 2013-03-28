package  Demeter::UI::Artemis::Buffer;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_CLOSE EVT_CHAR EVT_BUTTON);
use base qw(Wx::Frame);

use List::MoreUtils qw(uniq);

my @ifeffit_buffer = ();
my $pointer = -1;
my $prompttext = "  Ifeffit [%4d]> ";
my $aleft = Wx::TextAttr->new();
$aleft->SetAlignment(wxTEXT_ALIGNMENT_LEFT);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Ifeffit \& Plot Buffer]",
				wxDefaultPosition, [500,800],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  $this -> SetBackgroundColour( wxNullColour );
  EVT_CLOSE($this, \&on_close);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $splitter = Wx::SplitterWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxSP_NOBORDER );
  $vbox->Add($splitter, 1, wxGROW|wxALL, 0);


  $this->{IFEFFIT} = Wx::Panel->new($splitter, -1, wxDefaultPosition, wxDefaultSize);
  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $this->{IFEFFIT} = Wx::Panel->new($splitter, -1);
  my $iffbox = Wx::StaticBox->new($this->{IFEFFIT}, -1, ' Command buffer ', wxDefaultPosition, wxDefaultSize);
  my $iffboxsizer  = Wx::StaticBoxSizer->new( $iffbox, wxHORIZONTAL );
  $this->{iffcommands} = Wx::TextCtrl->new($this->{IFEFFIT}, -1, q{}, wxDefaultPosition, wxDefaultSize,
					   wxHSCROLL|wxTE_READONLY|wxTE_MULTILINE|wxTE_RICH);
  $this->{iffcommands}->SetDefaultStyle($aleft);
  $iffboxsizer -> Add($this->{iffcommands}, 1, wxALL|wxGROW, 5);
  $box -> Add($iffboxsizer, 1, wxGROW|wxALL, 5);
  $this->{IFEFFIT} -> SetSizerAndFit($box);

  my @font = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );
  $this->{IFEFFIT}->{normal}     = Wx::TextAttr->new(Wx::Colour->new( '#000000' ), wxNullColour, Wx::Font->new( @font ) );
  $this->{IFEFFIT}->{comment}    = Wx::TextAttr->new(Wx::Colour->new( '#046A15' ), wxNullColour, Wx::Font->new( @font ) );
  $this->{IFEFFIT}->{feedback}   = Wx::TextAttr->new(Wx::Colour->new( '#000099' ), wxNullColour, Wx::Font->new( @font ) );
  $this->{IFEFFIT}->{warning}    = Wx::TextAttr->new(Wx::Colour->new( '#ff9e1f' ), wxNullColour, Wx::Font->new( @font ) );
  $this->{IFEFFIT}->{singlefile} = Wx::TextAttr->new(Wx::Colour->new( '#F08557' ), wxNullColour, Wx::Font->new( @font ) );


  $this->{PLOT} = Wx::Panel->new($splitter, -1, wxDefaultPosition, wxDefaultSize);
  $box = Wx::BoxSizer->new( wxVERTICAL );

  my $pltbox = Wx::StaticBox->new($this->{PLOT}, -1, ' Plot buffer ', wxDefaultPosition, wxDefaultSize);
  my $pltboxsizer  = Wx::StaticBoxSizer->new( $pltbox, wxHORIZONTAL );
  $this->{pltcommands} = Wx::TextCtrl->new($this->{PLOT}, -1, q{}, wxDefaultPosition, wxDefaultSize,
					   wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxTE_RICH);
  $this->{pltcommands}->SetDefaultStyle($aleft);
  $pltboxsizer -> Add($this->{pltcommands}, 1, wxALL|wxGROW, 5);
  $box -> Add($pltboxsizer, 1, wxGROW|wxALL, 5);
  $this->{PLOT} -> SetSizerAndFit($box);

  $this->{iffcommands} -> SetFont( Wx::Font->new( @font ) );
  $this->{pltcommands} -> SetFont( Wx::Font->new( @font ) );

  $splitter->SplitHorizontally($this->{IFEFFIT}, $this->{PLOT}, 500);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox->Add($hbox, 0, wxGROW|wxALL, 0);

  $this->{ifeffitprompt} = Wx::StaticText->new($this, -1, sprintf($prompttext, 1), wxDefaultPosition, wxDefaultSize);
  $hbox->Add( $this->{ifeffitprompt}, 0, wxALL, 2);
  $this->{commandline} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER|wxHSCROLL);
  $hbox->Add( $this->{commandline}, 1, wxALL|wxGROW, 0);
  EVT_CHAR($this->{commandline}, sub{ OnChar($this, @_) });

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox->Add($hbox, 0, wxGROW|wxALL, 0);
  $this->{doc} = Wx::Button->new($this, wxID_ABOUT, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{doc}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('monitor', 'thecommandbuffer')});
  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{close}, \&on_close);

  $this->SetSizer($vbox);


  return $this;
};

sub insert {
  my ($self, $which, $text) = @_;
  return if ($which !~ m{\A(?:ifeffit|plot)\z});
  my $textctrl = ($which eq 'ifeffit') ? 'iffcommands' : 'pltcommands';
  my $was = $self->{$textctrl}->GetInsertionPoint;
  $self->{$textctrl} -> AppendText($text);
  my $is = $self->{$textctrl}->GetInsertionPoint;
  return ($was, $is);
};

sub color {
  my ($self, $which, $begin, $end, $color) = @_;
  return if ($which !~ m{\A(?:ifeffit|plot)\z});
  my $textctrl = ($which eq 'ifeffit') ? 'iffcommands' : 'pltcommands';
  $self->{$textctrl}->SetStyle($begin, $end, $self->{IFEFFIT}->{$color});
};


# wxEVENT_TYPE_TEXT_ENTER_COMMAND
sub OnChar {
  my ($parent, $textctrl, $event) = @_;
  my $prompt   = $parent->{ifeffitprompt};
  my $code = $event->GetKeyCode;
  my $skip = 1;
  if ($code == 13) { # enter
    my $command = $textctrl->GetValue;
    if ($command !~ m{\A\s*\z}) {
      ## turn off all disposal modes other than ifeffit
      Demeter->dispose($command);
      push @ifeffit_buffer, $command;
      @ifeffit_buffer = reverse( uniq( reverse(@ifeffit_buffer)));
      $pointer = $#ifeffit_buffer+1;
      $textctrl -> SetValue(q{});
    };
    $skip = 0;
  } elsif (($code == WXK_UP) and (@ifeffit_buffer)) {
    $textctrl->SetValue(q{});
    --$pointer;
    $pointer = 0 if ($pointer < 0);
    $textctrl->SetValue($ifeffit_buffer[$pointer]);
    $textctrl->SetInsertionPointEnd;
    $skip = 0;
  } elsif ($code == WXK_DOWN) {
    $textctrl->SetValue(q{});
    ++$pointer;
    if ($pointer > $#ifeffit_buffer) {
      $pointer = $#ifeffit_buffer+1;
      $textctrl -> SetValue(q{});
    } else {
      $textctrl -> SetValue($ifeffit_buffer[$pointer]);
    };
    $textctrl->SetInsertionPointEnd;
    $skip = 0;
  };
  $prompt -> SetLabel(sprintf($prompttext, $pointer+1)) if not $skip;
  $event  -> Skip($skip);
  return;
};


sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

1;



=head1 NAME

Demeter::UI::Artemis::Buffer - A command and plot command buffer for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This module provides a space to display the text issued as commands to
Ifeffit and as plotting commands to the plotting backend.

It also provides a simple Ifeffit command line and command history.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
