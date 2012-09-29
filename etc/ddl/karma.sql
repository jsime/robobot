begin;

create table karma_karma (
    id              serial not null primary key,
    nick_id         integer not null,
    karma           integer not null,
    from_nick_id    integer not null,
    created_at      timestamp with time zone not null default now()
);

create index karma_karma_nick_id_idx on karma_karma (nick_id);
create index karma_karma_from_nick_id_idx on karma_karma (from_nick_id);
create index karma_karma_created_at_idx on karma_karma (created_at);

alter table karma_karma add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;
alter table karma_karma add foreign key (from_nick_id) references nicks (id) on update cascade on delete cascade;

alter table karma_karma add constraint karma_values check (karma in (1,-1));

commit;
