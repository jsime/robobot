begin;

create table note_notes (
    note_id     serial not null primary key,
    nick_id     integer not null,
    note        text not null,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);

create index note_notes_nick_id_idx on note_notes (nick_id);
create index note_notes_created_at_idx on note_notes (created_at);

alter table note_notes add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;

commit;
