use strict;

use lib './t';

$ENV{NO_VALIDATE} = 1;
require Params::Validate;
Params::Validate->import(':all');

use vars qw(@expect);

require 'tests.pl';

# everything should pass
run_tests();
