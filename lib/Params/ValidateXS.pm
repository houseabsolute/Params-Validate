# Copyright (c) 2000-2003 Dave Rolsky
# All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.  See the LICENSE
# file that comes with this distribution for more details.

package Params::Validate;

use strict;

require DynaLoader;

if ( $] >= 5.006 )
{
    require XSLoader;
    XSLoader::load( 'Params::Validate', $Params::Validate::VERSION );
}
else
{
    require DynaLoader;
    push @ISA, 'DynaLoader';
    Params::Validate->bootstrap( $Params::Validate::VERSION );
}

my $default_fail = sub { require Carp;
                         Carp::confess($_[0]) };

{
    my %defaults = ( ignore_case   => 0,
		     strip_leading => 0,
		     allow_extra   => 0,
		     on_fail       => $default_fail,
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
}

sub _check_regex_from_xs { return $_[0] =~ /$_[1]/ ? 1 : 0 }

sub _fail_from_xs
{
    my ( $error, $sub ) = @_;

    # set this just in case the user did something really weird.
    $sub ||= $default_fail;

    $sub->($error);

    # ensure that we always die
    die $error;
}

1;

__END__

=head1 NAME

Params::ValidateXS - XS implementation of Params::Validate

=head1 SYNOPSIS

  See Params::Validate

=head1 DESCRIPTION

This is an XS implementation of Params::Validate.  See the
Params::Validate documentation for details.

=cut
