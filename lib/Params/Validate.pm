package Params::Validate;

use strict;

BEGIN
{
    sub SCALAR    () { 1; };
    sub ARRAYREF  () { 2; };
    sub HASHREF   () { 4; };
    sub CODEREF   () { 8; };
    sub GLOB      () { 16; };
    sub GLOBREF   () { 32; };
    sub SCALARREF () { 64; };
    sub UNKNOWN   () { 128; };
    sub HANDLE    () { 16 | 32 };

    if ( $ENV{NO_VALIDATE} )
    {
	*validate = sub { 1 };
	*set_options = sub { 1 };
    }
    else
    {
	require Params::Validate::Heavy;
	*validate = \&_validate;
	*set_options = \&_set_options;
    }
}

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter);

my %tags = ( types => [ qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE ) ],
	   );

%EXPORT_TAGS = ( 'all' => [ qw( validate ), map { @{ $tags{$_} } } keys %tags ],
		 %tags,
	       );
@EXPORT_OK = ( @{ $EXPORT_TAGS{all} } );
@EXPORT = qw( validate );

$VERSION = '0.01';

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
       validate( @_, 1, 1, 0 ); # first two are mandatory, third is optional
  }


  sub foo2
  {
       validate( @_, { foo =>
                       { type => ARRAYREF }, # specify a type
                       bar =>
                       { can => [ 'print', 'flush', 'frobnicate' ] }, # specify an interface
                       baz =>
                       { type => SCALAR,   # a scalar ...
                         callbacks =>
                         { 'numbers only' => sub { shift() =~ /^\d+$/ }, # ... that is a plain integer
                           'less than 90' => sub { shift() < 90 },       # ... and smaller than 90
                         },
                       }
                     }
               );
  }


=head1 DESCRIPTION

The Params::Validate module allows you to validate method or function
call parameters to an arbitrary level of specificity.  At the simplest
level, it is capable of validating the required parameters were given
and that no unspecified additional parameters were passed in.

It is also capable of referring that a parameter is of a specific
type, that it is an object of a certain class hierarchy, that it
possesses certain methods, etc.

=head2 EXPORT

The module always exports the C<validate> method.  In addition, it can
export the following constants, which are used as part of the type
checking.  These are C<SCALAR>, C<ARRAYREF>, C<HASHREF>, C<CODEREF>,
C<GLOB>, C<GLOBREF>, and C<SCALARREF>, and C<HANDLE>.  These are
explained in more detail later on.  These constants are available via
the tag C<:types>.  There is also a C<:all> tag, which for now is
equivalent to C<:types> tag.

=head1 USAGE

The validation mechanism provided by this module can handle both named
parameters or positional.  For the most part, the same features are
available for each.  The biggest difference is the way that the
C<validate> subroutine is called by the subroutine that wants the
validation done.  The other difference is in the error messages
produced when validation checks fail.

When handling named parameters, the module is capable of handling
either a hash or a hash reference transparently.

All calls to the C<validate> subroutine start like this:

 validate( @_, ... );

What goes in the '...' depends on what validation you want performed
and whether you are using named or positional parameters.

Subroutines expecting named parameters should call the C<validate>
subroutine like this:

 validate( @_, { parameter1 => ... validation,
                 parameter2 => ... validation,
                 ...
               } );

Subroutines expected positional parameters should call the C<validate>
subroutine like this:

 validate( @_, { validation }, { validation }, { validation } );

=head2 Mandatory/Optional Parameters

If you just want to specify that some parameters are mandatory and
others are optional, this can be done very simply.

For a subroutine expecting named parameters, you would do this:

 validate( @_, { foo => 1, bar => 1, baz => 0 } );

This says that the C<foo> and C<bar> parameters are mandatory and that
the C<baz> parameter is optional.  The presence of any other
parameters will cause an error.

For a subroutine expecting positional parameters, you would do this:

 validate( @_, 1, 1, 0, 0 );

This says that you expect at least 2 and no more than 4 parameters.
If you have a subroutine that has a minimum number of parameters but
can take any maximum number, you can do this:

 validate( @_, 1, 1, (0) x @_ );

This will always be valid as long as at least two parameters are
given.  A similar construct could be used for the more complex
validation parameters described further on.

Please note that this:

 validate( @_, 1, 1, 0, 1, 1 );

makes absolutely no sense, so don't do it.  Any zeros must come at the
end of the validation specification.

=head2 Type Validation

This module supports the following simple types, which can be
L<exported as constants|EXPORT>:

=over 4

=item * SCALAR

A scalar which is not a reference, such as C<10> or C<'hello'>.

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

=item * HANDLE

This option is special, in that it just the equivalent of C<GLOB |
GLOBREF>.  However, it seems likely to me that most people interested
in either globs or glob references are likely to really be interested
in whether what is being in is a potentially valid file or directory
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

 validate( @_, { type => SCALAR | ARRAYREF }, { type => CODEREF } );

=head2 Interface Validation

To specify that a parameter is expected to have a certain set of
methods, we can do the following:

 validate( @_,
           { foo =>
             { can => 'bar' } } ); # just has to be able to ->bar

 ... or ...

 validate( @_,
           { foo =>
             { can => [ qw( bar print ) ] } } ); # must be able to ->bar and ->print

=head2 Class Validation

A word of warning.  When constructing your external interfaces, it is
probably better to specify what you methods you expect an object to
have rather than what class it should be of (or a child of).  This
will make your API much more flexible.

With that said, if you want to verify that an incoming parameter
belongs to a class (or a child class) or classes, do:

 validate( @_,
           { foo =>
             { isa => 'My::Frobnicator' } } );

 ... or ...

 validate( @_,
           { foo =>
             { can => [ qw( My::Frobnicator IO::Handle ) ] } } );
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
                  sub { my $val = shift; $val eq 'green' || $val eq 'blue' } } } );

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

 validate( @_, { type => SCALAR }, { type => ARRAYREF, optional => 1 } );

By default, parameters are assumed to be mandatory unless specified as
optional.

=head1 LIMITATIONS

Right now there is no way (short of a callback) to specify that
something must be of one of a list of classes, or that it must possess
one of a list of methods.  If this is desired, it can be added in the
future.

=head1 SEE ALSO

Carp::Assert and Class::Contract.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
