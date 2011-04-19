package Params::Validate;

use strict;
use warnings;

require XSLoader;
XSLoader::load( 'Params::Validate', $Params::Validate::VERSION );

my $default_fail = sub {
    require Carp;
    Carp::confess( $_[0] );
};

{
    my %defaults = (
        ignore_case    => 0,
        strip_leading  => 0,
        allow_extra    => 0,
        on_fail        => $default_fail,
        stack_skip     => 1,
        normalize_keys => undef,
    );

    *set_options = \&validation_options;

    sub validation_options {
        my %opts = @_;

        my $caller = caller;

        foreach ( keys %defaults ) {
            $opts{$_} = $defaults{$_} unless exists $opts{$_};
        }

        $OPTIONS{$caller} = \%opts;
    }
}

sub _check_regex_from_xs {
    return ( defined $_[0] ? $_[0] : '' ) =~ /$_[1]/ ? 1 : 0;
}

BEGIN {
    *validate      = \&_validate;
    *validate_pos  = \&_validate_pos;
    *validate_with = \&_validate_with;
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

=head1 COPYRIGHT

Copyright (c) 2004-2007 David Rolsky.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
