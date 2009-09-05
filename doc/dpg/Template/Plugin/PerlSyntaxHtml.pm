package Template::Plugin::PerlSyntaxHtml;

use strict;
use warnings;
use Syntax::Highlight::Perl ':BASIC';
use Template::Plugin::Filter;

use base qw(Template::Plugin::Filter);
my %perl_html = (close  => "</span>");
foreach my $key (qw(comment_normal comment_pod directive label quote
		    string subroutine scalar array typeglob character
		    function keyword operator bareword package number symbol
		    codeterm data line filename)) {
  $perl_html{$key} = "<span class=perl_$key>";

};

sub filter_with_linum {
  my $text = shift;
  filter($text, 1);
};
sub filter_without_linum {
  my $text = shift;
  filter($text, 0);
};

sub filter {
  my $text = shift;
  my $do_linum = shift;
  my $formatter = new Syntax::Highlight::Perl;
  $formatter->unstable(0);
  $formatter->set_format(
    'Comment_Normal'   => [$perl_html{'comment_normal'}, $perl_html{'close'}],
    'Comment_POD'      => [$perl_html{'comment_pod'},    $perl_html{'close'}],
    'Directive'        => [$perl_html{'directive'},      $perl_html{'close'}],
    'Label'            => [$perl_html{'label'},          $perl_html{'close'}],
    'Quote'            => [$perl_html{'quote'},          $perl_html{'close'}],
    'String'           => [$perl_html{'string'},         $perl_html{'close'}],
    'Subroutine'       => [$perl_html{'subroutine'},     $perl_html{'close'}],
    'Variable_Scalar'  => [$perl_html{'scalar'},         $perl_html{'close'}],
    'Variable_Array'   => [$perl_html{'array'},          $perl_html{'close'}],
    'Variable_Hash'    => [$perl_html{'hash'},           $perl_html{'close'}],
    'Variable_Typeglob'=> [$perl_html{'typeglob'},       $perl_html{'close'}],
    'Whitespace'       => ['',                           ''                ],
    'Character'        => [$perl_html{'character'},      $perl_html{'close'}],
    'Keyword'          => [$perl_html{'keyword'},        $perl_html{'close'}],
    'Builtin_Function' => [$perl_html{'function'},       $perl_html{'close'}],
    'Builtin_Operator' => [$perl_html{'operator'},       $perl_html{'close'}],
    'Operator'         => [$perl_html{'operator'},       $perl_html{'close'}],
    'Bareword'         => [$perl_html{'bareword'},       $perl_html{'close'}],
    'Package'          => [$perl_html{'package'},        $perl_html{'close'}],
    'Number'           => [$perl_html{'number'},         $perl_html{'close'}],
    'Symbol'           => [q{},                          q{}],
    'CodeTerm'         => [$perl_html{'codeterm'},       $perl_html{'close'}],
    'DATA'             => [$perl_html{'data'},           $perl_html{'close'}],

    'Line'             => [$perl_html{'line'},           $perl_html{'close'}],
    'File_Name'        => [$perl_html{'filename'},       $perl_html{'close'}],
			);


  my @lines = split(/\n/, $text);
  my $return_text = q{};
  foreach my $l (@lines) {
    if ($do_linum) {
      #my $ln = sprintf("%5s", $formatter->line_count()+1);
      #$ln =~ s{ }{&nbsp;}g;
      #$ln = $formatter->format_token($ln, 'Line');
      #$return_text .= "$ln&nbsp;&nbsp;";
      $return_text .= "<li>";
    } else {
      $return_text .= "&nbsp;&nbsp;";
    };
    my $this = $formatter->format_string($l);
    while ($this =~ m{(\s{2,})}) {
      my $space = "&nbsp;" x length($1);
      $this =~ s{$1}{$space};
    };
    $return_text .= $this;
    $return_text .= $/;
  };
  chomp $return_text;
  return $return_text;
};
sub load {
  my ($class, $context) = @_;
  $context->define_filter('highlighter', \&filter_with_linum);
  $context->define_filter('highlighter_nolinum', \&filter_without_linum);
  return $class;
};
1;
