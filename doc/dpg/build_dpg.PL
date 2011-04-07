#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Path;

chdir dirname($0);

mkdir 'html' if not -d 'html';
system(q(./configure));
system(q(./bin/build));

## could consider building pod tree with Pod::ProjectDocs
