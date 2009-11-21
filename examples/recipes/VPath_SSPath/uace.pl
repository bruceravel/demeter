#!/usr/bin/perl

## strict and warnings imported automatically with Demeter
use Demeter qw(:plotwith=gnuplot :ui=screen);

unlink("controlfit.iff") if (-e "controlfit.iff");

my $prj = Demeter::Data::Prj -> new(file=>'U.prj');
my $data = $prj -> record(1);
$data -> set_mode(screen  => 0, ifeffit => 1); #, file => ">controlfit.iff");

$data -> set(name       => 'U control',
             fft_kmin   => 3.0,    fft_kmax  => 10.5,
             bft_rmin   => 1,      bft_rmax  => 3.3, #4.22,
             fit_space  => 'r',
             fit_k1     => 1,      fit_k2    => 1,    fit_k3    => 1,
             fit_do_bkg => 0,
            );

my @gds = (
           $data->simpleGDS("guess amp   = 1"),
           $data->simpleGDS("guess enot  = 0"),
           $data->simpleGDS("guess drax  = 0"),
           $data->simpleGDS("guess dreq  = 0"),
           $data->simpleGDS("guess drc   = 0"),
           $data->simpleGDS("guess ssax  = 0.003"),
           $data->simpleGDS("guess sseq  = 0.003"),
           $data->simpleGDS("guess ssc   = 0.003"),
           $data->simpleGDS("guess drhyd = 0"),
           $data->simpleGDS("guess sshyd = 0.003"),
          );

my $atoms = Demeter::Atoms->new(file=>"uranyl_acetate.inp");
mkdir 'UAce';
open(my $inp, '>UAce/uace.inp');
print $inp $atoms->Write('feff');
close $inp;

my $feff = Demeter::Feff->new(file=>"UAce/uace.inp");
$feff -> set(workspace=>"UAce", screen=>0, buffer=>q{}, save=>1);
$feff -> potph -> pathfinder;
my @list_of_paths = @{ $feff->pathlist };
my @paths = ();
my $carbon  = Demeter::VPath->new(name=>"carbon SS + MS");
my $axialms = Demeter::VPath->new(name=>"axial MS");
my $index = 0;
my @common = (parent => $feff, data => $data, s02 => "amp", e0 => "enot");

## axial oxygen
my $this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "axial oxygens",
         delr   => "drax",      sigma2 => "ssax",
        );
push @paths, $this_path;

## equatorial oxygen
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "equatorial oxygens",
         delr   => "dreq",      sigma2 => "sseq",
        );
push @paths, $this_path;

## carbon
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "C",
         delr   => "drc",       sigma2 => "ssc",
        );
push @paths, $this_path;
$carbon->include($this_path);

## C-O triangle
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "C-O triangle",
         delr   => "(dreq+drc)/2",   sigma2 => "2*(sseq+ssc)/3",
        );
push @paths, $this_path;
$carbon->include($this_path);

## axial oxygen rattle MS path
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "axial MS rattle",
         delr   => "drax*2",   sigma2 => "ssax*4",
        );
push @paths, $this_path;
$axialms->include($this_path);

## axial oxygen non-forward scattering MS path
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "axial MS non-forward linear",
         delr   => "drax*2",   sigma2 => "ssax*2",
        );
push @paths, $this_path;
$axialms->include($this_path);

## axial oxygen forward scattering through absorber MS path
$this_path = Demeter::Path -> new()
  -> set(@common, sp => $list_of_paths[$index++],
         name   => "axial MS forward linear",
         delr   => "drax*2",   sigma2 => "ssax*2",
        );
push @paths, $this_path;
$axialms->include($this_path);


## make up a scatterer to act as the hydration sphere
my $ss = Demeter::SSPath -> new(@common,
                                name   => "hydration sphere",
                                ipot   => 3,
                                reff   => 3.35,

                                delr   => 'drhyd',
                                sigma2 => 'sshyd',
                               );
push @paths, $ss;


my $fit = Demeter::Fit->new(gds   => \@gds,
                            data  => [$data],
                            paths => \@paths, );
$fit -> fit;
##$fit -> logfile("controlfit.log", "U control", q{});

##$data->save_many("many.out", 'chik3', $paths[0], $paths[1], $carbon);

$data -> po -> set(kweight=>2, rmax=>6, r_pl=>'r', plot_fit=>1);
my ($step, $jump) = (0,-0.3);
map {$_->data->y_offset($step);
     $_->plot('r');
     $step+=$jump;
   } ($data, $paths[0], $paths[1], $carbon, $axialms, $ss);

$data->pause;
