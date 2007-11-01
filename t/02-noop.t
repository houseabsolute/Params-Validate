#!/usr/bin/perl -w

use strict;

use File::Spec;
use lib File::Spec->catdir( 't', 'lib' );

BEGIN { $ENV{PERL_NO_VALIDATION} = 1 }

use PVTests;
PVTests::run_tests();
