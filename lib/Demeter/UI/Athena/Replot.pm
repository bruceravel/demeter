package Demeter::UI::Athena::Replot;

use strict;
use base qw( Exporter );
our @EXPORT = qw(replot $APP);

our $APP = $::app;

sub replot {
  my ($plot, $space, $how) = @_;
  $::app->plot(q{}, q{}, $space, $how), $/;
};

1;
