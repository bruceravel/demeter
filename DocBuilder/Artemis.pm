package DocBuilder::Artemis;
1;

package DemeterBuilder;
use Cwd;

################################################################################
### Artemis Users' Guide

sub ACTION_build_artug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/artug/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system "./configure";
  system(q(./bin/build -v));
  chdir $here;
  rmtree(File::Spec->catfile($ghpages, 'artug'), 1, 1);
  move('doc/artug/html', File::Spec->catfile($ghpages, 'artug'));
};

sub ACTION_local_artug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/artug/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system(q(./configure));
  system(q(./bin/build -v));
  chdir $here;
  mkdir 'lib/Demeter/UI/Artemis/share/artug';
  chdir 'lib/Demeter/UI/Artemis/share/artug';
  symlink('../../../../../../doc/artug/html', 'html');# or die "symlink failed: $!";
  symlink('../../../../../../doc/artug/images', 'images');# or die "symlink failed: $!";
  chdir $here;
};

sub ACTION_copy_artug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/artug/';
  mkdir 'html' if not -d 'html';
  $self->dispatch("configure_artug");
  $self->dispatch("ttree_artug");
  chdir $here;
  mkdir 'blib/lib/Demeter/UI/Artemis/share/artug';
  dircopy('doc/artug/html', 'blib/lib/Demeter/UI/Artemis/share/artug/html') or die "symlink failed: $!";
  dircopy('doc/artug/images', 'blib/lib/Demeter/UI/Artemis/share/artug/images') or die "symlink failed: $!";
};


sub ACTION_copy_artug_images {
  my $self = shift;
  my $here = cwd;
  opendir(my $IM, 'doc/artug/images');
  my @list = grep {$_ =~ m{\.(png|jpg)\z}} readdir $IM;
  foreach my $image (@list) {
    copy(File::Spec->catfile('doc', 'artug', 'images', $image), File::Spec->catfile($ghpages, 'images'));
  };
};

sub ACTION_configure_artug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/artug' if (cwd !~ m{artug});
  my $id = cwd;

  print "Building Artemis User's Guide\n" if (not $self->verbose);
  print "Configuring the Artemis User's Guide build system for your machine\n" if ($self->verbose);

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
  copy(File::Spec->catfile('etc', 'map'),  File::Spec->catfile('..', 'lib', 'config', 'map.artemis'));
  copy(File::Spec->catfile('etc', 'version'),  File::Spec->catfile('..', 'lib', 'config', 'version.artemis'));

  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    print "  copying perl modules from DPG\n" if ($self->verbose);
    dircopy(File::Spec->catfile('..', 'dpg', 'Template'), 'Template');
  } else {
    print "  linking to perl modules from DPG\n" if ($self->verbose);
    symlink('../dpg/Template', 'Template');
  };

  chdir $here;
};

sub ACTION_ttree_artug {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/artug' if (cwd !~ m{artug});
  my $id = cwd;
  my $verbose = q{};
  $verbose = "--verbose", if ($self->verbose);
  system("ttree -f $id/etc/ttree.cfg --relative --trim $verbose");
  chdir $here;
};



1;
