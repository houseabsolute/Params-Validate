#!/usr/bin/perl -w

use strict;

use Params::Validate qw(validate);
use Test::More tests => 3;

{
    my @p = ( foo => 'ClassCan' );

    eval
    {
        validate( @p,
                  { foo => { can => 'cancan' } },
                );
    };

    ok( ! $@ );

    eval
    {
        validate( @p,
                  { foo => { can => 'thingy' } },
                );
    };

    like( $@, qr/does not have the method: 'thingy'/ );
}

{
    my @p = ( foo => undef );
    eval
    {
        validate( @p,
                  { foo => { can => 'baz' } },
                );
    };

    like( $@, qr/does not have the method: 'baz'/ );
}


package ClassCan;

sub can
{
    return 1 if $_[1] eq 'cancan';
    return 0;
}

sub thingy { 1 }
