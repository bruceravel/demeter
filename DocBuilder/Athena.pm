package DocBuilder::Athena;
1;

package DemeterBuilder;
use Cwd;

################################################################################
### Athena Users' Guide

sub ACTION_build_aug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/aug/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system "./configure";
  system(q(./bin/build -v));
  chdir $here;
  rmtree(File::Spec->catfile($ghpages, 'aug'), 1, 1);
  move('doc/aug/html', File::Spec->catfile($ghpages, 'aug'));
};

sub ACTION_local_aug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/aug/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system(q(./configure));
  system(q(./bin/build -v));
  chdir $here;
  mkdir 'lib/Demeter/UI/Athena/share/aug';
  chdir 'lib/Demeter/UI/Athena/share/aug';
  symlink('../../../../../../doc/aug/html', 'html');# or die "symlink failed: $!";
  symlink('../../../../../../doc/aug/images', 'images');# or die "symlink failed: $!";
  chdir $here;
};

sub ACTION_copy_aug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/aug/';
  mkdir 'html' if not -d 'html';
  $self->dispatch("configure_aug");
  $self->dispatch("ttree_aug");
  chdir $here;
  mkdir 'blib/lib/Demeter/UI/Athena/share/aug';
  dircopy('doc/aug/html', 'blib/lib/Demeter/UI/Athena/share/aug/html') or die "symlink failed: $!";
  dircopy('doc/aug/images', 'blib/lib/Demeter/UI/Athena/share/aug/images') or die "symlink failed: $!";
};


sub ACTION_copy_aug_images {
  my $self = shift;
  my $here = cwd;
  opendir(my $IM, 'doc/aug/images');
  my @list = grep {$_ =~ m{\.(png|jpg)\z}} readdir $IM;
  foreach my $image (@list) {
    copy(File::Spec->catfile('doc', 'aug', 'images', $image), File::Spec->catfile($ghpages, 'images'));
  };
};

sub ACTION_configure_aug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/aug' if (cwd !~ m{aug});
  my $id = cwd;

  print "Building Athena User's Guide\n" if (not $self->verbose);
  print "Configuring the Athena User's Guide build system for your machine\n" if ($self->verbose);

  print "  configuring bin directory\n" if ($self->verbose);
  foreach my $b (qw(build)) { # tex texbw pod mobile
    unlink File::Spec->catfile('bin', $b);
    system("tpage --define installdir=$id bin/$b.tt > bin/$b");
    chmod 0755, File::Spec->catfile('bin', $b);
  };

  print "  configuring etc directory\n" if ($self->verbose);
  foreach my $b (qw(ttree)) { #  ttree_tex ttree_texbw ttree_pod ttree_mobile
    unlink File::Spec->catfile('etc', $b);
    system("tpage --define installdir=$id etc/$b.tt > etc/$b.cfg");
  };

  print "  copying map and version templates\n" if ($self->verbose);
  copy(File::Spec->catfile('etc', 'map'),  File::Spec->catfile('..', 'lib', 'config', 'map.athena'));
  copy(File::Spec->catfile('etc', 'version'),  File::Spec->catfile('..', 'lib', 'config', 'version.athena'));

  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    print "  copying perl modules from DPG\n" if ($self->verbose);
    dircopy(File::Spec->catfile('..', 'dpg', 'Template'), 'Template');
  } else {
    print "  linking to perl modules from DPG\n" if ($self->verbose);
    symlink('../dpg/Template', 'Template');
  };

  chdir $here;
};

sub ACTION_ttree_aug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/aug' if (cwd !~ m{aug});
  my $id = cwd;
  my $verbose = q{};
  $verbose = "--verbose", if ($self->verbose);
  system("ttree -f $id/etc/ttree.cfg --relative --trim $verbose -a");
  chdir $here;
};



1;
