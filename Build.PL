use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'RoboBot',
    license             => 'perl',
    dist_author         => q{Jon Sime <jonsime@gmail.com>},
    dist_version_from   => 'lib/RoboBot.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.10,
        'DBIx::DataStore' => undef,
        'Module::Pluggable' => undef,
        'POE' => undef,
        'POE::Component::IRC' => undef,
        'YAML' => undef,
    },
    add_to_cleanup      => [ 'RoboBot-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
