package Demeter::UI::Athena::Prefs;

use Demeter::UI::Wx::Config;

use Wx qw( :everything );
use base 'Wx::Panel';

use vars qw($label);
$label = "Preferences";

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;

  my $config = Demeter::UI::Wx::Config->new($this, \&target);
  $config->populate([qw(athena bft bkg clamp convolution fft fit gnuplot indicator
			interpolation marker operations plot rebin xanes)]);
  $box->Add($config, 1, wxGROW|wxALL, 5);

  $this->SetSizerAndFit($box);
  return $this;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($param eq 'plotwith') and do {
      $Demeter::UI::Athena::demeter->plot_with($value);
      last SWITCH;
    };
  };

#  ($save)
#    ? $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param and an ini file was saved")
#      : $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param");

};

1;
