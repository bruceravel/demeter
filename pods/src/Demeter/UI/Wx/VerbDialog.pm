package Demeter::UI::Wx::VerbDialog;

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


=head1 NAME

Demeter::UI::Wx::Verbdialog - A Wx yes/no action dialog

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This allows asking a user a yes/no question but with the design
principle that a question should be specific to the situation.

  use Demeter::UI::Wx::VerbDialog;
  my $dialog = Demeter::UI::Wx::VerbDialog->new($parent, -1,
                          "Do you really want to discard the feff.inp file?",
                          "Discard?",
                          "Discard",
                          );

This results in a window like this:

   +---------------------------------------+
   |             Discard?                  |
   +---------------------------------------+
   |  Do you really want to discard the    |
   |  feff.inp file?                       |
   |                                       |
   |  +---------+       +---------------+  |
   |  | Discard |       | Don't discard |  |
   |  +---------+       +---------------+  |
   |                                       |
   +---------------------------------------+

which is less ambiguous than a generic yes/no dialog.

=head1 DESCRIPTION

The arguments of the constructor are

=over 4

=item 1.

The parent widget

=item 2.

The ID

=item 3.

The text for the body of the dialog

=item 4.

The text for the title of the dialog

=item 5.

The verb for the positive and negated buttons

=item 6.

An optional boolean for which true means to include a "Cancel" button.

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

use strict;
use warnings;
use Carp;
use Text::Wrap;
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::Dialog';

my @icon;
foreach (<DATA>) {
  next if $_ =~ /^\/\*/;
  next if $_ =~ /^static/;
  next if $_ =~ /^\}/;
  chomp; # end of line
  $_ =~ s{\A\"}{}g;
  $_ =~ s{\",\z}{}g;
  push @icon, $_;
};
our $image = Wx::Bitmap->newFromXPM(\@icon);

sub new {
  my ($class, $parent, $id, $message, $title, $verb, $cancel) = @_;

  ##Wx::GetMousePosition
  my $this = $class->SUPER::new($parent, $id, $title, wxDefaultPosition, wxDefaultSize,
				wxCLOSE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

#my $lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. Sed sit amet ipsum mauris. Maecenas congue ligula ac quam viverra nec consectetur ante hendrerit. Donec et mollis dolor. Praesent et diam eget libero egestas mattis sit amet vitae augue. Nam tincidunt congue enim, ut porta lorem lacinia consectetur. Donec ut libero sed arcu vehicula ultricies a non tortor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean ut gravida lorem. Ut turpis felis, pulvinar a semper sed, adipiscing id dolor. Pellentesque auctor nisi id magna consequat sagittis. Curabitur dapibus enim sit amet elit pharetra tincidunt feugiat nisl imperdiet. Ut convallis libero in urna ultrices accumsan. Donec sed odio eros. Donec viverra mi quis quam pulvinar at malesuada arcu rhoncus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. In rutrum accumsan ultricies. Mauris vitae nisi at sem facilisis semper ac in est.";

  local $Text::Wrap::columns = 60;

  $hbox->Add(Wx::StaticBitmap->new($this, -1, $image, wxDefaultPosition, wxDefaultSize), 0, wxALL, 2);
  $hbox->Add(Wx::StaticText->new($this, -1, wrap(q{}, q{}, $message), wxDefaultPosition, [-1,-1]), 0, wxALL|wxGROW, 20);
  $vbox->Add($hbox, 0, wxALL|wxGROW, 2);
  $vbox->Add(Wx::StaticLine->new($this, -1, [-1,-1], [1,1], wxLI_HORIZONTAL), 0, wxALL|wxGROW, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox->Add($hbox, 0, wxALL|wxGROW, 2);

  my $affirmative = Wx::Button->new($this, wxID_YES, $verb);
  $hbox->Add($affirmative, 1, wxALL, 2);
  $affirmative->SetFocus;
  EVT_BUTTON($this, $affirmative, sub{OnButton(@_, wxID_YES)});
  my $negative    = Wx::Button->new($this, wxID_NO, "Don't ".lc($verb));
  $hbox->Add($negative, 1, wxALL, 2);
  EVT_BUTTON($this, $negative, sub{OnButton(@_, wxID_NO)});
  $hbox->Add(Wx::Button->new($this, wxID_CANCEL, q{}), 1, wxALL, 2) if $cancel;
  $this->SetSizerAndFit($vbox);

  return $this;
};

sub OnButton {
  my ($this, $event, $value) = @_;
  $this->EndModal($value);
};

1;

__DATA__
/* XPM */
static char *dialog_question[] = {
/* columns rows colors chars-per-pixel */
"90 90 140 2 ",
"   c #0419285C000F",
".  c #097D2C5A057A",
"X  c #0C612ED9085E",
"o  c #0651321200EC",
"O  c #080835550242",
"+  c #06663B7B0000",
"@  c #08F43B660343",
"#  c #0E8E302F0A8B",
"$  c #116632C00D63",
"%  c #155535741151",
"&  c #191937371596",
"*  c #196E395515C0",
"=  c #1D1C3CBC19BA",
"-  c #20753EE91D73",
";  c #070743EE0000",
":  c #0BB6436E0485",
">  c #0C0C4B8B0404",
",  c #0C7A52770404",
"<  c #0A3D5BF50033",
"1  c #101053D40707",
"2  c #106655550808",
"3  c #12925BDC08C9",
"4  c #222140951EC9",
"5  c #0B6162620000",
"6  c #0C0C6AAA0000",
"7  c #101063630505",
"8  c #152C65080A67",
"9  c #168D6BF50B95",
"0  c #18186F6F0C0C",
"q  c #0CC474E20000",
"w  c #0DCE7B7B0000",
"e  c #191974570CD4",
"r  c #1BF77C330E7C",
"t  c #252442752222",
"y  c #292947472626",
"u  c #2A2A48C82727",
"i  c #2C814645297F",
"p  c #2D9F4A832A9C",
"a  c #31644CB22E61",
"s  c #323250502F2F",
"d  c #34344A4A3232",
"f  c #373754533434",
"g  c #38B953D335B6",
"h  c #3CE754FF39E4",
"j  c #3DBD59DA3ABB",
"k  c #404057573D3D",
"l  c #44C45D5D4242",
"z  c #4B4B62214909",
"x  c #505064644E4E",
"c  c #505069684D4D",
"v  c #55556AEA52D3",
"b  c #58986C2B5696",
"n  c #5A5964645959",
"m  c #5C066CEC5A2F",
"M  c #5D5D74745A5A",
"N  c #609372A55E5E",
"B  c #642374346222",
"V  c #65E679FA63E4",
"C  c #696978786767",
"Z  c #6C167B7B6A14",
"A  c #711B7E286F19",
"S  c #71717F7F7070",
"D  c #7A7A7B7B7A7A",
"F  c #0F0F85850000",
"G  c #121283830404",
"H  c #113C8CB7012C",
"J  c #1C5C81C10F0F",
"K  c #111192920000",
"L  c #125B9BE40126",
"P  c #19199B9B0707",
"I  c #1EC994EA0EB9",
"U  c #1D809D750C34",
"Y  c #1DB785851010",
"T  c #1F1F8A9B10AA",
"R  c #1F1F915E1010",
"E  c #202094940F0F",
"W  c #20208C8C1110",
"Q  c #202091911010",
"!  c #1292A6260000",
"~  c #14AEAC450101",
"^  c #186EAD5704AF",
"/  c #1D8BA4110B54",
"(  c #1D42AD3F09E5",
")  c #1494B4130020",
"_  c #1A1AB2B20606",
"`  c #1616BBBB0000",
"'  c #1B8DBB49063F",
"]  c #1C7CB4740848",
"[  c #1688C48B001D",
"{  c #1B1BC351053E",
"}  c #1684CAA50000",
"|  c #19A5CC28025F",
" . c #18FBD41800D0",
".. c #191ADBD30000",
"X. c #6C6C82026A6A",
"o. c #74F483AE739E",
"O. c #787884847777",
"+. c #76768A8A7474",
"@. c #7BD187877AD0",
"#. c #7DD388DE7CD2",
"$. c #7E7E91117C7C",
"%. c #818193937F7F",
"&. c #83A88D8D82A7",
"*. c #8B8B8B8B8B8B",
"=. c #858592D28403",
"-. c #888891918787",
";. c #8CBF94618BBE",
":. c #909097978F8F",
">. c gray57",
",. c #952E9A339461",
"<. c #9A9A9D1D9A1A",
"1. c #9413A2E29212",
"2. c #9898A6A69696",
"3. c #9CF2A2229C9C",
"4. c #9E1EABAB9C1C",
"5. c #A2E2A5A5A2E2",
"6. c #A5E5A8E8A5E5",
"7. c #AB80AD3BAB72",
"8. c #A6A6B3B3A5A5",
"9. c #AE03B2B2ADAD",
"0. c #B2EBB2EBB2EB",
"q. c #B534BE3EB433",
"w. c #BC43BC80BC43",
"e. c #B7B7C1C1B6B6",
"r. c #BCBCC56FBBE6",
"t. c #C475C475C475",
"y. c #C2C2CBCBC1C1",
"u. c #CC86CC86CC86",
"i. c #CD66D3D3CC99",
"p. c #D3C2D3C2D3C2",
"a. c #D6D6DC5CD5D5",
"s. c #DD0FDD98DCFE",
"d. c #DE33E28CDD32",
"f. c #E457E497E457",
"g. c #E791EA94E791",
"h. c #ECDBED0EECDB",
"j. c #EFEFF2F2EFEF",
"k. c #F4AFF4E3F4AF",
"l. c #F7F7F8F8F7F7",
"z. c None",
/* pixels */
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.j.a.r.r.i.a.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.j.r.=.c u $               X p M 2.d.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.i.$.s                                     y =.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.a.+.4                                               X b i.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.4.j                             o o                         X C u.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.1.=                     + 6 K ) } ........[ ! w ;                   p 5.u.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.2.*                   ; F ` ..........................) 5                 $ =.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.r.u                   6 ~ ....................................` 7                 A 0.t.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.V                   6 [ ............................................P @               o.0.w.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.p                 < [ ..................................................( 1               #.0.0.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.v               ; ~ ........................................................( 9             X :.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.o.            w  ............................................................./ r             = 7.0.0.h.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.q.        ; ) ................................................................ .E r o           z 0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.j.p         } ..................................................................| W e             %.0.0.w.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.:.        6 ....................................................................U W 8           = 9.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.p         ) ..................................................................] W W >           m 0.0.0.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.&.        , ..................................................................| W W T @         X 6.0.0.w.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.f.a         L ................} _ / U Q W W W U ^  ........................... .W W W 0           m 0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.:.        +  ......... .^ I T W W W W W T Q T T I } ..........................Q W W W @         X 7.0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.s.h         H ....} P Q W W W W W W W W T T T J 8 G ..........................E W W W 0           Z 0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.7..       o ) P W W W W W W W W W T T 0 1 O     o ..........................E W W W W O         k 0.0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.g.c           > e W W W W W W W J 2 o             } ........................W W W W W 1         = 0.0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.w.%             @ 8 T W W T 3                 o ........................ .W W W W W 9           5.0.0.0.0.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.o.                . > 9 @                   w ........................{ W W W W W r           :.0.0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.a.;.h                           %         +  .........................( W W W W W W           &.0.0.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.w.0.5.m #                 y &.&         F ..........................U W W W W W W .         #.0.0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.g.0.0.0.6.N %         $ C 0.b         > .......................... .W W W W W W W           #.0.0.0.0.u.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.p.0.0.0.9.A t   z 6.0.,.        o { ..........................( W W W W W W T           >.0.0.0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.f.w.0.0.0.3.0.0.7.t         K ............................W W W W W W W r           3.0.0.0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.g.t.0.0.0.0.l         7 ............................] W W W W W W W 8         X 9.0.0.0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.p.0.Z         ,  ........................... .Q W W W W W W W :         i 0.0.0.0.0.u.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.1.        + } ............................/ W W W W W W W W           b 0.0.0.0.0.u.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.8.          ) ............................{ W W W W W W W W 8           -.0.0.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.$.        . ) ............................ .Q W W W W W W W W @         = 0.0.0.0.0.0.h.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.+.          L ..............................U W W W W W W W W 8           m 0.0.0.0.0.0.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.g           H ..............................( W W W W W W W W Y .         X 7.0.0.0.0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.8.$           H ..............................] W W W W W W W W W >           m 0.0.0.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.X.            L ..............................] W W W W W W W W W 8           $ 6.0.0.0.0.0.0.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.s           o L ..............................{ W W W W W W W W W r             A 0.0.0.0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.f           ; [ ..............................] W W W W W W W W W r O           g 0.0.0.0.0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.*         q  ...............................' W W W W W W W W T Y @           & 6.0.0.0.0.0.0.p.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.u     o  .................................( W W W W W W W W W J @             ;.0.0.0.0.0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.j       } ............................ ./ W W W W W W R W W J O             S 0.0.0.0.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.M       ~ ..........................| I W W W W W W W T T e .             C 0.0.0.0.0.0.0.u.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.$.      H ........................] T W W W W W W W W W 0               B 0.0.0.0.0.0.0.w.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.4.      6 ....................} / W W W W W W W W W W 3               N 0.0.0.0.0.0.0.0.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.r.      < ....................R T W W W W W W W T J :             # &.0.0.0.0.0.0.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.      + ....................R T W W W W W W W 0 o             - <.0.0.0.0.0.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.        } ................../ W W W W W W Y >               h 6.0.0.0.0.0.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.-       ) ..................( W W W W W W O             % O.0.0.0.0.0.0.0.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l       K ..................' Q W W W W W :         $ m 7.0.0.0.0.0.0.0.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.Z       w ..................{ W W W W W W 1       * 7.0.0.0.0.0.0.0.0.0.w.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.1.      < ................ .] W W W W W W 9         7.0.0.0.0.0.0.0.0.u.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.e.      + .......... .] U W W W W W W W W J         &.0.0.0.0.0.0.0.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.d.         ... .^ / W W W W W W W W W W W W         m 0.0.0.0.0.a.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.        L P T W W W W W W W W W W W W W W :       d 0.0.0.u.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.y         1 J W W W W W W W W W W W W W W 3       . 9.0.a.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z             3 T W W W W W W W W W W Y 0 :         >.0.w.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.s.h             O 8 W W W W W W Y 8 @ .             B 0.0.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.w.-.t             @ 9 W Y 0 >   .               - -.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.t.0.0.@.&             @ o                   & O.0.0.0.0.u.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.p.0.0.0.7.b X                               . i m <.7.0.0.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.s.0.0.0.0.0.<.l                                   & n *.6.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.t.0.0.0.0.0.0.:.p                                   d D >.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.g.w.0.0.0.0.0.A         o < q w q ,                 i ,.0.h.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.f.w.0.0.@.      o F  ...........} H 1             l 0.0.h.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.p.3.#     ; [ ..................{ T 3 o         Z 0.0.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.v     @ } ......................{ W r         # 7.0.w.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.i.      ~ ..........................( W J o       v 0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.X.    < ............................ .Q T e       $ 0.0.w.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.=     L ............................../ W W :       -.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.s.      } ..............................' W T 0       B 0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.y.      ................................{ W W W       z 0.0.0.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.8.    O ................................{ W W W O     h 0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.q.       ...............................' W W W @     l 0.0.0.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.i.      ~ ..............................( W W W O     x 0.0.0.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.h.      q ..............................Q W W W       C 0.0.0.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.p       [ ..........................] W W W 0       <.0.0.0.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.+.      < ........................ .Q W W W >     t 0.0.0.t.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.s.X       q .................... .U W W W r       Z 0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.C         < | ..............{ E W W W J .     t 0.0.0.0.l.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.g.=         @ / ' |  .| ' U W W W W J @     . -.0.0.0.s.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.w.&           8 T T T W T T W W 8         S 0.0.0.w.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.<.&           o 1 0 e e 9 2 O       . C 0.0.0.0.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.9.d                             & -.0.0.0.0.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.k.w.&.4                     X N 7.0.0.0.0.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.u.9.&.x t X     X & h A 6.0.0.0.0.w.j.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.j.u.0.0.0.7.6.0.0.0.0.0.0.0.w.f.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.h.s.w.0.0.0.0.0.0.w.p.g.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.",
"z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.l.j.j.k.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z.z."
};
