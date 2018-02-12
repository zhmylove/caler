use 5.018000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'CalerXS::Util',
    VERSION_FROM      => 'lib/CalerXS/Util.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {'XSLoader'    =>  0, }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/CalerXS/Util.pm', # retrieve abstract from module
    AUTHOR            => 'Valeriy Kireev <valeriykireev@gmail.com>',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    INC               => '', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
