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
    sub BOOLEAN   () { 1 | 256 }

    my $val = $ENV{PERL_NO_VALIDATION} ? 1 : 0;
    eval "sub NO_VALIDATE () { $val }";
}

require Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %OPTIONS $options);
@ISA = qw(Exporter);

my %tags =
    ( types =>
      [ qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF
            SCALARREF HANDLE BOOLEAN UNDEF OBJECT ) ],
    );

%EXPORT_TAGS =
    ( 'all' => [ qw( validate validate_pos validation_options validate_with ),
                 map { @{ $tags{$_} } } keys %tags ],
      %tags,
    );

@EXPORT_OK = ( @{ $EXPORT_TAGS{all} }, 'set_options' );
@EXPORT = qw( validate validate_pos );

$VERSION = '0.24';

=pod

=begin internals

Various internals notes (for me and any future readers of this
monstrosity):

- A lot of the weirdness is _intentional_, because it optimizes for
  the _success_ case.  It does not really matter how slow the code is
  after it enters a path that leads to reporting failure.  But the
  "success" path should be as fast as possible.

-- We only calculate $called as needed for this reason, even though it
   means copying code all over.

- All the validation routines need to be careful never to alter the
  references that are passed.

-- The code assumes that _most_ callers will not be using the
   skip_leading or ignore_case features.  In order to not alter the
   references passed in, we copy them wholesale when normalize them to
   make these features work.  This is slower but lets us be faster
   when not using them.

=end

=cut


# Matt Sergeant came up with this prototype, which slickly takes the
# first array (which should be the caller's @_), and makes it a
# reference.  Everything after is the parameters for validation.
sub validate_pos (\@@)
{
    return if NO_VALIDATE && ! defined wantarray;

    my $p = shift;

    my @specs = @_;

    my @p = @$p;
    if ( NO_VALIDATE )
    {
        # if the spec is bigger that's where we can start adding
        # defaults
        for ( my $x = $#p + 1; $x <= $#specs; $x++ )
	{
            $p[$x] =
                $specs[$x]->{default}
                    if ref $specs[$x] && exists $specs[$x]->{default};
	}

	return wantarray ? @p : \@p;
    }

    # I'm too lazy to pass these around all over the place.
    local $options ||= _get_options( (caller(0))[0] )
        unless defined $options;

    my $min = 0;

    while (1)
    {
        last unless ( ref $specs[$min] ?
                      ! ( exists $specs[$min]->{default} || $specs[$min]->{optional} ) :
                      $specs[$min] );

	$min++;
    }

    my $max = scalar @specs;

    my $actual = scalar @p;
    unless ($actual >= $min && ( $options->{allow_extra} || $actual <= $max ) )
    {
	my $minmax =
            ( $options->{allow_extra} ?
              "at least $min" :
              ( $min != $max ? "$min - $max" : $max ) );

	my $val = $options->{allow_extra} ? $min : $max;
	$minmax .= $val != 1 ? ' were' : ' was';

        my $called = _get_called();

	$options->{on_fail}->
            ( "$actual parameter" .
              ($actual != 1 ? 's' : '') .
              " " .
              ($actual != 1 ? 'were' : 'was' ) .
              " passed to $called but $minmax expected\n" );
    }

    my $bigger = $#p > $#specs ? $#p : $#specs;
    foreach ( 0..$bigger )
    {
	my $spec = $specs[$_];

	next unless ref $spec;

	if ( $_ <= $#p )
	{
	    _validate_one_param( $p[$_], $spec, "Parameter #" . ($_ + 1) );
	}

	$p[$_] = $spec->{default} if $_ > $#p && exists $spec->{default};
    }

    return wantarray ? @p : \@p;
}

sub validate (\@$)
{
    return if NO_VALIDATE && ! defined wantarray;

    my $p = $_[0];

    my $specs = $_[1];

    local $options = _get_options( (caller(0))[0] ) unless defined $options;

    unless ( NO_VALIDATE )
    {
        if ( ref $p eq 'ARRAY' )
        {
            # we were called as validate( @_, ... ) where @_ has a
            # single element, a hash reference
            if ( ref $p->[0] )
            {
                $p = $p->[0];
            }
            elsif ( @$p % 2 )
            {
                my $called = _get_called();

                $options->{on_fail}->
                    ( "Odd number of parameters in call to $called " .
                      "when named parameters were expected\n" );
            }
            else
            {
                $p = {@$p};
            }
        }
    }

    if ( $options->{ignore_case} || $options->{strip_leading} )
    {
	$specs = _normalize_named($specs);
	$p = _normalize_named($p);
    }

    if ( NO_VALIDATE )
    {
        return
            ( wantarray ?
              (
               # this is a has containing just the defaults
               ( map { $_ => $specs->{$_}->{default} }
                 grep { ref $specs->{$_} && exists $specs->{$_}->{default} }
                 keys %$specs
               ),
               # this recapitulates the login seen above in order to
               # derefence our parameters properly
               ( ref $p eq 'ARRAY' ?
                 ( ref $p->[0] ?
                   %{ $p->[0] } :
                   @$p ) :
                 %$p
               )
              ) :
              do
              {
                  my $ref =
                      ( ref $p eq 'ARRAY' ?
                        ( ref $p->[0] ?
                          $p->[0] :
                          {@$p} ) :
                        $p
                      );

                  foreach ( grep { ref $specs->{$_} && exists $specs->{$_}->{default} }
                            keys %$specs )
                  {
                      $ref->{$_} = $specs->{$_}->{default}
                          unless exists $ref->{$_};
                  }

                  return $ref;
              }
            );
    }

    unless ( $options->{allow_extra} )
    {
        my $called = _get_called();

	if ( my @unmentioned = grep { ! exists $specs->{$_} } keys %$p )
	{
	    $options->{on_fail}->
                ( "The following parameter" . (@unmentioned > 1 ? 's were' : ' was') .
                  " passed in the call to $called but " .
                  (@unmentioned > 1 ? 'were' : 'was') .
                  " not listed in the validation options: @unmentioned\n" );
	}
    }

    my @missing;
 OUTER:
    while ( my ($key, $spec) = each %$specs )
    {
	if ( ! exists $p->{$key} &&
             ( ref $spec ?
               ! (
                  do
                  {
                      # we want to short circuit the loop here if we
                      # can assign a default, because there's no need
                      # check anything else at all.
                      if ( exists $spec->{default} )
                      {
                          $p->{$key} = $spec->{default};
                          next OUTER;
                      }
                  }
                  ||
                  do
                  {
                      # Similarly, an optional parameter that is
                      # missing needs no additional processing.
                      $spec->{optional} && next OUTER
                  }
                 ) :
               $spec )
           )
        {
            push @missing, $key;
	}
        # Can't validate a non hashref spec beyond the presence or
        # absence of the parameter.
        elsif (ref $spec)
        {
	    _validate_one_param( $p->{$key}, $spec, "The '$key' parameter" );
	}
    }

    if (@missing)
    {
        my $called = _get_called();

	my $missing = join ', ', map {"'$_'"} @missing;
	$options->{on_fail}->
            ( "Mandatory parameter" .
              (@missing > 1 ? 's': '') .
              " $missing missing in call to $called\n" );
    }

    return wantarray ? %$p : $p;
}

sub validate_with
{
    return if NO_VALIDATE && ! defined wantarray;

    my %p = @_;

    local $options = _get_options( (caller(0))[0], %p );

    unless ( NO_VALIDATE )
    {
        unless ( exists $options->{called} )
        {
            $options->{called} = (caller( $options->{stack_skip} ))[3];
        }

    }

    if ( UNIVERSAL::isa( $p{spec}, 'ARRAY' ) )
    {
	return validate_pos( @{ $p{params} }, @{ $p{spec} } );
    }
    else
    {
        # intentionally ignore the prototype because this contains
        # either an array or hash reference, and validate() will
        # handle either one properly
	return &validate( $p{params}, $p{spec} );
    }
}

sub _normalize_named
{
    # intentional copy so we don't destroy original
    my %h = %{ $_[0] };

    if ( $options->{ignore_case} )
    {
	foreach (keys %h)
	{
	    $h{ lc $_ } = delete $h{$_};
	}
    }

    if ( $options->{strip_leading} )
    {
	foreach my $key (keys %h)
	{
	    my $new;
	    ($new = $key) =~ s/^$options->{strip_leading}//;
	    $h{$new} = delete $h{$key};
	}
    }

    return \%h;
}

sub _validate_one_param
{
    my ($value, $spec, $id) = @_;

    if ( exists $spec->{type} )
    {
	unless ( _get_type($value) & $spec->{type} )
	{
            my $type = _get_type($value);

	    my @is = _typemask_to_strings($type);
	    my @allowed = _typemask_to_strings($spec->{type});
	    my $article = $is[0] =~ /^[aeiou]/i ? 'an' : 'a';

            my $called = _get_called(1);

	    $options->{on_fail}->
                ( "$id to $called was $article '@is', which " .
                  "is not one of the allowed types: @allowed\n" );
	}
    }

    # short-circuit for common case
    return unless $spec->{isa} || $spec->{can} || $spec->{callbacks};

    if ( exists $spec->{isa} )
    {
	foreach ( ref $spec->{isa} ? @{ $spec->{isa} } : $spec->{isa} )
	{
	    unless ( UNIVERSAL::isa( $value, $_ ) )
	    {
		my $is = ref $value ? ref $value : 'plain scalar';
		my $article1 = $_ =~ /^[aeiou]/i ? 'an' : 'a';
		my $article2 = $is =~ /^[aeiou]/i ? 'an' : 'a';

                my $called = _get_called(1);

		$options->{on_fail}->
                    ( "$id to $called was not $article1 '$_' " .
                      "(it is $article2 $is)\n" );
	    }
	}
    }

    if ( exists $spec->{can} )
    {
	foreach ( ref $spec->{can} ? @{ $spec->{can} } : $spec->{can} )
	{
            unless ( UNIVERSAL::can( $value, $_ ) )
            {
                my $called = _get_called(1);

                $options->{on_fail}->( "$id to $called does not have the method: '$_'\n" );
            }
	}
    }

    if ( $spec->{callbacks} )
    {
        unless ( UNIVERSAL::isa( $spec->{callbacks}, 'HASH' ) )
        {
            my $called = _get_called(1);

            $options->{on_fail}->
                ( "'callbacks' validation parameter for $called must be a hash reference\n" );
        }


	foreach ( keys %{ $spec->{callbacks} } )
	{
            unless ( UNIVERSAL::isa( $spec->{callbacks}{$_}, 'CODE' ) )
            {
                my $called = _get_called(1);

                $options->{on_fail}->( "callback '$_' for $called is not a subroutine reference\n" );
            }

            unless ( $spec->{callbacks}{$_}->($value) )
            {
                my $called = _get_called(1);

                $options->{on_fail}->( "$id to $called did not pass the '$_' callback\n" );
            }
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
    my %simple_refs = map { $_ => 1 } keys %isas;

    sub _get_type
    {
	return UNDEF unless defined $_[0];

	my $ref = ref $_[0];
	unless ($ref)
	{
	    # catches things like:  my $fh = do { local *FH; };
	    return GLOB if UNIVERSAL::isa( \$_[0], 'GLOB' );
	    return SCALAR;
	}

	return $isas{$ref} if $simple_refs{$ref};

	foreach ( keys %isas )
	{
	    return $isas{$_} | OBJECT if UNIVERSAL::isa( $_[0], $_ );
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
	foreach ( SCALAR, ARRAYREF, HASHREF, CODEREF, GLOB, GLOBREF,
                  SCALARREF, UNDEF, OBJECT, UNKNOWN )
	{
	    push @types, $type_to_string{$_} if $mask & $_;
	}
	return @types ? @types : ('unknown');
    }
}

{
    my %defaults = ( ignore_case   => 0,
		     strip_leading => 0,
		     allow_extra   => 0,
		     on_fail       => sub { require Carp;
                                            Carp::confess($_[0]) },
		     stack_skip    => 1,
		   );

    *set_options = \&validation_options;
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
	my ( $caller, %override ) = @_;

        if ( %override )
        {
            return
                ( $OPTIONS{$caller} ?
                  { %{ $OPTIONS{$caller} },
                    %override } :
                  { %defaults, %override }
                );
        }
        else
        {
            return
                ( exists $OPTIONS{$caller} ?
                  $OPTIONS{$caller} :
                  \%defaults );
        }
    }
}

sub _get_called
{
    my $extra_skip = $_[0] || 0;

    # always add one more for this sub
    $extra_skip++;

    return ( exists $options->{called} ?
             $options->{called} :
             ( caller( $options->{stack_skip} + $extra_skip ) )[3]
           );
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

  sub sets_options_on_call
  {
       my %p = validate_with
                   ( params => \@_,
                     spec   => { foo => { type SCALAR, default => 2 } },
                     ignore_case   => 1,
                     strip_leading => '-',
                   );
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

It also has an additional function available for export,
C<validate_with>, which can be used to validate any type of
parameters, and set various options on a per-invocation basis.

In addition, it can export the following constants, which are used as
part of the type checking.  These are C<SCALAR>, C<ARRAYREF>,
C<HASHREF>, C<CODEREF>, C<GLOB>, C<GLOBREF>, and C<SCALARREF>,
C<UNDEF>, C<OBJECT>, C<BOOLEAN>, and C<HANDLE>.  These are explained
in the section on L<Type Validation|Params::Validate/Type Validation>.

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

Subroutines expecting positional parameters should call the
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

 validate_pos( @_, 1, 1, (0) x (@_ - 2) );

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

=item * BOOLEAN

This is a special option, and is just a shortcut for C<UNDEF | SCALAR>.

=item * HANDLE

This option is also special, and is just a shortcut for C<GLOB |
GLOBREF>.  However, it seems likely that most people interested in
either globs or glob references are likely to really be interested in
whether the parameter in questoin could be a valid file or directory
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

With that said, if you want to validate_with that an incoming
parameter belongs to a class (or child class) or classes, do:

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

In scalar context, a hash reference or array reference will be
returned, as appropriate.

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

When this is turned on, we have to copy more data around internally,
leading to a potential speed impact.

=item * strip_leading => $characters

This too is only relevant when dealing with named parameters.  If this
is given then any parameters starting with these characters will be
considered equivalent to parameters without them entirely.  For
example, if this is specified as '-', then C<-foo> and C<foo> would be
considered identical.

When this is turned on, we have to copy more data around internally,
leading to a potential speed impact.

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

=item * stack_skip => $number

This tells Params::Validate how many stack frames to skip when finding
a subroutine name to use in error messages.  By default, it looks one
frame back, at the immediate caller to C<validate> or C<validate_pos>.
If this option is set, then the given number of frames are skipped
instead.

=back

=head1 PER-INVOCATION OPTIONS

The C<validate_with> function can be used to set the options listed above on
a per-invocation basis.  For example:

  my %p =
      validate_with
          ( params => \@_,
            spec   => { foo => { type => SCALAR },
                        bar => { default => 10 } },
            allow_extra => 1,
          );

In addition to the options listed above, it is also possible to set
the option C<called>, which should be a string.  This string will be
used in any error messages caused by a failure to meet the validation
spec.

This subroutine will validate named parameters as a hash if the
C<spec> parameter is a hash reference.  If it is an array reference,
the parameters are assumed to be positional.

  my %p =
      validate_with
          ( params => \@_,
            spec   => { foo => { type => SCALAR },
                        bar => { default => 10 } },
            allow_extra => 1,
            called => 'The Quux::Baz class constructor',
          );

  my @p =
      validate_with
          ( params => \@_,
            spec   => [ { type => SCALAR },
                        { default => 10 } ],
            allow_extra => 1,
            called => 'The Quux::Baz class constructor',
          );

=head1 DISABLING VALIDATION

If the environment variable C<PERL_NO_VALIDATION> is set to something
true, then all calls to the validation functions are turned into
no-ops.  This may be useful if you only want to use this module during
development but don't want the speed hit during production.

The only error that will be caught will be when an odd number of
parameters are passed into a function/method that expects a hash.

This environment value is checked B<only> when the module is first
loaded.  You cannot change it after the module has loaded.

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
