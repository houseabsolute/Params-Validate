#!/usr/bin/perl -w

use strict;

use Params::Validate qw( validate SCALAR );
use Test::More tests => 7;

{
    my @p = ( foo => 1 );

    my $ref = validate( @p,
                        { foo => { type => SCALAR } },
                      );

    eval { $ref->{foo} = 2 };
    ok( ! $@, 'returned hashref values are not read only' );
    is( $ref->{foo}, 2, 'double check that setting value worked' );
}

{
    package ScopeTest;

    my $live = 0;

    sub new { $live++; bless {}, shift }
    sub DESTROY { $live-- }

    sub Live { $live }
}

{
    my @p = ( foo => ScopeTest->new() );

    is( ScopeTest->Live(), 1,
        'one live object' );

    my $ref = validate( @p,
                        { foo => 1 },
                      );

    isa_ok( $ref->{foo}, 'ScopeTest' );

    @p = ();

    is( ScopeTest->Live(), 1,
        'still one live object' );

    ok( defined $ref->{foo},
        'foo key stays in scope after original version goes out of scope' );

    undef $ref->{foo};

    is( ScopeTest->Live(), 0,
        'no live objects' );
}
