use 5.006;

use strict;
use warnings;

use Module::Build;

my $force_pp = grep { $_ eq '--pp' } @ARGV;

my @pp = _make_pp_tests();

my $builder = Module::Build->new(
    module_name => 'Params::Validate',
    license     => 'perl',
    requires    => {
        'Attribute::Handlers' => '0.79',
        'Test::More'          => '0',
        'Scalar::Util'        => '1.10',
    },
    build_requires => {
        'ExtUtils::CBuilder' => '0',
        'Pod::Man'           => '1.14',
        'Test::More'         => '0.34',
    },
    c_source       => 'c',
    add_to_cleanup => \@pp,
    create_readme  => 1,
    sign           => 1,
    meta_merge     => {
        resources => {
            bugtracker =>
                'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Params-Validate',
            repository =>
                'https://svn.urth.org/svn/Params-Validate',
        },
    },
    create_makefile_pl => 'traditional',
);

if ($force_pp) {
    $builder->build_elements(
        [ grep { $_ ne 'xs' } @{ $builder->build_elements() } ] );
}

$builder->create_build_script();

sub _make_pp_tests {
    return unless -d '.svn';

    require File::Slurp;
    File::Slurp->import(qw( read_file write_file ));

    opendir my $dh, 't'
        or die "Cannot read t: $!";

    my @pp;
    foreach my $file ( grep {/^\d.+\.t$/} readdir $dh ) {
        next if $file !~ /^\d/;

        my $test = read_file("t/$file");

        my $bang_flags = $test =~ /perl -Tw/ ? '-Tw' : '-w';
        $test
            = "#!/usr/bin/perl $bang_flags \n\nBEGIN { \$ENV{PV_TEST_PERL} = 1 }\n\n$test";

        my $new_file = "t/pp_$file";
        write_file( $new_file, $test );

        push @pp, $new_file;
    }

    return @pp;
}
