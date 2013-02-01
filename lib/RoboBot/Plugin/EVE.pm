package RoboBot::Plugin::EVE;

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP::Simple;
use Number::Format;
use XML::LibXML;
use XML::Simple;

sub commands { qw( eve ) }
sub usage { "[ price <name> [<qty>] | item <name> | pilot <name> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    return sprintf('This plugin has not been properly configured. Please notify your %s administrator.',
        $bot->config->nick)
        unless $bot->config->plugins->{'eve'}{'pilot'}
            && ref($bot->config->plugins->{'eve'}{'regions'}) eq 'ARRAY'
            && scalar(@{$bot->config->plugins->{'eve'}{'regions'}}) > 0;

    my @args = split(/\s+/, $message);

    my $subcmd = shift(@args);
    my $subcmd_args = join(' ', @args);

    return item_info($bot, $subcmd_args) if $subcmd eq 'item';
    return pilot_info($bot, $subcmd_args) if $subcmd eq 'pilot';
    return item_prices($bot, $subcmd_args) if $subcmd eq 'price';
    return item_materials($bot, $subcmd_args) if $subcmd eq 'materials';
}

sub item_info {
    my ($bot, $name) = @_;

    my $ft = Number::Format->new();

    my @items = lookup_item($bot, $name);

    my @r = map { sprintf('%s (%s)', $_->{'name'}, $_->{'path'}) } @items;

    return "No items matching that pattern were found." unless scalar(@r) > 0;
    return (@r[0..9], sprintf('... and %s more ...', $ft->format_number(scalar(@r) - 10, 0))) if scalar(@r) > 10;
    return @r;
}

sub item_materials {
    my ($bot, $name) = @_;

    my @items = lookup_item($bot, $name);
}

sub item_prices {
    my ($bot, $args) = @_;

    my ($name, $qty);
    my (%types, %regions);

    if ($args =~ m{^(.*)\b(\d+)\s*$}o) {
        $name = $1;
        $qty = $2;
    } else {
        ($name, $qty) = ($args, 1);
    }

    my @item_list = lookup_item($bot, $name);
    return "No items matching that pattern were found." unless scalar(@item_list) > 0;

    # try to keep things reasonable and not abuse anyone's APIs too much
    @item_list = @item_list[0..4] if scalar(@item_list) > 5;

    my $ft = Number::Format->new();

    my %prices = lookup_item_prices($bot, map { $_->{'item_id'} } @item_list);

    my @r;

    foreach my $item (@item_list) {
        my $item_id = $item->{'item_id'};

        push(@r,
            sprintf('%s (%s)', $item->{'name'}, $item->{'path'}),
            sprintf('  Base Price: %s ISK', $ft->format_number($item->{'base_price'}, 2, 1))
        );

        my $l_region = 0;
        my @lens;
        foreach my $region_id (keys %{$prices{$item_id}{'regions'}}) {
            $l_region = length($prices{$item_id}{'regions'}{$region_id}{'name'})
                if length($prices{$item_id}{'regions'}{$region_id}{'name'}) > $l_region;

            my $fld_i = 0;
            foreach my $fld (qw( avg median min max volume )) {
                $lens[$fld_i] = 0 unless $lens[$fld_i];

                $prices{$item_id}{'regions'}{$region_id}{'buy_' . $fld} =
                    $ft->format_number($prices{$item_id}{'regions'}{$region_id}{'buy_' . $fld},
                        ($fld eq 'volume' ? (0) : (2, 1)));
                $prices{$item_id}{'regions'}{$region_id}{'sell_' . $fld} =
                    $ft->format_number($prices{$item_id}{'regions'}{$region_id}{'sell_' . $fld},
                        ($fld eq 'volume' ? (0) : (2, 1)));

                $lens[$fld_i] = length($prices{$item_id}{'regions'}{$region_id}{'buy_' . $fld})
                    if length($prices{$item_id}{'regions'}{$region_id}{'buy_' . $fld}) > $lens[$fld_i];
                $lens[$fld_i] = length($prices{$item_id}{'regions'}{$region_id}{'sell_' . $fld})
                    if length($prices{$item_id}{'regions'}{$region_id}{'sell_' . $fld}) > $lens[$fld_i];

                $fld_i++;
            }
        }

        # Done only because we're folding max/min price columns into the same space,
        # depending on whether the line is for Buy or Sell data. Need to make sure
        # that the folded column is the width of whichever was the larger of the two.
        $lens[2] = $lens[3] if $lens[3] > $lens[2];
        $lens[3] = $lens[2] if $lens[2] > $lens[3];

        foreach my $region_id (
                sort { $prices{$item_id}{'regions'}{$a}{'name'}
                       cmp
                       $prices{$item_id}{'regions'}{$b}{'name'}
                     } keys %{$prices{$item_id}{'regions'}}) {
            push(@r, sprintf("  [%-${l_region}s] BUY  Med: %$lens[1]s / Max: %$lens[3]s / Vol: %$lens[4]s",
                $prices{$item_id}{'regions'}{$region_id}{'name'},
                $prices{$item_id}{'regions'}{$region_id}{'buy_median'},
                $prices{$item_id}{'regions'}{$region_id}{'buy_max'},
                $prices{$item_id}{'regions'}{$region_id}{'buy_volume'},
            ));
            push(@r, sprintf("   %-${l_region}s  SELL Med: %$lens[1]s / Min: %$lens[2]s / Vol: %$lens[4]s",
                '',
                $prices{$item_id}{'regions'}{$region_id}{'sell_median'},
                $prices{$item_id}{'regions'}{$region_id}{'sell_min'},
                $prices{$item_id}{'regions'}{$region_id}{'sell_volume'},
            ));
        }
    }

    return @r;
}

sub pilot_info {
    my ($bot, $name) = @_;

    return unless $name =~ m{^[a-z0-9 .-]+$}oi;

    $name =~ s{(^\s+|\s+$)}{}ogs;
    $name =~ s{\s+}{ }ogs;

    my $pilot = $bot->db->do(q{
        select p.pilot_id, p.name, p.gender, p.race, p.bloodline, p.dob, p.security, p.cached_until,
            c.name as corporation, max(pc.from_date) as corporation_date, a.name as alliance
        from eve_pilots p
            join eve_pilot_corps pc on (pc.pilot_id = p.pilot_id and pc.to_date is null)
            join eve_corps c on (c.corp_id = pc.corp_id)
            left join eve_corp_alliances ca on (ca.corp_id = c.corp_id and ca.to_date is null)
            left join eve_alliances a on (a.alliance_id = ca.alliance_id)
        where lower(p.name) = lower(?) and p.cached_until >= now()
        group by p.pilot_id, p.name, p.gender, p.race, p.bloodline, p.dob, p.security, p.cached_until,
            c.name, a.name
    }, $name);

    unless ($pilot && $pilot->next) {
        my $xs = XML::Simple->new;

        my $resp = get('https://api.eveonline.com/eve/CharacterID.xml.aspx?names=' . $name);
        return 'Error contacting EVE Online CharacterID API.' unless $resp;

        my $xml = $xs->XMLin($resp) || "Error parsing XML response from EVE Online CharacterID API.";

        return "Unexpected data strucure while resolving character ID."
            unless $xml->{'result'}{'rowset'}{'row'}{'characterID'};

        my $charid = $xml->{'result'}{'rowset'}{'row'}{'characterID'};

        $resp = get('https://api.eveonline.com/eve/CharacterInfo.xml.aspx?characterID=' . $charid);
        return 'Error contacting EVE Online CharacterInfo API.' unless $resp;

        $xml = $xs->XMLin($resp) || "Error parsing XML response from EVE Online CharacterInfo API.";

        my @corps = sort { $a->{'startDate'} cmp $b->{'startDate'} } @{$xml->{'result'}{'rowset'}{'row'}};

        $pilot = {
            pilot_id    => $xml->{'result'}{'characterID'},
            name        => $xml->{'result'}{'characterName'},
            race        => $xml->{'result'}{'race'},
            bloodline   => $xml->{'result'}{'bloodline'},
            dob         => $corps[0]->{'startDate'},
            security    => $xml->{'result'}{'securityStatus'},
            cached_until=> $xml->{'cachedUntil'} . '+00',
        };

        my $res = $bot->db->do(q{
            update eve_pilots
            set ???
            where pilot_id = ?
            returning pilot_id
        }, $pilot, $pilot->{'pilot_id'});

        if ($res && $res->next) {
            $pilot->{'pilot_id'} = $res->{'pilot_id'};
        } else {
            # API for non-key requests doesn't return gender -- we'll fake it in the DB for now
            $pilot->{'gender'} = 'Female';

            $res = $bot->db->do(q{ insert into eve_pilots ??? returning pilot_id }, $pilot);

            return "Couldn't update expired cache entry for plot"
                unless $res && $res->next;

            $pilot->{'pilot_id'} = $res->{'pilot_id'};
        }

        my @insert;

        # for(;;) loops aren't fashionable, but we need to refer to the next element to
        # get the end date for the current one
        for (my $i = 0; $i < scalar(@corps); $i++) {
            my $corp = $bot->db->do(q{
                select *
                from eve_corps
                where corp_id = ? and cached_until >= now()
            }, $corps[$i]->{'corporationID'});

            unless ($corp && $corp->next) {
                $corp = update_corporation($bot, $corps[$i]->{'corporationID'});
            }

            my $end_date = $i < scalar(@corps) - 1 ? $corps[$i - 1]->{'startDate'} . '+00' : undef;

            push(@insert, { pilot_id    => $pilot->{'pilot_id'},
                            corp_id     => $corp->{'corp_id'},
                            from_date   => $corps[$i]->{'startDate'} . '+00',
                            to_date     => $end_date
                          });
        }

        $bot->db->begin;

        $res = $bot->db->do(q{ delete from eve_pilot_corps where pilot_id = ? }, $pilot->{'pilot_id'});
        $res = $bot->db->do(q{ insert into eve_pilot_corps ??? }, \@insert);

        unless ($bot->db->commit) {
            $bot->db->rollback;
            return "Encountered an error while updating pilot's corporation membership.";
        }

        $res = $bot->db->do(q{
            select c.name as corporation, pc.from_date, a.name as alliance
            from eve_pilot_corps pc
                join eve_corps c on (c.corp_id = pc.corp_id)
                left join eve_corp_alliances ca on (ca.corp_id = c.corp_id and ca.to_date is null)
                left join eve_alliances a on (a.alliance_id = ca.alliance_id)
            where pc.pilot_id = ? and pc.to_date is null
        }, $pilot->{'pilot_id'});

        if ($res && $res->next) {
            $pilot->{'corporation'} = $res->{'corporation'};
            $pilot->{'corporation_date'} = $res->{'from_date'};
            $pilot->{'alliance'} = $res->{'alliance'};
        } else {
            return "Error determining pilot's corporate status.";
        }
    }

    my @r = (sprintf('Pilot:       %s', $pilot->{'name'}));
    push(@r, sprintf('Born:        %s', $pilot->{'dob'}));
    push(@r, sprintf('Race:        %s (%s)', $pilot->{'bloodline'}, $pilot->{'race'}));
    push(@r, sprintf('Corporation: %s (since: %s)', $pilot->{'corporation'}, $pilot->{'corporation_date'}));
    push(@r, sprintf('Alliance:    %s', $pilot->{'alliance'})) if $pilot->{'alliance'};
    push(@r, sprintf('Sec. Status: %.2f', $pilot->{'security'}));

    return @r;
}

sub update_corporation {
    my ($bot, $corp_id) = @_;

    my $xs = XML::Simple->new;

    my $resp = get('https://api.eveonline.com/corp/CorporationSheet.xml.aspx?corporationID=' . $corp_id);
    return 'Error contacting EVE Online CorporationSheet API.' unless $resp;

    my $xml = $xs->XMLin($resp) || "Error parsing XML response from EVE Online CharacterID API.";

    my $corp = {
        corp_id      => $xml->{'result'}{'corporationID'},
        name         => $xml->{'result'}{'corporationName'},
        ticker       => $xml->{'result'}{'ticker'},
        shares       => $xml->{'result'}{'shares'},
        tax_rate     => $xml->{'result'}{'taxRate'},
        member_count => $xml->{'result'}{'memberCount'},
        cached_until => $xml->{'cachedUntil'} . '+00',
    };

    my $res = $bot->db->do(q{
        update eve_corps
        set ???
        where corp_id = ?
        returning *
    }, $corp, $corp->{'corp_id'});

    if ($res && $res->next) {
        return $corp;
    } else {
        $res = $bot->db->do(q{ insert into eve_corps ??? returning * }, $corp);

        return $corp if $res && $res->next;
    }

    return;
}

sub lookup_item {
    my ($bot, $name) = @_;

    $name =~ s{(^\s+|\s+$)}{}ogs;
    $name =~ s{\s+}{ }ogs;

    my $res = $bot->db->do(q{
        select i.item_id, i.name, i.description, i.base_price, igp.path
        from eve_items i
            join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
        where lower(i.name) = lower(?)
    }, $name);

    # We favor exact matches, so if one is found we return that item alone.
    if ($res && $res->next) {
        $res->{'path'} =~ s{(^\s+|\s+$)}{}ogs;
        return { map { $_ => $res->{$_} } $res->columns };
    }

    # Failing an exact match, use the name as a PG regex and grab the three matches
    # with the small levenshtein distances (a little odd, considering the input name
    # might have wildcards, character classes, etc. -- but the only other real options
    # would be to try and remove those, or to take two parameters)
    $res = $bot->db->do(q{
        select i.item_id, i.name, i.description, i.base_price, igp.path
        from eve_items i
            join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
        where i.name ~* ?
        order by levenshtein(lower(?),lower(i.name)) asc, i.name asc
        limit 3
    }, $name, $name);

    return unless $res;

    my @items;

    while ($res->next) {
        $res->{'path'} =~ s{(^\s+|\s+$)}{}ogs;
        push(@items, { map { $_ => $res->{$_} } $res->columns });
    }

    return @items if scalar(@items) > 0;
    return;
}

sub lookup_item_prices {
    my ($bot, @ids) = @_;

    @ids = grep { defined $_ && $_ =~ m{^\d+$}o } @ids;
    return unless scalar(@ids) > 0;

    my $res = $bot->db->do(q{
        select r.region_id, r.name
        from eve_regions r
        where r.price_default
    });

    return unless $res;

    my %regions;

    while ($res->next) {
        $regions{$res->{'region_id'}} = { id => $res->{'region_id'}, name => $res->{'name'} };
        $regions{$res->{'region_id'}}{'items'} = {
            map { $_ => 1 } @ids
        };
    }

    return unless scalar(keys(%regions)) > 0;

    my %items;

    $res = $bot->db->do(q{
        select *
        from eve_item_prices
        where item_id in ??? and region_id in ???
            and cached_until >= now()
    }, [@ids], [keys %regions]);

    return unless $res;

    while ($res->next) {
        $items{$res->{'item_id'}} = { regions => {} } unless exists $items{$res->{'item_id'}};
        $items{$res->{'item_id'}}{'regions'}{$res->{'region_id'}} = {
            name => $regions{$res->{'region_id'}}{'name'},
            map { $_ => $res->{$_} } $res->columns
        };

        delete $regions{$res->{'region_id'}}{'items'}{$res->{'item_id'}};
    }

    foreach my $region_id (keys %regions) {
        next unless scalar(keys(%{$regions{$region_id}{'items'}})) > 0;

        my $lwp_res = get('http://api.eve-central.com/api/marketstat?hours=72&regionlimit='
            . $region_id . '&'
            . join('&', map { sprintf('typeid=%d', $_) } keys %{$regions{$region_id}{'items'}}));
        next unless $lwp_res;

        my $dom = XML::LibXML->load_xml( string => $lwp_res );
        next unless $dom;

        foreach my $type ($dom->getElementsByTagName('type')) {
            my $type_id = (grep { $_->nodeName eq "id" } $type->attributes)[0]->nodeValue;

            $items{$type_id} = { regions => {} } unless exists $items{$type_id};
            $items{$type_id}{'regions'}{$region_id} = {};

            foreach my $tr_type (qw( buy sell )) {
                my $txn = ($type->getElementsByTagName($tr_type))[0] || undef;
                next unless $txn;

                foreach my $fld (qw( min max avg median stddev percentile volume )) {
                    my $node = ($txn->getElementsByTagName($fld))[0];
                    next unless $node;

                    my $value = $node->textContent || 0;

                    $items{$type_id}{'regions'}{$region_id}{$tr_type . '_' . $fld} = $value;
                }
            }

            $res = $bot->db->do(q{
                update eve_item_prices
                set ???
                where item_id = ? and region_id = ?
                returning *
            }, $items{$type_id}{'regions'}{$region_id}, $type_id, $region_id);

            unless ($res && $res->next) {
                $items{$type_id}{'regions'}{$region_id}{'item_id'} = $type_id;
                $items{$type_id}{'regions'}{$region_id}{'region_id'} = $region_id;
                $res = $bot->db->do(q{
                    insert into eve_item_prices ???
                }, $items{$type_id}{'regions'}{$region_id});
            }

            $items{$type_id}{'regions'}{$region_id}{'name'} = $regions{$region_id}{'name'};
        }
    }

    $res = $bot->db->do(q{
        update eve_item_prices
        set cached_until = now() + interval '6 hours'
        where item_id in ??? and region_id in ???
            and cached_until < now()
    }, [@ids], [keys %regions]);

    return %items if scalar(keys(%items)) > 0;
    return;
}

1;
