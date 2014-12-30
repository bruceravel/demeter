package  Demeter::UI::Artemis::LogText;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>).
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
use Demeter::UI::Wx::Colours;

use List::Util qw(max);

my @font      = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );
my @bold      = (9, wxTELETYPE, wxNORMAL,   wxBOLD, 0, "" );
my @underline = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 1, "" );

my %attr = (
	    normal     => Wx::TextAttr->new(Wx::Colour->new('#000000'), $wxBGC, Wx::Font->new( @font ) ),
	    happiness  => Wx::TextAttr->new(Wx::Colour->new('#acacac'), $wxBGC, Wx::Font->new( @font ) ),
	    parameters => Wx::TextAttr->new(Wx::Colour->new('#000000'), $wxBGC, Wx::Font->new( @underline ) ),
	    header     => Wx::TextAttr->new(Wx::Colour->new('#000055'), $wxBGC, Wx::Font->new( @bold ) ), # '#8B4726'
	    data       => Wx::TextAttr->new(Wx::Colour->new('#ffffff'), Wx::Colour->new('#000055'), Wx::Font->new( @bold ) ),
	   );

sub make_text {
  my ($self, $location, $fit) = @_;
  return if not defined $fit;
  my $text = $fit->logtext;
  $location -> SetValue(q{});
  #my $max = 0;
  #foreach my $line (split(/\n/, $text)) {
  #  $max = max($max, length($line));
  #};
  my $max = 80;
  my $pattern = '%-' . $max . 's';
  $attr{stats} = Wx::TextAttr->new(Wx::Colour->new('#000000'), Wx::Colour->new($fit->color), Wx::Font->new( @font ) );

  my $was;
  foreach my $line (split(/\n/, $text)) {
    $was = $location -> GetInsertionPoint;
    # my $is = $location -> GetInsertionPoint;

    my $color = ($line =~ m{(?:parameters|variables):})                                                  ? 'parameters'
              : ($line =~ m{(?:Happiness|semantic|NEVER|a penalty of|Penalty of)})                       ? 'happiness'
              : ($line =~ m{\A(?:R-factor|Reduced)})                                                     ? 'stats'
              : ($line =~ m{\A(?:=+\s+Data set)})                                                        ? 'data'
              : ($line =~ m{\A (?:Name|Description|Figure|Time|Environment|Interface|Prepared|Contact)}) ? 'header'
              : ($line =~ m{\A\s+\.\.\.})                                                                ? 'header'
	      :                                                                                            'normal';
    $color = 'normal' if ((not Demeter->co->default("artemis", "happiness"))
			  and ($color eq 'stats'));
    #local $|=1;
    #print join("|", $was, $is, $color), $/;

    if ($color ne 'normal') {
      $location -> AppendText(sprintf($pattern, $line) . $/);
      $location -> SetStyle($was, $location->GetInsertionPoint, $attr{$color});
    } else {
      $location -> AppendText($line . $/);
    };
  };
  $location->ShowPosition(0);
  return 1;
};

1;

=head1 NAME

Demeter::UI::Artemis::LogText - Add some color to a logfile

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This is used by L<Demeter::UI::Artemis::Log> and
L<Demeter::UI::Artemis::History> to colorize the display of log files
from fits.

=head1 METHOD

This module provides the C<make_text> method, which performs the
colorization by lexically analyzing the text of the log file.  It then
places the colorized text in the specified Wx::TextCtrl.

    Demeter::UI::Artemis::LogText->make_text($textcrtl, $fit);

The first argument is a reference to the Wx::TextCrtl widget which
will hold the text of the log file.  The second argument is the
L<Demeter::Fit> object of the fit for which the log is being
displayed.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
