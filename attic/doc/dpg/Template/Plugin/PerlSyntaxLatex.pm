package Template::Plugin::PerlSyntaxLatex;

use strict;
use warnings;
use Syntax::Highlight::Perl ':BASIC';
use Template::Plugin::Filter;

use base qw(Template::Plugin::Filter);
my %perl_tex  = (close  => "}", nothing => q{});
my %color = (
	     comment_normal => "orangered3",
	     comment_pod    => q{},
	     directive	    => q{},
	     label	    => q{},
	     quote	    => q{},
	     string	    => "green4",
	     subroutine	    => "mediumorchid4",
	     scalar	    => "gray25",
	     array	    => q{},
	     typeglob	    => "gray25",
	     character	    => q{},
	     function	    => "steelblue3",
	     keyword	    => "steelblue3",
	     operator	    => "black",
	     bareword	    => q{},
	     package	    => "rosybrown4",
	     number	    => q{},
	     symbol	    => q{},
	     codeterm	    => q{},
	     data	    => q{},
	     line	    => "gold3",
	     filename	    => q{},
	    );
foreach my $key (qw(comment_normal comment_pod directive label quote
		    string subroutine scalar array typeglob character
		    function keyword operator bareword package number symbol
		    codeterm data line filename)) {
  $perl_tex{$key}  = ($color{$key}) ? "{\\color{$color{$key}}" : q{};
};

sub filter {
  my $text = shift;
  my $formatter = new Syntax::Highlight::Perl;
  $formatter->unstable(0);
  $formatter->set_format(
    'Comment_Normal'   => [$perl_tex{'comment_normal'}, $perl_tex{'close'}],
    'Comment_POD'      => [$perl_tex{'comment_pod'},    $perl_tex{'nothing'}],
    'Directive'        => [$perl_tex{'directive'},      $perl_tex{'nothing'}],
    'Label'            => [$perl_tex{'label'},          $perl_tex{'nothing'}],
    'Quote'            => [$perl_tex{'quote'},          $perl_tex{'nothing'}],
    'String'           => [$perl_tex{'string'},         $perl_tex{'close'}],
    'Subroutine'       => [$perl_tex{'subroutine'},     $perl_tex{'close'}],
    'Variable_Scalar'  => [$perl_tex{'scalar'},         $perl_tex{'close'}],
    'Variable_Array'   => [$perl_tex{'array'},          $perl_tex{'nothing'}],
    'Variable_Hash'    => [$perl_tex{'hash'},           $perl_tex{'close'}],
    'Variable_Typeglob'=> [$perl_tex{'typeglob'},       $perl_tex{'close'}],
    'Whitespace'       => [q{},                         q{}                ],
    'Character'        => [$perl_tex{'character'},      $perl_tex{'nothing'}],
    'Keyword'          => [$perl_tex{'keyword'},        $perl_tex{'close'}],
    'Builtin_Function' => [$perl_tex{'function'},       $perl_tex{'close'}],
    'Builtin_Operator' => [$perl_tex{'operator'},       $perl_tex{'close'}],
    'Operator'         => [$perl_tex{'operator'},       $perl_tex{'close'}],
    'Bareword'         => [$perl_tex{'bareword'},       $perl_tex{'nothing'}],
    'Package'          => [$perl_tex{'package'},        $perl_tex{'close'}],
    'Number'           => [$perl_tex{'number'},         $perl_tex{'nothing'}],
    'Symbol'           => [q{},                          q{}],
    'CodeTerm'         => [$perl_tex{'codeterm'},       $perl_tex{'nothing'}],
    'DATA'             => [$perl_tex{'data'},           $perl_tex{'nothing'}],

    'Line'             => [$perl_tex{'line'},           $perl_tex{'close'}],
    'File_Name'        => [$perl_tex{'filename'},       $perl_tex{'nothing'}],
			);


  my @lines = split(/\n/, $text);
  my $return_text = q{};
  foreach my $l (@lines) {
    my $ln = sprintf("%5s", $formatter->line_count()+1);
    $ln =~ s{ }{ }g;
    $ln = $formatter->format_token($ln, 'Line');
    $return_text .= "$ln  ";
    my $this = $formatter->format_string($l);
    if ($this =~ m{\A(\s+)}) {
      my $space = " " x length($1);
      $this =~ s{\A\s+}{$space};
    };
    $return_text .= $this;
    $return_text .= $/;
  };
  return $return_text;
};
sub load {
  my ($class, $context) = @_;
  $context->define_filter('highlighter', \&filter);
  return $class;
};
1;
