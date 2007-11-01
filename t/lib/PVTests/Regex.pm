package PVTests::Regex;

use strict;
use warnings;

use Params::Validate qw(:all);

use PVTests;
use Test::More;


sub run_tests
{
    plan tests => 7;

    eval
    {
        my @a = ( foo => 'bar' );
        validate( @a, { foo => { regex => '^bar$' } } );
    };
    is( $@, '' );

    eval
    {
        my @a = ( foo => 'bar' );
        validate( @a, { foo => { regex => qr/^bar$/ } } );
    };
    is( $@, '' );

    eval
    {
        my @a = ( foo => 'baz' );
        validate( @a, { foo => { regex => '^bar$' } } );
    };

    if ( $ENV{PERL_NO_VALIDATION} )
    {
        is( $@, '' );
    }
    else
    {
        like( $@, qr/'foo'.+did not pass regex check/ );
    }

    eval
    {
        my @a = ( foo => 'baz' );
        validate( @a, { foo => { regex => qr/^bar$/ } } );
    };

    if ( $ENV{PERL_NO_VALIDATION} )
    {
        is( $@, '' );
    }
    else
    {
        like( $@, qr/'foo'.+did not pass regex check/ );
    }

    eval
    {
        my @a = ( foo => 'baz', bar => 'quux' );
        validate( @a, { foo => { regex => qr/^baz$/ },
                        bar => { regex => 'uqqx' },
                      } );
    };

    if ( $ENV{PERL_NO_VALIDATION} )
    {
        is( $@, '' );
    }
    else
    {
        like( $@, qr/'bar'.+did not pass regex check/ );
    }

    eval
    {
        my @a = ( foo => 'baz', bar => 'quux' );
        validate( @a, { foo => { regex => qr/^baz$/ },
                        bar => { regex => qr/^(?:not this|quux)$/ },
                      } );
    };
    is( $@, '' );

    eval
    {
        my @a = ( foo => undef );
        validate( @a, { foo => { regex => qr/^$|^bubba$/ } } );
    };
    is( $@, '' );
}


1;
