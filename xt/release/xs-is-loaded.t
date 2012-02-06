use strict;
use warnings;

use Test::More;

use Params::Validate;

is(
    Params::Validate::_implementation(), 'XS',
    'XS implementation is loaded by default'
);

done_testing();
