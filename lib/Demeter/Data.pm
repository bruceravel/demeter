package Demeter::Data;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .transmission
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Carp;

use File::Basename;
use List::MoreUtils qw(any);
use Regexp::Common;
use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
Readonly my $PI       => 4*atan2(1,1);
Readonly my $NULLFILE => '@&^^null^^&@';
use YAML::Tiny;

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
with 'Demeter::Data::Athena';
with 'Demeter::Data::Defaults';
with 'Demeter::Data::E0';
with 'Demeter::Data::FT';
with 'Demeter::Data::IO';
with 'Demeter::Data::Mu';
with 'Demeter::Data::Parts';
with 'Demeter::Data::Plot';
with 'Demeter::Data::Process';
with 'Demeter::Data::SelfAbsorption';
with 'Demeter::Data::Units';

use MooseX::Aliases;
#use MooseX::AlwaysCoerce;   # this might be useful....
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Element
			  Edge
			  Clamp
			  FitSpace
			  Window
			  Empty
			  DataType
		       );
use Demeter::NumTypes qw( Natural
			  PosInt
			  PosNum
			  NonNeg
		       );

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');


## To do: triggers for keeping min/max pairs in the right order, respecting the complicated configuration rules

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::Data');
has 'is_mc'       => (is => 'ro', isa => 'Bool', default => 0); # is not Demeter::Data::MultiChannel
has 'tag'         => (is => 'rw', isa => 'Str',  default => q{});
has 'cv'          => (is => 'rw', isa => 'Num',  default => 0);
has 'file'        => (is => 'rw', isa => 'Str',  default => $NULLFILE,
		      trigger => sub{my ($self, $new) = @_;
				     if ($new and ($new ne $NULLFILE)) {
				       $self->update_data(1);
				       $self->source($new);
				     };
				   });
has 'source'      => (is => 'rw', isa => 'Str',  default => $NULLFILE,);
has 'prjrecord'   => (is => 'rw', isa => 'Str',  default => q{});
has 'from_athena' => (is => 'rw', isa => 'Bool', default => 0);
subtype 'FitSum'
      => as 'Str'
      => where { lc($_) =~ m{\A(?:\s*|fit|sum)\z} }
      => message { "This is either a fit or a sum." };
has 'fitsum'      => (is => 'rw', isa => 'FitSum', default => q{});
has 'fitting'     => (is => 'rw', isa => 'Bool',   default => 0);
has 'plotkey'     => (is => 'rw', isa => 'Str',    default => q{});
has 'frozen'      => (is => 'rw', isa => 'Bool',   default => 0);

has 'provenance'  => (is => 'rw', isa => 'Str',    default => q{});
has 'importance'  => (is => 'rw', isa => 'Num',    default => 1);
has 'merge_weight'=> (is => 'rw', isa => 'Num',    default => 1);


has 'tying' => (is=>'rw', isa => 'Bool', default => 0);
has 'reference'   => (is => 'rw', isa => Empty.'|Demeter::Data', default => q{},
		      trigger => sub{ my ($self, $new) = @_;
				      $self->tie_reference($new) if not $self->tying;
				      $self->tying(0);
				      $self->referencegroup($new->group) if (ref($new) =~ m{Demeter});
				    },
		     );
has 'referencegroup' => (is => 'rw', isa => 'Str',     default => q{});

# subtype 'DemeterInt',
#   => as 'Int'
#   => where { }
#   => message { "This group is frozen." };
# has 'foo' => (is=>'rw', isa => 'DemeterInt', default => 0);

## -------- column selection attributes
has  $_  => (is => 'rw', isa => 'Str',  default => q{},
	     trigger => sub{ my ($self, $new) = @_;
			     if ($new) {
			       $self->datatype('xmu');
			       $self->update_columns(1);
			       $self->is_col(1)
			     }
			   })
  foreach (qw(energy numerator));
has  denominator  => (is => 'rw', isa => 'Str',  default => q{1},
		      trigger => sub{ my ($self, $new) = @_;
				      if ($new and $self->numerator) {
					$self->datatype('xmu');
					$self->update_columns(1);
					$self->is_col(1)
				      }
				    });
has  $_ => (is => 'rw', isa => 'Num',  default => 0) foreach (qw(i0_scale signal_scale));

has  $_  => (is => 'rw', isa => 'Str',  default => q{})
  foreach (qw(columns energy_string xmu_string i0_string signal_string));
has 'ln' => (is => 'rw', isa => 'Bool', default => 0,
	     trigger => sub{ my ($self, $new) = @_; $self->update_columns(1), $self->is_col(1) if $new});
has 'display' => (is => 'rw', isa => 'Bool', default => 0,);

## -------- data type flags
has 'datatype' => (is => 'rw', isa => Empty.'|'.DataType, default => q{},
		   trigger => sub{shift->explain_recordtype},
		  );
has  $_  => (is => 'rw', isa => 'Bool',  default => 0, trigger => sub{shift->explain_recordtype},)
  foreach (qw(is_col is_nor is_kev is_special));
has 'is_merge' => (is => 'rw', isa => 'Str',  default => q{});
#foreach (qw(is_col is_xmu is_xmudat is_chi is_nor is_xanes is_merge));

has 'generated'  => (is => 'rw', isa => 'Bool',  default => 0,
		    trigger => sub{ my ($self, $new) = @_;
				    $self->update_data(0);
				    $self->update_columns(0);
				    $self->is_col(0);
				    $self->columns(q{});
				    $self->energy(q{});
				    $self->numerator(q{});
				    $self->denominator(q{});
				    $self->ln(0);
				    $self->energy_string(q{});
				    $self->xmu_string(q{});
				    $self->signal_string(q{});
				    $self->i0_string(q{});
				    $self->file(q{});
				  });
has 'rebinned'  => (is => 'rw', isa => 'Bool',  default => 0,);

## -------- stuff for about dialog
has 'recordtype'       => (is => 'rw', isa => 'Str',  default => q{});
has 'plotspaces'       => (is => 'rw', isa => 'Str',  default => q{any});
has 'npts'             => (is => 'rw', isa => 'Int',  default => 0);
has 'xmax'             => (is => 'rw', isa => 'Num',  default => 0);
has 'xmin'             => (is => 'rw', isa => 'Num',  default => 0);
has 'epsk'             => (is => 'rw', isa => 'Num',  default => 0);
has 'epsr'             => (is => 'rw', isa => 'Num',  default => 0);
has 'recommended_kmax' => (is => 'rw', isa => 'Num',  default => 0);
has 'nknots'           => (is => 'rw', isa => 'Num',  default => 0);
has 'maxk'             => (is => 'rw', isa => 'Num',  default => 0);


## -------- data processing status flags
has 'update_data'    => (is => 'rw', isa => 'Bool',  default => 1,
			 trigger => sub{ my($self, $new) = @_; $self->update_columns(1) if $new});

has 'update_columns' => (is => 'rw', isa => 'Bool',  default => 1,
			 trigger => sub{ my($self, $new) = @_; $self->update_norm(1) if $new});

has 'update_norm'    => (is => 'rw', isa => 'Bool',  default => 1,
			 trigger => sub{ my($self, $new) = @_; $self->update_bkg(1) if $new});

has 'update_bkg'     => (is => 'rw', isa => 'Bool',  default => 1,
			 trigger => sub{ my($self, $new) = @_; $self->update_fft(1) if $new});

has 'update_fft'     => (is => 'rw', isa => 'Bool',  default => 1,
			 trigger => sub{ my($self, $new) = @_; $self->update_bft(1) if $new});

has 'update_bft'     => (is => 'rw', isa => 'Bool',  default => 1);

has 'nidp'           => (is => 'rw', isa => 'Num', default => 0);

## -------- background removal parameters
has 'bkg_algorithm'   => (is => 'rw', isa => 'Str',   default => 'autobk',);
has 'bkg_e0'          => (is => 'rw', isa => 'Num',   default => 0,
			  trigger => sub{ my($self) = @_; $self->update_bkg(1), $self->update_norm(1) });

has 'bkg_e0_fraction' => (is => 'rw', isa =>  PosNum, default => sub{ shift->co->default("bkg", "e0_fraction") || 0.5},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->update_norm(1) });

has 'bkg_eshift'      => (is => 'rw', isa => 'Num',   default => 0,
			  alias => 'eshift',
			  trigger => sub{ my($self) = @_; 
					  $self->update_bkg(1);
					  $self->update_norm(1);
					  $self->shift_reference if not $self->tying;
					  $self->tying(0); # prevent deep recursion
					});

has 'bkg_kw'          => (is => 'rw', isa =>  NonNeg, default => sub{ shift->co->default("bkg", "kw")          || 1},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has 'bkg_rbkg'        => (is => 'rw', isa =>  PosNum, default => sub{ shift->co->default("bkg", "rbkg")        || 1},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->set_nknots; });

has 'bkg_dk'          => (is => 'rw', isa =>  NonNeg, default => sub{ shift->co->default("bkg", "dk")          || 1},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has 'bkg_pre1'        => (is => 'rw', isa => 'Num',   default => sub{ shift->co->default("bkg", "pre1")        || -150},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->update_norm(1) });

has 'bkg_pre2'        => (is => 'rw', isa => 'Num',   default => sub{ shift->co->default("bkg", "pre2")        || -30},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->update_norm(1) });

has 'bkg_nor1'        => (is => 'rw', isa => 'Num',   default => sub{ shift->co->default("bkg", "nor1")        || 150},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->update_norm(1) });

has 'bkg_nor2'        => (is => 'rw', isa => 'Num',   default => sub{ shift->co->default("bkg", "nor2")        || 400},
			  trigger => sub{ my($self) = @_; $self->update_bkg(1); $self->update_norm(1) });

## these need a trigger
has 'bkg_spl1'        => (is => 'rw', isa => 'Num',
			  trigger => sub{ my($self) = @_;
					  $self->update_bkg(1);
					  $self->spline_range("spl1") if not $self->tying;
					  $self->tying(0);
					},
			  default => sub{ shift->co->default("bkg", "spl1")        || 0});
has 'bkg_spl2'        => (is => 'rw', isa => 'Num',
			  trigger => sub{ my($self) = @_;
					  $self->update_bkg(1);
					  $self->spline_range("spl2") if not $self->tying;
					  $self->tying(0);
					},
			  default => sub{ shift->co->default("bkg", "spl2")        || 0});
has 'bkg_spl1e'       => (is => 'rw', isa => 'Num',
			  trigger => sub{ my($self) = @_;
					  $self->update_bkg(1);
					  $self->spline_range("spl1e") if not $self->tying;
					  $self->tying(0);
					},
			  default => 0);
has 'bkg_spl2e'       => (is => 'rw', isa => 'Num',
			  trigger => sub{ my($self) = @_;
					  $self->update_bkg(1);
					  $self->spline_range("spl2e") if not $self->tying;
					  $self->tying(0);
					},
			  default => 0);

has 'bkg_kwindow' => (is => 'rw', isa =>  Window,   default => sub{ shift->co->default("bkg", "kwindow")     || 'kaiser-bessel'},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has $_ => (is => 'rw', isa => 'Num',  default => 0) foreach (qw(bkg_slope bkg_int bkg_step bkg_fitted_step bkg_nc0 bkg_nc1 bkg_nc2 bkg_former_e0));

has $_ => (is => 'rw', isa => 'Bool', default => 0) foreach (qw(bkg_fixstep bkg_tie_e0 bkg_cl));

has 'bkg_z'       => (is => 'rw', isa =>  Element,  default => 'H');

has 'bkg_stan'    => (is => 'rw', isa => 'Str',     default => 'None',
		      trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has 'bkg_flatten' => (is => 'rw', isa => 'Bool',    default => sub{ shift->co->default("bkg", "flatten") || 1},
		      trigger => sub{ my($self) = @_; $self->update_norm(1) });

has 'bkg_fnorm'	  => (is => 'rw', isa => 'Bool',    default => sub{ shift->co->default("bkg", "fnorm")   || 0},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1), $self->update_norm(1) });

has 'bkg_nnorm'	  => (is => 'rw', isa =>  PosInt,   default => sub{ shift->co->default("bkg", "nnorm")   || 3},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1), $self->update_norm(1) });

has 'bkg_clamp1'  => (is => 'rw', isa =>  Natural,  default => sub{ shift->co->default("bkg", "clamp1")  || 0},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has 'bkg_clamp2'  => (is => 'rw', isa =>  Natural,  default => sub{ shift->co->default("bkg", "clamp2")  || 24},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1) });

has 'bkg_nclamp'  => (is => 'rw', isa =>  PosInt,   default => sub{ shift->co->default("bkg", "nclamp")  || 5},
		      trigger => sub{ my($self) = @_; $self->update_bkg(1) });

## -------- foreward Fourier transform parameters
has 'fft_edge'    => (is => 'rw', isa =>  Edge,    default => 'K', coerce => 1);

has 'fft_kmin'    => (is => 'rw', isa => 'Num',
		      trigger => sub{ my($self) = @_; $self->update_fft(1); $self->_nidp},
		      default => sub{ shift->co->default("fft", "kmin")     ||  3});

has 'fft_kmax'    => (is => 'rw', isa => 'Num',
		      trigger => sub{ my($self) = @_; $self->update_fft(1); $self->_nidp},
		      default => sub{ shift->co->default("fft", "kmax")     || -2});

has 'fft_dk'      => (is => 'rw', isa =>  NonNeg,  default => sub{ shift->co->default("fft", "dk")       ||  2},
		      trigger => sub{ my($self) = @_; $self->update_fft(1)});

has 'fft_kwindow' => (is => 'rw', isa =>  Window,  default => sub{ shift->co->default("fft", "kwindow")  || 'hanning'},
		      trigger => sub{ my($self) = @_; $self->update_fft(1)});

has 'fft_pc'      => (is => 'rw', isa => 'Any',   default => sub{ shift->co->default("fft", "pc")       ||  0},
		      trigger => sub{ my($self) = @_; $self->update_fft(1)});
has 'fft_pctype'  => (is => 'rw', isa => 'Str',   default => "central", # "path"
		      trigger => sub{ my($self) = @_; $self->update_fft(1)});
has 'fft_pcpath'  => (is => 'rw', isa => 'Any', # isa => Empty.'|Demeter::Path',
		      default => q{},
		      trigger => sub{ my($self, $new) = @_; $self->update_fft(1); $self->fft_pcpathgroup($new->group) if $new;});
has 'fft_pcpathgroup' => (is => 'rw', isa => 'Str', default => q{},);

has 'rmax_out'    => (is => 'rw', isa =>  PosNum,  default => sub{ shift->co->default("fft", "rmax_out") ||  10},
		      trigger => sub{ my($self) = @_; $self->update_fft(1)});

## -------- backward Fourier transform parameters
has 'bft_rwindow' => (is => 'rw', isa =>  Window,  default => sub{ shift->co->default("bft", "rwindow")  || 'hanning'},
		      trigger => sub{ my($self) = @_; $self->update_bft(1)});

has 'bft_rmin'    => (is => 'rw', isa =>  NonNeg,
		      trigger => sub{ my($self) = @_; $self->update_bft(1); $self->_nidp},
		      default => sub{ shift->co->default("bft", "rmin")     ||  1});

has 'bft_rmax'    => (is => 'rw', isa =>  PosNum,
		      trigger => sub{ my($self) = @_; $self->update_bft(1); $self->_nidp},
		      default => sub{ shift->co->default("bft", "rmax")     ||  3});

has 'bft_dr'      => (is => 'rw', isa =>  NonNeg,    default => sub{ shift->co->default("bft", "dr")       ||  0.2},
		      trigger => sub{ my($self) = @_; $self->update_bft(1)});


## -------- fitting parameters
has 'fit_k1'		  => (is => 'rw', isa => 'Bool',     default => sub{ shift->co->default("fit", "k1")         ||  1});
has 'fit_k2'		  => (is => 'rw', isa => 'Bool',     default => sub{ shift->co->default("fit", "k2")         ||  1});
has 'fit_k3'		  => (is => 'rw', isa => 'Bool',     default => sub{ shift->co->default("fit", "k3")         ||  1});
has 'fit_karb'		  => (is => 'rw', isa => 'Bool',     default => sub{ shift->co->default("fit", "karb")       ||  0});
has 'fit_karb_value'	  => (is => 'rw', isa =>  NonNeg,    default => sub{ shift->co->default("fit", "karb_value") ||  0});
has 'fit_space'	          => (is => 'rw', isa =>  FitSpace,  default => sub{ shift->co->default("fit", "space")      || 'r'}, coerce => 1);
has 'fit_epsilon'	  => (is => 'rw', isa => 'Num',      default => 0);
has 'fit_cormin'	  => (is => 'rw', isa =>  PosNum,    default => sub{ shift->co->default("fit", "cormin")     ||  0.4});
has 'fit_include'	  => (is => 'rw', isa => 'Bool',     default => 1);
has 'fit_data'	          => (is => 'rw', isa =>  Natural,   default => 0);
has 'fit_plot_after_fit'  => (is => 'rw', isa => 'Bool',     default => 0);
has 'fit_do_bkg'          => (is => 'rw', isa => 'Bool',     default => 0);
has 'titles'	          => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });

## -------- plotting parameters
has 'y_offset'	          => (is => 'rw', isa => 'Num',      default => 0);
has 'plot_multiplier'	  => (is => 'rw', isa => 'Num',      default => 1);


sub BUILD {
  my ($self, @params) = @_;
  $self->data($self); # I do not know of a way to set the data attribute to this instance using "has"....
  $self->tag($self->group);
  if (ref($self) =~ m{Data\z}) {
    $self->mo->push_Data($self);
    my $thiscv = $self->mo->datacount;
    $self->cv($thiscv);
    ++$thiscv;
    $self->mo->datacount($thiscv);
  };
};

sub DEMOLISH {
  my ($self) = @_;
  ##$self->dispose("erase \@group ".$self->group);
  $self->alldone;
};

sub discard {
  my ($self) = @_;
  $self->dispose("erase \@group " . $self->group);
  $self->DEMOLISH;
};


override alldone => sub {
  my ($self) = @_;
  if ($self->reference) {
    my $ref = $self->reference;
    $ref->reference(q{});
    $self->reference(q{});
  };
  $self->remove;
  return $self;
};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{fft_pcpath};
  delete $all{is_mc};
  return %all;
};


override clone => sub {
  my ($self, @arguments) = @_;
  $self->_update('background');
  $self->_update('fft') if ($self->datatype =~ m{(?:xmu|chi)});
  my $new = $self->SUPER::clone();

  $new  -> standard;
  $self -> dispose($self->template("process", "clone"));
  $new  -> unset_standard;
  $new  -> update_data(0);
  $new  -> update_columns(0);
  $new  -> update_norm($self->datatype =~ m{(?:xmu|xanes)});
  $new  -> update_fft($self->datatype =~ m{(?:xmu|chi)});

  my ($old_group, $new_group) = ($self->group, $new->group);
  foreach my $att (qw(energy_string i0_string signal_string xmu_string)) {
    my $newval = $self->$att;
    $newval =~ s{$old_group}{$new_group}g;
    $new->$att($newval);
  };

  ## data from Athena
  if ((ref($self) =~ m{Data}) and $self->from_athena) {
    $new -> data($new);
    $new -> provenance("cloned");

  ## mu(E) data from a file
  } elsif (ref($self) =~ m{Data}) {
    $new -> data($new);
    $new -> provenance("cloned");

  };

  $new->set(@arguments);
  my $newtag = $new->cv || $new->group;
  $new->tag( $newtag );
  return $new;
};

sub about {
  my ($self) = @_;
  $self->_update('bft');
  my $string = $self->template("process", "about");
  return $string;
};

sub _nidp {
  my $self = shift;
  $self->nidp( 2*($self->fft_kmax - $self->fft_kmin)*($self->bft_rmax - $self->bft_rmin)/$PI );
}
sub chi_noise {
  my ($self) = @_;
  my $string = $self->template("process", "chi_noise");
  $self->dispose($string);
  $self->epsk( sprintf("%.3e", Ifeffit::get_scalar("epsilon_k")) );
  $self->epsr( sprintf("%.3e", Ifeffit::get_scalar("epsilon_r")) );
  $self->recommended_kmax( sprintf("%.3f", Ifeffit::get_scalar("kmax_suggest")) );
  return $self;
};

sub _kw_string {
  my ($self) = @_;
  my @list = ();
  push @list, "1" if $self->fit_k1;
  push @list, "2" if $self->fit_k2;
  push @list, "3" if $self->fit_k3;
  push @list, $self->fit_karb_value if $self->fit_karb;
  return join(",", @list);
};


sub standard {
  my ($self) = @_;
  $self->mode->standard($self);
  return $self;
};
sub unset_standard {
  my ($self) = @_;
  $self->mode->standard(q{});
  return $self;
};

sub set_windows {
  my ($self, $window) = @_;
  $window = lc($window);
  return 0 if not is_Window($window);
  $self->bkg_kwindow($window);
  $self->fft_kwindow($window);
  $self->bft_rwindow($window);
  return $self;
};

## test for athena project file
sub determine_data_type {
  my ($self) = @_;
  my $file = $self->file;
  return 0 if ($file eq $NULLFILE);
  return 0 if is_Empty($file);
  ## figure out how to interpret these data -- need some error checking
  if ((not $self->is_col) and ($self->datatype ne "xmu") and ($self->datatype ne "chi") ) {
    $self->dispose("read_data(file=\"$file\", group=deter___mine)\n");
    my $f = (split(" ", Ifeffit::get_string('$column_label')))[0];
    my @x = Ifeffit::get_array("deter___mine.$f");
    $self->dispose("erase \@group deter___mine\n");
    if ($x[0] > 100) {		# seems to be energy data
      $self->datatype('xmu');
      $self->update_columns(0);
      $self->update_norm(1);
    } elsif (($x[0] > 3) and ($x[-1] < 35)) {	# seems to be relative energy data
      $self->datatype('xmu');
      $self->is_kev(1);
      $self->update_columns(0);
      $self->update_norm(1);
    } else {			# it's chi(k) data
      $self->datatype('chi');
      $self->update_columns(0);
      $self->update_norm(0);
      $self->update_bkg(0);
    };
  };
  return $self;
};


sub _update {
  my ($self, $which) = @_;
  $which = lc($which);

 WHICH: {
    ($which eq 'data') and do {
      $self->read_data if ($self->update_data);
      last WHICH;
    };
    ($which eq 'normalize') and do {
      $self->read_data if ($self->update_data);
      $self->put_data  if ($self->update_columns);
      last WHICH;
    };
    ($self->display) and do {	# bail if the display flag is set
      return $self;		# this effectively disables most Data object
    };				# functionality while doing column selection.
    ($self->is_mc) and do {	# bail if this is a Data::MultiChannel object
      return $self;		# this effectively disables most Data object
    };				# functionality for D:MC.
    ($which eq 'background') and do {
      $self->read_data if ($self->update_data);
      $self->put_data  if ($self->update_columns);
      $self->normalize if ($self->update_norm and ($self->datatype =~ m{xmu|xanes}));
      last WHICH;
    };
    ($which eq 'fft') and do {
      $self->read_data if ($self->update_data);
      $self->put_data  if ($self->update_columns);
      $self->normalize if ($self->update_norm and ($self->datatype =~ m{(?:xmu|xanes)}));
      $self->autobk    if ($self->update_bkg  and ($self->datatype =~ m{xmu}));
      $self->fft_pcpath->_update('fft') if $self->fft_pcpath;
      last WHICH;
    };
    ($which eq 'bft') and do {
      $self->read_data if ($self->update_data);
      $self->put_data  if ($self->update_columns);
      $self->normalize if ($self->update_norm and ($self->datatype =~ m{xmu|xanes}));
      $self->autobk    if ($self->update_bkg  and ($self->datatype =~ m{xmu}));
      $self->fft       if ($self->update_fft  and ($self->datatype =~ m{xmu|chi}));
      last WHICH;
    };
    ($which eq 'all') and do {
      $self->read_data if ($self->update_data);
      $self->put_data  if ($self->update_columns);
      $self->normalize if ($self->update_norm and ($self->datatype =~ m{xmu|xanes}));
      $self->autobk    if ($self->update_bkg  and ($self->datatype =~ m{xmu}));
      $self->fft       if ($self->update_fft  and ($self->datatype =~ m{xmu|chi}));
      $self->bft       if ($self->update_bft  and ($self->datatype =~ m{xmu|chi}));
      last WHICH;
    };

 };
  return $self;
};


sub read_data {
  my ($self) = @_;
  my $return = $self->readable($self->file);
  croak($return) if $return;
  my $type = ($self->is_col) ? q{}
           :  $self->datatype;
  if ((not $self->is_col) and (not $type)) {
    $self->determine_data_type;
    $type = $self->datatype;
  };
  my $string = $self->_read_data_command($type);
  $self->dispose($string);
  $self->update_data(0);
  if ($self->is_col) {
    $self->columns(Ifeffit::get_string("column_label"));
  };
  $self->sort_data;
  $self->put_data;
  return $self if $self->is_mc; # bail if this is a Data::MultiChannel object
  my $array = ($type eq 'xmu') ? 'energy'
            : ($type eq 'chi') ? 'k'
	    :                    'energy';
  my @x = $self->get_array($array); # set things for about dialog
  $self->npts($#x+1);
  $self->xmin($x[0]);
  $self->xmax($x[$#x]);
  my $filename = fileparse($self->file, qr{\.dat}, qr{\.xmu}, qr{\.chi});
  $self->name($filename) if not $self->name;
  return $self;
};

sub explain_recordtype {
  my ($self) = @_;
  my $string = ($self->datatype eq 'xmu')        ? 'mu(E)'
             : ($self->datatype eq 'xanes')      ? 'xanes(E)'
             : ($self->datatype eq 'chi')        ? 'chi(k)'
             : ($self->datatype eq 'xmudat')     ? 'Feff mu(E)'
             : ($self->datatype eq 'background') ? 'background'
             : ($self->datatype eq 'detector')   ? 'detector'
	     :                                     'unknown';
  $string = 'normalized ' . $string if $self->is_nor;
  $string = 'merged '     . $string if $self->is_merge;
  $self->recordtype($string);

  $string = ($self->datatype eq 'xmu')        ? 'any'
          : ($self->datatype eq 'xanes')      ? 'energy'
          : ($self->datatype eq 'chi')        ? 'k, R, or q'
          : ($self->datatype eq 'xmudat')     ? 'any'
          : ($self->datatype eq 'background') ? 'any'
          : ($self->datatype eq 'detector')   ? 'energy'
	  :                                     'any';
  $self->plotspaces($string);

  return $self;
};

sub sort_data {
  my ($self) = @_;
  my @x = ();
  if ($self->is_col) {

    ## This block is a complicated bit.  The idea is to store all
    ## the data in a list of lists.  In this way, I can sort all the
    ## data in one swoop by sorting off the energy part of the list
    ## of lists.  After sorting, I check the data for repeated
    ## points and remove them.  Finally, I reload the data into
    ## ifeffit and carry on like normal data

    ## This gets a list of column labels
    my @cols = split(" ", $self->columns);
    my @lol;
    ## energy value is zeroth in each anon list
    unshift @cols, q{};
    my $ecol = $self->energy || '$1';
    $ecol =~ s{^\$}{};
    my @array = $self->get_array($cols[$ecol]);
    # print join(" ", @array), $/, $/;
    foreach (0 .. $#array) {push @{$lol[$_]}, $array[$_]};
    foreach my $c (@cols) {
      next unless $c;
      ## load other cols (including energy col) into anon. lists
      my @this_array = $self->get_array($c);
      foreach (0 .. $#this_array) {push @{$lol[$_]}, $this_array[$_]};
    };
    ## sort the anon. lists by energy (i.e. zeroth element)
    @lol = sort {$a->[0] <=> $b->[0]} @lol;

    ## now fish thru lol looking for repeated energy points
    my $ii = 0;
    while ($ii < $#lol) {
      ($lol[$ii+1]->[0] > $lol[$ii]->[0]) ? ++$ii : splice(@lol, $ii+1, 1);
    };

    ## now feed columns back to ifeffit
    my $group = $self->group;
    $self->dispose("##| replacing arrays for $group with sorted versions\nerase \@group $group"); #.$cols[$c]");
    foreach my $c (1 .. $#cols) {
      my @array;
      foreach (@lol) {push @array, $_->[$c]};
      Ifeffit::put_array("$group.$cols[$c]", \@array);
    };
    # @array = $self->get_array($cols[$ecol]);
    # print join(" ", @array), $/, $/, $/;
  };
  return $self;
};
sub _read_data_command {
  my ($self, $type) = @_;
  my $string = q[];
  if ($type eq 'xmu') {
    $string  = $self->template("process", "read_xmu");
    $string .= $self->template("process", "deriv");
    $self->provenance("mu(E) file ".$self->file);
  } elsif ($type eq 'chi') {
    $string  = $self->template("process", "read_chi");
    $self->provenance("chi(k) file ".$self->file);
  } elsif ($type eq 'feff.dat') {
    $string  = $self->template("process", "read_feffdat");
  } else {
    $string  = $self->template("process", "read");
    $self->provenance("column data file ".$self->file);
  };
  return $string;
};



sub rfactor {
  my ($self) = @_;
  my (@x, @dr, @di, @fr, @fi, $xmin, $xmax);
  if (lc($self->fit_space) eq 'k') {
    ($xmin,$xmax) = $self->get(qw(fft_kmin fft_kmax));
    @x  = $self -> get_array("k");
    @di = $self -> get_array("chi");
    @fr = $self -> get_array("chi", "fit");
  } elsif (lc($self->fit_space) eq 'r') {
    ($xmin,$xmax) = $self->get(qw(bft_rmin bft_rmax));
    @x  = $self -> get_array("r");
    @dr = $self -> get_array("chir_re");
    @di = $self -> get_array("chir_im");
    @fr = $self -> get_array("chir_re", "fit");
    @fi = $self -> get_array("chir_im", "fit");
  } elsif (lc($self->fit_space) eq 'q') {
    ($xmin,$xmax) = $self->get(qw(fft_kmin fft_kmax));
    @x  = $self -> get_array("q");
    @dr = $self -> get_array("chiq_re");
    @di = $self -> get_array("chiq_im");
    @fr = $self -> get_array("chiq_re", "fit");
    @fi = $self -> get_array("chiq_im", "fit");
  };
  my ($numerator, $denominator) = (0,0);
  foreach my $i (0 .. $#x) {
    next if ($x[$i] < $xmin);
    last if ($x[$i] > $xmax);
    $numerator   += ($dr[$i] - $fr[$i])**2;
    $denominator +=  $dr[$i]           **2;
    if (lc($self->fit_space) ne 'k') {
      $numerator   += ($di[$i] - $fi[$i])**2;
      $denominator +=  $di[$i]           **2;
    };
  };
  return ($denominator) ? $numerator/$denominator : 0;
};


sub prep_peakfit {
  my ($self, $xmin, $xmax) = @_;
  $self->_update('background');
  return ($self->bkg_e0+$xmin, $self->bkg_e0+$xmax);
};

## this appends the actual data to the base class serialization
override 'serialization' => sub {
  my ($self) = @_;
  my $string = $self->SUPER::serialization;
  if ($self->datatype =~ m{(?:xmu|xanes)}) {
    $string .= YAML::Tiny::Dump($self->ref_array("energy"));
    $string .= YAML::Tiny::Dump($self->ref_array("xmu"));
    if ($self->is_col) {
      $string .= YAML::Tiny::Dump($self->ref_array("i0"));
    }
  } elsif ($self->datatype eq "chi") {
    $string .= YAML::Tiny::Dump($self->get_array("k"));
    $string .= YAML::Tiny::Dump($self->get_array("chi"));
  };
  return $string;
};

#   ## standard deviation array?

override 'deserialize' => sub {
  my ($self, $fname) = @_;
  my @stuff = YAML::Tiny::LoadFile($fname);

  ## load the attributes
  my %args = %{ $stuff[0] };
  delete $args{plottable};
  delete $args{pathtype};
  delete $args{fit_pcpath};	# correct an early
  delete $args{fit_do_pcpath};	# design mistake...
  my @args = %args;
  $self -> set(@args);
  $self -> group($self->_get_group);
  $self -> update_data(0);
  $self -> update_columns(0);
  $self -> update_norm(1);

  my $path = $self -> mo -> fetch('Path', $self->fft_pcpathgroup);
  $self -> fft_pcpath($path);

  my @x  = @{ $stuff[1] };
  my @y  = @{ $stuff[2] };
  my @i0 = @{ $stuff[3] };

  if ($self->datatype =~ m{(?:xmu|xanes)}) {
    Ifeffit::put_array($self->group.".energy",    \@x);
    Ifeffit::put_array($self->group.".xmu", \@y);
    if ($self->is_col) {
      Ifeffit::put_array($self->group.".i0",   \@i0);
    };
  } elsif ($self->datatype eq 'chi') {
    Ifeffit::put_array($self->group.".k",      \@x);
    Ifeffit::put_array($self->group.".chi",    \@y);
  };

  return $self;
};
alias thaw => 'deserialize';

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Data - Process and analyze EXAFS data with Ifeffit


=head1 VERSION

This documentation refers to Demeter version 0.4.


=head1 SYNOPSIS

  use Demeter;
  my $data = Demeter::Data -> new;
  $data -> set(file      => "example/cu/cu10k.chi",
	       name      => 'My copper data',
	       fft_kmin  => 3,	       fft_kmax  => 14,
	       bft_rmin  => 1,         bft_rmax  => 4.3,
	       fit_k1    => 1,	       fit_k3    => 1,
	      );
  $data -> plot("r");

=head1 DESCRIPTION

This subclass of the L<Demeter> class is inteded to hold information
pertaining to data for use in data processing and analysis.

=head1 ATTRIBUTES

The following are the attributes of the Data object.  Attempting to
access an attribute not on this list will throw an exception.

The type of argument expected in given in parentheses. i.e. number,
integer, string, and so on.  The default value, if one exists, is
given in square brackets.

For a Data object to be included in a fit, it is necessary that it be
gathered into a Fit object.  See L<Demeter::Fit> for details.

=head2 General Attributes

=over 4

=item C<group> (string) I<[random 5-letter string]>

This is the name associated with the data.  It's primary use is as the
group name for the arrays associated with the data in Ifeffit.  That
is, its arrays will be called I<group>.k, I<group>.chi, and so on.  It
is best if this is a reasonably short word and it B<must> follow the
conventions of a valid group name in Ifeffit.  The default group is a
random five-letter string generated automatically when the object is
created.

=item C<tag> (string) I<[same random 5-letter string as group]>

Use to disambiguate guess parameter names when doing variable name
substitution for local parameters.

=item C<file> (filename)

This is the file containing the chi(k) associated with this Data
object.  It will be an empty string if the data comes from an Athena
project file or is generated by Demeter.

=item C<prjrecord> (project filename and record number)

This is the Athena project file from which the data associated with
this Data object.  It will be an empty string if the data comes from a
normal file or is generated by Demeter.  The format of this string is
the project file name and the record number separated by a comma:

  print $data->prjrecord, $/;
   ==prints==>
     whatever.prj, 5

This will be set automatically by the Data::Prj C<record> method.
Setting it by hand I<does not> trigger a reading of the record.  So,
you should pretend that this is a read-only attribute.

=item C<provenance> (string)

This is a short string explaining where the data object came from,
e.g. from a column data file or an Athena project file.

=item C<name> (string)

This is a text string used to describe this object in a plot ot a user
interface.  Like the C<group> attribute, this should be short, but it
can be a bit more verbose.  It should be a single line, unlike the
C<title> attibute.

=item C<plotkey> (string)

This is a text string used as a temporary override to the name of Data
object for use in a plot.  It should be reset to an empty string as
soon as the plot requiring the name override is finished.

=item C<cv> (number)

The characteristic value is a number associated with the data object.
The cv is used to generate guess parameteres from lguess parameters
and is used as the substitution value in math expressions containing
the string C<[cv]>.  The default value is a number that is incremented
as Data objects are created.

=item C<datatype> (string)

This identifies the record type.  It is one of

  xmu chi xmudat xanes

Earlier versions of Demeter had attributes like C<is_xmu> and
C<is_chi>.  Those are now obsolete and there use will return an error
about being unknown attributes.

=item C<is_col> (boolean)

This is true if the file indicated by the C<file> attribute contains
column data that needs to be converted into mu(E) data.  See the
description of the C<read_data> method for how this gets set
automatically and when you may need to set it by hand.

=item C<is_col> (string)

This is an empty string by default.  When a merge group is made, its
string value is set to themanner in which the merge was made, which is
one of C<e> for mu(E), C<n> for norm(E>, and C<k> for chi(k).

=item C<columns> (string)

This string contains Ifeffit's C<$column_label> string from importing
the data file.

=item C<energy> (string)

This string uses gnuplot-like notation to indicate which column in the
data file contains the energy axis.  As an example, the default is that the
first column contains the energy and this string is C<$1>.

=item C<numerator> (string)

This string uses gnuplot-like notation to indicate how to convert
columns from the data file into the numerator of the expression for
computing mu(E).  For example, the default is that these are
transmission data and I0 is in the 2nd column and the default for
this string is C<$2>.

If these are fluorescence data measured with a multichannel analyzer
and the MCA channels are in columns 7 - 10, then this string would be
C<$7+$8+$9+$10>.

=item C<denominator> (string)

This string uses gnuplot-like notation to indicate how to convert
columns from the data file into the denominator of the expression for
computing mu(E).  For example, the default is that these are
transmission data and transmission is in the 3nd column and the
default for this string is C<$3>.

=item C<ln> (boolean)

This is true for transmission data, i.e. if conversion from columns to
mu(E) requires that the natural log be taken.  In fact, the natural
log of the absolute value of the ratio of the numerator and
denominator is computed to avoid numerical error in certain situations.

=item C<ln> (boolean)

This flag severely restricts data processing to just what is necessary
to make a plot of unnormalized mu(E).  It is for use in a GUI's column
selection dialog so that swift plot updates can be made while columns
are being selected.

=item C<display> (boolean)

This is a flag used by a GUI while selecting columns.  It severely
limits the amount of data processing done so that the display updates
quickly in the GUI.  This should be set back to 0 B<as soon as
possible> so t hat subsequent data processing proceeds properly.

=back

=head2 Background Removal Attributes

=over 4

=item C<bkg_e0> (number)

The E0 value of mu(E) data.  This is determined from the data when the
read_data method is called.

=item C<bkg_e0_fraction> (number) I<[0.5]>

This is a number between 0 and 1 used for the e0 algorithm which sets
e0 to a fraction of the edge step.  See L<Demeter::Data::E0>.

=item C<bkg_eshift> (number) I<[0]>

An energy shift to apply to the data before doing any further processing.

=item C<bkg_kw> (number) I<[1]>

The k-weight to use during the background removal using the Autobk algorithm.

=item C<bkg_rbkg> (number) I<[1]>

The Rbkg value in the Autobk algorithm.

=item C<bkg_dk> (number) I<[0]>

The dk value to be used in the Fourier transform as part of the Autobk
algorithm.

=item C<bkg_pre1> (number) I<[-150]>

The lower end of the range of the pre-edge regression, relative to E0.

=item C<bkg_pre2> (number) I<[-30]>

The upper end of the range of the pre-edge regression, relative to E0.

=item C<bkg_nor1> (number) I<[100]>

The lower end of the range of the post-edge regression, relative to E0.

=item C<bkg_nor2> (number) I<[600]>

The upper end of the range of the post-edge regression, relative to E0.

=item C<bkg_spl1> (number) I<[0]>

The lower end in k of the spline range in the Autobk algorithm.  The value of
bkg_spl1e is updated whenever this is updated.

=item C<bkg_spl2> (number) I<[15]>

The upper end in k of the spline range in the Autobk algorithm.  The value of
bkg_spl2e is updated whenever this is updated.

=item C<bkg_spl1e> (number) I<[0]>

The lower end in energy of the spline range in the Autobk algorithm,
relative to E0.  The value of bkg_spl1 is updated whenever this is
updated.

=item C<bkg_spl2e> (number) I<[857]>

The upper end in energy of the spline range in the Autobk algorithm,
relative to E0.  The value of bkg_spl2 is updated whenever this is
updated.

=item C<bkg_kwindow> (list) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the Autobk algorithm.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<bkg_slope> (number)

The slope of the pre-edge line.  This is set as part of the
C<normalize> method.

=item C<bkg_int> (number)

The intercept of the pre-edge line.  This is set as part of the
C<normalize> method.

=item C<bkg_step> (number)

The edge step found by the C<normalize> method.  This attribute will
be overwritten the next time the C<normalize> method is called unless
the C<bkg_fixstep> atribute is set true.

=item C<bkg_fitted_step> (number)

The value of edge step found by the C<normalize> method, regardless of
the setting of C<bkg_fixstep>.  This is needed to correctly flatten
data.

=item C<bkg_fixstep> (boolean) I<[0]>

When true, the value of the c<bkg>_step will not be overwritten by the
c<normalize> method.

=item C<bkg_nc0> (number)

The constant parameter in the post-edge regression.  This is set as part of
the c<normalize> method.

=item C<bkg_nc1> (number)

The linear parameter in the post-edge regression.  This is set as part of
the C<normalize> method.

=item C<bkg_nc2> (number)

The cubic parameter in the post-edge regression.  This is set as part of
the C<normalize> method.

=item C<bkg_flatten> (boolean) I<[1]>

When true, a plot of normalized mu(E) data will be flattened.

=item C<bkg_fnorm> (boolean) I<[0]>

When true, a functional normalization is performed.  I<not yet implemented>

=item C<bkg_nnorm> (integer) I<[3]>

This can be either 2 or 3 and specifies the order of the post-edge regression.
When this is 2, C<bkg_nc2> will be forced to 0 in the regression.  I<not yet
implemented>

=item C<bkg_stan> (Data or Path object)

The background removal standard.  This can be either a Data object or a Path
object.  I<not yet implemented>

=item C<bkg_clamp1> (integer) I<[0]>

The value of the low-end spline clamp.

=item C<bkg_clamp2> (integer) I<[24]>

The value of the high-end spline clamp.

=item C<bkg_nclamp> (integer) I<[5]>

The number of data points to use in evaluating the clamp.

=item C<bkg_cl> (boolean) I<[0]>

When true, use Cromer-Liberman normalization rather than the Autobk algorithm.
I<not yet implemented>

=item C<bkg_z> (number)

The Z number of the absorber for these data.  This is determined as part of
the normalize method but can also be set by hand.  To deal with edge energy
confusions, certain K and L3 edges are prefered over nearby L2 and L3 edges
when this attribute is set automatically.

       prefer     over
      ----------------
       Fe K       Nd L1
       Mn K       Ce L1
       Bi K       Ir L1
       Se K       Tl L2
       Pt L3      W  L2
       Se K       Pb L2
       Np L3      At L1
       Cr K       Ba L1

There is a configuration parameter to turn this behavor on and off.

=back

=head2 Forward Transform Attributes

Note that there is not an C<fft_kw> attribute.  For all plotting and
data processing purposes, the Plot object's C<kweight> attribute is
used, while in fits the Fit object's k-weighting attributes are used.

=over 4

=item C<fft_edge> (edge symbol) I<[K]>

The absorption edge measured by the input data.  This is used doing a
central-atom-only phase correction to the Fourier transform.

=item C<fft_kmin> (number) I<[2]>

The lower end of the k-range for the forward transform.  C<fft_kmin> and
C<fft_kmax> will be sorted by Demeter.

=item C<fft_kmax> (number) I<[12]>

The upper end of the k-range for the forward transform.  C<fft_kmin> and
C<fft_kmax> will be sorted by Demeter.

=item C<fft_dk> (number) I<[2]>

The width of the window sill used for the forward transform.  The meaning of
this parameter depends on the functional form of the window.  See the Ifeffit
document for a full discussion of the functional forms.

=item C<fft_kwindow> (list) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the forward transform.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<fft_pc> (Path object) I<[0]>

This is set to the Path object to be used for a full phase correction to the
Fourier transform.

=item C<rmax_out> (number) I<[10]>

This tells Ifeffit how to size output arrays after doing a Fourier transform.

=back

=head2 Back Transform Attributes

=over 4

=item C<bft_rwindow> (number) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the backward transform.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<bft_rmin> (number) I<[1]>

The lower end of the R-range for the backward transform or the fitting range.
C<bft_rmin> and C<bft_rmax> will be sorted by Demeter.

=item C<bft_rmax> (number) I<[3]>

The upper end of the R-range for the backward transform or the fitting range.
C<bft_rmin> and C<bft_rmax> will be sorted by Demeter.

=item C<bft_dr> (number) I<[0.2]>

The width of the window sill used for the backward transform.  The meaning of
this parameter depends on the functional form of the window.  See the Ifeffit
document for a full discussion of the functional forms.

=back

=head2 Fitting Attributes

Note that parameters with C<fft_> and C<bft_> analogs such as
C<fft_kmin> have been deprecated along with the C<process> mode.

=over 4

=item C<fitting> (boolean) I<[0]>

This is set to true when a Data object is used in a fit.  It is used by
plotting methods to determine whether data parts (fit, background, residual)
should be considered for plotting.

=item C<fit_k1> (boolean) I<[1]>

If true, then k-weight of 1 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.  By default, fits are done with kweight of 1, 2, and 3.

=item C<fit_k2> (boolean) I<[1]>

If true, then k-weight of 2 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.  By default, fits are done with kweight of 1, 2, and 3.

=item C<fit_k3> (boolean) I<[1]>

If true, then k-weight of 3 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.  By default, fits are done with kweight of 1, 2, and 3.

=item C<fit_karb> (boolean) I<[0]>

If true, then the user-supplied, arbitrary k-weight will be used in
the fit.  Setting more than one k-weighting parameter to true will
result in a multiple k-weight fit.  By default, fits are done with
kweight of 1, 2, and 3.

=item C<fit_karb_value> (number) I<[0]>

This is the value of the arbitrary k-weight which will be used in the
fit is C<fit_karb> is true.

=item C<fit_space> (list) I<[R]>

This is the space in which the fit will be evaluated.  It is one of
C<k>, C<r>, or C<q>.

=item C<fit_epsilon> (number) I<[0]>

If this number is non-zero, it will be used as the measurement
uncertainty in k-space when the fit is evaluated.  If it is zero, then
Ifeffit's default will be used.

=item C<fit_cormin> (number) I<[0.4]>

This is the minimum value of correlation to be reported in the log
file after a fit.

=item C<fit_pcpath> (Path object)

This is the Path object to use for phase correction when these data
and it paths are plotted.  It takes the reference to the Path object
as its value.

=item C<fit_include> (boolean) I<[1]>

When this is true, the data will be included in the next fit.

=item C<fit_plot_after_fit> (boolean) I<[0]>

This is a flag for use by a user interface to indicate that after a
fit is finished, this data set should be plotted.

=item C<fit_do_bkg> (boolean) I<[0]>

When true, the background function will be corefined for this data set
and the "bkg" part of the data will be created.

=item C<fit_titles> (multiline string)

These are title lines associated with this Data object.  These lines
will be written to log files, output data files, etc.

=item C<fitsum> (list)

This attribute indicates whether the Fit objects C<fit> or C<ff2chi>
mehthod was most recently called.  It is one of C<fit> or C<sum>.
It's purpose is to allow the fit part of the data object to be labeled
correctly in a plot.

=back

=head2 Plotting Attributes

Most aspects of how plots are made are handled by the attributes of
the Plot object.  These Data attributes are specific to a particular
Data object and influence how that object is plotted.

=over 4

=item C<y_offset> (number) I<[0]>

The vertical displacement given to this data when plotted.  This is
useful for making stacked plots.

=item C<plot_multiplier> (number) I<[1]>

An over-all scaling factor for this data when plotted.  It is probably
a bad idea for this to be 0.

=back

=head1 METHODS

This subclass inherits from Demeter, so all of the methods of the
parent class are available.

See L<Demeter/Object_handling_methods> for a discussion of accessor
methods.

=head2 I/O methods

These methods handle the details of file I/O.  See also the C<save>
method of the parent class.

=over 4

=item C<save>

This method returns the Ifeffit commands necessary to write column
data files based on the data object.  See C<Demeter::Data::IO> for
details.

=item C<data_parameter_report>

This method returns a simple, textual summary of the attributes of the data
object related to background removal and data processing.  It is used in log
files, output data files, and elsewhere.  It may also be useful as a way of
interactively describing the data.

=item C<fit_parameter_report>

This method returns a simple, textual summary of the attributes of the
data object related to the fit.  It is used in log files, output data
files, and elsewhere.  It may also be useful as a way of interactively
describing the data.  The two optional arguments control whether the
r-factor is computed as part of the report.

=item C<r_factor>

This returns an evaluation of the R-factor from a fit for a single
data set.  This is different from the R-factor for a multiple data set
fit as reported by Ifeffit in that this number includes only the
misfit of the single data set.

  $r = $data_object -> r_factor;

=item C<nidp>

This returns the number of independent points associated with this
data set, as determined from the values of the k- and R-range
parameters.

   $n = $data_object -> nidp;

The Athena-like fft and bft ranges are used if the processing mode is
set to "fft".  The Artemis-like fit ranges are used if the processing
mode is set to "fit".

=item C<plot>

Use this method to make plots of data.  Demeter keeps track of changes
to parameters and which data processing steps need to be taken in
order to correctly make the plot.  Consequently, it should never be
necessary to import data or perform a Fourier tansform by hand.  The
practice with Demeter is to create a Data group, set some of its
attributes, and then make a plot.

  $data_object -> plot($space)

The argument is one of C<E>, C<k>, C<R>, C<q>, or C<kq>.  The details
of the plot are determine by the current state of the
L<Demeter::Plot> object.

=back

=head2 Convenience methods

=over 4

=item C<set_windows>

This is a shortcut to setting the functional form of all Fourier
transform windows used by the Data object.  In one swoop, this method
sets C<bkg_kwindow>, C<fit_kwindow>, C<fit_rwindow>, C<fft_kwindow>,
and C<bft_rwindow> to the specified window type.

  $data_object -> set_windows("Hanning");

The window type must be one of C<Kaiser-Bessel>, C<Hanning>,
C<Parzen>, C<Welch>, C<Sine>, or C<Gaussian>.

=item C<data>

This method returns the reference to the data object itself.  This is
less silly than it seems.  Having a C<data> method defined for both
Data and Path objects allows a loop over both kinds of objects and
provides a simple way to identify the correct Data object.

  foreach my $obj (@data_objects, @paths_objects) {
     my $d = $obj->data;
     ## do something with $d
  };

=back

=head1 DATA FILES AND DATA PARTS


When data are imported, Demeter tries to figure out whether the data
are raw data, mu(E) or chi(k) data, if that has not been specified.
The heuristics are as follows:

=over 4

=item *

If the C<numerator> or C<denominator> attributes are set, this is data
is assumed to be column data that will be interpreted as raw data and
converted to mu(E) data.

=item *

The data will be read by Ifeffit.  If the first data point is greater
than 100, it will be assumed that these data are mu(E) and that the
energy axis is absolute energy.

=item *

If the last data point is greater than 35, it will be assumed that
these data are mu(E) and that the energy axis is relative energy.

=item *

If none of the above are true, then the data must be chi(k) data.

=back

If your data will be misintepreted by these heuristics, then you
B<must> set the C<data_type> attribute by hand.

The Data object has several parts associated with it.  Before a fit
(or summation) is done, there are two parts: the data itself and the
window.  After the fit, there is a residual, a fit, and (if the
C<fit_do_bkg> attribute is true) a background.  Attributes of the
L<Demeter::Plot> object are used to specify which Data parts
are shown in a plot.

=head1 DIAGNOSTICS

These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).

=over 4

=item C<"$key" is not a valid Demeter::Data parameter>

(W) You have attempted to access an attribute that does not exist.  Check
the spelling of the attribute at the point where you called the accessor.

=item C<Demeter::Data: "group" is not a valid group name>

(F) You have used a group name that does not follow Ifeffit's rules for group
names.  The group name must start with a letter.  After that only letters,
numbers, &, ?, _, and : are acceptable characters.  The group name must be no
longer than 64 characters.

=item C<Demeter::Data: "$key" takes a number as an argument>

(F) You have attempted to set a numerical attribute with something
that cannot be interpretted as a number.


=item C<Demeter::Data: $k must be a number>

(F) You have attempted to set an attribute that requires a numerical
value to something that cannot be interpreted as a number.

=item C<Demeter::Data: $k must be a positive integer>

(F) You have attempted to set an attribute that requires a positive
integer value to something that cannot be interpreted as such.

=item C<Demeter::Data: $k must be a window function>

(F) You have set a Fourier transform window attribute to something not
recognized as a window function.

=item C<Demeter::Data: $r_hash->{$k} is not a readable data file>

(F) You have set the C<file> attribute to something that cannot be
found on disk.

=item C<Demeter::Data: $k must be one of (k R q)>

(F) You have set a fitting space that is not one C<k>, C<R>, or C<q>.

=item C<Demeter::Data: $k must be one of (K L1 L2 L3)>

(F) You have attempted to set the C<fft_edge> attribute to something
that is not recognized as an edge symbol.

=item C<No filename specified for save>

(F) You have called the save method without supplying a filename
for the output file.

=item C<Valid save types are: xmu norm chi r q fit bkgsub>

(F) You have called the save method with an unknown output file type.

=item C<cannot save mu(E) file from chi(k) data>

=item C<cannot save norm(E) file from chi(k) data>

(F) You have attempted to write out data in energy for data that were
imported as chi(k).

=item C<No filename specified for serialize>

(F) You have not supplied a filename for your data serialization.

=item C<No filename or YAML stream specified for deserialize>

(F) You have not supplied a filename from which to deserialization
data.

=back


=head1 SERIALIZATION AND DESERIALIZATION

The serialization format of a data object is as a YAML file.  The YAML
serialization begins with a mapping of the Data object attributes.  This is
followed by sequences representing the data.  For mu(E) data, the sequences
are energy and xmu.  If the data was column data, the xmu sequence is followed
by a sequence representing the i0 array.  For chi(k) data, the mapping is
followed by sequences representing k and chi(k).

To serialize a Data object to a file:

  $data -> serialize($filename);

To import the serialized data and create a Data object to hold it:

  $data -> deserialize($filename);

As a convenience C<freeze> is a synonym for C<serialize> and C<thaw>
is a synonym for C<deserialize>.

Among the many attractive features of YAML as a serialization format is that
YAML is supported by lots of programming languages.  So Demeter serialization
can be imported easily into other analysis software.

In principle, the Athena project file is also a serialization
format. The YAML serialization is intended for use as part of a
fitting project.  An Athena project file is probably a more useful
user interaction format for data processing.

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.
Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Several features have not yet been implemented.

=over 4

=item *

Should there only be two items in a collection of tied references?
Consider importing MED channels -- it would be reasonable for each
channel and the reference to be a reference collection.

=item *

Only some of the Athena-like data process methods (alignment, merging,
and so on) have been implemented at this time.  None of the analysis
features of Athena (LCF, LR/PD, peak fitting) have been implemeneted.

=item *

Various background and normalization options: functional
normalization, normalization order, background removal standard,
Cromer-Liberman.

=item *

Tied reference channel

=item *

Standard deviation for merged data not written to serialization.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
