begin;

create table poll_polls (
    poll_id    serial not null primary key,
    nick_id    integer not null,
    question   text not null,
    created_at timestamp with time zone not null default now(),
    closed_at  timestamp with time zone
);

create index poll_polls_nick_id_idx on poll_polls (nick_id);
create index poll_polls_created_at_idx on poll_polls (created_at);
create index poll_polls_closed_at_idx on poll_polls (closed_at);

alter table poll_polls add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;

create table poll_choices (
    poll_id    integer not null,
    choice_num integer not null,
    choice     text not null
);

alter table poll_choices add primary key (poll_id, choice_num);

create index poll_choices_choice_num_idx on poll_choices (choice_num);

alter table poll_choices add foreign key (poll_id) references poll_polls (poll_id) on update cascade on delete cascade;

create table poll_votes (
    nick_id    integer not null,
    poll_id    integer not null,
    choice_num integer not null,
    voted_at   timestamp with time zone not null default now()
);

alter table poll_votes add primary key (nick_id, poll_id);

create index poll_votes_poll_id_idx on poll_votes (poll_id);
create index poll_votes_choice_num_idx on poll_votes (choice_num);
create index poll_votes_voted_at_idx on poll_votes (voted_at);

alter table poll_votes add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;
alter table poll_votes add foreign key (poll_id, choice_num) references poll_choices (poll_id, choice_num) on update cascade on delete cascade;

commit;
