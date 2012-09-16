begin;

create table servers (
    id      serial not null primary key,
    name    text not null
);

create unique index servers_name_idx on servers (name);

create table channels (
    id          serial not null primary key,
    server_id   integer not null,
    name        text not null
);

create index channels_server_id_idx on channels (server_id);
create index channels_name_idx on channels (name);
create unique index channels_server_id_name_idx on channels (server_id, name);

alter table channels add foreign key (server_id) references servers (id);

create table nicks (
    id      serial not null primary key,
    nick    text not null
);

create unique index nicks_nick_idx on nicks (nick);

commit;
