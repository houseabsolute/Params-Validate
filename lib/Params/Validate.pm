package Params::Validate;

use strict;

BEGIN
{
    sub SCALAR    () { 1; };
    sub ARRAY     () { 2; };
    sub HASH      () { 4; };
    sub CODE      () { 8; };
    sub GLOB      () { 16; };
    sub GLOBREF   () { 32; };
    sub SCALARREF () { 64; };
    sub UNKNOWN   () { 128; };

    if ( $ENV{NO_VALIDATE} )
    {
	*validate = sub { 1 };
    }
    else
    {
	require Params::Validate::Heavy;
	*validate = \&_validate;
    }
}

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter);

my %tags = ( types => [ qw( SCALAR ARRAY HASH CODE GLOB GLOBREF SCALARREF ) ],
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

  use Params::Validate;


=head1 DESCRIPTION


=head2 EXPORT

None by default.


=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
