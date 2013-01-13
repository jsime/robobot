package RoboBot::Plugin::EVE;

use strict;
use warnings;

use JSON;
use LWP::Simple;
use Number::Format;
use XML::Simple;

sub commands { qw( eve ) }
sub usage { "[ price <item name or type ID> [<qty>] | item <pattern> | pilot <name> | corp <pattern> | alliance <pattern> ]" }

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

    my $res = $bot->{'dbh'}->do(q{
        select i.item_id, i.name, i.description, ig.name as group_name, igp.path
        from eve_items i
            join eve_item_groups ig on (ig.item_group_id = i.item_group_id)
            join eve_item_group_paths igp on (igp.item_group_id = ig.item_group_id)
        where i.name ~* ?
        order by i.name asc
    }, $name_pattern);

    return unless $res;

    my @r;

    while ($res->next) {
        push(@r, sprintf('%s (%s)', $res->{'name'}, $res->{'path'}));
    }

    return unless scalar(@r) > 0;
    return (@r[0..2], sprintf('... and %d more ...', scalar(@r) - 3)) if scalar(@r) > 3;
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
        select i.item_id, i.name, igp.path
        from eve_items i
            join eve_item_group_paths igp on (igp.item_group_id = i.item_group_id)
        where lower(i.name) = lower(?)
    }, $name);

    if ($res && $res->next) {
        $types{$res->{'item_id'}} = { map { $_ => $res->{$_} } $res->columns };
    } else {
        $res = $bot->{'dbh'}->do(q{
            select i.item_id, i.name, igp.path
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

    $res = $bot->{'dbh'}->do(q{
        select r.region_id, r.name
        from eve_regions r
        where r.name in ???
    }, [@{$bot->{'config'}->plugins->{'eve'}{'regions'}}]);

    return unless $res;

    while ($res->next) {
        $regions{$res->{'region_id'}} = { map { $_ => $res->{$_} } $res->columns };
    }

    my $charname = $bot->{'config'}->plugins->{'eve'}{'pilot'};

    my $url = sprintf('http://api.eve-marketdata.com/api/item_prices2.json?char_name=%s&' .
                      'type_ids=%s&region_ids=%s&buysell=a',
                      $charname, join(',', keys %types), join(',', keys %regions));
    $res = get($url);

    return unless $res;
    my $data = from_json($res) || return;

    my $ft = Number::Format->new();
    my %items;

    foreach my $result (@{$data->{'emd'}{'result'}}) {
        my $type_id = $result->{'row'}->{'typeID'};
        my $region_id = $result->{'row'}->{'regionID'};
        my $buyorsell = $result->{'row'}->{'buysell'};
        my $price = sprintf('%.2f', $result->{'row'}->{'price'});

        $items{$type_id} = { regions => {} } unless $items{$type_id};
        $items{$type_id}{'regions'}{$region_id} = { buy => undef, sell => undef }
            unless $items{$type_id}{'regions'}{$region_id};

        $items{$type_id}{'regions'}{$region_id}{'name'} =
            $regions{$region_id}->{'name'};

        $items{$type_id}{'regions'}{$region_id}{'buy'} =
            $ft->format_number($qty * $price, 2, 1) if $buyorsell eq 'b';
        $items{$type_id}{'regions'}{$region_id}{'sell'} =
            $ft->format_number($qty * $price, 2, 1) if $buyorsell eq 's';

        $items{$type_id}{'name'} = $types{$type_id}->{'name'};
        $items{$type_id}{'category'} = $types{$type_id}->{'path'};
    }

    my @r;

    foreach my $type_id (sort { $items{$a}{'name'} cmp $items{$b}{'name'} } keys %items ) {
        push(@r, sprintf('%s (%s)', $items{$type_id}{'name'}, $items{$type_id}{'category'}));

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
            push(@r, sprintf(" |-[%-${l_region}s] %sBuy: %${l_buy}s / Sell: %${l_sell}s",
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

    my $pilot = $bot->{'dbh'}->do(q{
        select p.*, c.name as corporation, max(pc.from_date) as corporation_date, a.name as alliance
        from eve_pilots p
            join eve_pilot_corps pc on (pc.pilot_id = p.pilot_id and pc.to_date is null)
            join eve_corps c on (c.corp_id = pc.corp_id)
            left join eve_corp_alliances ca on (ca.corp_id = c.corp_id and ca.to_date is null)
            left join eve_alliances a on (a.alliance_id = ca.alliance_id)
        where lower(p.name) = lower(?) and p.cached_until >= now()
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
            name        => $xml->{'result'}{'characterName'},
            gender      => $xml->{'result'}{'gender'},
            race        => $xml->{'result'}{'race'},
            bloodline   => $xml->{'result'}{'bloodline'},
            dob         => $corps[0]->{'startDate'},
            security    => $xml->{'result'}{'securityStatus'},
            cached_until=> $xml->{'result'}{'cachedUntil'} . '+00',
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
            $res = $bot->{'dbh'}->do(q{ insert into eve_pilots ??? returning pilot_id }, $pilot);

            return "Couldn't update expired cache entry for plot"
                unless $res && $res->next;

            $pilot->{'pilot_id'} = $res->{'pilot_id'};
        }

        my @insert;

        # for(;;) loops aren't fashionable, but we need to refer to the next element to
        # get the end date for the current one
        for (my $i; $i < scalar(@corps); $i++) {
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
    push(@r, sprintf('Born:        %s', $pilot->{'dob'});
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

    $xml = $xs->XMLin($resp) || "Error parsing XML response from EVE Online CharacterInfo API.";

    my $corp = {
        corp_id      => $xml->{'result'}{'corporationID'},
        name         => $xml->{'result'}{'corporationName'},
        description  => $xml->{'result'}{'description'},
        ticker       => $xml->{'result'}{'ticker'},
        shares       => $xml->{'result'}{'shares'},
        tax_rate     => $xml->{'result'}{'taxRate'},
        member_count => $xml->{'result'}{'memberCount'},
        cached_until => $xml->{'result'}{'cachedUntil'} . '+00',
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
