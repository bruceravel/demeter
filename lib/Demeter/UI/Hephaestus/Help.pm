package Demeter::UI::Hephaestus::Help;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);
use Wx::Html;
use File::Basename;
use File::Spec;
use Pod::Html;
use base 'Wx::Panel';

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize );
  $self->{echo} = $echoarea;

  my $top_s = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->SetSizer($top_s);

  my $file = File::Spec->catfile(dirname($INC{'Demeter/UI/Hephaestus.pm'}), 'Hephaestus', 'data', "hephaestus.pod");
  my $html = File::Spec->catfile(Demeter->stash_folder, 'hephaestus.html');
  ##my $css  = File::Spec->catfile(dirname($INC{'Demeter/UI/Hephaestus.pm'}), 'Hephaestus', 'data', "ab.css");

  pod2html("--infile=$file",
	   "--outfile=$html",);
  $self->{html} = Wx::HtmlWindow->new($self, -1, wxDefaultPosition, wxDefaultSize );
  my $ok = $self->{html} -> LoadPage( $html );


  my $but_s = Wx::BoxSizer->new( wxVERTICAL );
  my $print = Wx::Button->new( $self, -1, 'Print' );
  #my $forward = Wx::Button->new( $self, -1, 'Forward' );
  #my $back = Wx::Button->new( $self, -1, 'Back' );
  my $preview = Wx::Button->new( $self, -1, 'Preview' );
  my $pages = Wx::Button->new( $self, -1, 'Page Setup' );
  #my $prints = Wx::Button->new( $self, -1, 'Printer Setup' );

  my ($w, $h) = $print->GetSizeWH;

  #$but_s->Add( $back, 0, wxALL, 2 );
  #$but_s->Add( $forward, 0, wxALL, 2 );
  $but_s->Add( $pages, 0, wxALL, 2 );
  $but_s->Add( $preview, 0, wxALL, 2 );
  $but_s->Add( Wx::StaticLine->new($self, -1, wxDefaultPosition, [$w, -1], wxLI_HORIZONTAL), 0, wxALL, 2 );
  $but_s->Add( $print, 0, wxALL, 2 );
  #$but_s->Add( $prints, 0, wxALL, 2 );

   $top_s->Add( $self->{html}, 1, wxGROW|wxALL, 5 );
  $top_s->Add( $but_s, 0, wxALL, 5 );

  $self->SetSizer( $top_s );
  $self->SetAutoLayout( 1 );

  $self->{printer} = Wx::HtmlEasyPrinting->new( 'Hephaestus document' );
  EVT_BUTTON( $self, $print, \&OnPrint );
  EVT_BUTTON( $self, $preview, \&OnPreview );
  #EVT_BUTTON( $self, $forward, \&OnForward );
  #EVT_BUTTON( $self, $back, \&OnBack );
  EVT_BUTTON( $self, $pages, \&OnPageSetup );
  #EVT_BUTTON( $self, $prints, \&OnPrinterSetup );

  unlink('pod2htmd.tmp') if -e 'pod2htmd.tmp';
  unlink('pod2htmi.tmp') if -e 'pod2htmi.tmp';
  ## need button controls

  return $self;
};


## all of this is swiped directly from wxperl_demo.

sub OnPrint {
  my( $self, $event ) = @_;
  $self->{printer}->PrintFile( $self->{html}->GetOpenedPage );
}

sub OnPageSetup {
  my $self = shift;
  $self->{printer}->PageSetup();
}

sub OnPrinterSetup {
  my $self = shift;
  $self->{printer}->PrinterSetup();
}

sub OnPreview {
  my( $self, $event ) = @_;
  $self->{printer}->PreviewFile( $self->{html}->GetOpenedPage );
}

sub OnForward {
  my( $self, $event ) = @_;
  $self->{html}->HistoryForward();
}

sub OnBack {
  my( $self, $event ) = @_;
  $self->{html}->HistoryBack();
}

1;

=head1 NAME

Demeter::UI::Hephaestus::Help - Hephaestus' document utility

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

The contents of Hephaestus' document utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Help->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility displays the Hephaestus Users' Guide as an html page.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Wx's standard html display widget does not correctly handle the aug
css file.

=item *

Would pod be better that html?  Perhaps, but where is the Wx pod
browser?

=back

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
