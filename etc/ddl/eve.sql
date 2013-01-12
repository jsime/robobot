begin;

create table eve_item_groups (
    item_group_id   integer not null primary key,
    parent_group_id integer,
    name            text not null,
    description     text
);
create index eve_item_groups_parent_group_id_idx on eve_item_groups (parent_group_id);
create index eve_item_groups_name_idx on eve_item_groups (name);
alter table eve_item_groups add foreign key (parent_group_id) references eve_item_groups (item_group_id) on update cascade on delete set null;

create table eve_items (
    item_id         integer not null primary key,
    item_group_id   integer not null,
    name            text not null,
    description     text,
    base_price      numeric(18,2) not null default 0.00
);
create index eve_items_item_group_id_idx on eve_items (item_group_id);
create index eve_items_name_text_pattern_ops_idx on eve_items (name text_pattern_ops);
create index eve_items_base_price_idx on eve_items (base_price);
alter table eve_items add foreign key (item_group_id) references eve_item_groups (item_group_id) on update cascade;

create table eve_regions (
    region_id   integer not null primary key,
    name        text not null
);
create unique index eve_regions_name_idx on eve_regions (name);

create table eve_item_prices (
    item_id         integer not null,
    region_id       integer not null,
    price           numeric(18,2) not null default 0.00,
    cached_until    timestamp with time zone not null default now() + interval '1 hour'
);
alter table eve_item_prices add primary key (item_id, region_id);
create index eve_item_prices_region_id_idx on eve_item_prices (region_id);
create index eve_item_prices_cached_until_idx on eve_item_prices (cached_until);
alter table eve_item_prices add foreign key (item_id) references eve_items (item_id) on update cascade on delete cascade;
alter table eve_item_prices add foreign key (region_id) references eve_regions (region_id) on update cascade on delete cascade;

create table eve_pilots (
    pilot_id      integer not null primary key,
    name          text not null,
    gender        text not null,
    race          text not null,
    bloodline     text not null,
    dob           timestamp with time zone not null,
    security      numeric(6,4) not null default 0.0000,
    cached_until  timestamp with time zone
);
create unique index eve_pilots_name_idx on eve_pilots (name);
create index eve_pilots_gender_idx on eve_pilots (gender);
create index eve_pilots_cached_until_idx on eve_pilots (cached_until);
alter table eve_pilots add constraint pilot_gender check (gender in ('Female','Male'));
alter table eve_pilots add constraint security_status check (security between -10.0000 and 10.0000);

create table eve_corps (
    corp_id       integer not null primary key,
    name          text not null,
    description   text,
    ticker        text not null,
    shares        integer not null default 0,
    tax_rate      numeric(5,2) not null default 0.00,
    member_count  integer not null default 1,
    cached_until  timestamp with time zone
);
create unique index eve_corps_name_idx on eve_corps (name);
create unique index eve_corps_ticker_idx on eve_corps (ticker);
create index eve_corps_cached_until_idx on eve_corps (cached_until);
alter table eve_corps add constraint positive_shares check (shares >= 0);
alter table eve_corps add constraint positive_tax_rate check (tax_rate between 0.00 and 100.00);
alter table eve_corps add constraint corp_membership check (member_count > 0);

create table eve_alliances (
    alliance_id   integer not null primary key,
    name          text not null,
    short_name    text not null,
    cached_until  timestamp with time zone
);
create unique index eve_alliances_name_idx on eve_alliances (name);
create unique index eve_alliances_short_name_idx on eve_alliances (short_name);
create index eve_alliances_cached_until_idx on eve_alliances (cached_until);

create table eve_pilot_corps (
    pilot_id    integer not null,
    corp_id     integer not null,
    from_date   timestamp with time zone not null,
    to_date     timestamp with time zone
);
alter table eve_pilot_corps add primary key (pilot_id, corp_id, from_date, to_date);
create index eve_pilot_corps_corp_id_idx on eve_pilot_corps (corp_id);
create index eve_pilot_corps_from_date_idx on eve_pilot_corps (from_date);
create index eve_pilot_corps_to_date_idx on eve_pilot_corps (to_date);
alter table eve_pilot_corps add constraint membership_dates check (to_date is null or (to_date > from_date));
alter table eve_pilot_corps add foreign key (pilot_id) references eve_pilots (pilot_id) on update cascade on delete cascade;
alter table eve_pilot_corps add foreign key (corp_id) references eve_corps (corp_id) on update cascade on delete cascade;

create table eve_corp_alliances (
    corp_id     integer not null,
    alliance_id integer not null,
    from_date   timestamp with time zone not null,
    to_date     timestamp with time zone
);
alter table eve_corp_alliances add primary key (corp_id, alliance_id, from_date, to_date);
create index eve_corp_alliances_alliance_id_idx on eve_corp_alliances (alliance_id);
create index eve_corp_alliances_from_date_idx on eve_corp_alliances (from_date);
create index eve_corp_alliances_to_date_idx on eve_corp_alliances (to_date);
alter table eve_corp_alliances add constraint alliance_dates check (to_date is null or (to_date > from_date));

create table eve_nick_regions (
    nick_id     integer not null,
    region_id   integer not null
);
alter table eve_nick_regions add primary key (nick_id, region_id);
create index eve_nick_regions_region_id_idx on eve_nick_regions (region_id);
alter table eve_nick_regions add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;
alter table eve_nick_regions add foreign key (region_id) references eve_regions (region_id) on update cascade on delete cascade;

commit;
