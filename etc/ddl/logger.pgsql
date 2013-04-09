begin;

create table logger_log (
    id          bigserial not null primary key,
    channel_id  integer not null,
    nick_id     integer not null,
    message     text not null,
    posted_at   timestamp with time zone not null default now()
);

create index logger_log_channel_id_idx on logger_log (channel_id);
create index logger_log_nick_id_idx on logger_log (nick_id);
create index logger_log_posted_at_idx on logger_log (posted_at);
create index logger_log_nick_id_posted_at_idx on logger_log (nick_id, posted_at);

alter table logger_log add foreign key (channel_id) references channels (id);
alter table logger_log add foreign key (nick_id) references nicks (id);

commit;
