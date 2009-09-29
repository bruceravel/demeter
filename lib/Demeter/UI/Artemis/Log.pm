package  Demeter::UI::Artemis::Log;

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

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE);
use base qw(Wx::Frame);

use List::Util qw(max);

my @font      = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );
my @bold      = (9, wxTELETYPE, wxNORMAL,   wxBOLD, 0, "" );
my @underline = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 1, "" );

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Log]",
				wxDefaultPosition, [550,500],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  EVT_CLOSE($this, \&on_close);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{text} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				    wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL);
  $this->{text} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  $this->{normal}     = Wx::TextAttr->new(Wx::Colour->new('#000000'), wxNullColour, Wx::Font->new( @font ) );
  $this->{happiness}  = Wx::TextAttr->new(Wx::Colour->new('#acacac'), wxNullColour, Wx::Font->new( @font ) );
  $this->{parameters} = Wx::TextAttr->new(Wx::Colour->new('#000000'), wxNullColour, Wx::Font->new( @underline ) );
  $this->{header}     = Wx::TextAttr->new(Wx::Colour->new('#736853'), wxNullColour, Wx::Font->new( @bold ) );
  $this->{data}       = Wx::TextAttr->new(Wx::Colour->new('#ffffff'), Wx::Colour->new('#000055'), Wx::Font->new( @bold ) );


  $vbox -> Add($this->{text}, 1, wxGROW, 0);
  $this -> SetSizer($vbox);
  return $this;
};

sub put_log {
  my ($self, $text, $color) = @_;
  $self -> {text} -> SetValue(q{});
  my $max = 0;
  foreach my $line (split(/\n/, $text)) {
    $max = max($max, length($line));
  };
  my $pattern = '%-' . $max . 's';
  $self->{stats} = Wx::TextAttr->new(Wx::Colour->new('#000000'), Wx::Colour->new($color), Wx::Font->new( @font ) );

  foreach my $line (split(/\n/, $text)) {
    my $was = $self -> {text} -> GetInsertionPoint;
    $self -> {text} -> AppendText(sprintf($pattern, $line) . $/);
    my $is = $self -> {text} -> GetInsertionPoint;

    my $color = ($line =~ m{(?:parameters|variables):})                     ? 'parameters'
              : ($line =~ m{(?:Happiness|semantic|NEVER|gives a penalty)})  ? 'happiness'
              : ($line =~ m{\A(?:R-factor|Reduced)})                        ? 'stats'
              : ($line =~ m{\A(?:=+\s+Data set)})                           ? 'data'
              : ($line =~ m{\A (?:Name|Description|Figure|Time|Environment|Interface|Prepared|Contact)}) ? 'header'
	      :                                                               'normal';


    $self->{text}->SetStyle($was, $is, $self->{$color});
  };
  $self -> {text} -> ShowPosition(0);
};


sub on_close {
  my ($self) = @_;
  $self->Show(0);
  $self->GetParent->{log_toggle}->SetValue(0);
};

1;
