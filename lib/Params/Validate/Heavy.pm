package Params::Validate;

use strict;

$Params::Validate::Heavy::VERSION = sprintf '%2d.%02d', q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

1;

# Matt Sergeant came up with this prototype, which slickly takes the
# first array (which should be the caller's @_), and makes it a
# reference.  Everything after is the parameters for validation.
sub _validate (\@@)
{
    # params passed to sub as reference
    my $p = shift;

    my $called = (caller(1))[3];
    # positional parameters
    if (@_ > 1)
    {
	_validate_positional($p, \@_, $called);
    }
    else
    {
	# hashref of named params
	if ( ref $p->[0] && UNIVERSAL::isa( $p->[0], 'HASH' ) )
	{
	    $p = [ %{ $p->[0] } ];
	}
	die "Odd number of parameters in call to $called when named parameters were expected\n"
	    if @$p % 2;
	_validate_named( {@$p}, shift, $called);
    }
}

sub _validate_positional
{
    my $p = shift;
    my $opts = shift;
    my $called = shift;

    my $actual = scalar @$p;

    my $min = 0;
    while (1)
    {
	last if ( ( ref $opts->[$min] && $opts->[$min]{optional} ) ||
		  ! $opts->[$min] );
	$min++;
    }

    my $max = scalar @$opts;

    unless ($actual >= $min && $actual <= $max )
    {
	my $minmax = $min != $max ? "$min - $max" : $max;
	$minmax .= $max != 1 ? ' were' : ' was';
	die "$actual parameter" . ($actual != 1 ? 's' : '') . " " . ($actual != 1 ? 'were' : 'was' ) . " passed to $called but $minmax expected\n";
    }

    foreach ( 0..$#{ $opts } )
    {
	_validate_one_param( $p->[$_], $opts->[$_], "Parameter #$_", $called )
	    if ref $opts->[$_];
    }
}

sub _validate_named
{
    my $p = shift;
    my $opts = shift;
    my $called = shift;

    if ( my @unmentioned = grep { ! exists $opts->{$_} } keys %$p )
    {
	die( "The following parameter" . (@unmentioned > 1 ? 's were' : ' was') . " passed in the call to $called but " .
	     (@unmentioned > 1 ? 'were' : 'was') . " not listed in the validation options: @unmentioned\n" );
    }

    my @missing;
    foreach (keys %$opts)
    {
	# foo => 1  used to mark mandatory argument with no other validation
	if ( ( ! ref $opts->{$_} && $opts->{$_} ) ||
	     ( ref $opts->{$_} && ! $opts->{$_}{optional} ) )
	{
	    push @missing, $_ unless exists $p->{$_};
	}
    }

    if (@missing)
    {
	my $missing = join ', ', map {"'$_'"} @missing;
	die "Mandatory parameter" . (@missing > 1 ? 's': '') . " $missing missing in call to $called\n";
    }

    foreach (keys %$opts)
    {
	_validate_one_param( $p->{$_}, $opts->{$_}, "The '$_' parameter", $called )
	    if ref $opts->{$_};
    }
}

sub _validate_one_param
{
    my $value = shift;
    my $opt = shift;
    my $id = shift;
    my $called = shift;

    if ( exists $opt->{type} )
    {
	my $type = _get_type($value);
	unless ( $type & $opt->{type} )
	{
	    my $is = (_typemask_to_strings($type))[0];
	    my @allowed = _typemask_to_strings($opt->{type});
	    my $article = $is =~ /^[aeiou]/ ? 'an' : 'a';
	    die "$id is $article '$is', which is not one of the allowed types: @allowed\n";
	}
    }

    if ( exists $opt->{isa} )
    {
	foreach ( ref $opt->{isa} ? @{ $opt->{isa} } : $opt->{isa} )
	{
	    unless ( UNIVERSAL::isa( $value, $_ ) )
	    {
		my $is = ref $value ? ref $value : 'plain scalar';
		die "$id is not a '$_'\n";
	    }
	}
    }

    if ( exists $opt->{can} )
    {
	foreach ( ref $opt->{can} ? @{ $opt->{can} } : $opt->{can} )
	{
	    die "$id cannot '$_'\n" unless UNIVERSAL::can( $value, $_ );
	}
    }

    if ($opt->{callbacks})
    {
	die "'callbacks' validation parameter must be a hash reference\n"
	    unless UNIVERSAL::isa( $opt->{callbacks}, 'HASH' );

	foreach ( keys %{ $opt->{callbacks} } )
	{
	    die "callback '$_' is not a subroutine reference\n"
		unless UNIVERSAL::isa( $opt->{callbacks}{$_}, 'CODE' );

	    die "$id did not pass the '$_' callback\n"
		unless $opt->{callbacks}{$_}->($value);
	}
    }
}

{
    # if it UNIVERSAL::isa the string on the left then its the type on
    # the right
    my %isas = ( ARRAY  => ARRAYREF,
		 HASH   => HASHREF,
		 CODE   => CODEREF,
		 GLOB   => GLOBREF,
		 SCALAR => SCALARREF,
	       );

    sub _get_type
    {
	my $value = shift;

	unless (ref $value)
	{
	    # catches things like:  my $fh = do { local *FH; };
	    return GLOB if UNIVERSAL::isa( \$value, 'GLOB' );
	    return SCALAR;
	}

	foreach ( keys %isas )
	{
	    return $isas{$_} if UNIVERSAL::isa( $value, $_ );
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
			   UNKNOWN()   => 'unknown',
			 );

    sub _typemask_to_strings
    {
	my $mask = shift;

	my @types;
	foreach ( SCALAR, ARRAYREF, HASHREF, CODEREF, GLOB, GLOBREF, SCALARREF, UNKNOWN )
	{
	    push @types, $type_to_string{$_} if $mask & $_;
	}
	return @types ? @types : ('unknown');
    }
}
