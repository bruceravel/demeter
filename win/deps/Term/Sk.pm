package Term::Sk;

use strict;
use warnings;

use Time::HiRes qw( time );
use Fcntl qw(:seek);

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(set_chunk_size set_bkup_size rem_backspace) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.06';

our $errcode = 0;
our $errmsg  = '';

sub new {
    shift;
    my $self = {};
    bless $self;

    $errcode = 0;
    $errmsg  = '';

    my %hash     = (freq => 1, base => 0, target => 1_000, quiet => 0, test => 0, num => q{9_999});
    %hash        = (%hash, %{$_[1]}) if defined $_[1];

    my $format = defined $_[0] ? $_[0] : '%8c';

    $self->{base}    = $hash{base};
    $self->{target}  = $hash{target};
    $self->{quiet}   = $hash{quiet};
    $self->{test}    = $hash{test};
    $self->{format}  = $format;
    $self->{freq}    = $hash{freq};
    $self->{value}   = $hash{base};
    $self->{oldtext} = '';
    $self->{line}    = '';
    $self->{pdisp}   = '#';
    $self->{commify} = $hash{commify};
    $self->{token}   = $hash{token} || q{};

    unless (defined $self->{quiet}) {
        $self->{quiet} = !-t STDOUT;
    }

    if ($hash{num} eq '9') {
        $self->{sep}   = '';
        $self->{group} = 0;
    }
    else {
        my ($sep, $group) = $hash{num} =~ m{\A 9 ([^\d\+\-]) (9+) \z}xms or do {
            $errcode = 95;
            $errmsg  = qq{Can't parse num => '$hash{num}'};
            die sprintf('Error-%04d: %s', $errcode, $errmsg);
        };
        $self->{sep}   = $sep;
        $self->{group} = length($group);
    }

    # Here we de-compose the format into $self->{action}

    $self->{action} = [];

    my $fmt = $format;
    while ($fmt ne '') {
        if ($fmt =~ m{^ ([^%]*) % (.*) $}xms) {
            my ($literal, $portion) = ($1, $2);
            unless ($portion =~ m{^ (\d*) ([a-zA-Z]) (.*) $}xms) {
                $errcode = 100;
                $errmsg  = qq{Can't parse '%[<number>]<alpha>' from '%$portion', total line is '$format'};
                die sprintf('Error-%04d: %s', $errcode, $errmsg);
            }

            my ($repeat, $disp_code, $remainder) = ($1, $2, $3);

            if ($repeat eq '') { $repeat = 1; }
            if ($repeat < 1)   { $repeat = 1; }

            unless ($disp_code eq 'b'
            or      $disp_code eq 'c'
            or      $disp_code eq 'd'
            or      $disp_code eq 'm'
            or      $disp_code eq 'p'
            or      $disp_code eq 'P'
            or      $disp_code eq 't'
            or      $disp_code eq 'k') {
                $errcode = 110;
                $errmsg  = qq{Found invalid display-code ('$disp_code'), expected ('b', 'c', 'd', 'm', 'p', 'P' or 't') in '%$portion', total line is '$format'};
                die sprintf('Error-%04d: %s', $errcode, $errmsg);
            }

            push @{$self->{action}}, {type => '*lit',     len => length($literal), lit => $literal} if length($literal) > 0;
            push @{$self->{action}}, {type => $disp_code, len => $repeat};
            $fmt = $remainder;
        }
        else {
            push @{$self->{action}}, {type => '*lit', len => length($fmt), lit => $fmt};
            $fmt = '';
        }
    }

    # End of format de-composition

    $self->{tick}      = 0;
    $self->{out}       = 0;
    $self->{sec_begin} = int(time * 100);
    $self->{sec_print} = $self->{sec_begin};

    $self->show;

    return $self;
}

sub whisper {
    my $self = shift;
    
    my $back  = qq{\010} x length $self->{oldtext};
    my $blank = q{ }     x length $self->{oldtext};

    $self->{line} = join('', $back, $blank, $back, @_, $self->{oldtext});

    unless ($self->{test}) {
        local $| = 1;
        if ($self->{quiet}) {
            print @_;
        }
        else {
            print $self->{line};
        }
    }
}

sub get_line {
    my $self = shift;

    return $self->{line};
}

sub up    { my $self = shift; $self->{value} += defined $_[0] ? $_[0] : 1; $self->show_maybe; }
sub down  { my $self = shift; $self->{value} -= defined $_[0] ? $_[0] : 1; $self->show_maybe; }
sub close { my $self = shift; $self->{value} = undef;                      $self->show;       }

sub ticks { my $self = shift; return $self->{tick} }

sub token { my $self = shift; $self->{token} = shift; $self->up }

sub DESTROY {
    my $self = shift;
    $self->close;
}

sub show_maybe {
    my $self = shift;

    $self->{line} = '';

    my $sec_now  = int(time * 100);
    my $sec_prev = $self->{sec_print};

    $self->{sec_print} = $sec_now;
    $self->{tick}++;

    if ($self->{freq} eq 's') {
        if (int($sec_prev / 100) != int($sec_now / 100)) {
            $self->show;
        }
    }
    elsif ($self->{freq} eq 'd') {
        if (int($sec_prev / 10) != int($sec_now / 10)) {
            $self->show;
        }
    }
    else {
        unless ($self->{tick} % $self->{freq}) {
            $self->show;
        }
    }
}

sub show {
    my $self = shift;
    $self->{out}++;

    my $back  = qq{\010} x length $self->{oldtext};
    my $blank = q{ }     x length $self->{oldtext};

    my $text = '';
    if (defined $self->{value}) {

        # Here we compose a string based on $self->{action} (which, of course, is the previously de-composed format)

        for my $act (@{$self->{action}}) {
            my ($type, $lit, $len) = ($act->{type}, $act->{lit}, $act->{len});

            if ($type eq '*lit') { # print (= append to $text) a simple literal
                $text .= $lit;
                next;
            }
            if ($type eq 't') { # print (= append to $text) time elapsed in format 'hh:mm:ss'
                my $unit = int(($self->{sec_print} - $self->{sec_begin}) / 100);
                my $hour = int($unit / 3600);
                my $min  = int(($unit % 3600) / 60);
                my $sec  = $unit % 60;
                my $stamp = sprintf '%02d:%02d:%02d', $hour, $min, $sec;
                $text .= sprintf "%${len}.${len}s", $stamp;
                next;
            }
            if ($type eq 'd') { # print (= append to $text) a revolving dash in format '/-\|'
                $text .= substr('/-\|', $self->{out} % 4, 1) x $len;
                next;
            }
            if ($type eq 'b') { # print (= append to $text) progress indicator format '#####_____'
                my $progress = $self->{target} == $self->{base} ? 0 :
                   int ($len * ($self->{value} - $self->{base}) / ($self->{target} - $self->{base}) + 0.5);
                if    ($progress < 0)    { $progress = 0    }
                elsif ($progress > $len) { $progress = $len }
                $text .= $self->{pdisp} x $progress.'_' x ($len - $progress);
                next;
            }
            if ($type eq 'p') { # print (= append to $text) progress in percentage format '999%'
                my $percent = $self->{target} == $self->{base} ? 0 :
                   100 * ($self->{value} - $self->{base}) / ($self->{target} - $self->{base});
                $text .= sprintf "%${len}.${len}s", sprintf("%.0f%%", $percent);
                next;
            }
            if ($type eq 'P') { # print (= append to $text) literally '%' characters
                $text .= '%' x $len;
                next;
            }
            if ($type eq 'c') { # print (= append to $text) actual counter value (commified)
                $text .= sprintf "%${len}s", commify($self->{commify}, $self->{value}, $self->{sep}, $self->{group});
                next;
            }
            if ($type eq 'm') { # print (= append to $text) target (commified)
                $text .= sprintf "%${len}s", commify($self->{commify}, $self->{target}, $self->{sep}, $self->{group});
                next;
            }
            if ($type eq 'k') {
                $text .= sprintf "%s", $self->{token};
                next;
            }
            # default: do nothing, in the (impossible) event that $type is none of '*lit', 't', 'b', 'p', 'P', 'c' or 'm'
        }

        # End of string composition
    }

    $self->{line} = join('', $back, $blank, $back, $text);

    unless ($self->{test} or $self->{quiet}) {
        local $| = 1;
        print $self->{line};
    }

    $self->{oldtext} = $text;
}

sub commify {
    my $com = shift;
    if ($com) { return $com->($_[0]); }

    local $_ = shift;
    my ($sep, $group) = @_;

    if ($group > 0) {
        my $len = length($_);
        for my $i (1..$len) {
            last unless s/^([-+]?\d+)(\d{$group})/$1$sep$2/;
        }
    }
    return $_;
}

my $log_info = '';

sub log_info { $log_info }

my $chunk_size = 10000;
my $bkup_size  = 80;

sub set_chunk_size { $chunk_size = $_[0]; if ($chunk_size < 100) { $chunk_size = 100;} }
sub set_bkup_size  { $bkup_size  = $_[0]; if ($bkup_size  <  10) { $bkup_size  =  10;} }

sub rem_backspace {
    my ($fname) = @_;

    open my $ifh, '<', $fname or die "Error-0200: Can't open < '$fname' because $!";
    open my $tfh, '+>', undef or die "Error-0210: Can't open +> undef (tempfile) because $!";

    $log_info = '';

    my $out_buf = '';

    while (read($ifh, my $inp_buf, $chunk_size)) {
        $out_buf .= $inp_buf;
        my $log_input = length($inp_buf);

        my $log_backspaces = 0;
        # here we are removing the backspaces:
        while ($out_buf =~ m{\010+}xms) {
            # $& is the same as substr($out_buf, $-[0], $+[0] - $-[0])
            my ($pos_from, $pos_to) = ($-[0], $+[0]);
            $log_backspaces += $pos_to - $pos_from;

            my ($underflow, $pos_left);
            if ($pos_from * 2 >= $pos_to) {
                $underflow = 0;
                $pos_left  = $pos_from * 2 - $pos_to;
            }
            else {
                $underflow = 1;
                $pos_left  = 0;
            }

            my $delstr = substr($out_buf, $pos_left, $pos_from - $pos_left);

            if ($underflow) {
                $log_info .= "[** Buffer underflow **]\n";
            }
            if ($delstr =~ s{([[:cntrl:]])}{sprintf('[%02d]',ord($1))}xmsge) {
                $log_info .= "[** Ctlchar: '$delstr' **]\n";
            }

            $out_buf = substr($out_buf, 0, $pos_left).substr($out_buf, $pos_to);
        }

        if (length($out_buf) > $bkup_size) {
            print {$tfh} substr($out_buf, 0, -$bkup_size);
            $out_buf = substr($out_buf, -$bkup_size);
        }

        $log_info .= "[I=$log_input,B=$log_backspaces]";
    }

    CORE::close $ifh; # We need to employ CORE::close because there is already another close subroutine defined in the current namespace "Term::Sk"

    print {$tfh} $out_buf;

    # Now copy back temp-file to original file:

    seek $tfh, 0, SEEK_SET    or die "Error-0220: Can't seek tempfile to 0 because $!";
    open my $ofh, '>', $fname or die "Error-0230: Can't open > '$fname' because $!";

    while (read($tfh, my $buf, $chunk_size)) { print {$ofh} $buf; }

    CORE::close $ofh;
    CORE::close $tfh;
}

1;
__END__

=head1 NAME

Term::Sk - Perl extension for displaying a progress indicator on a terminal.

=head1 SYNOPSIS

  use Term::Sk;

  my $ctr = Term::Sk->new('%d Elapsed: %8t %21b %4p %2d (%8c of %11m)',
    {quiet => 0, freq => 10, base => 0, target => 100, pdisp => '!'})
    or die "Error 0010: Term::Sk->new, ".
           "(code $Term::Sk::errcode) ".
           "$Term::Sk::errmsg";

  $ctr->up for (1..100);

  $ctr->down for (1..100);

  $ctr->whisper('abc'); 

  my last_line = $ctr->get_line;

  $ctr->close;

  print "Number of ticks: ", $ctr->ticks, "\n";

=head1 EXAMPLES

Term::Sk is a class to implement a progress indicator ("Sk" is a short form for "Show Key"). This is used to provide immediate feedback for
long running processes.

A sample code fragment that uses Term::Sk:

  use Term::Sk;

  print qq{This is a test of "Term::Sk"\n\n};

  my $target = 2_845;
  my $format = '%2d Elapsed: %8t %21b %4p %2d (%8c of %11m)';

  my $ctr = Term::Sk->new($format,
    {freq => 10, base => 0, target => $target, pdisp => '!'})
    or die "Error 0010: Term::Sk->new, ".
           "(code $Term::Sk::errcode) ".
           "$Term::Sk::errmsg";

  for (1..$target) {
      $ctr->up;
      do_something();
  }

  $ctr->close;

  sub do_something {
      my $test = 0;
      for my $i (0..10_000) {
          $test += sin($i) * cos($i);
      }
  }

Another example that counts upwards:

  use Term::Sk;

  my $format = '%21b %4p';

  my $ctr = Term::Sk->new($format, {freq => 's', base => 0, target => 70})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";

  for (1..10) {
      $ctr->up(7);
      sleep 1;
  }

  $ctr->close;

At any time, after Term::Sk->new(), you can query the number of ticks (i.e. number of calls to
$ctr->up or $ctr->down) using the method 'ticks':

  use Term::Sk;

  my $ctr = Term::Sk->new('%6c', {freq => 's', base => 0, target => 70})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";

  for (1..4288) {
      $ctr->up;
  }

  $ctr->close;

  print "Number of ticks: ", $ctr->ticks, "\n";

This example uses a simple progress bar in quiet mode (nothing is printed to STDOUT), but
instead, the content of what would have been printed can now be extracted using the get_line() method:

  use Term::Sk;

  my $format = 'Ctr %4c';

  my $ctr = Term::Sk->new($format, {freq => 2, base => 0, target => 10, quiet => 1})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";

  my $line = $ctr->get_line;
  $line =~ s/\010/</g;
  print "This is what would have been printed upon new(): [$line]\n";

  for my $i (1..10) {
      $ctr->up;

      $line = $ctr->get_line;
      $line =~ s/\010/</g;
      print "This is what would have been printed upon $i. call to up(): [$line]\n";
  }

  $ctr->close;

  $line = $ctr->get_line;
  $line =~ s/\010/</g;
  print "This is what would have been printed upon close(): [$line]\n";

Here are some examples that show different values for option {num => ...}

  my $format = 'act %c max %m';

  my $ctr1 = Term::Sk->new($format, {base => 1234567, target => 2345678})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  # The following numbers are shown: act 1_234_567 max 2_345_678

  my $ctr2 = Term::Sk->new($format, {base => 1234567, target => 2345678, num => q{9,999}})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  # The following numbers are shown: act 1,234,567 max 2,345,678

  my $ctr3 = Term::Sk->new($format, {base => 1234567, target => 2345678, num => q{9'99}})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  # The following numbers are shown: act 1'23'45'67 max 2'34'56'78

  my $ctr4 = Term::Sk->new($format, {base => 1234567, target => 2345678, num => q{9}})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  # The following numbers are shown: act 1234567 max 2345678

  my $ctr5 = Term::Sk->new($format, {base => 1234567, target => 2345678,
    commify => sub{ join '!', split m{}xms, $_[0]; }})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  # The following numbers are shown: act 1!2!3!4!5!6!7 max 2!3!4!5!6!7!8

=head1 DESCRIPTION

=head2 Format strings

The first parameter to new() is the format string which contains the following
special characters:

=over

=item characters '%d'

a revolving dash, format '/-\|'

=item characters '%t'

time elapsed, format 'hh:mm:ss'

=item characters '%b'

progress bar, format '#####_____'

=item characters '%p'

Progress in percentage, format '999%'

=item characters '%c'

Actual counter value (commified by '_'), format '99_999_999'

=item characters '%m'

Target maximum value (commified by '_'), format '99_999_999'

=item characters '%P'

The '%' character itself

=back

=head2 Options

The second parameter are the following options:

=over

=item option {freq => 999}

This option sets the refresh-frequency on STDOUT to every 999 up() or
down() calls. If {freq => 999} is not specified at all, then the
refresh-frequency is set by default to every up() or down() call.

=item option {freq => 's'}

This is a special case whereby the refresh-frequency on STDOUT  is set to every
second.

=item option {freq => 'd'}

This is a special case whereby the refresh-frequency on STDOUT  is set to every
1/10th of a second.

=item option {base => 0}

This specifies the base value from which to count. The default is 0

=item option {target => 10_000}

This specifies the maximum value to which to count. The default is 10_000.

=item option {pdisp => '!'}

This option (with the exclamation mark) is obsolete and has no effect whatsoever. The
progressbar will always be displayed using the hash-symbol "#".

=item option {quiet => 1}

This option disables most printing to STDOUT, but the content of the would be printed
line is still available using the method get_line(). The whisper-method, however,
still shows its output.

The default is in fact {quiet => !-t STDOUT}

=item option {num => '9_999'}

This option configures the output number format for the counters.

=item option {commify => sub{...}}

This option allows to register a subroutine that formats the counters.

=item option {test => 1}

This option is used for testing purposes only, it disables all printing to STDOUT, even
the whisper shows no output. But again, the content of the would be printed line is
still available using the method get_line().

=back

=head2 Processing

The new() method immediately displays the initial values on screen. From now on,
nothing must be printed to STDOUT and/or STDERR. However, you can write to STDOUT during
the operation using the method whisper().

We can either count upwards, $ctr->up, or downwards, $ctr->down. Everytime we do so, the
value is either incremented or decremented and the new value is replaced on STDOUT. We should
do so regularly during the process. Both methods, $ctr->up(99) and $ctr->down(99) can take an
optional argument, in which case the value is incremented/decremented by the specified amount.

When our process has finished, we must close the counter ($ctr->close). By doing so, the last
displayed value is removed from STDOUT, as if nothing had happened. Now we are allowed to print
again to STDOUT and/or STDERR.

=head2 Post hoc transformation

In some cases it makes sense to redirected STDOUT to a flat file. In this case, the backspace
characters remain in the flat file.

There is a function "rem_backspace()" that removes the backspaces (including the characters that
they are supposed to remove) from a redirected file.

Here is a simplified example:

  use Term::Sk qw(rem_backspace);

  my $flatfile = "Test hijabc\010\010\010xyzklm";

  printf "before (len=%3d): '%s'\n", length($flatfile), $flatfile;

  rem_backspace(\$flatfile);

  printf "after  (len=%3d): '%s'\n", length($flatfile), $flatfile;

You can also control (within limits) the internal chunk size and the internal backup size using the
functions set_chunk_size() and set_bkup_size():

  use Term::Sk qw(rem_backspace set_chunk_size and set_bkup_size);

  set_chunk_size(5000);
  set_bkup_size(60);

  my $flatfile = "Test hijabc\010\010\010xyzklm";

  printf "before (len=%3d): '%s'\n", length($flatfile), $flatfile;

  rem_backspace(\$flatfile);

  printf "after  (len=%3d): '%s'\n", length($flatfile), $flatfile;

=head1 AUTHOR

Klaus Eichner, January 2008

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Klaus Eichner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
