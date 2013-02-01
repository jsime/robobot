begin;

create table auth_permissions (
    permission_id   serial not null,
    server_id       integer not null,
    nick_id         integer, -- null indicates command default state for server_id
    command         text not null,
    state           text not null,
    granted_by      integer not null,
    created_at      timestamp with time zone not null default now(),
    updated_at      timestamp with time zone
);
alter table auth_permissions add primary key (permission_id);
create unique index auth_permissions_server_nick_command_idx on auth_permissions (server_id, nick_id, command);
create index auth_permissions_nick_id_idx on auth_permissions (nick_id);
create index auth_permissions_command_idx on auth_permissions (command);
create index auth_permissions_granted_by_idx on auth_permissions (granted_by);
alter table auth_permissions add foreign key (server_id) references servers (id) on update cascade on delete cascade;
alter table auth_permissions add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;
alter table auth_permissions add foreign key (granted_by) references nicks (id) on update cascade on delete cascade;
alter table auth_permissions add constraint permission_states check (state in ('allow','deny'));

commit;
