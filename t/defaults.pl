print "1..20\n";

{
    my %def = eval { foo() };

    ok( ! $@,
        "Error calling foo(): $@\n" );

    ok( $def{a} == 1,
        "Parameter 'a' was altered: $def{a}\n" );

    ok( $def{b} == 2,
        "Parameter 'b' was altered: $def{b}\n" );

    ok( $def{c} == 42,
        "No default (or incorrect default) assigned for parameter 'c': $def{c}\n" );

    ok( $def{d} == 0,
        "No default (or incorrect default) assigned for parameter 'd': $def{d}\n" );
}

{
    my $def = eval { foo() };

    ok( ! $@,
        "Error calling foo(): $@\n" );

    ok( $def->{a} == 1,
        "Parameter 'a' was altered: $def->{a}\n" );

    ok( $def->{b} == 2,
        "Parameter 'b' was altered: $def->{b}\n" );

    ok( $def->{c} == 42,
        "No default (or incorrect default) assigned for parameter 'c': $def->{c}\n" );

    ok( $def->{d} == 0,
        "No default (or incorrect default) assigned for parameter 'd': $def->{d}\n" );
}

{
    my @def = eval { bar() };

    ok( ! $@,
        "Error calling bar(): $@\n" );

    ok( $def[0] == 1,
        "1st parameter was altered: $def[0]\n" );

    ok( $def[1] == 2,
        "2nd parameter was altered: $def[1]\n" );

    ok( $def[2] == 42,
        "No default (or incorrect default) assigned for 3rd parameter: $def[2]\n" );

    ok( $def[3] == 0,
        "No default (or incorrect default) assigned for 4rd parameter: $def[0]\n" );
}

{
    my $def = eval { bar() };

    ok( ! $@,
        "Error calling bar(): $@\n" );

    ok( $def->[0] == 1,
        "1st parameter was altered: $def->[0]\n" );

    ok( $def->[1] == 2,
        "2nd parameter was altered: $def->[1]\n" );

    ok( $def->[2] == 42,
        "No default (or incorrect default) assigned for 3rd parameter: $def->[2]\n" );

    ok( $def->[3] == 0,
        "No default (or incorrect default) assigned for 4rd parameter: $def->[0]\n" );
}

sub foo
{
    my @params = ( a => 1, b => 2 );
    return validate( @params, { a => 1,
                                b => { default => 99 },
                                c => { optional => 1, default => 42 },
                                d => { default => 0 },
                              } );
}

sub bar
{
    my @params = ( 1, 2 );

    return validate_pos( @params, 1, { default => 99 }, { default => 42 }, { default => 0 } );
}

sub ok
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print "@_\n" if !$ok;
}

1;
