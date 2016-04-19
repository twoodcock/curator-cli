use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::Curator',
    AUTHOR           => q{Tim Woodcock <tim@0th.ca>},
    VERSION_FROM     => 'lib/App/Curator.pm',
    ABSTRACT_FROM    => 'lib/App/Curator.pm',
    LICENSE          => 'mit',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'IO::Scalar' => 0,
        'Test::Differences' => 0,
    },
    PREREQ_PM => {
        'File::Path' => 2.09,
        'File::Spec' => 3.40,
        'Template' => 2.26,
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    # TJW: allow tests in subdirs, eg: t/subdir/subdir/*.t
    # CAVEAT: you must run make Makefile.PL for this to run tests in a new
    # subidr.
    test => { RECURSIVE_TEST_FILES => 1, },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Curator-*' },
);
