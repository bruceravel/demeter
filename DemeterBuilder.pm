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
use IPC::Open3;

## this eval is required so that the build scripts can be made even if
## F::C::R is not yet installed.  A "Build installdeps" is required to
## actually install F::C::R.  Once that is done, the build will
## proceed correctly.
eval "
use File::Copy::Recursive qw(dircopy);
use DocBuilder::Artemis;
use DocBuilder::Athena;
use Pod::ProjectDocs;
use File::Slurp::Tiny qw(read_file write_file);
";
#use File::Which;


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
	       artug      => 'C:\strawberry\c\perl\site\lib\Demeter\share',
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
  $self->SUPER::ACTION_build;
  $self->dispatch("copy_artug");
  $self->dispatch("copy_aug");
  $self->dispatch("post_build");
}

sub ACTION_ghpages {
  my $self = shift;
  $self->dispatch("build_dpg");
  $self->dispatch("build_artug");
  $self->dispatch("copy_artug_images");
  $self->dispatch("build_aug");
  $self->dispatch("copy_aug_images");
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
    print STDOUT "this is windows.  Using gnuplot with the wxt terminal.\n";
    return;
  };

  ## in the following system calls, I want to capture and NOT display STDERR
  ## from the call to gnuplot, instead relying upon the return value $?
  ## see http://perldoc.perl.org/perlfaq8.html#How-can-I-capture-STDERR-from-an-external-command%3f
  my $in = '';
  #my $gp = File::Which::where('gnuplot');
  my $pid = open3($in, ">&STDERR", \*PH, 'gnuplotxxx -d -e "set xrange [0:1]"');
  while( <PH> ) { }
  waitpid($pid, 0);
  if ($? != 0) {
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

  ## now test for terminal type
  my $term = 'x11';
  $in = '';
  $pid = open3($in, ">&STDERR", \*PH, 'gnuplot -d -e "set terminal wxt"');
  while( <PH> ) { }
  waitpid($pid, 0);
  if ($? == 0) {
    $term = 'wxt';
  };
  $in = '';
  $pid = open3($in, ">&STDERR", \*PH, 'gnuplot -d -e "set terminal qt"');
  while( <PH> ) { }
  waitpid($pid, 0);
  if ($? == 0) {
    $term = 'qt';
  };
  $text = _slurp(File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf.in'));
  $text =~ s{default=x11}{default=$term};
  open($FIXED, '>', File::Spec->catfile('lib', 'Demeter', 'configuration', 'gnuplot.demeter_conf'));
  print $FIXED $text;
  close $FIXED;

  print STDOUT "$term terminal.\n";
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

######
## need to manage moving images across for DPG and ARTUG
######
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





################################################################################
### Manage org-mode pages

sub ACTION_org2html {
  print "copying stylesheets\n";
  copy(File::Spec->catfile('css','orgstyle.css'), File::Spec->catfile($ghpages, 'stylesheets', 'orgstyle.css'));
  copy(File::Spec->catfile('css','orgtocstyle.css'), File::Spec->catfile($ghpages, 'stylesheets', 'orgtocstyle.css'));
  if (not is_older("todo.org", File::Spec->catfile($ghpages, 'todo.html'))) {
    #system(q{emacs --batch --eval="(require 'org)" -f org-html-export-to-html todo.org});
    system('emacs --batch --visit=todo.org --funcall org-html-export-as-html');
    move('todo.html', File::Spec->catfile($ghpages, 'todo.html'));
  };
  if (not is_older("Changes.org", File::Spec->catfile($ghpages, 'Changes.html'))) {
    system('emacs --batch --visit=Changes.org --funcall org-html-export-as-html');
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
  my $text = read_file($file);
  $text    =~ s{$oldtext}{$newtext}g;
  write_file($file, $text);
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
	bin/bugs.pod
	bin/contribute.pod
	bin/help.pod
	bin/installation.pod
	bin/nonroot.pod
	Build.PL
        lib/Demeter/UI/Hephaestus/data/hephaestus.pod

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

    my $head = <<EOT;
    \@rem = '--*-Perl-*--
    \@echo off
    SET DOTDIR="%APPDATA%\\demeter"
    IF NOT EXIST %DOTDIR% MD %DOTDIR%
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
