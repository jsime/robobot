package RoboBot::Macro;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use RoboBot::Nick;

use Clone qw( clone );
use Data::Dumper;
use Data::SExpression;
use DateTime;
use DateTime::Format::Pg;
use JSON;

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

has 'id' => (
    is        => 'rw',
    isa       => 'Num',
    traits    => [qw( SetOnce )],
    predicate => 'has_id',
);

has 'name' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'arguments' => (
    is       => 'rw',
    isa      => 'HashRef',
    default  => sub { { has_optional => 0, positional => [], keyed => {}, rest => undef } },
    required => 1,
);

has 'definition' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'definer' => (
    is        => 'rw',
    isa       => 'RoboBot::Nick',
    predicate => 'has_definer',
);

has 'timestamp' => (
    is       => 'rw',
    isa      => 'DateTime',
    traits   => [qw( SetOnce )],
    default  => sub { DateTime->now() },
    required => 1,
);

has 'valid' => (
    is     => 'ro',
    isa    => 'Bool',
    writer => '_set_valid',
);

has 'error' => (
    is     => 'ro',
    isa    => 'Str',
    writer => '_set_error',
);

has 'expression' => (
    is     => 'ro',
    isa    => 'ArrayRef',
    writer => '_set_expression',
);

sub BUILD {
    my ($self) = @_;

    $self->_generate_expression($self->definition) if defined $self->definition;
}

around 'definition' => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig() unless @_;

    my $def = shift;

    $self->_generate_expression($def);
    return $self->$orig($def);
};

sub _generate_expression {
    my ($self, $def) = @_;

    unless (defined $def) {
        $self->_set_expression([]);
        return;
    }

    my $ds = Data::SExpression->new({
        fold_lists       => 1,
        use_symbol_class => 1,
    });

    my $expr;

    eval {
        $expr = $ds->read($def);
    };

    if ($@) {
        $self->_set_valid(0);
        $self->_set_error("Macro definition is not a valid expression.");
        return;
    }

    unless (ref($expr) eq 'ARRAY') {
        $self->_set_valid(0);
        $self->_set_error("Macro definition body must be provided as a list of expressions.");
        return;
    }

    $self->_set_valid(1);
    $self->_set_expression($expr);
};

sub load_all {
    my ($class, $config) = @_;

    my $res = $config->db->do(q{
        select m.macro_id, m.name, m.arguments, m.definition, n.name as nick, m.defined_at
        from macros m
            join nicks n on (n.id = m.defined_by)
    });

    return unless $res;

    my %macros;

    while ($res->next) {
        $macros{$res->{'name'}} = $class->new(
            config     => $config,
            id         => $res->{'macro_id'},
            name       => $res->{'name'},
            arguments  => decode_json($res->{'arguments'}),
            definition => $res->{'definition'},
            definer    => RoboBot::Nick->new( config => $config, name => $res->{'nick'} ),
            timestamp  => DateTime::Format::Pg->parse_datetime($res->{'defined_at'}),
        );
    }

    return %macros;
}

sub save {
    my ($self) = @_;

    my $res;

    if ($self->has_id) {
        $res = $self->config->db->do(q{
            update macros set ??? where macro_id = ?
        }, {
            name       => $self->name,
            arguments  => encode_json($self->arguments),
            definition => $self->definition,
        }, $self->id);

        return 1 if $res;
    } else {
        unless ($self->has_definer) {
            warn sprintf("Attempted to save macro '%s' without a definer attribute.\n", $self->name);
            return 0;
        }

        $res = $self->config->db->do(q{
            insert into macros ??? returning macro_id
        }, {
            name       => $self->name,
            arguments  => encode_json($self->arguments),
            definition => $self->definition,
            defined_by => $self->definer->id,
            defined_at => $self->timestamp,
        });

        if ($res && $res->next) {
            $self->id($res->{'macro_id'});
            return 1;
        }
    }

    return 0;
}

sub delete {
    my ($self) = @_;

    return 0 unless $self->has_id;

    my $res = $self->config->db->do(q{
        delete from macros where macro_id = ?
    }, $self->id);

    return 0 unless $res;
    return 1;
}

sub expand {
    my ($self, $message, @args) = @_;

    my $expr = $message->flatten_symbols(clone($self->expression));

    my $req_count = scalar( grep { $_->{'optional'} != 1 } @{$self->arguments->{'positional'}} ) // 0;
    if ($req_count > 0 && scalar(@args) < $req_count) {
        $message->response->raise('Macro %s expects at least %d arguments, but you provided %d.', $self->name, $req_count, scalar(@args));
        return;
    }

    # TODO: Add a first pass to collect any &key'ed arguments first, before
    #       processing the simple positional ones. Possibly needs to be done
    #       even before the argument count check above is performed.
    my %rpl = ();
    foreach my $arg (@{$self->arguments->{'positional'}}) {
        # No need to care whether argument is required or not at this point.
        # We would have already errored out above if there was a mismatch. Just
        # set the optional ones without values to undefined.
        $rpl{$arg->{'name'}} = @args ? shift(@args) : undef;
    }
    # If anything is left in the arguments list passed to the macro invocation,
    # then it belongs in &rest, should the macro care to make use of them.
    if ($self->arguments->{'rest'} && @args) {
        $rpl{ $self->arguments->{'rest'} } = [@args];
    }

    return $self->expand_list($message, $expr, \%rpl);
}

sub expand_list {
    my ($self, $message, $list, $args) = @_;

    return $list unless ref($list) eq 'ARRAY';

    my $new_list = [];
    foreach my $el (@{$list}) {
        if (ref($el) eq 'ARRAY') {
            if (exists $message->bot->commands->{$el->[0]} && exists $message->bot->commands->{$el->[0]}{'preprocess_args'} && $message->bot->commands->{$el->[0]}{'preprocess_args'} == 0) {
                push(@{$new_list}, clone($el));
            } else {
                push(@{$new_list}, $self->expand_list($message, $el, $args));
            }
        } elsif (exists $args->{"$el"}) {
            push(@{$new_list}, $args->{"$el"});
        } else {
            push(@{$new_list}, "$el");
        }
    }

    return $new_list;
}

sub collapse {
    my ($class, $definition) = @_;

    unless (ref($definition) eq 'ARRAY') {
        return __PACKAGE__->quoted_string($definition);
    }

    my $backquoted = $definition->[0] eq 'backquote'
                  && ref($definition->[1]) eq 'ARRAY'
                  && scalar(@{$definition}) == 2
        ? 1 : 0;

    my @r;
    if ($backquoted) {
        push(@r, __PACKAGE__->collapse($_)) foreach @{$definition->[1]};
    } else {
        push(@r, __PACKAGE__->collapse($_)) foreach @{$definition};
    }

    return sprintf('%s(%s)', ($backquoted ? "'" : ''), join(' ', @r));
}

sub quoted_string {
    my ($class, $string) = @_;

    return $string unless $string =~ m{[\s"]+}o;

    $string =~ s{\"}{\\"}og;
    return sprintf('"%s"', $string);
}

sub signature {
    my ($self) = @_;

    my @arg_list = ();

    if (scalar(@{$self->arguments->{'positional'}}) > 0) {
        my $opt_shown = 0;

        foreach my $arg (@{$self->arguments->{'positional'}}) {
            if (!$opt_shown && $arg->{'optional'}) {
                # TODO: Before listing optional positional arguments, list out
                # any required &key'ed arguments. (And then follow up with the
                # optional &key'ed arguments after listing the optional
                # positionals.)
                push(@arg_list, '&optional');
                $opt_shown = 1;
            }

            push(@arg_list, $arg->{'name'});
        }
    }

    if ($self->arguments->{'rest'}) {
        push(@arg_list, '&rest', $self->arguments->{'rest'});
    }

    return join(' ', @arg_list);
}

__PACKAGE__->meta->make_immutable;

1;
