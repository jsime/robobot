begin;

create table markov_sentence_forms (
    id          serial not null primary key,
    nick_id     integer not null,
    structure   text not null,
    used_count  integer not null default 1
);

create index markov_sentence_forms_nick_id_idx on markov_sentence_forms (nick_id);
create index markov_sentence_forms_structure_idx on markov_sentence_forms (structure);

alter table markov_sentence_forms add foreign key (nick_id) references nicks (id);

create table markov_phrases (
    id          serial not null primary key,
    nick_id     integer not null,
    structure   text not null,
    phrase      text not null,
    used_count  integer not null default 1
);

create index markov_phrases_nick_id_idx on markov_phrases (nick_id);
create index markov_phrases_structure_idx on markov_phrases (structure);
create index markov_phrases_phrase_idx on markov_phrases (phrase);

alter table markov_phrases add foreign key (nick_id) references nicks (id);

commit;
