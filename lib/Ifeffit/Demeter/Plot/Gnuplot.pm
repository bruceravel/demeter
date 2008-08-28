package Ifeffit::Demeter::Plot::Gnuplot;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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
#use diagnostics;
use Class::Std;
use Carp;
use Fatal qw(open close);
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};

{
  use base 'Ifeffit::Demeter::Plot';

  sub gnuplot_start {
    my ($self) = @_;
    my $command = $self->template("plot", "start");
    $self->dispose($command, "plotting");
    $self->set({lastplot=>q{}});
  };

  sub end_plot {
    my ($self) = @_;
    $self->dispose("quit", "plotting");
    return $self;
  };

  sub tempfile {
    my ($self) = @_;
    my $this = File::Spec->catfile($self->stash_folder, 'gp_'.Ifeffit::Demeter::Tools->random_string(8));
    $self->Push({tempfiles => $this});
    return $this;
  };
  sub legend {
    my ($self, $arguments) = @_;
    foreach my $which (qw(dy y x)) {
      $arguments->{$which} ||= $arguments->{"key_".$which};
      $arguments->{$which} ||= $self -> po ->get("key_".$which);
    };

    foreach my $key (keys %$arguments) {
      next if ($key !~ m{\A(?:dy|x|y)\z});
      carp("$key must be a positive number."), ($arguments->{$key}=$self->po->("key_".$key)) if ($arguments->{$key} !~ m{$NUMBER});
      carp("$key must be a positive number."), ($arguments->{$key}=$self->po->("key_".$key)) if ($arguments->{$key} < 0);
      $self->set({ "key_".$key=>$arguments->{$key} });
    };
    ## this is wrong!!!
    #$self->get_mode('external_plot_object')->gnuplot_cmd("set key inside left top");
    return $self;
  };

  sub file {
    my ($self, $type, $file) = @_;
    my $old = $self->get('lastplot');
    ## need to parse $old to replace replot commands with
    ## continuations so that the plot ends up in a single image
    my $command = $self->template("plot", "file", { device => $type,
						    file   => $file });
    $self -> dispose($command, "plotting");
    #$self -> dispose($old, "plotting");
    #$command = $self->template("plot", "restore");
    #$self -> dispose($command, "plotting");
    $self -> set({lastplot=>$old});
    return $self;
  };

  sub font {
    my ($self, $arguments) = @_;
    $arguments->{font} ||= $arguments->{charfont};
    $arguments->{size} ||= $arguments->{charsize};
    $arguments->{font} ||= $self->config->default('gnuplot','font');
    $arguments->{size} ||= $self->config->default('gnuplot','fontsize');
    ## need to verify that font exists...
    $self->config->set_default('gnuplot', 'font',     $arguments->{font});
    $self->config->set_default('gnuplot', 'fontsize', $arguments->{size});
    $self->dispose($self->template("plot", "start"), "plotting");
    return $self;
  };

  sub replot {
    my ($self) = @_;
    carp("Ifeffit::Demeter::Plot::Gnuplot: Cannot replot, there is no previous plot."), return $self if ($self->get('lastplot') =~ m{\A\s*\z});
    $self -> dispose($self->get('lastplot'), "plotting");
    return $self;
  };

  sub gnuplot_kylabel {
    my ($self) = @_;
    my $w = $self->get('kweight');
    if ($w == 1) {
      return 'k {\267} {/Symbol c}(k)&{aa}({\101})';
    } elsif ($w == 0) {
      return '{/Symbol c}(k)';
    } else {
      return sprintf('k^%s {\267} {/Symbol c}(k)&{aa}({\305}^{-%s})', $w, $w);
    };
  };

  sub gnuplot_rylabel {
    my ($self) = @_;
    my $w = $self->get('kweight');
    my $part = $self->get('r_pl');
    my ($open, $close) = ($part eq 'm') ? ('{/*1.25 |}',    '{/*1.25 |}')
                       : ($part eq 'r') ? ('{/*1.25 Re[}',  '{/*1.25 ]}')
                       : ($part eq 'i') ? ('{/*1.25 Im[}',  '{/*1.25 ]}')
                       : ($part eq 'p') ? ('{/*1.25 Pha[}', '{/*1.25 ]}')
		       :                  ('{/*1.25 Env[}', '{/*1.25 ]}');
    return sprintf('%s{/Symbol c}(R)%s&{aa}({\305}^{-%s})', $open, $close, $w+1);
  };
  sub gnuplot_qylabel {
    my ($self) = @_;
    my $w = $self->get('kweight');
    my $part = $self->get('q_pl');
    my ($open, $close) = ($part eq 'm') ? ('{/*1.25 |}',    '{/*1.25 |}')
                       : ($part eq 'r') ? ('{/*1.25 Re[}',  '{/*1.25 ]}')
                       : ($part eq 'i') ? ('{/*1.25 Im[}',  '{/*1.25 ]}')
                       : ($part eq 'p') ? ('{/*1.25 Pha[}', '{/*1.25 ]}')
		       :                  ('{/*1.25 Env[}', '{/*1.25 ]}');
    return sprintf('%s{/Symbol c}(q)%s&{aa}({\305}^{-%s})', $open, $close, $w);
  };
};
1;

=head1 NAME

Ifeffit::Demeter::Plot::Gnuplot - Using Gnuplot with Demeter

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  use Ifeffit::Demeter;
  Ifeffit::Demeter -> plot_with("gnuplot");

=head1 DESCRIPTION

This base class of Ifeffit::Demeter::Plot contains methods for
interacting with Gnuplot via L<Graphics::GnuplotIF>.

=head1 METHODS

=over 4

=item C<gnuplot_start>

=item C<gnuplot_kylabel>

=item C<gnuplot_rylabel>

=item C<gnuplot_qylabel>

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.  The plot and ornaments configuration groups control the
attributes of the Plot object.

=head1 DEPENDENCIES

This module requires L<Graphics::GnuplotIF> and gnuplot itself.  On a
linux machine, I strongly recommend a version of gnuplot at 4.2 or
higher so you can use the wonderful wxt terminal type.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Breakage if trying to plot a path with no data

=item *

The file method is broken -- need to replace replot commands with
continuations

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

