# The perl/C checking voodoo is stolen from Graham Barr's
# Scalar-List-Utils distribution.

use strict;

use ExtUtils::MakeMaker;
use Config qw(%Config);

my $no_xs;
for (@ARGV)
{
    /^--pm/ and $no_xs = 1;
    /^--xs/ and $no_xs = 0;
}

write_makefile();

exit if defined $no_xs;

print "Testing if you have a C compiler\n";

unless ( open F, ">test.c" )
{
    warn "Cannot write test.c, skipping test compilation and install pure Perl version.\n";
    no_cc();
}

print F <<'EOF';
int main() { return 0; }
EOF

close F or no_cc();

my $make = $^O =~ /win32/i ? 'nmake' : 'make';
system("$make test$Config{obj_ext}") and no_cc();

sub write_makefile
{
    print <<'EOF';

*** NOTE ***

You can safely ignore the warnings below about 'Too late to run
CHECK/INIT blocks'.

*************

EOF

    WriteMakefile( VERSION_FROM    => "lib/Params/Validate.pm",
                   NAME            => "Params::Validate",
                   PREREQ_PM       => $] >= 5.006 ? { 'Attribute::Handlers' => 0 } : {},
                   CONFIGURE       => \&init,
                   clean           => { FILES => 'test.c' },
                   ( $] >= 5.005 ?
                     ( ABSTRACT_FROM => 'lib/Params/Validate.pm',
                       AUTHOR        => 'Dave Rolsky, <autarch@urth.org>') :
                     ()
                   ),
                 );
}

sub init
{
    my $hash = $_[1];

    if ($no_xs)
    {
        @{ $hash }{ 'XS', 'C' } = ( {}, [] );
    }

    $hash;
}

sub no_cc
{
    $no_xs = 1;
    print <<'EOF';

 I cannot determine if you have a C compiler
 so I will install a perl-only implementation

 You can force installation of the XS version with

    perl Makefile.PL --xs

EOF

    write_makefile();
    exit;
}
