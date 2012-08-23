package Demeter::UI::Wx::ColourDatabase;


=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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
#use Carp;
use File::Spec;
use Wx qw(wxNullColour);

use Demeter qw(:none);
################# The stuff from here to the next row of hashes is taken from Mark Dootson

sub new {
  my $class = shift;
  my $self = bless {}, $class;
  $self->__init();
  $self->X11;
  $self->gnuplot;
  return $self;
};

sub AddColour {
  my $self = shift;
  my $name = shift;
  my $col = shift;
  my $colkey = $col->Red() . '-' . $col->Green() . '-' . $col->Blue();
  my @RGB = split(/-/, $colkey);
  if (exists($self->{__colours}->{$name})) {
    # delete existing colkey
    my $existingkey = join('-', @{ $self->{__colours}->{$name} });
    delete($self->{__colourkeys}->{$existingkey});
  }
  $self->{__colourkeys}->{$colkey} = $name;
  $self->{__colours}->{$name} = \@RGB;
};

sub Find {
  my $self = shift;
  my $name = shift;
  my $colour = Wx::Colour->new(wxNullColour);

  $name = uc($name) if (not exists( $self->{__colours}->{$name} ));
  if (exists( $self->{__colours}->{$name} )) {
    ##                                             v-- alpha channel
    $colour->Set(@{ $self->{__colours}->{$name} }, 0);
  };
  return $colour;
};

sub FindName {
  my $self = shift;
  my $col = shift;
  my $colname = "";
  if ($col->Ok()) {
    my $colkey = $col->Red() . '-' . $col->Green() . '-' . $col->Blue();
    $colname = $self->{__colourkeys}->{$colkey} || "";
  };
  return $colname;
};

sub __init {
  my $self = shift;
  $self->{__colours} = {
			'AQUAMARINE'	       => [ 112, 219, 147 ],
			'BLACK'		       => [   0,   0,   0 ],
			'BLUE'		       => [   0,   0, 255 ],
			'BLUE VIOLET'	       => [ 159,  95, 159 ],
			'BROWN'		       => [ 165,  42,  42 ],
			'CADET BLUE'	       => [  95, 159, 159 ],
			'CORAL'		       => [ 255, 127,   0 ],
			'CORNFLOWER BLUE'      => [  66,  66, 111 ],
			'CYAN'		       => [   0, 255, 255 ],
			'DARK GREY'	       => [  47,  47,  47 ],
			'DARK GREEN'	       => [  47,  79,  47 ],
			'DARK OLIVE GREEN'     => [  79,  79,  47 ],
			'DARK ORCHID'	       => [ 153,  50, 204 ],
			'DARK SLATE BLUE'      => [ 107,  35, 142 ],
			'DARK SLATE GREY'      => [  47,  79,  79 ],
			'DARK TURQUOISE'       => [ 112, 147, 219 ],
			'DIM GREY'	       => [  84,  84,  84 ],
			'FIREBRICK'	       => [ 142,  35,  35 ],
			'FOREST GREEN'	       => [  35, 142,  35 ],
			'GOLD'		       => [ 204, 127,  50 ],
			'GOLDENROD'	       => [ 219, 219, 112 ],
			'GREY'		       => [ 128, 128, 128 ],
			'GREEN'		       => [   0, 255,   0 ],
			'GREEN YELLOW'	       => [ 147, 219, 112 ],
			'INDIAN RED'	       => [  79,  47,  47 ],
			'KHAKI'		       => [ 159, 159,  95 ],
			'LIGHT BLUE'	       => [ 191, 216, 216 ],
			'LIGHT GREY'	       => [ 192, 192, 192 ],
			'LIGHT STEEL BLUE'     => [ 143, 143, 188 ],
			'LIME GREEN'	       => [  50, 204,  50 ],
			'MAGENTA'	       => [ 255,   0, 255 ],
			'MAROON'	       => [ 142,  35, 107 ],
			'MEDIUM AQUAMARINE'    => [  50, 204, 153 ],
			'MEDIUM BLUE'	       => [  50,  50, 204 ],
			'MEDIUM FOREST GREEN'  => [ 107, 142,  35 ],
			'MEDIUM GOLDENROD'     => [ 234, 234, 173 ],
			'MEDIUM ORCHID'	       => [ 147, 112, 219 ],
			'MEDIUM SEA GREEN'     => [  66, 111,  66 ],
			'MEDIUM SLATE BLUE'    => [ 127,   0, 255 ],
			'MEDIUM SPRING GREEN'  => [ 127, 255,   0 ],
			'MEDIUM TURQUOISE'     => [ 112, 219, 219 ],
			'MEDIUM VIOLET RED'    => [ 219, 112, 147 ],
			'MIDNIGHT BLUE'	       => [  47,  47,  79 ],
			'NAVY'		       => [  35,  35, 142 ],
			'ORANGE'	       => [ 204,  50,  50 ],
			'ORANGE RED'	       => [ 255,   0, 127 ],
			'ORCHID'	       => [ 219, 112, 219 ],
			'PALE GREEN'	       => [ 143, 188, 143 ],
			'PINK'		       => [ 188, 143, 234 ],
			'PLUM'		       => [ 234, 173, 234 ],
			'PURPLE'	       => [ 176,   0, 255 ],
			'RED'		       => [ 255,   0,   0 ],
			'SALMON'	       => [ 111,  66,  66 ],
			'SEA GREEN'	       => [  35, 142, 107 ],
			'SIENNA'	       => [ 142, 107,  35 ],
			'SKY BLUE'	       => [  50, 153, 204 ],
			'SLATE BLUE'	       => [   0, 127, 255 ],
			'SPRING GREEN'	       => [   0, 255, 127 ],
			'STEEL BLUE'	       => [  35, 107, 142 ],
			'TAN'		       => [ 219, 147, 112 ],
			'THISTLE'	       => [ 216, 191, 216 ],
			'TURQUOISE'	       => [ 173, 234, 234 ],
			'VIOLET'	       => [  79,  47,  79 ],
			'VIOLET RED'	       => [ 204,  50, 153 ],
			'WHEAT'		       => [ 216, 216, 191 ],
			'WHITE'		       => [ 255, 255, 255 ],
			'YELLOW'	       => [ 255, 255,   0 ],
			'YELLOW GREEN'	       => [ 153, 204,  50 ],
		       };
  $self->{__colourkeys} = {};
  foreach my $col (keys (%{ $self->{__colours} })) {
    my $colkey = join('-', @{ $self->{__colours}->{$col} });
    $self->{__colourkeys}->{$colkey} = $col;
  };
};

###################################################################################################

sub X11 {
  my ($self) = @_;
  my $rgbtxt = File::Spec->catfile(Demeter->location, "Demeter", "share", "rgb_colors.dem");
  open RGB, $rgbtxt;
  while (<RGB>) {
    next if ($_ =~ m{^\!});
    chomp;
    my @list = split(" ", $_);
    my ($r, $g, $b) = @list[0..2];
    my $name = lc( join(" ", @list[3..$#list]) );

    $self->{__colours}->{$name} = [$r, $g, $b];
    my $colkey = join('-', $r, $g, $b);
    $self->{__colourkeys}->{$colkey} = $name;
  };
  close RGB;
  return $self;
};

sub gnuplot {
  my ($self) = @_;
  my $gp = File::Spec->catfile(Demeter->location, "Demeter", "share", "gnuplot_colors.dem");
  open GP, $gp;
  while (<GP>) {
    chomp;
    my @list = split(" ", $_);
    my ($r, $g, $b) = @list[3..5];
    my $name = $list[0];

    $self->{__colours}->{$name} = [$r, $g, $b];
    my $colkey = join('-', $r, $g, $b);
    $self->{__colourkeys}->{$colkey} = $name;
  };
  close GP;
  return $self;
};

1;


=head1 NAME

Demeter::UI::Wx::ColourDatabase - An objective interface to Wx::ColourDatabase

=head1 VERSION

This documentation refers to Demeter version 0.9.11.

=head1 SYNOPSIS

This is a pure perl implementation of Wx::ColourDatabase which
implements those colors named by X11's rgb.txt file and those
named by gnuplot.

  use Demeter::UI::Wx::ColourDatabase;
  my $cdb = Demeter::UI::Wx::ColourDatabase->new;
  my $wx_color_object = $cdb -> Find("yellowgreen");

The semantics are very similar to those documented for
Wx::ColourDatabase, except that there is a constructor and object,
rather than just class methods.

=head1 DESCRIPTION

This is an object oriented interface to the functionality provided by
Wx::ColourDatabase and extended to include the named colors from X11's
rgb.txt file and from gnuplot.  The purpose of this object is to
simplify the interaction with Wx colored windows while using named
colors.  The C<Add>, C<Find>, and C<FindName> methods from
Wx::ColourDatabase are all implemented.

Most of this was swiped from a post to the wxperl-users mailing list,
L<http://www.nntp.perl.org/group/perl.wxperl.users/2007/06/msg3756.html>
by Mark Dootson on June 28, 2007.

Bruce added the interface to X11 and gnuplot colors.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.
This requires Wx (of course) and L<File::Spec> as well as files from a
properly installed Demeter distribution.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
