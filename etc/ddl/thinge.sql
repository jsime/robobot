begin;

create table thinge_types (
    id      serial not null primary key,
    name    text not null
);

create unique index thinge_types_name_idx on thinge_types (name);

create table thinge_thinges (
    id          serial not null primary key,
    type_id     integer not null,
    thinge_num  integer not null,
    thinge_url  text not null,
    added_by    integer not null,
    added_at    timestamp with time zone not null default now(),
    deleted     boolean not null default false
);

create index thinge_thinges_type_id_idx  on thinge_thinges (type_id);
create index thinge_thinges_added_by_idx on thinge_thinges (added_by);
create index thinge_thinges_added_at_idx on thinge_thinges (added_at);
create index thinge_thinges_deleted_idx  on thinge_thinges (deleted);

create unique index thinge_thinges_type_id_thinge_url_idx on thinge_thinges (type_id, thinge_url);
create unique index thinge_thinges_type_id_thinge_num_idx on thinge_thinges (type_id, thinge_num);

alter table thinge_thinges add foreign key (type_id) references thinge_types (id);
alter table thinge_thinges add foreign key (added_by) references nicks (id);

create table thinge_tags (
    id          serial not null primary key,
    tag_name    text not null
);

create unique index thinge_tags_tag_name_idx on thinge_tags (lower(tag_name));

create table thinge_thinge_tags (
    thinge_id   integer not null,
    tag_id      integer not null
);
alter table thinge_thinge_tags add primary key (thinge_id, tag_id);

create index thinge_thinge_tags_tag_id_idx on thinge_thinge_tags (tag_id);

alter table thinge_thinge_tags add foreign key (thinge_id) references thinge_thinges (id);
alter table thinge_thinge_tags add foreign key (tag_id) references thinge_tags (id);

commit;
