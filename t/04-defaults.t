use strict;

use Params::Validate qw(:all);

print "1..8\n";

my %def = eval { foo() };

ok( ! $@,
    "Error calling foo(): $@\n" );

ok( $def{a} == 1,
    "Parameter 'a' was altered: $def{a}\n" );

ok( $def{b} == 2,
    "Parameter 'b' was altered: $def{b}\n" );

ok( $def{c} == 42,
    "No default (or incorrect default) assigned for parameter 'c': $def{c}\n" );

my @def = eval { bar() };

ok( ! $@,
    "Error calling bar(): $@\n" );

ok( $def{a} == 1,
    "1st parameter was altered: $def[0]\n" );

ok( $def{b} == 2,
    "2nd parameter was altered: $def[1]\n" );

ok( $def{c} == 42,
    "No default (or incorrect default) assigned for 3rd parameter: $def[2]\n" );

sub foo
{
    my @params = ( a => 1, b => 2 );
    my %def = validate( @params, { a => 1,
				   b => { default => 99 },
				   c => { default => 42 },
				 } );

    return %def;
}

sub bar
{
    my @params = ( 1, 2 );
    my @def = validate_pos( @params, 1, { default => 99 }, { default => 42 } );

    return @def;
}

sub ok
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print "@_\n" if !$ok;
}
