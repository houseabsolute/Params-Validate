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
	   q|^Parameter #1 did not pass the '5 elements' callback|,

	   # positional - 2
	   q|^Parameter #2 is not a 'Bar'|,
	   0,

	   # hashref named params
	   q|^The 'bar' parameter is a 'hashref'.* types: arrayref|,
	   q|^Mandatory parameter 'bar' missing|,
	  );

require 'tests.pl';

run_tests();
