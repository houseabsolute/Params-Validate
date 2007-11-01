#!/usr/bin/perl -w

use strict;

use File::Spec;
use lib File::Spec->catdir( 't', 'lib' );

use PVTests::Standard;
PVTests::Standard::run_tests();
