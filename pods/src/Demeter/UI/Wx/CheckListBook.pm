package Demeter::UI::Wx::CheckListBook;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

use Demeter::Constants qw($NUMBER);

use Wx qw( :everything );
use Wx::Event qw(EVT_LISTBOX EVT_LEFT_DOWN EVT_MIDDLE_DOWN EVT_RIGHT_DOWN EVT_CHECKLISTBOX
		 EVT_LEFT_DCLICK EVT_MOUSEWHEEL);

use base 'Wx::SplitterWindow';

use vars qw(@initial_page_callback);
@initial_page_callback = (sub{ print "callback 1\n" },
			  sub{ print "callback 2\n" },
			 );

## height, width, ratio
sub new {
  my ($class, $parent, $id, $position, $size, $initial) = @_;
  #print join(" ", $parent, $id, $position, $size), $/;
  $position = Wx::Size->new(@$position) if (ref($position) !~ m{Point});
  $size = Wx::Size->new(@$size) if (ref($size) !~ m{Size});
  my $self = $class->SUPER::new($parent, $id, $position, $size, wxSP_NOBORDER );
  my ($w, $h) = ($size->GetWidth, $size->GetHeight);

  if (($w <= 0) or ($h <= 0)) {
    ($w = 520) if ($w <= 0);
    ($h = 300) if ($h <= 0);
    $self -> SetSize($w, $h);
  };

  #$self->{LEFT} = Wx::Panel->new( $self, -1, wxDefaultPosition, Wx::Size->new(int($w/4),$h) );
  #my $box = Wx::BoxSizer->new( wxVERTICAL );
  #$self->{LEFT} -> SetSizerAndFit($box);

  $self->{LIST} = Wx::CheckListBox->new($self, -1, wxDefaultPosition, Wx::Size->new(int($w/4),$h), [ ], wxLB_SINGLE);
  $self->{LIST}->{datalist} = []; # see modifications to CheckBookList at end of this file....
  $self->{LIST} -> SetFont( Wx::Font->new( 8, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{LIST}->{PARENT} = $self;
  EVT_LEFT_DOWN(   $self->{LIST},        sub{OnLeftDown(@_)}  );
  EVT_LEFT_DCLICK( $self->{LIST},        sub{OnLeftDclick(@_)});
  EVT_MIDDLE_DOWN( $self->{LIST},        sub{OnMiddleDown(@_)});
  EVT_RIGHT_DOWN(  $self->{LIST},        sub{OnRightDown(@_)} );
  EVT_LISTBOX(     $self, $self->{LIST}, sub{OnList(@_)}      );
  EVT_CHECKLISTBOX($self, $self->{LIST}, sub{OnCheck(@_)}     );
  EVT_MOUSEWHEEL(  $self->{LIST},        sub{OnWheel(@_)}     );

  #$box -> Add($self->{LIST}, 1, wxGROW|wxALL, 0);

  $self->{PAGE}  = Wx::Panel->new($self, -1, wxDefaultPosition, Wx::Size->new($w-int($w/4),$h));

  $self->SplitVertically($self->{LIST}, $self->{PAGE}, -int($w)-10);


  $self->{PAGEBOX} = Wx::BoxSizer->new( wxVERTICAL );
  $self->{PAGE} -> SetSizer($self->{PAGEBOX});

  $self->{W} = $w;
  $self->{H} = $h;
  $self->{CTRL}  = 0;
  $self->{SHIFT} = 0;
  $initial ||= Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize);
  $self->{initial} = $initial;
  $self->{initial} -> Reparent($self->{PAGE});
  $self->{PAGEBOX} -> Add($self->{initial}, 1, wxGROW|wxALL, 5);
  $self->{initial} -> Hide;
  $self->InitialPage;
  return $self;
};

sub InitialPage {
  my ($self) = @_;
  $self->{VIEW}->Hide if $self->{VIEW};
  $self->{LIST}->Clear;
  $self->{LIST}->AddData('Path list', $self->{initial});
  $self->{LIST}->Select(0);

  $self->{VIEW} = $self->{initial};
  $self->{VIEW} -> Show(1);

  #$self->{LIST}-> SetIndexedData(0, $self->{initial});
  $self->{LIST}-> Show;
};

sub do_callback {
  my ($self, $which) = @_;
  my $this = $self->{callbacks}->[$which];
  &$this;
};

sub set_initial_page_callback {
  my ($self, @callbacks) = @_;
  @initial_page_callback = @callbacks;
};

sub AddPage {
  my ($self, $page, $text, $select, $imageid, $position) = @_;
  my $end = (defined($position)) ? $position : $self->{LIST} -> GetCount;
  $self->{LIST} -> InsertData($text, $end, $page);
  #$self->{LIST} -> SetIndexedData($end, $page);
  $self->{LIST} -> Deselect($self->{LIST}->GetSelection);
  $self->{LIST} -> Select($end) if $select;

  $page->Reparent($self->{PAGE});
  $self->{initial} -> Hide;
  $self->{VIEW} -> Hide if ($self->{VIEW} and $self->{VIEW}->IsShown);

  $self->{VIEW}  = $page;
  $self->{VIEW} -> Show(1);
  $self->{PAGEBOX} -> Layout;
  return $self->{LIST} -> GetCount;
};

# sub MovePageAfter {
#   my ($self, $page_or_id, $pos) = @_;
#   my ($page, $id) = $self->page_and_id($page);
#   my $saved_page = $self->{LIST}-> GetClientData($id);

#   $self-> RemovePage($page);
#   $self->{LIST} -> InsertItems([$self->GetPageText($id)], $pos+1);
#   $self->{LIST} -> SetClientData($pos+1, $saved_page);
#   return $self->{LIST} -> GetCount;
# };

sub RemovePage {
  my ($self, $page) = @_;
  my ($obj, $id) = $self->page_and_id($page);
  return 0 if ($id == -1);
  my $new = ($id == 0) ? $id+1 : $id - 1;
  ($new = 0) if ($new >= $self->GetPageCount);
  ##print " ======== $id   $new\n";
  $self->{VIEW} -> Hide;
  $self->{LIST} -> GetIndexedData($new) -> Show;
  $self->{VIEW}  = ($self->{LIST}->IsEmpty) ? q{} : $self->{LIST}->GetIndexedData($new);
  $self->{LIST} -> Select($new);
  $self->{LIST} -> DeleteData($id);
  return 1;
};

sub DeletePage {
  my ($self, $page) = @_;
  my ($obj, $id) = $self->page_and_id($page);
  return 0 if ($id == -1);
  $self->RemovePage($id);
  $obj->Destroy if $obj !~ m{Panel}; # need to save initial page for later use
  ($self->{VIEW} = q{}) if ($self->{LIST}->IsEmpty);
  return 1;
};

sub Clear {
  my ($self, $page) = @_;
  foreach my $i (reverse(0 .. $self->GetPageCount-1)) {
    $self->DeletePage($i);
  };
};

## take a page object or a page id and return both
sub page_and_id {
  my ($self, $arg) = @_;
  my ($id, $obj) = (-1,-1);
  if ($arg =~ m{\A$NUMBER\z}) {
    $id = $arg;
    $obj = $self->{LIST}->GetIndexedData($arg)
  } else {
    foreach my $pos (0 .. $self->{LIST}->GetCount-1) {
      if ($arg eq $self->{LIST}->GetIndexedData($pos)) {
	$id = $pos;
	$obj = $arg;
	last;
      };
    };
  };
  return ($obj, $id);
};

sub DeleteAllPages {
  my ($self) = @_;
  $self->{LIST}->SetSelection(wxNOT_FOUND);
  $self->InitialPage;
};

sub GetCurrentPage {
  my ($self) = @_;
  return $self->{VIEW};
};

sub GetPage {
  my ($self, $pos) = @_;
  return $self->{LIST}->GetIndexedData($pos);
};

sub GetPageCount {
  my ($self) = @_;
  return $self->{LIST}->GetCount;
};

sub GetPageText {
  my ($self, $pos) = @_;
  return $self->{LIST}->GetString($pos);
};

sub GetSelection {
  my ($self) = @_;
  return $self->{LIST}->GetSelection;
};
sub SetSelection {
  my ($self, $pos) = @_;
  $self->{LIST} -> SetSelection($pos);
  ## plotzing here:
  ##print join("|", caller), $/;
  $self->{VIEW} -> Hide;
  $self->Refresh;
  $self->{LIST} -> GetIndexedData($pos) -> Show(1);
  $self->{VIEW} = $self->{LIST} -> GetIndexedData($pos);
  $self->{PAGEBOX} -> Layout;
};
{
  no warnings 'once';
  # alternate names
  *ChangeSelection = \ &SetSelection;
}

sub SetPageText {
  my ($self, $arg, $text) = @_;
  my ($obj, $id) = $self->page_and_id($arg);
  $self->{LIST}->SetString($id, $text);
};

#  HitTest
#  InsertPage

sub AdvanceSelection {
  my ($self, $dir) = @_;
  my $sel = $self->{LIST}->GetSelection;

  return if (($sel == 0) and (not $dir)); # already at top
  return if (($sel == $self->GetPageCount-1) and $dir); # already at bottom

  my $new = ($dir) ? $sel+1 : $sel-1;
  $self->SetSelection($new);
};

sub GetThemeBackgroundColour {
  return wxNullColour;
};

sub Check {
  my ($self, $pos, $value) = @_;
  my ($obj, $id) = $self->page_and_id($pos);
  $self->{LIST}->Check($id, $value);
  return $pos;
};
sub IsChecked {
  my ($self, $pos) = @_;
  my ($obj, $id) = $self->page_and_id($pos);
  return $self->{LIST}->IsChecked($id);
};

sub one {
  return 1;
};
sub noop {
  return 1;
};
{
  no warnings 'once';
  # alternate names
  *AssignImageList = \ &noop;
  *GetImageList	   = \ &noop;
  *SetImageList	   = \ &noop;
  *GetPageImage	   = \ &noop;
  *SetPageImage	   = \ &noop;
  *SetPadding	   = \ &noop;
  *SetPageSize	   = \ &noop;

  *GetRowCount	   = \ &one;
  *OnSelChange	   = \ &one;
}


sub OnLeftDown {
  my ($self, $event) = @_;
  if ($event->ControlDown) {
    #print "control left clicking\n";
    $self->{PARENT}->{CTRL} = 1;
    $self->{PARENT}->{NOW}  = $self->GetSelection;
  };
  if ($event->ShiftDown) {
    #print "shift left clicking\n";
    $self->{PARENT}->{SHIFT} = 1;
    $self->{PARENT}->{NOW}  = $self->GetSelection;
  };
  $event->Skip;
};
sub OnLeftDclick {
  my ($self, $event) = @_;
  #print "left double click\n";
  $self->GetParent->RenameSelection;
};

sub RenameSelection {
  my ($self) = @_;
  my $check_state = $self->{LIST}->IsChecked($self->{LIST}->GetSelection);
  my $oldname = $self->{LIST}->GetStringSelection;
  my $ted = Wx::TextEntryDialog->new( $self, "Enter the new name for \"$oldname\"", "Rename item", $oldname, wxOK|wxCANCEL, Wx::GetMousePosition);
  return if ($ted->ShowModal == wxID_CANCEL);
  my $newname = $ted->GetValue;
  return if ($newname =~ m{\A\s*\z});
  $self->{LIST}->SetString($self->{LIST}->GetSelection, $newname);
  my $page = $self->{LIST}->GetIndexedData($self->{LIST}->GetSelection);
  $page->Rename($newname) if $page->can('Rename');
  $self->{LIST}->Check($self->{LIST}->GetSelection, $check_state);
};

sub OnRightDown {
  my ($self, $event) = @_;
  #print "right clicking\n";
  ##$event->Skip;
}
sub OnMiddleDown {
  my ($self, $event) = @_;
  #print "middle clicking\n";
  ##$event->Skip;
}

sub OnList {
  my ($self, $event) = @_;
  my $sel = $event->GetSelection;
  return if ($sel == -1);
  my ($ctrl, $shift, $now) = ($self->{CTRL}, $self->{SHIFT}, $self->{NOW});
  $self->{CTRL}  =  0;
  $self->{SHIFT} =  0;
  $self->{NOW}   = -1;
  if ($ctrl) {
    my $onoff = ($self->{LIST}->IsChecked($sel)) ? 0 : 1;
    $self->{LIST}->Check($sel,$onoff);
    $self->{LIST}->Select($now);
  } elsif ($shift) {
    my ($i, $j) = sort {$a <=> $b} ($now, $sel);
    foreach my $pos ($i .. $j) {
      $self->{LIST}->Check($pos,1);
    };
    $self->{LIST}->Select($now);
  } else {
    $self->{VIEW} -> Hide;
    $self->{LIST} -> GetIndexedData($sel) -> Show;
    $self->{VIEW} = $self->{LIST} -> GetIndexedData($sel);
    $self->{PAGEBOX} -> Layout;
  };
};

sub OnCheck {
  my ($self, $event) = @_;
  my $sel = $event->GetSelection;
  #print $sel, $/;
  $event->Skip;
};

sub OnWheel {
  my ($self, $event) = @_;
  if ($event->GetWheelRotation < 0) { # scroll down, inrease selection
    $self->{PARENT}->AdvanceSelection(1);
  } else {			      # scroll up, decrease selection
    $self->{PARENT}->AdvanceSelection(0);
  };

  $event->Skip;
};
1;


=head1 NAME

Demeter::UI::Wx::CheckListBook - A CheckListBox-based notebook

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

Wx:CheckListBook is a class similar to Wx::Notebook but which uses a
Wx::CheckListBox to show the labels instead of tabs.

  $book = Demeter::UI::Wx::CheckListBook->new($parent, -1);

=head1 DESCRIPTION

This is a notebook which uses a Wx::CheckListBox to control the pages
of the notebook.  That is, the selected item in the CheckListBox has
its associated page displayed.  Each selectable item also has an
associated checkbox.  This allows an obvious chennel for simultaneous
single and multiple selection of items from the list.

Note that images associated with pages is not supported.  In fact,
some care is taken to make the list as compact as possible to allow
for maximum information display.

In the context of Artemis, this is used to display the set of paths
associated with a data set.

=head1 METHODS

=over 4

=item C<new>

The constructor.  It takes the same arguments as any other notebook
widget.

=item C<InitialPage>

This is called when the CheckListBook is initially created or whenever
its contents are deleted.  This makes a simple page intended to offer
instructions for how to begin using the CheckListBook.

=item C<AddPage>

Add a new page to the CheckListBook.  The arguments are the same as
for Wx::Notebook.

=item C<RemovePage>

Deletes the specified page, without deleting the associated window.
The argument is the same as for Wx::Notebook.

=item C<DeletePage>

Deletes the specified page, and the associated window.  The call to
this function generates the page changing events.  The argument is the
same as for Wx::Notebook.

=item C<Clear>

Same as C<DeleteAllPages> but without calling C<InitialPage>.

=item C<page_and_id>

Take a page object or a page id and return both as a two element list.

  ($obj, $id) = $book->page_and_id($page_or_id);

=item C<DeleteAllPages>

Delete all pages and their associated windows, then call
C<InitialPage>.

=item C<GetCurrentPage>

Return the page object currently displayed.

=item C<GetPage>

Return the page object at a given position.

  $page = $book->GetPage($position);

=item C<GetPageCount>

Return the number of items in the CheckListBook.  Note that position
indexing in 0-based, but this method returns the actual number of
items.

  $n = $book->GetPageCount;

=item C<GetPageText>

Return the label for a given position in the list.

  $label = $book->GetPageText;

=item C<GetSelection>

Returns the index (or list of indeces) of the selected item(s) or
wxNOT_FOUND if no item is selected.

=item C<SetSelection>

Sets the selection to the given item(s) or removes the selection
entirely if wxNOT_FOUND is given as the argument.

=item C<SetPageText>

Set the label for a given position to some given text.

  $book->SetPageText($position, $label);

=item C<AdvanceSelection>

Move the selection forward or backward for a true or false argument.

  $book->AdvanceSelection(1); # move selection forward by 1
  $book->AdvanceSelection(0); # move selection backward by 1

=item C<GetThemeBackgroundColour>

Unused

=item C<Check>

Toggle the checkbox for the given position.

  $book->Check($position, 1); # toggle it on
  $book->Check($position, 0); # toggle it off

=item C<IsChecked>

Returns true is the checkbox for the given position is toggled on.

=item C<RenameSelection>

Change the label at the given position interactively.

=back

=head1 DEPENDENCIES

L<Wx>, Wx::SplitterWindow, Wx::CheckListBox, and L<Const::Fast>

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
 
