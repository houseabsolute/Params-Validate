use ExtUtils::MakeMaker;

print <<'EOF';

*** NOTE ***

You can safely ignore the warnings below about 'Too late to run
CHECK/INIT blocks'.

*************

EOF

WriteMakefile( 'NAME'		=> 'Params::Validate',
	       'VERSION_FROM'	=> 'lib/Params/Validate.pm',
	       'PREREQ_PM'	=> $] >= 5.006 ? { 'Attribute::Handlers' => 0 } : {},
	       ( $] >= 5.005 ?
		 ( ABSTRACT_FROM => 'lib/Params/Validate.pm', # retrieve abstract from module
		   AUTHOR        => 'Dave Rolsky, <autarch@urth.org>') :
		 ()
	       ),
	     );
