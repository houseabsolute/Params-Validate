package Params::Validate;

use strict;

use vars qw(%OPTIONS $called $options);

$Params::Validate::Heavy::VERSION = sprintf '%2d.%02d', q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/;

1;

# Matt Sergeant came up with this prototype, which slickly takes the
# first array (which should be the caller's @_), and makes it a
# reference.  Everything after is the parameters for validation.
sub _validate_pos (\@@)
{
    my $p = shift;
    my @specs = @_;

    # I'm too lazy to pass these around all over the place.
    local $called = (caller(1))[3];
    local $options = _get_options( (caller(0))[0] );

    my $min = 0;
    while (1)
    {
	last if ( ( ref $specs[$min] && $specs[$min]{optional} ) ||
		  ! $specs[$min] );
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
}

sub _validate (\@$)
{
    my $p = shift;
    my $specs = shift;

    local $called = (caller(1))[3];
    local $options = _get_options( (caller(0))[0] );

    if ( ref $p->[0] && UNIVERSAL::isa( $p->[0], 'HASH' ) )
    {
	$p = [ %{ $p->[0] } ];
    }
    $options->{on_fail}->( "Odd number of parameters in call to $called when named parameters were expected\n" )
	if @$p % 2;

    $p = {@$p};

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
	# foo => 1  used to mark mandatory argument with no other validation
	if ( ( ! ref $specs->{$_} && $specs->{$_} ) ||
	     ( ref $specs->{$_} && ! $specs->{$_}{optional} ) )
	{
	    push @missing, $_ unless exists $p->{$_};
	}
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
	if ( ! grep { ref $value eq $_ } qw( SCALAR ARRAY HASH CODE GLOB ) )
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

    sub _validation_options
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
