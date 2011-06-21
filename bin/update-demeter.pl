#!/usr/bin/perl
use warnings;
use strict;

use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->proxy(['http', 'https'], 'http://192.168.1.130:3128');

my $url = 'http://github.com/bruceravel/demeter/downloads';
my $request = HTTP::Request->new(CONNECT => $url);
my $response = $ua->request($request);
print $response->as_string;

exit;




my $release = 1;
my $tag = 'http://github.com/bruceravel/demeter/downloads'; #zipball/release-' . $release;

print $tag, $/;
#exit;
#my $req = HTTP::Request->new(GET => $tag);

my $response = $ua->get($tag);


if ($response->is_success) {
  print $response->decoded_content;  # or whatever
} else {
  die $response->status_line;
}



#print $ua->request($req, $tag)->as_string;


# my $response = $ua->get($tag);

# print $tag, $/;
# print $ENV{https_proxy}, $/;

# if ($response->is_success) {
#   open(my $O, '>', "Demeter-r$release.tar.gz");
#   print $O $response->decoded_content;
#   close $0;
#   print "Got Demeter release $release\n";
# } else {
#   die "Oops! " . $response->status_line . $/;
# };
