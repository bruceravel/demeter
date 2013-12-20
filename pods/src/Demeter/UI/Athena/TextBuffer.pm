package Demeter::UI::Athena::TextBuffer;

use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(EVT_CHAR);
use base qw( Exporter );
our @EXPORT = qw(set_text_buffer OnTextBufferChar update_text_buffer);

sub set_text_buffer {
  my ($app, $dialog, $name) = @_;
  my $tc;
  foreach my $w ($dialog->GetChildren) {
    if (ref($w) =~ m{TextCtrl}) {
      $tc = $w;
      last;
    };
  };
  EVT_CHAR($tc, sub{ $app->OnTextBufferChar($dialog, $name, @_) });
};

sub OnTextBufferChar {
  my ($app, $dialog, $name, $textctrl, $event) = @_;
  my $bname = join("_", $name, "buffer");
  my $pname = join("_", $name, "pointer");
  my $code = $event->GetKeyCode;
  my $skip = 1;
  my @buffer = @{$app->{$bname}};
  if (($code == WXK_UP) and (@buffer)) {
    $textctrl->SetValue(q{});
    --$app->{$pname};
    $app->{$pname} = 0 if ($app->{$pname} < 0);
    $textctrl->SetValue($buffer[$app->{$pname}]);
    $textctrl->SetInsertionPointEnd;
    $skip = 0;
  } elsif ($code == WXK_DOWN) {
    $textctrl->SetValue(q{});
    ++$app->{$pname};
    if ($app->{$pname} > $#buffer) {
      $app->{$pname} = $#buffer+1;
      $textctrl -> SetValue(q{});
    } else {
      $textctrl -> SetValue($buffer[$app->{$pname}]);
    };
    $textctrl->SetInsertionPointEnd;
    $skip = 0;
  };
  $event  -> Skip($skip);
  return;
};

sub update_text_buffer {
  my ($app, $name, $value, $pos) = @_;
  my $bname = join("_", $name, "buffer");
  my $pname = join("_", $name, "pointer");
  push @{$app->{$bname}}, $value;
  $app->{$pname} = $#{$app->{$bname}} + $pos;
};

1;


=head1 NAME

Demeter::UI::Wx::TextBuffer - Manage a text buffers for a TextEntryDialog

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

In the main application:

  use Demeter::UI::Wx::TextBuffer;
  $app->{some_buffer}  = [];
  $app->{some_pointer} = -1;

Later:

  my $ted = Wx::TextEntryDialog->new($app->{main}, "Enter a string:", "Get a string",
                                     q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  $app->set_text_buffer($ted, "some");
  if ($ted->ShowModal == wxID_CANCEL) {
    $app->{main}->status("Renaming canceled.");
    return;
  };
  my $string = $ted->GetValue;
  $app->update_text_buffer("some", $string, 0);

The methods C<set_text_buffer> and C<update_text_buffer> are exported
by this module.

The third argument is 0 if you generate a default value for the text
string and 1 if you want the string blank.

=head1 DESCRIPTION

This provides some functionality for Athena and Artemis for
maintaining text buffers such that up and down arrows can be used to
recover the text strings from prior uses of a TextEntryDialog.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
