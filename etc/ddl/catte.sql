begin;

create table catte_types (
    id      serial not null primary key,
    name    text not null
);

create unique index catte_types_name_idx on catte_types (name);

create table catte_cattes (
    id          serial not null primary key,
    type_id     integer not null,
    catte_url   text not null,
    added_by    integer not null,
    added_at    timestamp with time zone not null default now(),
    deleted     boolean not null default false
);

create index catte_cattes_type_id_idx on catte_cattes (type_id);
create index catte_cattes_added_by_idx on catte_cattes (added_by);
create index catte_cattes_added_at_idx on catte_cattes (added_at);
create index catte_cattes_deleted_idx on catte_cattes (deleted);

create unique index catte_cattes_catte_url_idx on catte_cattes (catte_url);

alter table catte_cattes add foreign key (type_id) references catte_types (id);
alter table catte_cattes add foreign key (added_by) references nicks (id);

create table catte_tags (
    id          serial not null primary key,
    tag_name    text not null
);

create unique index catte_tags_tag_name_idx on catte_tags (tag_name);

create table catte_catte_tags (
    catte_id    integer not null,
    tag_id      integer not null
);
alter table catte_catte_tags add primary key (catte_id, tag_id);

create index catte_catte_tags_tag_id_idx on catte_catte_tags (tag_id);

alter table catte_catte_tags add foreign key (catte_id) references catte_cattes (id);
alter table catte_catte_tags add foreign key (tag_id) references catte_tags (id);

commit;
