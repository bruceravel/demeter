package Demeter::UI::Wx::ConfigurationDialog;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


=head1 NAME

Demeter::UI::Wx::ConfigurationDialog - A Wx dialog with a checkbox for suppressing the dialog in the future

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This dialog presents an informational message (like a
Wx::MessageDialog),and presents the user with a checkbox for
suppressing the message in the future.  The intent is that the return
value of the dialog will be used to set a boolean configuration
parameter.

  use Demeter::UI::Wx::VerbDialog;
  my $dialog = Demeter::UI::Wx::VerbDialog->new($parent, -1,
                          "Warning, Will Robinson!,
                          "Warning!",
                          );

When shown, a window like this is displayed:

   +-----------------------------------------+
   |                Warning!                 |
   +-----------------------------------------+
   |  Warning, Will Robinson!                |
   | _______________________________________ |
   |                               +------+  |
   |  [ ] Do not show again        |  OK  |  |
   |                               +------+  |
   +-----------------------------------------+

The dialog returns the value of the checkbox, which can then be used
to set a boolean:

   my $value = $dialog -> ShowModal;
   Demeter -> co -> set_default($group, $parameter, $value);

=head1 DESCRIPTION

The arguments of the constructor are

=over 4

=item 1.

The parent widget

=item 2.

The ID

=item 3.

The text for the body of the dialog

=item 4.

The text for the title of the dialog

=item 5.

Optional verb for checkbox label.  Default is to say "Do not show
again".  "ask" might be a better choice if C<$message> is a question.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


use strict;
use warnings;
use Carp;
use Text::Wrap;
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::Dialog';


sub new {
  my ($class, $parent, $id, $message, $title, $verb) = @_;
  $verb ||= 'show';

  my $this = $class->SUPER::new($parent, $id, $title, wxDefaultPosition, wxDefaultSize,
				wxCLOSE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  local $Text::Wrap::columns = 60;

  my $info = Wx::Bitmap->new( wxTheApp->GetStdIcon( wxICON_INFORMATION ) );
  $hbox->Add(Wx::StaticBitmap->new($this, -1, $info, wxDefaultPosition, wxDefaultSize), 0, wxTOP|wxBOTTOM, 10);
  $hbox->Add(Wx::StaticText->new($this, -1, wrap(q{}, q{}, $message), wxDefaultPosition, [-1,-1]), 0, wxALL|wxGROW, 20);
  $vbox->Add($hbox, 0, wxALL|wxGROW, 2);

  $vbox->Add(Wx::StaticLine->new($this, -1, [-1,-1], [1,1], wxLI_HORIZONTAL), 0, wxALL|wxGROW, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $check = Wx::CheckBox -> new($this, -1, "Do not $verb again", wxDefaultPosition, wxDefaultSize);
  $hbox->Add($check, 0, wxALL, 2);

  $hbox->Add(1,1,1);

  my $button = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox->Add($button, 0, wxALL, 2);
  $button->SetFocus;
  EVT_BUTTON($this, $button, sub{OnButton(@_, $check->GetValue)});
  $vbox->Add($hbox, 0, wxALL|wxGROW, 2);

  $this->SetSizerAndFit($vbox);
  return $this;
};


sub OnButton {
  my ($this, $event, $value) = @_;
  $this->EndModal($value);
};

1;
