use strict;

print "1..51\n";

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
	check(); # 10
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
		     bar => do { local *FH; *FH; },
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
		     quux => \*CODE,
		   ) };
	check(); # 15
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
		    { type => ARRAY },
		    baz =>
		    { type => HASH },
		    quux =>
		    { type => SCALAR | ARRAY },
		    brax =>
		    { type => SCALAR | HASH },
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
		    { type => CODE },
		  }
	    );
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

{
    my $x = 0;
    sub check
    {
	my $expect = $expect[$x++];
	$expect ?
	    ok( $@ =~ /$expect/ ? 1 : 0,
		$@ ? "$@ did not match:\n$expect" : 'no error when error was expected' ) :
	    ok( ! $@, $@ );
    }
}

sub sub12
{
    validate( @_, { foo =>
		    { type => ARRAY,
		      callbacks =>
		      { '5 elements' => sub { @{shift()} == 5 } }
		    } } );
}

sub sub13
{
    validate( @_,
	      { type => SCALAR },
	      { type => ARRAY,
		callbacks => 
		{ '5 elements' => sub { @{shift()} == 5 } }
	      } );
}

sub sub14
{
    validate( @_,
	      { type => SCALAR },
	      { type => ARRAY },
	      { isa => 'Bar' },
	    );
}

sub sub15
{
    validate( @_,
	      { foo => 1,
		bar => { type => ARRAY }
	      } );
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
