use strict;
use warnings;

use Test::More tests => 4;
use Params::Validate ();

is_deeply(
    [ sort @Params::Validate::EXPORT_OK ],
    [ sort qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE
               BOOLEAN UNDEF OBJECT
               validate validate_pos validation_options validate_with
               set_options ) ],
    '@EXPORT_OK'
);

is_deeply(
    [ sort keys %Params::Validate::EXPORT_TAGS ],
    [ qw( all types ) ],
    'keys %EXPORT_TAGS'
);

is_deeply(
    [ sort @{ $Params::Validate::EXPORT_TAGS{all} } ],
    [ sort qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE
               BOOLEAN UNDEF OBJECT
               validate validate_pos validation_options validate_with ) ],
    '$EXPORT_TAGS{all}',
);

is_deeply(
    [ sort @{ $Params::Validate::EXPORT_TAGS{types} } ],
    [ sort qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE
               BOOLEAN UNDEF OBJECT ) ],
    '$EXPORT_TAGS{types}',
);


