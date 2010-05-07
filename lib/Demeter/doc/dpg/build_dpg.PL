#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;

chdir dirname($0);

system(q(./configure));
system(q(./bin/build));

## could consider building pod tree with Pod::ProjectDocs
