#!/usr/bin/perl
use warnings;
use strict;

use LWP::UserAgent;

$ENV{https_proxy} ||= $ENV{http_proxy};

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy;

my $release = 1;
my $tag = 'https://github.com/bruceravel/demeter/tarball/release-' . $release;

#$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1));

my $req = HTTP::Request->new(GET => $tag);
print $ua->request($req, "Demeter-r$release.tar.gz")->as_string;


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
