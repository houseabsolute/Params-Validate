use strict;
use warnings;

use Test::More;

plan skip_all => 'This test is only run for the module author'
    unless $ENV{AUTHOR_TESTING};

eval { require Test::Kwalitee; Test::Kwalitee->import() };
plan skip_all => "Test::Kwalitee needed for testing kwalitee"
    if $@;
