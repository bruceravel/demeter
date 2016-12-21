package DemeterBuilder;
#
# subclass of Module::Build defining some Demeter specific installation instructions
#

use base 'Module::Build';

use warnings;
use strict;
use Carp;
use Cwd;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path qw(mkpath rmtree);
use File::Spec;
use IPC::Cmd qw(can_run);
use IPC::Open3;

## this eval is required so that the build scripts can be made even if
## F::C::R or any of the others are not yet installed.  A "Build
## installdeps" is required to actually install F::C::R.  Once that is
## done, the build will proceed correctly.
eval "
use File::Copy::Recursive qw(dircopy);
use Pod::ProjectDocs;
use File::Slurper qw(read_text write_text);
use File::Which qw(which);
";


######################################################################
## Configuration

my $WINPERL = File::Spec->catfile($ENV{APPDATA}||'./', 'DemeterPerl');
my %windows = (base    => $WINPERL,  # base of Demeter's perl
	       gnuwin  => File::Spec->catfile($WINPERL, 'lib'),
	       mingw   => File::Spec->catfile($WINPERL, 'c', 'lib', 'i686-w64-mingw32', '4.7.3'),
	       pgplot  => File::Spec->catfile($WINPERL, 'c', 'lib', 'pgplot'),
	       ifeffit => File::Spec->catfile($WINPERL, 'c', 'lib'),
	       gnuplot => File::Spec->catfile($WINPERL, 'c', 'bin', 'gnuplot', 'bin'),
	       artug   => File::Spec->catfile($WINPERL, 'perl', 'site', 'lib', 'Demeter', 'share'),
	      );
our $ghpages = '../demeter-gh-pages';

######################################################################
## Actions

sub ACTION_build {
  my $self = shift;
  unlink File::Spec->catfile('lib', 'Demeter', 'configuration', 'plot.demeter_conf');
  unlink File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf');
  $self->dispatch("compile_ifeffit_wrapper");
  $self->dispatch("test_for_gnuplot");
  # $self->dispatch("test_for_larchserver");
  $self->SUPER::ACTION_build;
  $self->dispatch("post_build");
}

sub ACTION_test {
  my $self = shift;
  $ENV{DEMETER_FORCE_IFEFFIT} = 1;
  print "NOTE: Forcing use of Ifeffit in testing.\n";
  $self->SUPER::ACTION_test;
};

sub ACTION_docs {
  1; ## null op
};

sub ACTION_manuals {
  my $self = shift;
  $self->dispatch("build_documents");
};


sub ACTION_ghpages {
  my $self = shift;
  $self->dispatch("build_documents");
  $self->dispatch("docs_to_ghpages");
  $self->dispatch("doctree");
  $self->dispatch("org2html");
};

sub ACTION_test_for_gnuplot {
  my $self = shift;
  my $infile   = File::Spec->catfile('lib', 'Demeter', 'configuration', 'plot.demeter_conf.in');
  my $conffile = File::Spec->catfile('lib', 'Demeter', 'configuration', 'plot.demeter_conf');
  return if not is_older($conffile, $infile);
  print STDOUT "Simple test for presence of gnuplot ---> ";
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    ## still need to make a gnuplot.demeter_conf so tests can run correctly
    copy(File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf.in'),
	 File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf'));
    copy($infile, $conffile);
    print STDOUT "this is windows.  Using gnuplot with the wxt terminal.\n";
    return;
  };

  ## in the following system calls, I want to capture and NOT display STDERR
  ## from the call to gnuplot, instead relying upon the return value $?
  ## see http://perldoc.perl.org/perlfaq8.html#How-can-I-capture-STDERR-from-an-external-command%3f
  my $in = '';
  ##my $gp = File::Which::where('gnuplot');
  #my $pid = open3($in, ">&STDERR", \*PH, 'gnuplot -e "set xrange [0:1]"');
  #my $pid = open3($in, ">&STDERR", \*PH, 'gnuplot -V');
  #while( <PH> ) { print '>', $_, '<', $/}
  #waitpid($pid, 0);
  #if ($? != 0) {

  my $gp = can_run("gnuplot");
  if (not $gp) {
    copy($infile, $conffile);
    ## still need to make a gnuplot.demeter_conf so tests can run correctly
    copy(File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf.in'),
	 File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf'));
    print STDOUT "*** Gnuplot not found: using pgplot.\n";
    return;
  };
  my $text = _slurp(File::Spec->catfile('lib', 'Demeter', 'configuration', 'plot.demeter_conf.in'));
  $text =~ s{default=pgplot}{default=gnuplot};
  open(my $FIXED, '>', $conffile);
  print $FIXED $text;
  close $FIXED;
  print STDOUT "found it!  Using gnuplot with the ";

  ## figure out the version number and patchlevel of this version of gnuplot
  ## we are looking to see if the version is 4.6.2 or higher so we can use the -d flag
  ## -d avoids getting tripped up by weirdness in the ~/.gnuplot file
  my $gpv = 0;
  $gpv = `$gp -V` if $gp;
  my ($major, $minor) = (0,0);
  my $command = 'gnuplot -d -e "set terminal wxt"';
  if ($gpv =~ m{gnuplot\s+(\d\.\d+)\s+patchlevel\s+(\d+)}) {
    if ($1 < 4.6) {
      $command = 'gnuplot -e "set terminal wxt"';
    } elsif ($1 eq '4.6' and $2 < 2) {
      $command = 'gnuplot -e "set terminal wxt"';
    };
  };

  ## now test for qt terminal
  my $term = 'x11';
  $in = '';
  my $pid = open3($in, ">&STDERR", \*PH, $command);
  while( <PH> ) { }
  waitpid($pid, 0);
  if ($? == 0) {
    $term = 'qt';
  };

  ## and for wxt terminal
  $command =~ s{qt}{wxt};
  $in = '';
  $pid = open3($in, ">&STDERR", \*PH, $command);
  while( <PH> ) { }
  waitpid($pid, 0);
  if ($? == 0) {
    $term = 'wxt';
  };

  ## and set conf file accordingly
  $text = _slurp(File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf.in'));
  $text =~ s{default=x11}{default=$term};
  open($FIXED, '>', File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf'));
  print $FIXED $text;
  close $FIXED;

  print STDOUT "$term terminal.\n";
};

## this is no longer needed -- Larch is tested for at runtime
sub ACTION_test_for_larchserver {
  # search for Python exe and Larch server script, write larch_server.ini
  my $inifile = File::Spec->catfile(cwd, 'lib', 'Demeter', 'share', 'ini', 'larch_server.ini');
  print STDOUT "Looking for Python and Larch ---> ";
  my $larchexec  = '';
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
      my @dirlist = split /;/, $ENV{'PATH'};
      push @dirlist,  (File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda3'),
		       File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda2'),
		       File::Spec->catfile($ENV{LOCALAPPDATA}, 'Continuum', 'Anaconda'),
		       File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda3'),
		       File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda2'),
		       File::Spec->catfile($ENV{APPDATA}, 'Continuum', 'Anaconda'),
		       'C:\Python27', 'C:\Python35');
      foreach my $d (@dirlist) {
	  my $pyexe_ =  File::Spec->catfile($d, 'python.exe');
	  my $larch_ =  File::Spec->catfile($d, 'Scripts', 'larch_server');
	  if ((-e $pyexe_) && (-e $larch_))  {
	      $larchexec = "$pyexe_ $larch_";
	      last;
	  }
      }
  } else {
      my @dirlist = split /:/, $ENV{'PATH'};
      push @dirlist,  (File::Spec->catfile($ENV{HOME}, 'anaconda3', 'bin'),
		       File::Spec->catfile($ENV{HOME}, 'anaconda2', 'bin'),
		       File::Spec->catfile($ENV{HOME}, 'anaconda', 'bin'));

      foreach my $d (@dirlist) {
	  my $pyexe_ =  File::Spec->catfile($d, 'python');
	  my $larch_ =  File::Spec->catfile($d, 'larch_server');
	  if ((-e $pyexe_) && (-e $larch_))  {
	      $larchexec = "$pyexe_ $larch_";
	      last;
	  }
      }
  }
  if ($larchexec eq '') {
      print "not found\n";
  } else {
      print "found  $larchexec \n";
  }
  my $larch_server_ini_text = <<"END_OF_FILE";
---
server: 'localhost' # URL of larch_server or "localhost" is running locally
port: 4966          # the port number the larch server is listening to
timeout: 3          # the timeout in seconds before Demeter gives up trying to talk to the larch server
quiet: 1            # 1 means to suppress larch_server screen messages, 0 means allow larch_server to print messages
windows: $larchexec
END_OF_FILE

  open(my $FOUT, '>', $inifile);
  print $FOUT $larch_server_ini_text;
  close $FOUT;
  print "Wrote $inifile\n";
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

		       q{-L}.$windows{base}.q{\perl\lib\CORE"},
		       q{-L}.$windows{base}.q{\c\lib"},
		       q{-L}.$windows{mingw},
		       q{-L}.$windows{ifeffit},
		       q{-lifeffit -lxafs},

		       #q{-L"C:\MinGW\bin"},
		       q{-L}.$windows{mingw},
		       q{-L}.$windows{mingw}.q{\lib"},
		       q(-lgfortran -lmingw32 -lgcc_s -lmoldname -lmingwex -lmsvcrt -luser32 -lkernel32 -ladvapi32 -lshell32),

		       q{-L}.$windows{pgplot},
		       qw{-lcpgplot -lpgplot -lGrWin -lgdi32 -lgfortran},
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


################################################################################
### Manage documents


sub ACTION_build_documents {
  my $sphinx = which('sphinx-build');
  if (not defined($sphinx)) {
    print "sphinx not found, not building documentation (see http://www.sphinx-doc.org)\n";
    return;
  };
  my $here = cwd;
  mkdir 'blib/lib/Demeter/share/documentation';

  print "-- Building Athena document\n";
  chdir File::Spec->catfile('documentation', 'Athena');
  system(q{make SPHINXOPTS=-q html});
  chdir $here;
  dircopy('documentation/Athena/_build/html', 'blib/lib/Demeter/share/documentation/Athena') or die "dircopy failed: $!";

  print "-- Building Artemis document\n";
  chdir File::Spec->catfile('documentation', 'Artemis');
  system(q{make SPHINXOPTS=-q html});
  chdir $here;
  dircopy('documentation/Artemis/_build/html', 'blib/lib/Demeter/share/documentation/Artemis') or die "dircopy failed: $!";

  print "-- Building Demeter Programming Guide\n";
  chdir File::Spec->catfile('documentation', 'DPG');
  system(q{make SPHINXOPTS=-q html});
  chdir $here;
  dircopy('documentation/DPG/_build/html', 'blib/lib/Demeter/share/documentation/DPG') or die "dircopy failed: $!";

  print "-- Building Single Page documents\n";
  chdir File::Spec->catfile('documentation', 'SinglePage');
  system(q{make SPHINXOPTS=-q html});
  chdir $here;
  dircopy('documentation/SinglePage/_build/html', 'blib/lib/Demeter/share/documentation/SinglePage') or die "dircopy failed: $!";
};


sub ACTION_docs_to_ghpages {
  print "copying Athena manual\n";
  dircopy('documentation/Athena/_build/html',     File::Spec->catfile($ghpages, 'documents/Athena'))     or die "dircopy failed: $!";
  print "copying Artemis manual\n";
  dircopy('documentation/Artemis/_build/html',    File::Spec->catfile($ghpages, 'documents/Artemis'))    or die "dircopy failed: $!";
  print "copying DPG\n";
  dircopy('documentation/DPG/_build/html',        File::Spec->catfile($ghpages, 'documents/DPG'))        or die "dircopy failed: $!";
  print "copying SinglePage documents\n";
  dircopy('documentation/SinglePage/_build/html', File::Spec->catfile($ghpages, 'documents/SinglePage')) or die "dircopy failed: $!";
};


################################################################################
### Manage org-mode pages

sub ACTION_org2html {
  my $org2html = which('org2html');
  if (not defined($org2html)) {
    print "org2html not found, not converting org pages (see https://github.com/fniessen/orgmk)\n";
    return;
  };
  print "copying stylesheets\n";
  copy(File::Spec->catfile('css','orgstyle.css'), File::Spec->catfile($ghpages, 'stylesheets', 'orgstyle.css'));
  copy(File::Spec->catfile('css','orgtocstyle.css'), File::Spec->catfile($ghpages, 'stylesheets', 'orgtocstyle.css'));
  if (not is_older("todo.org", File::Spec->catfile($ghpages, 'todo.html'))) {
    #system(q{emacs --batch --eval="(require 'org)" -f org-html-export-to-html todo.org});
    system('org2html -y todo.org');
    move('todo.html', File::Spec->catfile($ghpages, 'todo.html'));
  };
  if (not is_older("Changes.org", File::Spec->catfile($ghpages, 'Changes.html'))) {
    system('org2html -y Changes.org');
    move('Changes.html', File::Spec->catfile($ghpages, 'Changes.html'));
  };
};


################################################################################
### Manage programming documentation

my $old_cpan = qr{http://search\.cpan\.org/perldoc\?};
my $new_cpan = q{https://metacpan.org/pod/};
sub ACTION_doctree {
  my $self = shift;
  my $LIB  = 'lib'; #File::Spec->catfile('..', '..', '..', 'lib');
  my $BIN  = 'bin'; #File::Spec->catfile('..', '..', '..', 'bin');
  my @list = (qw(denv dhephaestus datoms dfeff dfeffit rdfit dlsprj standards dathena dartemis));
  foreach my $d (@list) {
    copy(File::Spec->catfile($BIN, $d),        File::Spec->catfile($BIN, "$d.pl"));
  };
  my $pd = Pod::ProjectDocs->new(
				 outroot  => File::Spec->canonpath(File::Spec->catfile($ghpages, 'pods')),
				 libroot  => [$LIB, $BIN],
				 forcegen => 1,
				 title    => 'Demeter',
				 desc     => "Perl tools for X-ray Absorption Spectroscopy",
				 except   => [qr(Savitzky), qr(ToolTemplate), qr(XDI), qr(PCA_new), qr(Larch_inline)],
				);
  $pd->gen();
  foreach my $d (@list) {
    unlink File::Spec->catfile($BIN, "$d.pl");
  };

  find({wanted=>\&fix_cpan_link}, File::Spec->canonpath(File::Spec->catfile($ghpages, 'pods')));
  my $n = File::Spec->catfile('..', 'demeter-gh-pages', 'pods', 'index.html');
  slurp_replace($n, $old_cpan, $new_cpan);
};
sub fix_cpan_link {		# change all search.cpan.org links to equivalent link to metacpan.org
  return if $_ !~ m{\.html\z};
  my $n    = File::Spec->canonpath(File::Spec->catfile(cwd, basename($File::Find::name)));
  slurp_replace($n, $old_cpan, $new_cpan);
};
sub slurp_replace {
  my ($file, $oldtext, $newtext) = @_;
  my $text = read_text($file);
  $text    =~ s{$oldtext}{$newtext}g;
  write_text($file, $text);
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


################################################################################
### Manage versioning

sub ACTION_bump {
  my $self = shift;
  (my $v = $self->dist_version) =~ s{\Av}{}; # strip letter v from beginning of version number
  my $ret = $self->do_system(qw(perl-reversion -bump), "--current=$v");
  map {chmod 0775, File::Spec->catfile('bin', $_)} (qw(dartemis datoms denv dfeffit dlsprj
						       dathena denergy dfeff dhephaestus
						       intrp rdfit standards));
  print "
perl-reversion misses version numbers in
	Build.PL

Don't forget to push and tag!
"


};
sub ACTION_bump_dryrun {
  my $self = shift;
  (my $v = $self->dist_version) =~ s{\Av}{}; # strip letter v from beginning of version number
  #print $v, $/;
  my $ret = $self->do_system(qw(perl-reversion -bump), "--current=$v", '-dryrun');
};

######################################################################
## tools

sub _slurp {
  my ($file) = @_;
  local $/;
  return q{} if (not -e $file);
  return q{} if (not -r $file);
  open(my $FH, $file);
  my $text = <$FH>;
  close $FH;
  return $text;
};

sub is_older {
  my ($file1, $file2) = @_;
  return 1 if not -e $file1;
  return 0 if not -e $file2;
  return (stat($file1))[9] < (stat($file2))[9]
};

## redefine (and suppress the warning about doing so) the methods used
## to generate the bat files.  this adds code for redirecting STDOUT
## and STDERR to a log file in %APPDATA%\demeter and for verifying
## that %APPDATA%\demeter actually exists

package Module::Build::Platform::Windows;

{
  use Config;
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


  # This routine was copied almost verbatim from the 'pl2bat' utility
  # distributed with perl. It requires too much voodoo with shell quoting
  # differences and shortcomings between the various flavors of Windows
  # to reliably shell out
  sub pl2bat {
    my $self = shift;
    my %opts = @_;

    # NOTE: %0 is already enclosed in doublequotes by cmd.exe, as appropriate
    $opts{ntargs}    = '-x -S %0 %*' unless exists $opts{ntargs};
    $opts{otherargs} = '-x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9' unless exists $opts{otherargs};

    $opts{stripsuffix} = '/\\.plx?/' unless exists $opts{stripsuffix};
    $opts{stripsuffix} = ($opts{stripsuffix} =~ m{^/([^/]*[^/\$]|)\$?/?$} ? $1 : "\Q$opts{stripsuffix}\E");

    unless (exists $opts{out}) {
      $opts{out} = $opts{in};
      $opts{out} =~ s/$opts{stripsuffix}$//oi;
      $opts{out} .= '.bat' unless $opts{in} =~ /\.bat$/i or $opts{in} =~ /^-$/;
    }

    ## %~dp0 will give the drive and path to the bat file being run
    ## if the bat file is C:\strawberry\perl\site\bin\dathena.bat
    ## %~dp0 = C:\strawberry\perl\site\bin\
    ## DEMETER_BASE will, therefore, be C:\strawberry
    ## presumably, all the bat files are in C:\strawberry\perl\site\bin\, so
    ##   trimming \perl\site\bin\ (which is what the following line does)
    ##   is ok
    ## then set a minimal path for running Demeter
    my $head = <<EOT;
    \@rem = '--*-Perl-*--
    \@echo off
    SET DOTDIR="%APPDATA%\\demeter"
    IF NOT EXIST %DOTDIR% MD %DOTDIR%
    SET DEMETER_BASE=%~dp0
    SET DEMETER_BASE=%DEMETER_BASE:\\perl\\site\\bin\\=%
    SET IFEFFIT_DIR=%DEMETER_BASE%\\c\\share\\ifeffit\\
    SET PATH=C:\\Windows\\system32;C:\\Windows;C:\\Windows\\System32\\Wbem;%DEMETER_BASE%\\c\\bin;%DEMETER_BASE%\\perl\\site\\bin;%DEMETER_BASE%\\perl\\bin;%DEMETER_BASE%\\c\\bin\\gnuplot\\bin
    if "%OS%" == "Windows_NT" goto WinNT
    perl $opts{otherargs}
    goto endofperl
    :WinNT
    perl $opts{ntargs}
    if NOT "%COMSPEC%" == "%SystemRoot%\\system32\\cmd.exe" goto endofperl
    if %errorlevel% == 9009 echo You do not have Perl in your PATH.
    if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
    goto endofperl
    \@rem ';
EOT

    $head =~ s/^\s+//gm;
    my $headlines = 2 + ($head =~ tr/\n/\n/);
    my $tail = "\n__END__\n:endofperl\n";

    my $linedone  = 0;
    my $taildone  = 0;
    my $linenum   = 0;
    my $skiplines = 0;

    my $start = $Config{startperl};
    $start = "#!perl" unless $start =~ /^#!.*perl/;

    my $in = IO::File->new("< $opts{in}") or die "Can't open $opts{in}: $!";
    my @file = <$in>;
    $in->close;

    foreach my $line ( @file ) {
      $linenum++;
      if ( $line =~ /^:endofperl\b/ ) {
	if (!exists $opts{update}) {
	  warn "$opts{in} has already been converted to a batch file!\n";
	  return;
	}
	$taildone++;
      }
      if ( not $linedone and $line =~ /^#!.*perl/ ) {
	if (exists $opts{update}) {
	  $skiplines = $linenum - 1;
	  $line .= "#line ".(1+$headlines)."\n";
	} else {
	  $line .= "#line ".($linenum+$headlines)."\n";
	}
	$linedone++;
      }
      if ( $line =~ /^#\s*line\b/ and $linenum == 2 + $skiplines ) {
	$line = "";
      }
    }

    my $out = IO::File->new("> $opts{out}") or die "Can't open $opts{out}: $!";
    print $out $head;
    print $out $start, ( $opts{usewarnings} ? " -w" : "" ),
      "\n#line ", ($headlines+1), "\n" unless $linedone;
    print $out @file[$skiplines..$#file];
    print $out $tail unless $taildone;
    $out->close;

    return $opts{out};
  }

}

1;
