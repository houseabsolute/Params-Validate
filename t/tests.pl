use strict;

use Params::Validate qw(:all);

print "1..80\n";

sub run_tests
{
    {
	# mandatory/optional
	eval { sub1( foo => 'a', bar => 'b' ) };
	check();

	eval { sub1( foo => 'a' ) };
	check();

	eval { sub1() };
	check();

	eval { sub1( foo => 'a', bar => 'b', baz => 'c' ) };
	check();

	eval { sub2( foo => 'a', bar => 'b', baz => 'c' ) };
	check();

	eval { sub2( foo => 'a', bar => 'b' ) };
	check();

	eval { sub2a( foo => 'a', bar => 'b' ) };
	check();

	eval { sub2a( foo => 'a' ) };
	check();
   }

    {
	# simple types
	eval { sub3( foo => 'a',
		     bar => [ 1, 2, 3 ],
		     baz => { a => 1 },
		     quux => 'yadda',
		     brax => { qw( a b c d ) },
		   ) };
	check();

	eval { sub3( foo => ['a'],
		     bar => [ 1, 2, 3 ],
		     baz => { a => 1 },
		     quux => 'yadda',
		     brax => { qw( a b c d ) },
		   ) };
	check();

	eval { sub3( foo => 'foobar',
		     bar => [ 1, 2, 3 ],
		     baz => { a => 1 },
		     quux => 'yadda',
		     brax => [ qw( a b c d ) ],
		   ) };
	check();

	eval { sub3( foo => 'foobar',
		     bar => { 1, 2, 3, 4 },
		     baz => { a => 1 },
		     quux => 'yadda',
		     brax => 'a',
		   ) };
	check();
    }

    {
	# funkier types
	my $foo = 'foobar';
	eval { sub4( foo => \$foo,
		     bar => do { local *FH; *FH; },
		     baz => \*BAZZY,
		     quux => sub { 'a coderef' },
		   ) };
	check();

	eval { sub4( foo => \$foo,
		     bar => \*BARRY,
		     baz => \*BAZZY,
		     quux => sub { 'a coderef' },
		   ) };
	check();

	eval { sub4( foo => \$foo,
		     bar => *GLOBBY,
		     baz => do { local *FH; *FH; },
		     quux => sub { 'a coderef' },
		   ) };
	check();

	eval { sub4( foo => $foo,
		     bar => do { local *FH; *FH; },
		     baz => \*BAZZY,
		     quux => sub { 'a coderef' },
		   ) };
	check();

	eval { sub4( foo => \$foo,
		     bar => do { local *FH; *FH; },
		     baz => \*BAZZY,
		     quux => \*CODEREF,
		   ) };
	check();

	# test HANDLE type
	eval { sub4a( foo => \*HANDLE) };
	check();

	eval { sub4a( foo => *HANDLE) };
	check();

	eval { sub4a( foo => ['not a handle'] ) };
	check();

	# test BOOLEAN type
	eval { sub4b( foo => undef ) };
	check();

	eval { sub4b( foo => 124125 ) };
	check();
    }

    {
	# isa
	my ($x, $y, $z, $zz);
	my $foo = bless \$x, 'Foo';
	my $bar = bless \$y, 'Bar';
	my $baz = bless \$z, 'Baz';
	my $quux = bless \$zz, 'Quux';

	eval { sub5( foo => $foo ) };
	check();
	eval { sub5( foo => $bar ) };
	check();
	eval { sub5( foo => $baz ) };
	check();

	eval { sub6( foo => $foo ) };
	check();
	eval { sub6( foo => $bar ) };
	check();
	eval { sub7( foo => $baz ) };
	check();

	eval { sub7( foo => $foo ) };
	check();
	eval { sub7( foo => $bar ) };
	check();
	eval { sub7( foo => $baz ) };
	check();

	eval { sub8( foo => $foo ) };
	check();
	eval { sub8( foo => $quux ) };
	check();
    }

    {
	# can
	my ($x, $y, $z, $zz);
	my $foo = bless \$x, 'Foo';
	my $bar = bless \$y, 'Bar';
	my $baz = bless \$z, 'Baz';
	my $quux = bless \$zz, 'Quux';

	eval { sub9( foo => $foo ) };
	check();
	eval { sub9( foo => $quux ) };
	check();

	eval { sub9a( foo => $foo ) };
	check();
	eval { sub9a( foo => $bar ) };
	check();

	eval { sub9b( foo => $baz ) };
	check();
	eval { sub9b( foo => $quux ) };
	check();

	eval { sub9c( foo => $bar ) };
	check();
	eval { sub9c( foo => $quux ) };
	check();
    }

    {
	# callbacks
	eval { sub10( foo => 1 ) };
	check();
	eval { sub10( foo => 19 ) };
	check();
	eval { sub10( foo => 20 ) };
	check();

	eval { sub11( foo => 1 ) };
	check();
	eval { sub11( foo => 20 ) };
	check();
	eval { sub11( foo => 0 ) };
	check();
    }

    {
	# mix n' match
	eval { sub12( foo => 1 ) };
	check();
	eval { sub12( foo => [ 1, 2, 3 ] ) };
	check();
	eval { sub12( foo => [ 1, 2, 3, 4, 5 ] ) };
	check();
    }

    {
	# positional - 1
	eval { sub13( 'a' ) };
	check();
	eval { sub13( 'a', [ 1, 2, 3 ] ) };
	check();
    }

    {
	# positional - 2
	my ($x, $y);
	my $foo = bless \$x, 'Foo';
	my $bar = bless \$y, 'Bar';
	eval { sub14( 'a', [ 1, 2, 3 ], $foo ) };
	check();
	eval { sub14( 'a', [ 1, 2, 3 ], $bar ) };
	check();
    }

    {
	# hashref named params
	eval { sub15( { foo => 1, bar => { a => 1 } } ) };
	check();

	eval { sub15( { foo => 1 } ) };
	check();
    }

    {
	# positional - 3
	eval { sub16( 1, 2, 3 ) };
	check();
	eval { sub16( 1, 2 ) };
	check();
	eval { sub16( 1 ) };
	check();
	eval { sub16() };
	check();
    }

    {
	# positional - 4
	eval { sub17( 1, 2, 3 ) };
	check();
	eval { sub17( 1, 2 ) };
	check();
	eval { sub17( 1 ) };
	check();
	eval { sub17() };
	check();
    }

    # validation_options
    {
	{
	    package Foo;
	    Params::Validate::validation_options( ignore_case => 1 );
	}
	eval { Foo::sub18( FOO => 1 ) };
	check();
	eval { sub18( FOO => 1 ) };
	check();
    }

    {
	{
	    package Foo;
	    validation_options( strip_leading => '-' );
	}
	eval { Foo::sub18( -foo => 1 ) };
	check();
	eval { sub18( -foo => 1 ) };
	check();
    }

    {
	{
	    package Foo;
	    validation_options( allow_extra => 1 );
	}
	eval { Foo::sub18( foo => 1, bar => 1 ) };
	check();
	eval { sub18( foo => 1, bar => 1 ) };
	check();

	eval { Foo::sub19( 1, 2 ) };
	check();
	eval { sub19( 1, 2 ) };
	check();

	validation_options( strip_leading => '-' );
	eval { Foo::sub18( -foo => 1 ) };
	check();
    }

    validation_options();

    {
	{
	    package Foo;
	    validation_options( on_fail => sub { die "ERROR WAS: $_[0]" } );
	}
	eval { Foo::sub18( bar => 1 ) };
	check();
	eval { sub18( bar => 1 ) };
	check();
    }

    eval { sub20( foo => undef ) };
    check();
    eval { sub21( foo => undef ) };
    check();

    eval { sub22( foo => [1] ) };
    check();
    eval { sub22( foo => bless [1], 'object' ) };
    check();

    eval { sub23( '1 element' ) };
    check();
}

sub sub1
{
    validate( @_, { foo => 1, bar => 1 } );
}

sub sub2
{
    validate( @_, { foo => 1, bar => 1, baz => 0 } );
}

sub sub2a
{
    validate( @_, { foo => 1, bar => { optional => 1 } } );
}

sub sub3
{
    validate( @_, { foo =>
		    { type => SCALAR },
		    bar =>
		    { type => ARRAYREF },
		    baz =>
		    { type => HASHREF },
		    quux =>
		    { type => SCALAR | ARRAYREF },
		    brax =>
		    { type => SCALAR | HASHREF },
		  }
	    );
}

sub sub4
{
    validate( @_, { foo =>
		    { type => SCALARREF },
		    bar =>
		    { type => GLOB },
		    baz =>
		    { type => GLOBREF },
		    quux =>
		    { type => CODEREF },
		  }
	    );
}

sub sub4a
{
    validate( @_, { foo => { type => HANDLE } } );
}

sub sub4b
{
    validate( @_, { foo => { type => BOOLEAN } } );
}

sub sub5
{
    validate( @_, { foo => { isa => 'Foo' } } );
}

sub sub6
{
    validate( @_, { foo => { isa => 'Bar' } } );
}

sub sub7
{
    validate( @_, { foo => { isa => 'Baz' } } );
}

sub sub8
{
    validate( @_, { foo => { isa => [ 'Foo', 'Yadda' ] } } );
}

sub sub9
{
    validate( @_, { foo => { can => 'fooify'} } );
}

sub sub9a
{
    validate( @_, { foo => { can => [ 'fooify', 'barify' ] } } );
}

sub sub9b
{
    validate( @_, { foo => { can => [ 'barify', 'yaddaify' ] } } );
}

sub sub9c
{
    validate( @_, { foo => { can => [ 'fooify', 'yaddaify' ] } } );
}

sub sub10
{
    validate( @_, { foo =>
		    { callbacks =>
		      { 'less than 20' => sub { shift() < 20 } }
		    } } );
}

sub sub11
{
    validate( @_, { foo =>
		    { callbacks =>
		      { 'less than 20' => sub { shift() < 20 },
			'more than 0'  => sub { shift() > 0 },
		      }
		    } } );
}

sub sub12
{
    validate( @_, { foo =>
		    { type => ARRAYREF,
		      callbacks =>
		      { '5 elements' => sub { @{shift()} == 5 } }
		    } } );
}

sub sub13
{
    validate_pos( @_,
		  { type => SCALAR },
		  { type => ARRAYREF,
		    callbacks => 
		    { '5 elements' => sub { @{shift()} == 5 } }
		  } );
}

sub sub14
{
    validate_pos( @_,
		  { type => SCALAR },
		  { type => ARRAYREF },
		  { isa => 'Bar' },
		);
}

sub sub15
{
    validate( @_,
	      { foo => 1,
		bar => { type => ARRAYREF }
	      } );
}

sub sub16
{
    validate_pos( @_, 1, 0 );
}

sub sub17
{
    validate_pos( @_, { type => SCALAR }, { type => SCALAR, optional => 1 } );
}

{
    package Foo;
    use Params::Validate;
    sub sub18
    {
	validate( @_, { foo => 1 } );
    }

    sub sub19
    {
	validate_pos( @_, 1 );
    }
}

sub sub18
{
    validate( @_, { foo => 1 } );
}

sub sub19
{
    validate_pos( @_, 1 );
}

sub sub20
{
    validate( @_, { foo => { type => SCALAR } } );
}

sub sub21
{
    validate( @_, { foo => { type => UNDEF | SCALAR } } );
}

sub sub22
{
    validate( @_, { foo => { type => OBJECT } } );
}

sub sub23
{
    validate_pos( @_, 1 );
}

{
    my $x = 0;
    sub check
    {
	my $expect = $expect[$x++];

        my $line = (caller(0))[2];

	$expect ?
	    ok( ( $@ =~ /$expect/ ? 1 : 0 ),
		$@ ?
                "$@ did not match:\n$expect" :
                "no error when error was expected ($expect) - line $line" ) :
	    ok( ! $@, $@ );
    }
}

sub ok
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print "@_\n" if !$ok;
}

package Foo;

use Params::Validate qw(:all);

sub fooify {1}

package Bar;

@Bar::ISA = ('Foo');

sub barify {1}

package Baz;

@Baz::ISA = ('Bar');

sub bazify {1}

package Yadda;

sub yaddaify {1}

package Quux;

@Quux::ISA = ('Foo', 'Yadda');

sub quuxify {1}

1;
