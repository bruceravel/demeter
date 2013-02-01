package Larch;

use strict;
use warnings;
use Cwd;

#use JSON::Tiny;
#my $json  = JSON::Tiny->new;

use XMLRPC::Lite;
our $client = XMLRPC::Lite -> proxy("http://localhost:4966");
our $rpcdata;
$client->larch(q{cd('} . cwd . q{')});

sub dispose {
  my ($text) = @_;
  $rpcdata = $client -> larch($text);
  return $rpcdata;
};




sub get_larch_array {
  my ($param) = @_;
  $rpcdata = $client -> get_data($param);
  my $ret = $rpcdata->result->{value};
  return @{eval $ret};
};

sub put_larch_array {
  my ($param, $aref) = @_;
  my $value = '[' . join(',', @$aref) . ']';
  return dispose("$param = array($value)");
};




sub get_larch_scalar {
  my ($param) = @_;
  $rpcdata = $client -> get_data($param);
  my $res = $rpcdata->result;
  if (not defined($res)) {
    return 0;
  } elsif (ref($res) eq 'HASH') {
    $res = $res->{value};
    #print $res, $/;
  } else {
    #print "------------- $param ", $res, $/;
    $res =~ s{(\A\"|\"\z)}{}g;
  };
  return $res;
};

sub put_larch_scalar {
  my ($param, $value) = @_;
  return dispose("$param = $value");
};

1;

