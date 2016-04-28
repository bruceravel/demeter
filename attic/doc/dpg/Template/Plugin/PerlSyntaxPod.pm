package Template::Plugin::PerlSyntaxPod;

use strict;
use warnings;
use Syntax::Highlight::Perl ':BASIC';
use Template::Plugin::Filter;

use base qw(Template::Plugin::Filter);
my %perl_html = (close  => q{});
foreach my $key (qw(comment_normal comment_pod directive label quote
		    string subroutine scalar array typeglob character
		    function keyword operator bareword package number symbol
		    codeterm data line filename)) {
  $perl_html{$key} = "q{}";

};

sub filter {
  my $text = shift;
  my $formatter = new Syntax::Highlight::Perl;
  $formatter->unstable(0);
  $formatter->set_format(
    'Comment_Normal'   => [q{}, q{}],
    'Comment_POD'      => [q{}, q{}],
    'Directive'        => [q{}, q{}],
    'Label'            => [q{}, q{}],
    'Quote'            => [q{}, q{}],
    'String'           => [q{}, q{}],
    'Subroutine'       => [q{}, q{}],
    'Variable_Scalar'  => [q{}, q{}],
    'Variable_Array'   => [q{}, q{}],
    'Variable_Hash'    => [q{}, q{}],
    'Variable_Typeglob'=> [q{}, q{}],
    'Whitespace'       => [q{}, q{}],
    'Character'        => [q{}, q{}],
    'Keyword'          => [q{}, q{}],
    'Builtin_Function' => [q{}, q{}],
    'Builtin_Operator' => [q{}, q{}],
    'Operator'         => [q{}, q{}],
    'Bareword'         => [q{}, q{}],
    'Package'          => [q{}, q{}],
    'Number'           => [q{}, q{}],
    'Symbol'           => [q{}, q{}],
    'CodeTerm'         => [q{}, q{}],
    'DATA'             => [q{}, q{}],

    'Line'             => [q{}, q{}],
    'File_Name'        => [q{}, q{}],
			);


  my @lines = split(/\n/, $text);
  my $return_text = q{};
  foreach my $l (@lines) {
    my $ln = sprintf("%5s", $formatter->line_count()+1);
    #$ln =~ s{ }{&nbsp;}g;
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
