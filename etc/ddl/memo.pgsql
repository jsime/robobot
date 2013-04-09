begin;

create table memo_memos (
    memo_id       serial not null primary key,
    from_nick_id  integer not null,
    to_nick_id    integer not null,
    message       text not null,
    created_at    timestamp with time zone not null default now(),
    delivered_at  timestamp with time zone
);

create index memo_memos_from_nick_id_idx on memo_memos (from_nick_id);
create index memo_memos_to_nick_id_idx on memo_memos (to_nick_id);
create index memo_memos_created_at_idx on memo_memos (created_at);
create index memo_memos_delivered_at_idx on memo_memos (delivered_at);

alter table memo_memos add foreign key (from_nick_id) references nicks (id) on update cascade on delete cascade;
alter table memo_memos add foreign key (to_nick_id) references nicks (id) on update cascade on delete cascade;

commit;
