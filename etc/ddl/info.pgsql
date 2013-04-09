begin;

create table info_entries (
    info_id     serial not null primary key,
    title       text not null,
    deleted     boolean not null default 'f',
    deleted_by  integer
);

create unique index info_entries_lower_title_idx on info_entries (lower(title));
create index info_entries_deleted_idx on info_entries (deleted);
create index info_entries_deleted_by_idx on info_entries (deleted_by);

alter table info_entries add foreign key (deleted_by) references nicks (id) on update cascade on delete set null;

create table info_revisions (
    revision_id  serial not null primary key,
    info_id      integer not null,
    body         text not null,
    added_by     integer not null,
    added_at     timestamp with time zone not null default now()
);

create index info_revisions_info_id_idx on info_revisions (info_id);
create index info_revisions_added_by_idx on info_revisions (added_by);
create index info_revisions_added_at_idx on info_revisions (added_at);

alter table info_revisions add foreign key (info_id) references info_entries (info_id) on update cascade on delete cascade;
alter table info_revisions add foreign key (added_by) references nicks (id) on update cascade on delete cascade;

commit;
