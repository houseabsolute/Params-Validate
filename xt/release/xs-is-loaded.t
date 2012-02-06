use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PV_WARN_FAILED_IMPLEMENTATION} = 1 }

use Params::Validate;

is(
    Params::Validate::_implementation(), 'XS',
    'XS implementation is loaded by default'
);

done_testing();
