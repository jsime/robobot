begin;

create table urltitle_urls (
    url_id        serial not null primary key,
    channel_id    integer not null,
    nick_id       integer not null,
    title         text,
    original_url  text not null,
    final_url     text not null,
    linked_at     timestamp with time zone not null default now()
);

create index urltitle_urls_channel_id_idx on urltitle_urls (channel_id);
create index urltitle_urls_nick_id_idx on urltitle_urls (nick_id);
create index urltitle_urls_title_idx on urltitle_urls (title);
create index urltitle_urls_final_url_idx on urltitle_urls (final_url);
create index urltitle_urls_linked_at_idx on urltitle_urls (linked_at);

alter table urltitle_urls add foreign key (channel_id) references channels (id) on update cascade on delete cascade;
alter table urltitle_urls add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;

commit;
