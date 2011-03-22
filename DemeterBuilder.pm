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
use File::Path qw(mkpath);
use File::Spec;

my %windows = (strawberry => 'C:\strawberry',                     # base of Strawberry perl
	       gnuwin     => 'C:\GnuWin32',                       # base of GnuWin32, readline, ncurses
	       mingw      => 'C:\MinGW',                          # base of the MinGW compiler suite
	       pgplot     => 'C:\MinGW\lib\pgplot',               # install location of GRwin and PGPLOT
	       ifeffit    => 'C:\source\ifeffit-1.2.11d\src\lib', # install location of libifeffit.a
	       gnuplot    => 'C:\gnuplot\binaries',		  # install location of gnuplot.exe
	      );

sub ACTION_build {
  my $self = shift;
  $self->dispatch("build_document");
  $self->dispatch("compile_ifeffit_wrapper");
  $self->SUPER::ACTION_build;
  $self->dispatch("post_build");
}

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
		       q{-L}.$windows{strawberry}.q{\perl\lib\CORE"},
		       q{-L}.$windows{strawberry}.q{\c\lib"},
		       q{-L}.$windows{strawberry}.q{\c\lib\gcc\i686-w64-mingw32\4.4.3"},

		       q{-L}.$windows{ifeffit},
		       q{-lifeffit -lxafs},

		       #q{-L"C:\MinGW\bin"},
		       q{-L}.$windows{mingw}.q{\lib\gcc\mingw32\4.5.2"},
		       q{-L}.$windows{mingw}.q{\lib"},
		       q(-lgfortran -lmingw32 -lgcc_s -lmoldname -lmingwex -lmsvcrt -luser32 -lkernel32 -ladvapi32 -lshell32),

		       q{-L}.$windows{gnuwin}.q{\lib"},
		       q{-lcurses -lreadline},

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

sub ACTION_build_document {
  my $self = shift;
  my $here = cwd;
  chdir 'lib/Demeter/doc/dpg/';
  #do 'build_dpg.PL';
  mkdir 'html' if not -d 'html';
  system(q(./configure));
  system(q(./bin/build));
  chdir $here;
};

sub ACTION_org2html {
  return if is_older("todo.org", "todo.html");
  system('emacs --batch --eval "(setq org-export-headline-levels 2)" --visit=todo.org --funcall org-export-as-html-batch');
};

sub ACTION_update {
  my $self = shift;
  my $ret = $self->do_system(qw(git fetch));
  die "failed to update Demeter from github\n" if not $ret;
};


sub is_older {
  my ($file1, $file2) = @_;
  return (stat($file1))[9] < (stat($file2))[9]
};


1;
