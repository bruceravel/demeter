#!/usr/bin/perl
package MyApp;
use base 'Wx::App';
use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON);
use Cwd;

$|=1;

sub OnInit {
  my $frame  = Wx::Frame ->  new(undef, -1, 'demo');
  my $box    = Wx::BoxSizer->new(wxVERTICAL);
  my $button = Wx::Button->new($frame, -1, "Open file");
  $box      -> Add($button, 0, wxALL, 5);
  EVT_BUTTON($frame, $button, \&doOpen);
  $frame    -> SetSizerAndFit($box);
  $frame    -> Show(1);
  1;
};

sub doOpen {
  my ($frame, $event) = @_;
  my $fd = Wx::FileDialog->new( $app->{main}, "Open file", cwd, q{},
				"All files|*.*|Data (*.dat)|*.dat",
				wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    print "Canceled\n";
    return;
  };
  print "Path     : ", $fd->GetPath, $/;
  print "Directory: ", $fd->GetDirectory, $/;
  print "Filename : ", $fd->GetFilename, $/;

};

package main;
use Wx qw(:everything);
my $app = MyApp->new->MainLoop;
