package Attribute::Params::Validate;

use strict;
use warnings; # ok to use cause Attribute::Handlers needs 5.6.0+ as well

use attributes;

use Attribute::Handlers;

# this will all be re-exported
use Params::Validate qw(:all);

require Exporter;

our @ISA = qw(Exporter);

my %tags = ( types => [ qw( SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF HANDLE UNDEF OBJECT ) ],
	   );

our %EXPORT_TAGS = ( 'all' => [ qw( validate validate_pos validation_options ), map { @{ $tags{$_} } } keys %tags ],
		     %tags,
		   );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{all} }, 'set_options' );
our @EXPORT = qw( validate validate_pos validation_options );


our $VERSION = sprintf '%2d.%02d', q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;


sub UNIVERSAL::Validate : ATTR(CODE, INIT)
{
    my ($package, $symbol, $referent, $attr, $params) = @_;

    $params = {@$params};

    my $subname = $package . '::' . *{$symbol}{NAME};

    my %attributes = map { $_ => 1 } attributes::get($referent);
    my $is_method = $attributes{method};

    {
	no warnings 'redefine';
	no strict 'refs';

	# An unholy mixture of closure and eval.  This is done so that
	# the code to automatically create the relevant scalars from
	# the hash of params can create the scalars in the proper
	# place lexically.
	my $code = <<"EOF";
sub
{
    package $package;
EOF

	$code .= "    my \$object = shift;\n" if $is_method;

	$code .= "    Params::Validate::validate(\@_, \$params);\n";

	$code .= "    unshift \@_, \$object if \$object;\n" if $is_method;

	$code .= <<"EOF";
    \$referent->(\@_);
}
EOF

	my $sub = eval $code;
	die $@ if $@;

	*{$subname} = $sub;
#	use B::Deparse;
#	print B::Deparse->new->coderef2text($sub), "\n\n";
    }
}


1;
