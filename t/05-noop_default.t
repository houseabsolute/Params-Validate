use strict;

use lib './t';

BEGIN
{
    $ENV{PERL_NO_VALIDATION} = 1;
    require Params::Validate;
    Params::Validate->import(':all');
}

print "1..10\n";

my %p;

eval { %p = foo( a => 1 ) };
ok( ! $@,
    "NO_VALIDATION env var did not cause validation to be skipped: $!" );

ok( exists $p{a},
    "Parameter 'a' did not exist in the returned hash" );

ok( exists $p{b},
    "Parameter 'b' did not exist in the returned hash" );

ok( $p{a} == 1,
    "Parameter 'a' was not equal to 1 in the returned hash" );

ok( $p{b} == 2,
    "Parameter 'b' was not equal to 2 in the returned hash" );

my @p;
eval { @p = bar( 1 ) };
ok( ! $@,
    "NO_VALIDATION env var did not cause validation to be skipped: $!" );

ok( defined $p[0],
    "Parameter 0 was not defined in the returned array" );

ok( defined $p[1],
    "Parameter 1' was not defined in the returned array" );

ok( $p[0] == 1,
    "Parameter 0 was not equal to 1 in the returned array" );

ok( $p[1] == 2,
    "Parameter 1 was not equal to 2 in the returned array" );

sub foo
{
    my %p = validate( @_, { a => { type => ARRAYREF },
			    b => { default => 2 } } );
    return %p;
}

sub bar
{
    my @p = validate_pos( @_, { type => ARRAYREF }, { default => 2 } );
    return @p;
}

sub ok
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print "@_\n" if !$ok;
}
