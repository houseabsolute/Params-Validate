package Params::Validate;

use strict;

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter);

%EXPORT_TAGS = ( 'all' => [ qw(

) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw(

);

BEGIN
{
    # can use this to make validate a no-op if an env var is set or
    # something.
    *validate = \&_validate;
}

$VERSION = '0.01';

1;

# Matt Sergeant came up with this prototype, which slickly takes the
# first array (which should be the caller's @_), and makes it a
# reference.  Everything after is the parameters for validation.
sub _validate (\@@)
{
    # params passed to sub as reference
    my $p = shift;

    # positional parameters
    if (ref $_[0])
    {
	_validate_positional($p, @opts);
    }
    else
    {
	_validate_named($p, @opts);
    }
}

sub _validate_positional
{
    my $p = shift;
    my @opts = @_;

}

sub _validate_named
{
    my $p = shift;
    my %opts = @_;

    my @unmentioned = grep { ! exists $opts{$_} } keys %$p;

    die "The following parameters were passed to the subroutine but not listed in the validation options: @unmentioned"
	if @unmentioned;

    foreach (keys %opts)
    {
	# foo => 1  used to mark mandatory argument with no other validation
	unless ( ref $opts{$_} )
	{
	    

}

__END__

=head1 NAME

Param::Validate - Validate method/function parameters

=head1 SYNOPSIS

  use Param::Validate;


=head1 DESCRIPTION


=head2 EXPORT

None by default.


=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
