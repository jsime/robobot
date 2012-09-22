begin;

create table quote_quotes (
    id          serial not null primary key,
    quote       text not null,
    added_by    integer not null,
    added_at    timestamp with time zone not null default now(),
    deleted     boolean not null default false
);

create index quote_quotes_added_by_idx on quote_quotes (added_by);
create index quote_quotes_added_at_idx on quote_quotes (added_at);
create index quote_quotes_deleted_idx on quote_quotes (deleted);

alter table quote_quotes add foreign key (added_by) references nicks (id);

create table quote_tags (
    id          serial not null primary key,
    tag_name    text not null
);

create unique index quote_tags_tag_name_idx on quote_tags (tag_name);

create table quote_quote_tags (
    quote_id    integer not null,
    tag_id      integer not null
);
alter table quote_quote_tags add primary key (quote_id, tag_id);

create index quote_quote_tags_tag_id_idx on quote_quote_tags (tag_id);

alter table quote_quote_tags add foreign key (quote_id) references quote_quotes (id);
alter table quote_quote_tags add foreign key (tag_id) references quote_tags (id);

commit;
