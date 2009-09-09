package Template::Plugin::PerlSyntaxHtml;

use strict;
use warnings;
use PPI;
use PPI::HTML;
use Template::Plugin::Filter;

use base qw(Template::Plugin::Filter);

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

  # Load your Perl text
  my $Document = PPI::Document->new( \$text );
  # Create a reusable syntax highlighter
  my $Highlight = PPI::HTML->new( line_numbers => 0 );

  my @lines = split(/\n/, $Highlight->html( $Document ));
  my $return_text = q{};
  foreach my $l (@lines) {
    if ($do_linum) {
      $return_text .= "<li>";
    } else {
      $return_text .= "&nbsp;&nbsp;";
    };
    $l =~ s{<br>}{\n};		# make linebreaks literal to avoid super long lines

    ## need to post-process comment and other multi-line spans

    while ($l =~ m{(\s{2,})}) {
      my $space = "&nbsp;" x length($1);
      $l =~ s{$1}{$space};
    };
    $return_text .= $l;
    #$return_text .= $/;
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
