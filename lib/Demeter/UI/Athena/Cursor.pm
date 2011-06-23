package Demeter::UI::Athena::Cursor;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use Wx qw( :everything );
use Wx::DND;
use base qw( Exporter );
our @EXPORT = qw(cursor);


# my %map = (
# 	   bkg_e0    => 'E0',
# 	   bkg_rbkg  => 'Rbkg',
# 	   bkg_pre1  => 'lower bound of pre-edge range',
# 	   bkg_pre2  => 'upper bound of pre-edge range',
# 	   bkg_nor1  => 'lower bound of normalization range',
# 	   bkg_nor2  => 'upper bound of normalization range',
# 	   bkg_spl1  => 'lower bound of spline range',
# 	   bkg_spl2  => 'upper bound of spline range',
# 	   bkg_spl1e => 'lower bound of spline range',
# 	   bkg_spl2e => 'upper bound of spline range',
# 	   fft_kmin  => 'lower bound of forward Fourier transform range',
# 	   fft_kmax  => 'upper bound of forward Fourier transform range',
# 	   bft_rmin  => 'lower bound of backward Fourier transform range',
# 	   bft_rmax  => 'upper bound of backward Fourier transform range',
# 	  );

sub cursor {
  my ($app) = @_;
  my ($ok, $x, $y) = (1, -100000, -100000);

  my $busy;
  if ($app->current_data->mo->template_plot eq 'pgplot') {
    $app->{main}->status("Click on a point to pluck its value...", "wait");
    $app->current_data->dispose("cursor(crosshair=true)");
    ($x, $y) = (Ifeffit::get_scalar("cursor_x"), Ifeffit::get_scalar("cursor_y"));

  } elsif ($app->current_data->mo->template_plot eq 'gnuplot') {
    my $yesno = Wx::MessageDialog
      -> new($app->{main},
	     "Double click in the Gnuplot window to pluck a point.  Click ok when ready.",
	     "Pluck a point",
	     wxOK|wxICON_EXCLAMATION|wxSTAY_ON_TOP)
	-> ShowModal;

    my $tdo;
    if (wxTheClipboard->Open) {
      $tdo = Wx::TextDataObject->new;
      wxTheClipboard->GetData( $tdo );
      wxTheClipboard->Close;
    };
    ($x, $y) = split(/,\s+/, $tdo->GetText);

      # if (wxTheClipboard->Open) {
      # $app->{main}->status("Double click on a point to pluck its value...", "wait");
      # $busy = Wx::BusyCursor->new();
      # my $tdo = Wx::TextDataObject->new;
      # $tdo->SetText(q{});
      # wxTheClipboard->GetData( $tdo );
      # wxTheClipboard->Close;
      # my $top_of_clipboard = $tdo->GetText;
      # my $new = $top_of_clipboard;
      # while ($new eq $top_of_clipboard) {
      # 	wxTheClipboard->Open if not wxTheClipboard->IsOpened;
      # 	next if not wxTheClipboard->IsSupport(wxDF_TEXT);
      # 	wxTheClipboard->GetData( $tdo );
      # 	wxTheClipboard->Close;
      # 	$new = $tdo->GetText;
      # 	sleep 0.5;
      # };
      # ($x, $y) = split(/,\s+/, $new);
      # };

  } else {
    $app->{main}->status("Unknown plotting backend.  Pluck canceled.");
    $ok = 0;

  };

  undef $busy;
  return (0, -100000, -100000) if ((not looks_like_number($x)) and (not looks_like_number($y)));
  return (0, $x, -100000) if not looks_like_number($y);
  return (0, -100000, $y) if not looks_like_number($x);
  return ($ok, $x, $y);
};

1;
