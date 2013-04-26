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
        'perl' => '5.010',
        'Acme::Scurvy::Whoreson::BilgeRat'  => undef,
        'DateTime::Format::Flexible'        => undef,
        'DBIx::DataStore'                   => undef,
        'File::HomeDir'                     => undef,
        'HTML::HeadParser'                  => undef,
        'JSON'                              => undef,
        'Lingua::EN::Tagger'                => undef,
        'LWP::Simple'                       => undef,
        'LWP::UserAgent'                    => undef,
        'Net::Ping'                         => undef,
        'Number::Format'                    => undef,
        'POE'                               => undef,
        'POE::Component::IRC'               => undef,
        'Term::ExtendedColor'               => undef,
        'Text::Aspell'                      => undef,
        'Text::Levenshtein'                 => undef,
        'Time::HiRes'                       => undef,
        'XML::LibXML'                       => undef,
        'XML::Simple'                       => undef,
        'YAML'                              => undef,
    },
    add_to_cleanup      => [ 'RoboBot-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
