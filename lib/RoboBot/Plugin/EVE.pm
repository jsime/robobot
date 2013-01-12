package RoboBot::Plugin::EVE;

use strict;
use warnings;

use JSON;
use LWP::Simple;
use Number::Format;
use XML::Simple;

sub commands { qw( eve ) }
sub usage { "[ price <item name or type ID> [<qty>] [<region>] | item <pattern> | pilot <name> | corp <pattern> | alliance <pattern> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

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

    # DEMO PURPOSES ONLY -- hardcoded type ID and regions, ignores all arguments

    my $url = sprintf('http://api.eve-marketdata.com/api/item_prices2.json?char_name=%s&' .
                      'type_ids=%s&region_ids=%s&buysell=a',
                      $charname, join(',', keys %items), join(',', keys %regions));
    my $res = get($url);

    return unless $res;
    my $data = from_json($res) || return;

    my %items;

    foreach my $result (@{$data->{'emd'}{'result'}}) {
        my $type_id = $result->{'row'}->{'typeID'};
        my $region_id = $result->{'row'}->{'regionID'};
        my $buyorsell = $result->{'row'}->{'buysell'};
        my $price = sprintf('%.2f', $result->{'row'}->{'price'});

        $items{$type_id} = { regions => {} } unless $items{$type_id};
        $items{$type_id}{'regions'}{$region_id} = { buy => undef, sell => undef }
            unless $items{$type_id}{'regions'}{$region_id};

        # DEMO PURPOSES ONLY -- fake a region name
        $items{$type_id}{'regions'}{$region_id}{'name'} =
            (qw( Citadel Maal Genesis Syndicate ))[int(rand(4))];

        $items{$type_id}{'regions'}{$region_id}{'buy'} = $price if $buyorsell eq 'b';
        $items{$type_id}{'regions'}{$region_id}{'sell'} = $price if $buyorsell eq 's';

        # DEMO PURPOSES ONLY -- fake name for now
        $items{$type_id}{'name'} =
            (qw( Tritanium Pyerite Isogen Mexallon Megacyte ))[int(rand(5))];
        $items{$type_id}{'category'} = 'Manufacturing > Materials > Minerals';
    }

    my $ft = Number::Format->new();
    my @r;

    foreach my $type_id (sort { $items{$a}{'name'} cmp $items{$b}{'name'} } keys %items ) {
        push(@r, sprintf('%s (%s)', $items{$type_id}{'name'}, $items{$type_id}{'category'}));

        foreach my $region_id (sort { $items{$type_id}{'regions'}{$a} cmp $items{$type_id}{'regions'}{$b} } keys %{$items{$type_id}{'regions'}}) {
            push(@r, sprintf(' |-[%s] Buy: %s / Sell: %s',
                $items{$type_id}{'regions'}{$region_id}{'name'},
                $ft->format_number($items{$type_id}{'regions'}{$region_id}{'buy'}, 2),
                $ft->format_number($items{$type_id}{'regions'}{$region_id}{'sell'}, 2))
            );
        }
    }

    return @r;
}

sub pilot_info {
    my ($bot, $name) = @_;

    return unless $name =~ m{^[a-z0-9 .-]+$}oi;

    my $res = $bot->{'dbh'}->do(q{
        -- placeholder so robobot doesn't break if i restart the daemon
        select 1 where ? is not null
    }, $name);

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

    my @r = (sprintf('Pilot:       %s', $xml->{'result'}{'characterName'}));
    push(@r, sprintf('Race:        %s (%s)', $xml->{'result'}{'bloodline'}, $xml->{'result'}{'race'}));
    push(@r, sprintf('Corporation: %s (since: %s)', $xml->{'result'}{'corporation'}, $xml->{'result'}{'corporationDate'}));
    push(@r, sprintf('Alliance:    %s', $xml->{'result'}{'alliance'})) if $xml->{'result'}{'alliance'};
    push(@r, sprintf('Sec. Status: %.2f', $xml->{'result'}{'securityStatus'}));

    return @r;
}

1;
