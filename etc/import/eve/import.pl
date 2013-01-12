#!/usr/bin/perl

use strict;
use warnings;

use DBIx::DataStore ( config => 'yaml' );
use Text::Iconv;

my %files = (
    groups => { file => 'item_groups.txt',
                cols => { item_group_id   => [  0,  12],
                          parent_group_id => [ 14,  26],
                          name            => [ 28, 127],
                          description     => [129, 384]
                        },
                fkey => { eve_item_groups_parent_group_id_fkey => q{
                            alter table eve_item_groups
                                add foreign key (parent_group_id)
                                references eve_item_groups (item_group_id)
                                on update cascade
                                on delete set null
                            }
                        }
              },
    items  => { file => 'items.txt',
                cols => { item_id       => [  0,  10],
                          item_group_id => [392, 404],
                          name          => [ 12, 111],
                          description   => [113, 368],
                          base_price    => [370, 390]
                        }
              },
    regions=> { file => 'regions.txt',
                cols => { region_id => [ 0, 10],
                          name      => [12, 48]
                        }
              },
);

die "Missing an import file!\n" if grep { !-f $files{$_}->{'file'} || !-r _ } keys %files;

my $cv = Text::Iconv->new('LATIN1','UTF-8');
my $db = DBIx::DataStore->new('robobot');

$db->begin or die $db->error;

# Import Item Groups
if (scalar(keys(%{$files{'groups'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'groups'}{'fkey'}})) {
        my $res = $db->do(qq{ alter table eve_item_groups drop constraint if exists $fkey });
        die "Could not temporarily remove foreign key constraint $fkey: " . $res->error unless $res;
    }
}

open(my $group_fh, '<', $files{'groups'}{'file'}) or die "Error opening groups file: $!";
while (my $line = <$group_fh>) {
    # skip first line if it still contains MSSQL column names
    next if $. == 1 && $line !~ m{^\s*\d+}o;
    chomp($line);

    my %group = ();

    foreach my $column (keys %{$files{'groups'}{'cols'}}) {
        $group{$column} = substr($line,
            $files{'groups'}{'cols'}{$column}[0],
            $files{'groups'}{'cols'}{$column}[1] - $files{'groups'}{'cols'}{$column}[0]);
        $group{$column} =~ s{(^\s+|\s+$)}{}ogs;
        $group{$column} =~ s{\s+}{ }ogs;
        $group{$column} = undef if $group{$column} =~ m{^(NULL|\\N)$}o;

        $group{$column} = $cv->convert($group{$column}) if $group{$column} =~ m{\D+}o;
    }

    my $res = $db->do(q{ insert into eve_item_groups ??? }, \%group);

    unless ($res) {
        $db->rollback;
        die "Error at line $. of $files{'groups'}{'file'}: " . $res->error;
    }
}
close($group_fh);

if (scalar(keys(%{$files{'groups'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'groups'}{'fkey'}})) {
        my $res = $db->do($files{'groups'}{'fkey'}{$fkey});
        die "Could not reinstate foreign key constraint $fkey: " . $res->error unless $res;
    }
}

# Import Items
if (scalar(keys(%{$files{'items'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'items'}{'fkey'}})) {
        my $res = $db->do(qq{ alter table eve_items drop constraint if exists $fkey });
        die "Could not temporarily remove foreign key constraint $fkey: " . $res->error unless $res;
    }
}

open(my $item_fh, '<', $files{'items'}{'file'}) or die "Error opening items file: $!";
while (my $line = <$item_fh>) {
    # skip first line if it still contains MSSQL column names
    next if $. == 1 && $line !~ m{^\s*\d+}o;
    chomp($line);

    my %item = ();

    foreach my $column (keys %{$files{'items'}{'cols'}}) {
        $item{$column} = substr($line,
            $files{'items'}{'cols'}{$column}[0],
            $files{'items'}{'cols'}{$column}[1] - $files{'items'}{'cols'}{$column}[0]);
        $item{$column} =~ s{(^\s+|\s+$)}{}ogs;
        $item{$column} =~ s{\s+}{ }ogs;
        $item{$column} = undef if $item{$column} =~ m{^(NULL|\\N)$}o;

        $item{$column} = $cv->convert($item{$column}) if $item{$column} =~ m{\D+}o;
    }

    my $res = $db->do(q{ insert into eve_items ??? }, \%item);

    unless ($res) {
        $db->rollback;
        die "Error at line $. of $files{'items'}{'file'}: " . $res->error;
    }
}
close($item_fh);

if (scalar(keys(%{$files{'items'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'items'}{'fkey'}})) {
        my $res = $db->do($files{'items'}{'fkey'}{$fkey});
        die "Could not reinstate foreign key constraint $fkey: " . $res->error unless $res;
    }
}

# Import Regions
if (scalar(keys(%{$files{'regions'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'regions'}{'fkey'}})) {
        my $res = $db->do(qq{ alter table eve_regions drop constraint if exists $fkey });
        die "Could not temporarily remove foreign key constraint $fkey: " . $res->error unless $res;
    }
}

open(my $region_fh, '<', $files{'regions'}{'file'}) or die "Error opening regions file: $!";
while (my $line = <$region_fh>) {
    # skip first line if it still contains MSSQL column names
    next if $. == 1 && $line !~ m{^\s*\d+}o;
    chomp($line);

    my %region = ();

    foreach my $column (keys %{$files{'regions'}{'cols'}}) {
        $region{$column} = substr($line,
            $files{'regions'}{'cols'}{$column}[0],
            $files{'regions'}{'cols'}{$column}[1] - $files{'regions'}{'cols'}{$column}[0]);
        $region{$column} =~ s{(^\s+|\s+$)}{}ogs;
        $region{$column} =~ s{\s+}{ }ogs;
        $region{$column} = undef if $region{$column} =~ m{^(NULL|\\N)$}o;

        $region{$column} = $cv->convert($region{$column}) if $region{$column} =~ m{\D+}o;
    }

    my $res = $db->do(q{ insert into eve_regions ??? }, \%region);

    unless ($res) {
        $db->rollback;
        die "Error at line $. of $files{'regions'}{'file'}: " . $res->error;
    }
}
close($region_fh);

if (scalar(keys(%{$files{'regions'}{'fkey'}})) > 0) {
    foreach my $fkey (keys(%{$files{'regions'}{'fkey'}})) {
        my $res = $db->do($files{'regions'}{'fkey'}{$fkey});
        die "Could not reinstate foreign key constraint $fkey: " . $res->error unless $res;
    }
}

$db->commit;
