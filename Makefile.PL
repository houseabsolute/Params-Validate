use ExtUtils::MakeMaker;

WriteMakefile( 'NAME'		=> 'Params::Validate',
	       'VERSION_FROM'	=> 'Validate.pm',
	       'PREREQ_PM'		=> {},
	       ( $] >= 5.005 ?
		 ( ABSTRACT_FROM => 'Validate.pm', # retrieve abstract from module
		   AUTHOR        => 'Dave Rolsky, <autarch@urth.org>') :
		 ()
	       ),
	     );
