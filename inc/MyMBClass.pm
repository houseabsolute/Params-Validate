package MyMBClass;

use strict;
use warnings;

use parent 'Module::Build';

sub new {

    my  $class = shift;

    my $self = $class->SUPER::new( @_ );

    if ( defined ( my $pp = $self->args( 'pp' ) ) ) {
        $self->args( 'pureperl_only', $pp );
        $self->pureperl_only($pp);
    }

    return $self;
}

1;

