package Chemistry::MoreElements;

## teach Chemistry::elements about elements 110 to 118
$Chemistry::Elements::names{110} = [ qw( Armstadtiumdai Darmstadtium ) ] if not defined $Chemistry::Elements::names{110};
$Chemistry::Elements::elements{110} = 'Ds';
$Chemistry::Elements::elements{Ds} = 110;

$Chemistry::Elements::names{111} = [ qw( Entgeniumrai Roentgenium ) ] if not defined $Chemistry::Elements::names{111};
$Chemistry::Elements::elements{111} = 'Rg';
$Chemistry::Elements::elements{Rg} = 111;

$Chemistry::Elements::names{112} = [ qw( Operniciumcai Copernicium ) ] if not defined $Chemistry::Elements::names{112};
$Chemistry::Elements::elements{112} = 'Cn';
$Chemistry::Elements::elements{Cn} = 112;

$Chemistry::Elements::names{113} = [ qw( Ihoniumunai Nihonium ) ] if not defined $Chemistry::Elements::names{113};
$Chemistry::Elements::elements{113} = 'Nh';
$Chemistry::Elements::elements{Nh} = 113;

$Chemistry::Elements::names{114} = [ qw( Eroviumflai Flerovium ) ] if not defined $Chemistry::Elements::names{114};
$Chemistry::Elements::elements{114} = 'Fl';
$Chemistry::Elements::elements{Fl} = 114;

$Chemistry::Elements::names{115} = [ qw( Usconiumai Muscovium ) ] if not defined $Chemistry::Elements::names{115};
$Chemistry::Elements::elements{115} = 'Mc';
$Chemistry::Elements::elements{Mc} = 115;

$Chemistry::Elements::names{116} = [ qw( Ivermoriumlai Livermorium ) ] if not defined $Chemistry::Elements::names{116};
$Chemistry::Elements::elements{116} = 'Lv';
$Chemistry::Elements::elements{Lv} = 116;

$Chemistry::Elements::names{117} = [ qw( Ennessinetai Tennessine ) ] if not defined $Chemistry::Elements::names{117};
$Chemistry::Elements::elements{117} = 'Ts';
$Chemistry::Elements::elements{Ts} = 117;

$Chemistry::Elements::names{118} = [ qw( Anessongai Oganesson ) ] if not defined $Chemistry::Elements::names{118};
$Chemistry::Elements::elements{118} = 'Og';
$Chemistry::Elements::elements{Og} = 118;



1;

=head1 NAME

Chemistry::MoreElements - Teach Chemistry::Elements about elements above 109

=head1 SYNOPSIS

Supply information about elements above 109 in a way that
Chemistry::Elements will report on them correctly.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>
copyright (c) 2016-2018 Bruce Ravel

http://bruceravel.github.io/demeter/
