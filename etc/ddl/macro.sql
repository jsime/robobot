begin;

create table macros (
    macro_id    serial not null primary key,
    nick_id     integer not null,
    name        text not null,
    macro       text not null,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);

create unique index macros_nick_id_name_idx on macros (nick_id, lower(name));

create index macros_name_idx on macros (lower(name));
create index macros_created_at_idx on macros (created_at);
create index macros_updated_at_idx on macros (updated_at);

alter table macros add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;

commit;
