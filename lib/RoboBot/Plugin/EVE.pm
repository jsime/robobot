package RoboBot::Plugin::EVE;

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP::Simple;
use Number::Format;
use XML::Simple;

sub commands { qw( eve ) }
sub usage { "[ price <name> [<qty>] | item <name> | pilot <name> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    return sprintf('This plugin has not been properly configured. Please notify your %s administrator.',
        $bot->{'config'}->nick)
        unless $bot->{'config'}->plugins->{'eve'}{'pilot'}
            && ref($bot->{'config'}->plugins->{'eve'}{'regions'}) eq 'ARRAY'
            && scalar(@{$bot->{'config'}->plugins->{'eve'}{'regions'}}) > 0;

    my $subcmd = (split(/\s+/, $message))[0];
    $subcmd =~ s{(^\s+|\s+$)}{}ogs; 

    my $subcmd_args = $message;
    $subcmd_args =~ s{^\s*$subcmd\s+}{}o;

    return item_info($bot, $subcmd_args) if $subcmd eq 'item';
    return pilot_info($bot, $subcmd_args) if $subcmd eq 'pilot';
    return item_prices($bot, $subcmd_args) if $subcmd eq 'price';
}

sub item_info {
    my ($bot, $name_pattern) = @_;

    $name_pattern =~ s{(^\s+|\s+$)}{}ogs;

    my $ft = Number::Format->new();

    my $res = $bot->{'dbh'}->do(q{
        select i.item_id, i.name, i.description, igp.path
        from eve_items i
            join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
        where i.name ~* ?
        order by i.name asc
    }, $name_pattern);

    return unless $res;

    my @r;

    while ($res->next) {
        push(@r, sprintf('%s (%s)', $res->{'name'}, $res->{'path'}));
    }

    return "No items matching that pattern were found." unless scalar(@r) > 0;
    return (@r[0..9], sprintf('... and %s more ...', $ft->format_number(scalar(@r) - 10, 0))) if scalar(@r) > 10;
    return @r;
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

    $name =~ s{(^\s+|\s+$)}{}ogs;
    $name =~ s{\s+}{ }ogs;

    my $res = $bot->{'dbh'}->do(q{
        select i.item_id, i.name, i.base_price, igp.path
        from eve_items i
            join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
        where lower(i.name) = lower(?)
    }, $name);

    if ($res && $res->next) {
        $types{$res->{'item_id'}} = { map { $_ => $res->{$_} } $res->columns };
    } else {
        $res = $bot->{'dbh'}->do(q{
            select i.item_id, i.name, i.base_price, igp.path
            from eve_items i
                join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
            where i.name ~* ?
            order by levenshtein(lower(?),lower(i.name)) asc, i.name asc
            limit 3
        }, $name, $name);

        return unless $res;

        while ($res->next) {
            $types{$res->{'item_id'}} = { map { $_ => $res->{$_} } $res->columns };
        }
    }

    return "No items matching that pattern were found." unless scalar(keys(%types)) > 0;

    $res = $bot->{'dbh'}->do(q{
        select r.region_id, r.name
        from eve_regions r
        where r.name in ???
    }, [@{$bot->{'config'}->plugins->{'eve'}{'regions'}}]);

    return unless $res;

    while ($res->next) {
        $regions{$res->{'region_id'}} = { map { $_ => $res->{$_} } $res->columns };
    }

    return "Could not locate any valid regions." unless scalar(keys(%regions)) > 0;

    $res = $bot->{'dbh'}->do(q{
        select *
        from eve_item_prices
        where item_id in ??? and region_id in ???
            and cached_until >= now()
    }, [keys %types], [keys %regions]);

    my $ft = Number::Format->new();

    my %items;

    if ($res) {
        while ($res->next) {
            $items{$res->{'item_id'}} = { regions => {} } unless $items{$res->{'item_id'}};
            $items{$res->{'item_id'}}{'regions'}{$res->{'region_id'}} =
                { buy  => $ft->format_number($qty * $res->{'buy_price'}, 2, 1),
                  sell => $ft->format_number($qty * $res->{'sell_price'}, 2, 1)
                };
        }
    }

    my @unseen_items = grep { !$items{$_} } keys %types;
    my %unseen_regions;

    foreach my $item_id (keys %types) {
        $unseen_regions{$_} = 1 for grep { !$items{$item_id}{'regions'}{$_} } keys %regions;
    }

    if (scalar(@unseen_items) > 0 || scalar(keys(%unseen_regions)) > 0) {
        my $charname = $bot->{'config'}->plugins->{'eve'}{'pilot'};

        my $url = sprintf('http://api.eve-marketdata.com/api/item_prices2.json?char_name=%s&' .
                          'type_ids=%s&region_ids=%s&buysell=a',
                          $charname, join(',', keys %types), join(',', keys %regions));
        my $resp = get($url);

        return unless $res;
        my $data = from_json($resp) || return;

        foreach my $result (@{$data->{'emd'}{'result'}}) {
            my $type_id = $result->{'row'}->{'typeID'};
            my $region_id = $result->{'row'}->{'regionID'};
            my $buyorsell = $result->{'row'}->{'buysell'};
            my $price = sprintf('%.2f', $result->{'row'}->{'price'});

            $res = $bot->{'dbh'}->do(q{
                update eve_item_prices
                set } . ($buyorsell eq 'b' ? 'buy_price' : 'sell_price') . q{ = ?,
                    cached_until = now() + interval '1 hour'
                where item_id = ? and region_id = ?
                returning cached_until
            }, $price, $type_id, $region_id);

            unless ($res && $res->next) {
                $res = $bot->{'dbh'}->do(q{
                    insert into eve_item_prices
                        ( item_id, region_id, buy_price, sell_price, cached_until )
                    values
                        ( ?, ?, ?, ?, now() + interval '1 hour' )
                    returning cached_until
                }, $type_id, $region_id,
                    ($buyorsell eq 'b' ? $price : 0),
                    ($buyorsell eq 's' ? $price : 0)
                );
            }

            $items{$type_id} = { regions => {} } unless $items{$type_id};
            $items{$type_id}{'regions'}{$region_id} = { buy => undef, sell => undef }
                unless $items{$type_id}{'regions'}{$region_id};

            $items{$type_id}{'regions'}{$region_id}{'buy'} =
                $ft->format_number($qty * $price, 2, 1) if $buyorsell eq 'b';
            $items{$type_id}{'regions'}{$region_id}{'sell'} =
                $ft->format_number($qty * $price, 2, 1) if $buyorsell eq 's';
        }
    }

    # fill in the names now that we have items from both the cache and the API
    foreach my $item_id (keys %items) {
        $items{$item_id}{'name'} = $types{$item_id}{'name'};
        $items{$item_id}{'category'} = $types{$item_id}{'path'};

        foreach my $region_id (keys %{$items{$item_id}{'regions'}}) {
            $items{$item_id}{'regions'}{$region_id}{'name'} = $regions{$region_id}{'name'};
        }
    }

    my @r;

    foreach my $type_id (sort { $items{$a}{'name'} cmp $items{$b}{'name'} } keys %items ) {
        push(@r, sprintf('%s (%s)', $items{$type_id}{'name'}, $items{$type_id}{'category'}));
        push(@r, sprintf('  Base Price: %s ISK',
            $types{$type_id}{'base_price'} > 0
                ? $ft->format_number($types{$type_id}{'base_price'}, 2, 1)
                : 'Unavailable'
            ));

        my $l_region = length($items{$type_id}{'regions'}{
                (sort { length($items{$type_id}{'regions'}{$a}{'name'})
                        <=>
                        length($items{$type_id}{'regions'}{$b}{'name'})
                      } keys %{$items{$type_id}{'regions'}})[-1]
            }{'name'});
        my $l_buy = length($items{$type_id}{'regions'}{
                (sort { length($items{$type_id}{'regions'}{$a}{'buy'})
                        <=>
                        length($items{$type_id}{'regions'}{$b}{'buy'})
                      } keys %{$items{$type_id}{'regions'}})[-1]
            }{'buy'});
        my $l_sell = length($items{$type_id}{'regions'}{
                (sort { length($items{$type_id}{'regions'}{$a}{'sell'})
                        <=>
                        length($items{$type_id}{'regions'}{$b}{'sell'})
                      } keys %{$items{$type_id}{'regions'}})[-1]
            }{'sell'});

        foreach my $region_id (sort { $items{$type_id}{'regions'}{$a} cmp $items{$type_id}{'regions'}{$b} } keys %{$items{$type_id}{'regions'}}) {
            push(@r, sprintf("  [ %-${l_region}s ] %sBuy: %${l_buy}s / Sell: %${l_sell}s",
                $items{$type_id}{'regions'}{$region_id}{'name'},
                ($qty > 1 ? sprintf('Qty: %s @ ', $ft->format_number($qty, 0)) : ''),
                $items{$type_id}{'regions'}{$region_id}{'buy'},
                $items{$type_id}{'regions'}{$region_id}{'sell'})
            );
        }
    }

    return @r;
}

sub pilot_info {
    my ($bot, $name) = @_;

    return unless $name =~ m{^[a-z0-9 .-]+$}oi;

    $name =~ s{(^\s+|\s+$)}{}ogs;
    $name =~ s{\s+}{ }ogs;

    my $pilot = $bot->{'dbh'}->do(q{
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

        my $res = $bot->{'dbh'}->do(q{
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

            $res = $bot->{'dbh'}->do(q{ insert into eve_pilots ??? returning pilot_id }, $pilot);

            return "Couldn't update expired cache entry for plot"
                unless $res && $res->next;

            $pilot->{'pilot_id'} = $res->{'pilot_id'};
        }

        my @insert;

        # for(;;) loops aren't fashionable, but we need to refer to the next element to
        # get the end date for the current one
        for (my $i = 0; $i < scalar(@corps); $i++) {
            my $corp = $bot->{'dbh'}->do(q{
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

        $bot->{'dbh'}->begin;

        $res = $bot->{'dbh'}->do(q{ delete from eve_pilot_corps where pilot_id = ? }, $pilot->{'pilot_id'});
        $res = $bot->{'dbh'}->do(q{ insert into eve_pilot_corps ??? }, \@insert);

        unless ($bot->{'dbh'}->commit) {
            $bot->{'dbh'}->rollback;
            return "Encountered an error while updating pilot's corporation membership.";
        }

        $res = $bot->{'dbh'}->do(q{
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

    my $res = $bot->{'dbh'}->do(q{
        update eve_corps
        set ???
        where corp_id = ?
        returning *
    }, $corp, $corp->{'corp_id'});

    if ($res && $res->next) {
        return $corp;
    } else {
        $res = $bot->{'dbh'}->do(q{ insert into eve_corps ??? returning * }, $corp);

        return $corp if $res && $res->next;
    }

    return;
}

1;
