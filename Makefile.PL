use ExtUtils::MakeMaker;

WriteMakefile( 'NAME'		=> 'Params::Validate',
	       'VERSION_FROM'	=> 'lib/Params/Validate.pm',
	       'PREREQ_PM'	=> $] >= 5.006 ? { 'Attribute::Handlers' => 0 } : {},
	       ( $] >= 5.005 ?
		 ( ABSTRACT_FROM => 'lib/Params/Validate.pm', # retrieve abstract from module
		   AUTHOR        => 'Dave Rolsky, <autarch@urth.org>') :
		 ()
	       ),
	     );
