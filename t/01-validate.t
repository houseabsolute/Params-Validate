use strict;

use lib './t';

use Params::Validate qw(:all);

use vars qw(@expect);
@expect = (
	   # mandatory/optional
	   0,
	   q|^Mandatory parameter 'bar' missing|,
	   q|^Mandatory parameters .* missing|,
	   q|^The following parameter .* baz|,
	   0,
	   0,
	   0,
	   0,
	   0,

	   # simple types
	   q|^The 'foo' parameter is an 'arrayref'.* types: scalar|,
	   q|^The 'brax' parameter is an 'arrayref'.* types: scalar hash|,
	   q|^The 'bar' parameter is a 'hashref'.* types: arrayref|,
	   0,

	   # funkier types
	   q|^The 'bar' parameter is a 'globref'.* types: glob|,
	   q|^The 'baz' parameter is a 'glob'.* types: globref|,
	   q|^The 'foo' parameter is a 'scalar'.* types: scalarref|,
	   q|^The 'quux' parameter is a 'globref'.* types: coderef|,

	   0,
	   0,
	   q|^The 'foo' parameter is an 'arrayref'.* types: glob globref|,

	   # isa
	   0,
	   0,
	   0,

	   q|^The 'foo' parameter is not a 'Bar'|,
	   0,
	   0,

	   q|^The 'foo' parameter is not a 'Baz'|,
	   q|^The 'foo' parameter is not a 'Baz'|,
	   0,

	   q|^The 'foo' parameter is not a 'Yadda'|,
	   0,

	   # can
	   0,
	   0,
	   q|^The 'foo' parameter cannot 'barify'|,
	   0,
	   q|^The 'foo' parameter cannot 'yaddaify'|,
	   q|^The 'foo' parameter cannot 'barify'|,
	   q|^The 'foo' parameter cannot 'yaddaify'|,
	   0,

	   # callbacks
	   0,
	   0,
	   q|^The 'foo' parameter did not pass the 'less than 20' callback|,

	   0,
	   q|^The 'foo' parameter did not pass the 'less than 20' callback|,
	   q|^The 'foo' parameter did not pass the 'more than 0' callback|,

	   # mix n' match
	   q|^The 'foo' parameter is a 'scalar'.* types: arrayref|,
	   q|^The 'foo' parameter did not pass the '5 elements' callback|,
	   0,

	   # positional - 1
	   q|^1 parameter was passed to .* but 2 were expected|,
	   q|^Parameter #2 did not pass the '5 elements' callback|,

	   # positional - 2
	   q|^Parameter #3 is not a 'Bar'|,
	   0,

	   # hashref named params
	   q|^The 'bar' parameter is a 'hashref'.* types: arrayref|,
	   q|^Mandatory parameter 'bar' missing|,

	   # positional - 3
	   q|^3 parameters were passed .* but 1 - 2 were expected|,
	   0,
	   0,
	   q|^0 parameters were passed .* but 1 - 2 were expected|,

	   # positional - 3
	   q|^3 parameters were passed .* but 1 - 2 were expected|,
	   0,
	   0,
	   q|^0 parameters were passed .* but 1 - 2 were expected|,

	   # set_options
	   0,
	   q|^The following parameter .* FOO|,

	   0,
	   q|^The following parameter .* -foo|,

	   0,
	   q|^The following parameter .* bar|,

	   '',
	   q|^2 parameters were passed .* but 1.*|,
	   q|^Mandatory parameter 'foo' missing|,

	   q|^ERROR WAS: The following parameter .* bar|,
	   q|^The following parameter .* bar|,

	   q|^The 'foo' parameter is an 'undef'.*|,
	   0,

	   q|^The 'foo' parameter is an 'arrayref'.*|,
	   0,
	  );

require 'tests.pl';

# 5.6.0 core dumps all over during the tests
if ( $] == 5.006 )
{
    warn <<'EOF';

Skipping tests for Perl 5.6.0.  5.6.0 core dumps all over during the
tests.  This may have to do with the test code rather than the module
itself.  5.6.1-trial1 worked fine so there is hope.
EOF

    print "ok $_\n" for 1..73;
    exit;
}

run_tests();
