package DemeterBuilder;
#
# subclass of Module::Build defining some Demeter specific installation instructions
#

use base 'Module::Build';

use warnings;
use strict;
use Carp;
use File::Copy;
use File::Path qw(mkpath);
use File::Spec;

sub ACTION_build {
  my $self = shift;
  $self->dispatch("compile_ifeffit_wrapper");
  $self->SUPER::ACTION_build;
  $self->dispatch("post_build");
}

sub ACTION_compile_ifeffit_wrapper {
  my $self = shift;

  ## figure out which platform we are on
  my $platform = 'unix';
 SWITCH: {
    ($platform = 'windows'), last SWITCH if (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
    ($platform = 'darwin'),  last SWITCH if (lc($^O) eq 'darwin');
    $platform = 'unix';
  };

  my ($compile_flags, $pgplot_location, $iffdir);
  if ($platform eq 'windows') {
    1;

  } elsif ($platform eq 'darwin') {
    1;

  } else {
    ($compile_flags, $pgplot_location, $iffdir) = ("", "", `ifeffit -i`);
    $iffdir =~ s/\s*$//;
    print STDOUT
      "Ifeffit's installations directory is $iffdir\n\t(found by capturing \`ifeffit -i\`)\n";
    open C, "$iffdir/config/Config.mak" or
      die "Could not open $iffdir/config/Config.mak file for reading\n";
    while (<C>) {
      next if (/^\s*\#/);
      chomp;
      ($compile_flags   .= (split(/=/, $_))[1]) if (/^LIB/);
      $compile_flags    .= " ";
      ($pgplot_location .= (split(" ", $_))[2]) if (/^LIB_PLT/);
    };
    print STDOUT "Compilation flags (from $iffdir/config/Config.mak):\n\t$compile_flags\n";
  };
  $pgplot_location =~ s/-L//;


  my $cbuilder = $self->cbuilder;
  my $obj_file = $cbuilder->compile(source => 'src/ifeffit_wrap.c');
  my $lib_file = $cbuilder->link(objects => $obj_file, extra_linker_flags=>$compile_flags, lib_file=>'src/Ifeffit.so');

};

sub ACTION_post_build {
  my $self = shift;
  mkpath(File::Spec->catfile('blib', 'arch', 'auto', 'Ifeffit'));
  copy(File::Spec->catfile('src', 'Ifeffit.so'), File::Spec->catfile('blib', 'arch', 'auto', 'Ifeffit'));
  copy(File::Spec->catfile('src', 'Ifeffit.bs'), File::Spec->catfile('blib', 'arch', 'auto', 'Ifeffit'));
  chmod 0755, File::Spec->catfile('blib', 'arch', 'auto', 'Ifeffit', 'Ifeffit.so');
};

#sub ACTION_install {
#  my $self = shift;
#  $self->dispatch("pre_install");
#  $self->SUPER::ACTION_install;
#};

sub ACTION_update {
  my $self = shift;
  my $ret = $self->do_system(qw(git fetch));
  die "failed to update Demeter from github\n" if not $ret;
};


1;
