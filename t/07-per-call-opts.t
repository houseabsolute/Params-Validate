use strict;

use Params::Validate qw(:all);

use Test;
BEGIN { plan test => 11 }

eval
{
    verify( params => [ 'foo' ],
            spec => [ SCALAR ],
	  );
};

ok( !$@ );

eval
{
    verify( params => { foo => 5,
                        bar => {} },
            spec => { foo => SCALAR,
                      bar => HASHREF },
	  );
};
ok( !$@ );

eval
{
    verify( params => [],
            spec => [ SCALAR ],
            called => 'Yo::Mama',
	  );
};
ok( $@ =~ /Yo::Mama/ );

{
    my %p;
    eval
    {
        %p =
            verify( params => [],
                    spec => { a => { default => 3 },
                              b => { default => 'x' } },
                  );
    };

    ok( exists $p{a} );
    ok( $p{a}, 3 );
    ok( exists $p{b} );
    ok( $p{b}, 'x' );
}

{
    my @p;
    eval
    {
        @p =
            verify( params => [],
                    spec => [ { default => 3 },
                              { default => 'x' } ],
                  );
    };

    ok( $p[0], 3 );
    ok( $p[1], 'x' );
}

{
    package Testing::X;
    use Params::Validate qw(:all);
    validation_options( allow_extra => 1 );

    eval
    {
        verify( params => [ a => 1, b => 2, c => 3 ],
                spec => { a => 1, b => 1 },
              );
    };
    main::ok( ! $@ );

    eval
    {
        verify( params => [ a => 1, b => 2, c => 3 ],
                spec => { a => 1, b => 1 },
                allow_extra => 0,
              );
    };
    main::ok( $@ =~ /was not listed/ );
}

