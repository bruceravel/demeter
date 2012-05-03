package DemeterBuilder;
#
# subclass of Module::Build defining some Demeter specific installation instructions
#

use base 'Module::Build';

use warnings;
use strict;
use Carp;
use Cwd;
use File::Copy;
use File::Path qw(mkpath rmtree);
use File::Spec;
#use File::Touch;

######################################################################
## Configuration

my %windows = (strawberry => 'C:\strawberry',                     # base of Strawberry perl
	       #gnuwin     => 'C:\GnuWin32',                      # base of GnuWin32, readline, ncurses
	       gnuwin     => 'C:\strawberry\lib',
	       #mingw      => 'C:\MinGW',                         # base of the MinGW compiler suite
	       mingw      => 'C:\strawberry\c\lib\gcc\i686-w64-mingw32\4.4.3',
	       #pgplot     => 'C:\MinGW\lib\pgplot',              # install location of GRwin and PGPLOT
	       pgplot     => 'C:\strawberry\c\lib\pgplot',
	       #ifeffit    => 'C:\source\ifeffit-1.2.11d\src\lib', # install location of libifeffit.a
	       ifeffit    => 'C:\strawberry\lib',
	       #gnuplot    => 'C:\gnuplot\binaries',		  # install location of gnuplot.exe
	       gnuplot    => 'C:\strawberry\c\bin',
	      );
my $ghpages = '../demeter-gh-pages';

######################################################################
## Actions

sub ACTION_build {
  my $self = shift;
  $self->dispatch("compile_ifeffit_wrapper");
  $self->SUPER::ACTION_build;
  $self->dispatch("post_build");
}

sub ACTION_ghpages {
  my $self = shift;
  $self->dispatch("build_dpg");
  $self->dispatch("doctree");
  $self->dispatch("org2html");
};

sub ACTION_compile_ifeffit_wrapper {
  my $self = shift;

  ## figure out which platform we are on
  my ($platform, $suffix) = ('unix', 'so');
 SWITCH: {
    (($platform, $suffix) = ('windows', 'dll')),   last SWITCH if (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
    (($platform, $suffix) = ('darwin',  'dylib')), last SWITCH if (lc($^O) eq 'darwin');
     ($platform, $suffix) = ('unix',    'so');
  };

  if (is_older("src/Ifeffit.$suffix", "src/ifeffit_wrap.c")) {
    my ($compile_flags, $linker_flags, $pgplot_location, $iffdir);
    if ($platform eq 'windows') {
      ($compile_flags, $linker_flags) = (q{}, q{});
      ($pgplot_location, $iffdir) = (q{}, q{});

      $linker_flags = [
		       q{-L}.$windows{gnuwin}.q{\lib"},
		       q{-lcurses -lreadline},

		       q{-L}.$windows{strawberry}.q{\perl\lib\CORE"},
		       q{-L}.$windows{strawberry}.q{\c\lib"},
		       q{-L}.$windows{strawberry}.q{\c\lib\gcc\i686-w64-mingw32\4.4.3"},

		       q{-L}.$windows{ifeffit},
		       q{-lifeffit -lxafs},

		       #q{-L"C:\MinGW\bin"},
		       q{-L}.$windows{mingw}.q{\lib\gcc\mingw32\4.5.2"},
		       q{-L}.$windows{mingw}.q{\lib"},
		       q(-lgfortran -lmingw32 -lgcc_s -lmoldname -lmingwex -lmsvcrt -luser32 -lkernel32 -ladvapi32 -lshell32),

		       q{-L}.$windows{pgplot},
		       qw{-lcpgplot -lpgplot -lGrWin -lgdi32 -lg2c},
		      ];
      #    $compile_flags = $linker_flags;
    } elsif ($platform eq 'darwin') {
      1;

    } else {
      ($compile_flags, $linker_flags) = (q{}, q{});
      ($pgplot_location, $iffdir) = ("", `ifeffit -i`);
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
	$linker_flags = $compile_flags;
      };
      print STDOUT "Compilation flags (from $iffdir/config/Config.mak):\n\t$compile_flags\n";
    };
    $pgplot_location =~ s/-L//;


    my $cbuilder = $self->cbuilder;
    my $obj_file = $cbuilder->compile(source               => 'src/ifeffit_wrap.c',
				      extra_compiler_flags => $compile_flags);
    my $lib_file = $cbuilder->link(objects            => $obj_file,
				   module_name        => 'Ifeffit',
				   extra_linker_flags => $linker_flags,
				   lib_file           => "src/Ifeffit.$suffix");
  };
};

sub ACTION_post_build {
  my $self = shift;
  my $suffix = 'so';
 SWITCH: {
    ($suffix = 'dll'),   last SWITCH if (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
    ($suffix = 'dylib'), last SWITCH if (lc($^O) eq 'darwin');
    $suffix = 'so';
  };

  $self->copy_if_modified( from    => File::Spec->catfile('src',"Ifeffit.$suffix"),
			   to_dir  => File::Spec->catdir('blib','arch','auto','Ifeffit'),
			   flatten => 1);
  $self->copy_if_modified( from    => File::Spec->catfile('src','Ifeffit.bs'),
			   to_dir  => File::Spec->catdir('blib','arch','auto','Ifeffit'),
			   flatten => 1);
};

sub ACTION_build_dpg {
  my $self = shift;
  my $here = cwd;
  chdir 'doc/dpg/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system(q(./configure));
  system(q(./bin/build));
  chdir $here;
  rmtree(File::Spec->catfile($ghpages, 'dpg'), 1, 1);
  move('doc/dpg/html', File::Spec->catfile($ghpages, 'dpg'));
};

sub ACTION_org2html {
  if (not is_older("todo.org", File::Spec->catfile($ghpages, 'todo.html'))) {
    system('emacs --batch --eval "(setq org-export-headline-levels 2)" --visit=todo.org --funcall org-export-as-html-batch');
    move('todo.html', File::Spec->catfile($ghpages, 'todo.html'));
  };
  if (not is_older("Changes.org", File::Spec->catfile($ghpages, 'Changes.html'))) {
    system('emacs --batch --eval "(setq org-export-headline-levels 2)" --visit=Changes.org --funcall org-export-as-html-batch');
    move('Changes.html', File::Spec->catfile($ghpages, 'Changes.html'));
  };
};

sub ACTION_doctree {
  my $self = shift;
  require Pod::ProjectDocs;
  my $LIB  = 'lib'; #File::Spec->catfile('..', '..', '..', 'lib');
  my $BIN  = 'bin'; #File::Spec->catfile('..', '..', '..', 'bin');
  my @list = (qw(denv dhephaestus datoms dfeff dfeffit rdfit dlsprj standards dathena dartemis));
  foreach my $d (@list) {
    copy(File::Spec->catfile($BIN, $d),        File::Spec->catfile($BIN, "$d.pl"));
  };
  my $pd = Pod::ProjectDocs->new(
				 outroot => File::Spec->canonpath(File::Spec->catfile($ghpages, 'pods')),
				 libroot => [$LIB, $BIN],
				 title   => 'Demeter',
				 desc    => "Perl tools for X-ray Absorption Spectroscopy",
				 except  => [qr(Savitzky), qr(ToolTemplate), qr(XDI)],
				);
  $pd->gen();
  foreach my $d (@list) {
    unlink File::Spec->catfile($BIN, "$d.pl");
  };
};

sub ACTION_pull {
  my $self = shift;
  my $ret = $self->do_system(qw(git pull));
  die "failed to pull Demeter from github\n" if not $ret;
};

sub ACTION_touch_wrapper {
  my $self = shift;
  eval "require File::Touch";
  print "touching src/ifeffit_wrap.c\n";
  File::Touch::touch(File::Spec->catfile('src', 'ifeffit_wrap.c'));
  $self->ACTION_build;
  printf("copying %s to %s\n",
	 File::Spec->catfile('src', 'Ifeffit.so'),
	 File::Spec->catfile($ENV{HOME}, 'perl', 'auto', 'Ifeffit', 'Ifeffit.so'));
  mkpath(File::Spec->catfile($ENV{HOME}, 'perl', 'auto', 'Ifeffit')) if not -e File::Spec->catfile($ENV{HOME}, 'perl', 'auto', 'Ifeffit');
  copy(File::Spec->catfile('src', 'Ifeffit.so'), File::Spec->catfile($ENV{HOME}, 'perl', 'auto', 'Ifeffit', 'Ifeffit.so'));
};

sub ACTION_bump {
  my $self = shift;
  (my $v = $self->dist_version) =~ s{\Av}{}; # strip letter v from beginning of version number
  my $ret = $self->do_system(qw(perl-reversion -bump), "--current=$v");
};
sub ACTION_bump_dryrun {
  my $self = shift;
  (my $v = $self->dist_version) =~ s{\Av}{}; # strip letter v from beginning of version number
  my $ret = $self->do_system(qw(perl-reversion -bump), "--current=$v", '-dryrun');
};

######################################################################
## tools

sub is_older {
  my ($file1, $file2) = @_;
  return 1 if not -e $file1;
  return (stat($file1))[9] < (stat($file2))[9]
};

## redefine (and suppress the warning about doing so) the method used
## to generate the bat files.  this adds code for redirecting STDOUT
## and STDERR to a log file in %APPDATA%\demeter

package Module::Build::Platform::Windows;

{
  no warnings 'redefine';
  sub make_executable {
    my $self = shift;

    $self->SUPER::make_executable(@_);

    foreach my $script (@_) {
      my @list = split(/\\/, $script);
      my $this = $list[-1];
      # Native batch script
      if ( $script =~ /\.(bat|cmd)$/ ) {
	$self->SUPER::make_executable($script);
	next;

	# Perl script that needs to be wrapped in a batch script
      } else {
	my %opts = ();
	if ( $script eq $self->build_script ) {
	  $opts{ntargs}    = q(-x -S %0 --build_bat %*);
	  $opts{otherargs} = q(-x -S "%0" --build_bat %1 %2 %3 %4 %5 %6 %7 %8 %9);
	} else {
	  my $logfile = ' > "%APPDATA%\\demeter\\' . $this . '.log" 2>&1';
	  $opts{ntargs}    = q(-x -S %0 %*) . $logfile;
	  $opts{otherargs} = q(-x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9) . $logfile;
	};

	my $out = eval {$self->pl2bat(in => $script, update => 1, %opts)};
	if ( $@ ) {
	  $self->log_warn("WARNING: Unable to convert file '$script' to an executable script:\n$@");
	} else {
	  $self->SUPER::make_executable($out);
	}
      }
    }
  }

}

1;
