package Params::Validate;

use strict;

BEGIN
{
    sub SCALAR    () { 1 }
    sub ARRAYREF  () { 2 }
    sub HASHREF   () { 4 }
    sub CODEREF   () { 8 }
    sub GLOB      () { 16 }
    sub GLOBREF   () { 32 }
    sub SCALARREF () { 64 }
    sub UNKNOWN   () { 128 }
    sub UNDEF     () { 256 }
    sub OBJECT    () { 512 }

    sub HANDLE    () { 16 | 32 }
}

require Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %OPTIONS $called $options);
@ISA = qw(Exporter);

my %tags = ( types => [ qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE UNDEF OBJECT ) ],
	   );

%EXPORT_TAGS = ( 'all' => [ qw( validate validate_pos validation_options ), map { @{ $tags{$_} } } keys %tags ],
		 %tags,
	       );
@EXPORT_OK = ( @{ $EXPORT_TAGS{all} }, 'set_options' );
@EXPORT = qw( validate validate_pos );

$VERSION = '0.09';

# Matt Sergeant came up with this prototype, which slickly takes the
# first array (which should be the caller's @_), and makes it a
# reference.  Everything after is the parameters for validation.
sub validate_pos (\@@)
{
    my $p = shift;
    my @specs = @_;

    if ( $ENV{PERL_NO_VALIDATION} )
    {
	foreach my $x (0..$#specs)
	{
	    if ( $x > $#{$p} )
	    {
		$p->[$x] = $specs[$x]->{default} if ref $specs[$x] && exists $specs[$x]->{default};
	    }
	}

	return @$p;
    }

    # I'm too lazy to pass these around all over the place.
    local $called = (caller(1))[3];
    local $options = _get_options( (caller(0))[0] );

    my $min = 0;

    while (1)
    {
	last if _is_optional( $specs[$min] );
	$min++;
    }

    my $max = scalar @specs;

    my $actual = scalar @$p;
    unless ($actual >= $min && ( $options->{allow_extra} || $actual <= $max ) )
    {
	my $minmax = $options->{allow_extra} ? "at least $min" : ( $min != $max ? "$min - $max" : $max );
	my $val = $options->{allow_extra} ? $min : $max;
	$minmax .= $val != 1 ? ' were' : ' was';
	$options->{on_fail}->( "$actual parameter" . ($actual != 1 ? 's' : '') . " " . ($actual != 1 ? 'were' : 'was' ) . " passed to $called but $minmax expected\n" );
    }

    foreach ( 0..$#$p )
    {
	_validate_one_param( $p->[$_], $specs[$_], "Parameter #" . ($_ + 1) )
	    if ref $specs[$_];
    }

    return unless wantarray;

    # Make a copy so we don't alter @_ for the caller.
    my @p = @$p;

    # Add defaults to existing parameters if called in list context
    foreach (0..$#specs)
    {
	next unless ref $specs[$_];
	next if $specs[$_]->{optional} || ! exists $specs[$_]->{default};

	$p[$_] = $specs[$_]->{default};
    }

    return @p;
}

sub validate (\@$)
{
    my $p = shift;
    my $specs = shift;

    if ( ref $p->[0] && UNIVERSAL::isa( $p->[0], 'HASH' ) )
    {
	# Make a copy so we don't alter the hash reference for the
	# caller.
	$p = { %{ $p->[0] } };
    }
    else
    {
	$options->{on_fail}->( "Odd number of parameters in call to $called when named parameters were expected\n" )
	    if @$p % 2;

	# This is to hashify the list.  Also has the side effect of
	# copying the values so we can play with it however we want
	# without actually changing @_.
	$p = {@$p};
    }

    if ( $ENV{PERL_NO_VALIDATION} )
    {
	while ( my ($key, $spec) = each %$specs )
	{
	    if ( ! exists $p->{$key} && ref $spec && exists $spec->{default} )
	    {
		$p->{$key} = $spec->{default};
	    }
	}

	return %$p;
    }

    local $called = (caller(1))[3];
    local $options = _get_options( (caller(0))[0] );

    if ( $options->{ignore_case} || $options->{strip_leading} )
    {
	$specs = _normalize_named($specs);
	$p = _normalize_named($p);
    }

    unless ( $options->{allow_extra} )
    {
	if ( my @unmentioned = grep { ! exists $specs->{$_} } keys %$p )
	{
	    $options->{on_fail}->( "The following parameter" . (@unmentioned > 1 ? 's were' : ' was') .
				   " passed in the call to $called but " .
				   (@unmentioned > 1 ? 'were' : 'was') .
				   " not listed in the validation options: @unmentioned\n" );
	}
    }

    my @missing;
    foreach (keys %$specs)
    {
	next if exists $p->{$_};
	push @missing, $_ unless _is_optional($specs->{$_});
    }

    if (@missing)
    {
	my $missing = join ', ', map {"'$_'"} @missing;
	$options->{on_fail}->( "Mandatory parameter" . (@missing > 1 ? 's': '') . " $missing missing in call to $called\n" );
    }

    foreach (keys %$specs)
    {
	_validate_one_param( $p->{$_}, $specs->{$_}, "The '$_' parameter" )
	    if ref $specs->{$_} && exists $p->{$_};
    }

    return unless wantarray;

    # Add defaults to existing parameters if called in list context
    while (my ($key, $spec) = each %$specs)
    {
	next if exists $p->{$key} || ! exists $spec->{default};

	$p->{$key} = $spec->{default};
    }
    return %$p;
}

sub _is_optional
{
    my $spec = shift;

    # foo => 1  used to mark mandatory argument with no other validation
    return ! $spec unless ref $spec;

    return $spec->{optional} if exists $spec->{optional};

    # If it has a default it has to be optional
    return exists $spec->{default};
}

sub _normalize_named
{
    my $h = shift;

    # we really don't want to mess with the original
    my %copy = %$h;

    if ( $options->{ignore_case} )
    {
	foreach (keys %copy)
	{
	    $copy{ lc $_ } = delete $copy{$_};
	}
    }

    if ( $options->{strip_leading} )
    {
	foreach my $key (keys %copy)
	{
	    my $new;
	    ($new = $key) =~ s/^$options->{strip_leading}//;
	    $copy{$new} = delete $copy{$key};
	}
    }

    return \%copy;
}

sub _validate_one_param
{
    my $value = shift;
    my $spec = shift;
    my $id = shift;

    if ( exists $spec->{type} )
    {
	my $type = _get_type($value);
	unless ( $type & $spec->{type} )
	{
	    my @is = _typemask_to_strings($type);
	    my @allowed = _typemask_to_strings($spec->{type});
	    my $article = $is[0] =~ /^[aeiou]/i ? 'an' : 'a';
	    $options->{on_fail}->( "$id to $called was $article '@is', which is not one of the allowed types: @allowed\n" );
	}
    }

    if ( exists $spec->{isa} )
    {
	foreach ( ref $spec->{isa} ? @{ $spec->{isa} } : $spec->{isa} )
	{
	    unless ( UNIVERSAL::isa( $value, $_ ) )
	    {
		my $is = ref $value ? ref $value : 'plain scalar';
		my $article1 = $_ =~ /^[aeiou]/i ? 'an' : 'a';
		my $article2 = $is =~ /^[aeiou]/i ? 'an' : 'a';
		$options->{on_fail}->( "$id to $called was not $article1 '$_' (it is $article2 $is)\n" );
	    }
	}
    }

    if ( exists $spec->{can} )
    {
	foreach ( ref $spec->{can} ? @{ $spec->{can} } : $spec->{can} )
	{
	    $options->{on_fail}->( "$id to $called does not have the method: '$_'\n" ) unless UNIVERSAL::can( $value, $_ );
	}
    }

    if ($spec->{callbacks})
    {
	$options->{on_fail}->( "'callbacks' validation parameter for $called must be a hash reference\n" )
	    unless UNIVERSAL::isa( $spec->{callbacks}, 'HASH' );

	foreach ( keys %{ $spec->{callbacks} } )
	{
	    $options->{on_fail}->( "callback '$_' for $called is not a subroutine reference\n" )
		unless UNIVERSAL::isa( $spec->{callbacks}{$_}, 'CODE' );

	    $options->{on_fail}->( "$id to $called did not pass the '$_' callback\n" )
		unless $spec->{callbacks}{$_}->($value);
	}
    }
}

{
    # if it UNIVERSAL::isa the string on the left then its the type on
    # the right
    my %isas = ( 'ARRAY'  => ARRAYREF,
		 'HASH'   => HASHREF,
		 'CODE'   => CODEREF,
		 'GLOB'   => GLOBREF,
		 'SCALAR' => SCALARREF,
	       );

    sub _get_type
    {
	my $value = shift;

	return UNDEF unless defined $value;

	unless (ref $value)
	{
	    # catches things like:  my $fh = do { local *FH; };
	    return GLOB if UNIVERSAL::isa( \$value, 'GLOB' );
	    return SCALAR;
	}

	my $or = 0;
	if ( ! grep { ref $value eq $_ } keys %isas )
	{
	    $or = OBJECT;
	}

	foreach ( keys %isas )
	{
	    return $isas{$_} | $or if UNIVERSAL::isa( $value, $_ );
	}

	# I really hope this never happens.
	return UNKNOWN;
    }
}

{
    my %type_to_string = ( SCALAR()    => 'scalar',
			   ARRAYREF()  => 'arrayref',
			   HASHREF()   => 'hashref',
			   CODEREF()   => 'coderef',
			   GLOB()      => 'glob',
			   GLOBREF()   => 'globref',
			   SCALARREF() => 'scalarref',
			   UNDEF()     => 'undef',
			   OBJECT()    => 'object',
			   UNKNOWN()   => 'unknown',
			 );

    sub _typemask_to_strings
    {
	my $mask = shift;

	my @types;
	foreach ( SCALAR, ARRAYREF, HASHREF, CODEREF, GLOB, GLOBREF, SCALARREF, UNDEF, OBJECT, UNKNOWN )
	{
	    push @types, $type_to_string{$_} if $mask & $_;
	}
	return @types ? @types : ('unknown');
    }
}

{
    my %defaults = ( ignore_case => 0,
		     strip_leading => 0,
		     allow_extra => 0,
		     on_fail => sub { require Carp;  Carp::confess(shift()) },
		   );

    sub validation_options
    {
	my %opts = @_;

	my $caller = caller;

	foreach ( keys %defaults )
	{
	    $opts{$_} = $defaults{$_} unless exists $opts{$_};
	}

	$OPTIONS{$caller} = \%opts;
    }

    sub _get_options
    {
	my $caller = shift;
	return exists $OPTIONS{$caller} ? $OPTIONS{$caller} : \%defaults;
    }
}

1;

__END__

=head1 NAME

Params::Validate - Validate method/function parameters

=head1 SYNOPSIS

  use Params::Validate qw(:all);

  # takes named params (hash or hashref)
  sub foo
  {
      validate( @_, { foo => 1, # mandatory
		      bar => 0, # optional
		    }
	      );
  }

  # takes positional params
  sub bar
  {
      # first two are mandatory, third is optional
      validate_pos( @_, 1, 1, 0 );
  }


  sub foo2
  {
      validate( @_,
		{ foo =>
		  # specify a type
		  { type => ARRAYREF },

		  bar =>
		  # specify an interface
		  { can => [ 'print', 'flush', 'frobnicate' ] },

		  baz =>
		  { type => SCALAR,   # a scalar ...
		    callbacks =>
		      # ... that is a plain integer ...
		    { 'numbers only' => sub { shift() =~ /^\d+$/ },
		      # ... and smaller than 90
		      'less than 90' => sub { shift() < 90 },
		    },
		  }
		}
	      );
  }

  sub with_defaults
  {
       my %p = validate( @_, { foo => 1, # required
                               # $p{bar} will be 99 if bar is not
                               # given.  bar is now optional.
                               bar => { default => 99 } } );
  }

  sub pos_with_defaults
  {
       my @p = validate( @_, 1, { default => 99 } );
  }

=head1 DESCRIPTION

The Params::Validate module allows you to validate method or function
call parameters to an arbitrary level of specificity.  At the simplest
level, it is capable of validating the required parameters were given
and that no unspecified additional parameters were passed in.

It is also capable of determining that a parameter is of a specific
type, that it is an object of a certain class hierarchy, that it
possesses certain methods, or applying validation callbacks to
arguments.

=head2 EXPORT

The module always exports the C<validate> and C<validate_pos>
functions.

In addition, it can export the following constants, which are used as
part of the type checking.  These are C<SCALAR>, C<ARRAYREF>,
C<HASHREF>, C<CODEREF>, C<GLOB>, C<GLOBREF>, and C<SCALARREF>,
C<UNDEF>, C<OBJECT>, and C<HANDLE>.  These are explained in the
section on L<Type Validation|Params::Validate/Type Validation>.

The constants are available via the export tag C<:types>.  There is
also an C<:all> tag which includes all of the constants as well as the
C<validation_options> function.

=head1 PARAMETER VALIDATION

The validation mechanisms provided by this module can handle both
named or positional parameters.  For the most part, the same features
are available for each.  The biggest difference is the way that the
validation specification is given to the relevant subroutine.  The
other difference is in the error messages produced when validation
checks fail.

When handling named parameters, the module is capable of handling
either a hash or a hash reference transparently.

Subroutines expecting named parameters should call the C<validate>
subroutine like this:

 validate( @_, { parameter1 => validation spec,
                 parameter2 => validation spec,
                 ...
               } );

Subroutines expected positional parameters should call the
C<validate_pos> subroutine like this:

 validate_pos( @_, { validation spec }, { validation spec } );

=head2 Mandatory/Optional Parameters

If you just want to specify that some parameters are mandatory and
others are optional, this can be done very simply.

For a subroutine expecting named parameters, you would do this:

 validate( @_, { foo => 1, bar => 1, baz => 0 } );

This says that the C<foo> and C<bar> parameters are mandatory and that
the C<baz> parameter is optional.  The presence of any other
parameters will cause an error.

For a subroutine expecting positional parameters, you would do this:

 validate_pos( @_, 1, 1, 0, 0 );

This says that you expect at least 2 and no more than 4 parameters.
If you have a subroutine that has a minimum number of parameters but
can take any maximum number, you can do this:

 validate_pos( @_, 1, 1, (0) x @_ - 2 );

This will always be valid as long as at least two parameters are
given.  A similar construct could be used for the more complex
validation parameters described further on.

Please note that this:

 validate_pos( @_, 1, 1, 0, 1, 1 );

makes absolutely no sense, so don't do it.  Any zeros must come at the
end of the validation specification.

In addition, if you specify that a parameter can have a default, then
it is considered optional.

=head2 Type Validation

This module supports the following simple types, which can be
L<exported as constants|EXPORT>:

=over 4

=item * SCALAR

A scalar which is not a reference, such as C<10> or C<'hello'>.  A
parameter that is undefined is B<not> treated as a scalar.  If you
want to allow undefined values, you will have to specify C<SCALAR |
UNDEF>.

=item * ARRAYREF

An array reference such as C<[1, 2, 3]> or C<\@foo>.

=item * HASHREF

A hash reference such as C<{ a => 1, b => 2 }> or C<\%bar>.

=item * CODEREF

A subroutine reference such as C<\&foo_sub> or C<sub { print "hello" }>.

=item * GLOB

This one is a bit tricky.  A glob would be something like C<*FOO>, but
not C<\*FOO>, which is a glob reference.  It should be noted that this
trick:

 my $fh = do { local *FH; };

makes C<$fh> a glob, not a glob reference.  On the other hand, the
return value from C<Symbol::gensym> is a glob reference.  Either can
be used as a file or directory handle.

=item * GLOBREF

A glob reference such as C<\*FOO>.  See the L<GLOB|GLOB> entry above
for more details.

=item * SCALARREF

A reference to a scalar such as C<\$x>.

=item * UNDEF

An undefined value

=item * OBJECT

A blessed reference.

=item * HANDLE

This option is special, in that it is just a shortcut for C<GLOB |
GLOBREF>.  However, it seems likely that most people interested in
either globs or glob references are likely to really be interested in
whether what is being in is a potentially valid file or directory
handle.

=back

To specify that a parameter must be of a given type when using named
parameters, do this:

 validate( @_, { foo => { type => SCALAR },
                 bar => { type => HASHREF } } );

If a parameter can be of more than one type, just use the bitwise or
(C<|>) operator to combine them.

 validate( @_, { foo => { type => GLOB | GLOBREF } );

For positional parameters, this can be specified as follows:

 validate_pos( @_, { type => SCALAR | ARRAYREF }, { type => CODEREF } );

=head2 Interface Validation

To specify that a parameter is expected to have a certain set of
methods, we can do the following:

 validate( @_,
           { foo =>
             # just has to be able to ->bar
             { can => 'bar' } } );

 ... or ...

 validate( @_,
           { foo =>
             # must be able to ->bar and ->print
             { can => [ qw( bar print ) ] } } );

=head2 Class Validation

A word of warning.  When constructing your external interfaces, it is
probably better to specify what methods you expect an object to
have rather than what class it should be of (or a child of).  This
will make your API much more flexible.

With that said, if you want to verify that an incoming parameter
belongs to a class (or child class) or classes, do:

 validate( @_,
           { foo =>
             { isa => 'My::Frobnicator' } } );

 ... or ...

 validate( @_,
           { foo =>
             { isa => [ qw( My::Frobnicator IO::Handle ) ] } } );
 # must be both, not either!

=head2 Callback Validation

If none of the above are enough, it is possible to pass in one or more
callbacks to validate the parameter.  The callback will be given the
B<value> of the parameter as its sole argument.  Callbacks are
specified as hash reference.  The key is an id for the callback (used
in error messages) and the value is a subroutine reference, such as:

 validate( @_,
           { foo =>
             callbacks =>
             { 'smaller than a breadbox' => sub { shift() < $breadbox },
               'green or blue' =>
                sub { $_[0] eq 'green' || $_[0] eq 'blue' } } } );

On a side note, I would highly recommend taking a look at Damian
Conway's Regexp::Common module, which could greatly simply the
callbacks you use, as it provides patterns useful for validating all
sorts of data.

=head2 Mandatory/Optional Revisited

If you want to specify something such as type or interface, plus the
fact that a parameter can be optional, do this:

 validate( @_, { foo =>
                 { type => SCALAR },
                 bar =>
                 { type => ARRAYREF, optional => 1 } } );

or this for positional parameters:

 validate_pos( @_, { type => SCALAR }, { type => ARRAYREF, optional => 1 } );

By default, parameters are assumed to be mandatory unless specified as
optional.

=head2 Specifying defaults

If the C<validate> or C<validate_pos> functions are called in a list
context, they will return an array or hash containing the original
parameters plus defaults as indicated by the validation spec.

If the function is not called in a list context, providing a default
in the validation spec still indicates that the parameter is optional.

The hash or array returned from the function will always be a copy of
the original parameters, in order to leave C<@_> untouched for the
calling function.

Simple examples of defaults would be:

 my %p = validate( @_, { foo => 1, bar => { default => 99 } } );

 my @p = validate( @_, 1, { default => 99 } );

=head1 USAGE NOTES

=head2 Validation failure

By default, when validation fails C<Params::Validate> calls
C<Carp::confess>.  This can be overridden by setting the C<on_fail>
option, which is described in the L<"GLOBAL" OPTIONS|"GLOBAL" OPTIONS>
section.

=head2 Method calls

When using this module to validate the parameters passed to a method
call, you will probably want to remove the class/object from the
parameter list B<before> calling C<validate> or C<validate_pos>.  If
your method expects named parameters, then this is necessary for the
C<validate> function to actually work, otherwise C<@_> will not
contain a hash, but rather your object (or class) B<followed> by a
hash.

Thus the idiomatic usage of C<validate> in a method call will look
something like this:

 sub method
 {
     my $self = shift;

     my %params = validate( @_, { foo => 1, bar => { type => ARRAYREF } } );
 }

=head1 "GLOBAL" OPTIONS

Because the calling syntax for the C<validate> and C<validate_pos>
functions does not make it possible to specify any options other than
the the validation spec, it is possible to set some options as
pseudo-'globals'.  These allow you to specify such things as whether
or not the validation of named parameters should be case sensitive,
for one example.

These options are called pseudo-'globals' because these settings are
B<only applied to calls originating from the package that set the
options>.

In other words, if I am in package C<Foo> and I call
C<Params::Validate::validation_options>, those options are only in
effect when I call C<validate> from package C<Foo>.

While this is quite different from how most other modules operate, I
feel that this is necessary in able to make it possible for one
module/application to use Params::Validate while still using other
modules that also use Params::Validate, perhaps with different
options set.

The downside to this is that if you are writing an app with a standard
calling style for all functions, and your app has ten modules, B<each
module must include a call to C<Params::Validate::validation_options>>.

=head2 Options

=over 4

=item * ignore_case => $boolean

This is only relevant when dealing with named parameters.  If it is
true, then the validation code will ignore the case of parameter
names.  Defaults to false.

=item * strip_leading => $characters

This too is only relevant when dealing with named parameters.  If this
is given then any parameters starting with these characters will be
considered equivalent to parameters without them entirely.  For
example, if this is specified as '-', then C<-foo> and C<foo> would be
considered identical.

=item * allow_extra => $boolean

If true, then the validation routine will allow extra parameters not
named in the validation specification.  In the case of positional
parameters, this allows an unlimited number of maximum parameters
(though a minimum may still be set).  Defaults to false.

=item * on_fail => $callback

If given, this callback will be called whenever a validation check
fails.  It will be called with a single parameter, which will be a
string describing the failure.  This is useful if you wish to have
this module throw exceptions as objects rather than as strings, for
example.

This callback is expected to C<die> internally.  If it does not, the
validation will proceed onwards, with unpredictable results.

The default is to simply use the Carp module's C<confess()> function.

=head1 DISABLING VALIDATION

If the environment variable C<PERL_NO_VALIDATION> is set to something
true, then all calls to the validation functions are turned into
no-ops.  This may be useful if you only want to use this module during
development but don't want the speed hit during production.

The only error that will be caught will be when an odd number of
parameters are passed into a function/method that expects a hash.

=head1 LIMITATIONS

Right now there is no way (short of a callback) to specify that
something must be of one of a list of classes, or that it must possess
one of a list of methods.  If this is desired, it can be added in the
future.

Ideally, there would be only one validation function.  If someone
figures out how to do this, please let me know.

=head1 SEE ALSO

Getargs::Long - similar capabilities with a different interface.  If
you like what Params::Validate does but not its 'feel' try this one
instead.

Carp::Assert and Class::Contract - other modules in the general spirit
of validating that certain things are true before/while/after
executing actual program code.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
