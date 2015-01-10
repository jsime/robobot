begin;

create table macro_defs (
    macro_id    serial not null primary key,
    name        text not null,
    arguments   text[] not null,
    definition  text not null,
    defined_by  integer not null,
    defined_at  timestamp with time zone not null default now()
);

create unique index macro_defs_name_idx on macro_defs (lower(name));
create index macro_defs_defined_by_idx on macro_defs (defined_by);

alter table macro_defs add foreign key (defined_by) references nicks (id) on update cascade;

create table markov_neighbors (
    phrase_id   integer not null,
    neighbor_id integer not null,
    occurrences integer not null default 1
);

alter table markov_neighbors add primary key (phrase_id, neighbor_id);

create index markov_neighbors_neighbor_id_idx on markov_neighbors (neighbor_id);

alter table markov_neighbors add foreign key (phrase_id) references markov_phrases (id) on update cascade on delete cascade;
alter table markov_neighbors add foreign key (neighbor_id) references markov_phrases (id) on update cascade on delete cascade;

commit;
