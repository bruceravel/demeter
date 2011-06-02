use DemeterPerlBuild;

my $dist = DemeterPerlBuild->new();
## set proxy correctly to fetch par files from titanium when building on vanadium
my $ua = $dist->user_agent;
$ua->no_proxy('10.0.61.254');
$dist->run();
