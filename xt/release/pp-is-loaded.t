use strict;
use warnings;

use Test::More;

BEGIN {
    $ENV{PV_TEST_PERL}                  = 1;
    $ENV{PV_WARN_FAILED_IMPLEMENTATION} = 1;
}

use Params::Validate;

is(
    Params::Validate::_implementation(), 'PP',
    'PP implementation is loaded when env var is set'
);

done_testing();
