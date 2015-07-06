begin;

drop schema if exists robobot cascade;
create schema robobot authorization robobot;

set search_path to robobot;

--
-- NICKS, NETWORKS, CHANNELS
--
create table nicks (
    id          serial not null primary key,
    name        text not null,
    extradata   jsonb not null default '{}',
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);
create unique index nicks_lower_name_idx on nicks (lower(name));

create table networks (
    id          serial not null primary key,
    name        text not null,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);
create unique index networks_lower_name_idx on networks (lower(name));

create table channels (
    id          serial not null primary key,
    network_id  integer not null references networks (id) on update cascade on delete cascade,
    name        text not null,
    extradata   jsonb not null default '{}',
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);
create unique index channels_network_lower_name_idx on channels (network_id, lower(name));

--
-- MACROS
--
create table macros (
    macro_id    serial not null primary key,
    name        text not null,
    arguments   text[] not null,
    definition  text not null,
    defined_by  integer not null references nicks (id) on update cascade on delete cascade,
    defined_at  timestamp with time zone not null default now()
);
create unique index macros_name_idx on macros (lower(name));

--
-- AUTHORIZATIONS
--
create table auth_permissions (
    permission_id   serial not null primary key,
    network_id      integer not null references networks (id) on update cascade on delete cascade,
    nick_id         integer references nicks (id) on update cascade on delete cascade,
    command         text not null,
    state           text not null,
    granted_by      integer not null references nicks (id) on update cascade on delete cascade,
    created_at      timestamp with time zone not null default now(),
    updated_at      timestamp with time zone
);
create unique index auth_permissions_network_nick_command_idx on auth_permissions (network_id, nick_id, command);
create index auth_permissions_command_idx on auth_permissions (command);
alter table auth_permissions add constraint "Valid permissions states." check (state in ('allow','deny'));

--
-- CHANNEL LOGGER
--
create table logger_log (
    id              serial not null primary key,
    channel_id      integer not null references channels (id) on update cascade on delete cascade,
    nick_id         integer not null references nicks (id) on update cascade on delete cascade,
    message         text not null,
    has_expression  boolean not null default false,
    posted_at       timestamp with time zone not null default now()
);
create index logger_log_channel_posted_at_idx on logger_log (channel_id, posted_at);
create index logger_log_nick_posted_at_idx on logger_log (nick_id, posted_at);
create index logger_log_posted_at_idx on logger_log (posted_at);

--
-- THINGE
--
create table thinge_types (
    id      serial not null primary key,
    name    text not null
);
create unique index thinge_types_lower_name_idx on thinge_types (lower(name));

create table thinge_thinges (
    id          serial not null primary key,
    type_id     integer not null references thinge_types (id) on update cascade on delete cascade,
    thinge_num  integer not null,
    thinge_url  text not null,
    added_by    integer not null references nicks (id) on update cascade on delete cascade,
    added_at    timestamp with time zone not null default now(),
    deleted     boolean not null default false
);
create unique index thinge_thinges_type_num_idx on thinge_thinges (type_id, thinge_num);
create unique index thinge_thinges_type_url_idx on thinge_thinges (type_id, thinge_url);

create table thinge_tags (
    id       serial not null primary key,
    tag_name text not null
);
create unique index thinge_tags_lower_name_idx on thinge_tags (lower(tag_name));

create table thinge_thinge_tags (
    thinge_id   integer not null references thinge_thinges (id) on update cascade on delete cascade,
    tag_id      integer not null references thinge_tags (id) on update cascade on delete cascade
);
alter table thinge_thinge_tags add primary key (thinge_id, tag_id);

--
-- KARMA
--
create table karma_karma (
    id              serial not null primary key,
    nick_id         integer not null references nicks (id) on update cascade on delete cascade,
    karma           integer not null,
    from_nick_id    integer not null references nicks (id) on update cascade on delete cascade,
    created_at      timestamp with time zone not null default now()
);
alter table karma_karma add constraint "One vote for or against at a time." check (karma in (-1,1));

--
-- MARKOV GENERATOR
--
create table markov_phrases (
    id          serial not null primary key,
    nick_id     integer not null references nicks (id) on update cascade on delete cascade,
    structure   text not null,
    phrase      text not null,
    used_count  integer not null default 1,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);
create index markov_phrases_structure_idx on markov_phrases (structure);
create index markov_phrases_phrase_idx on markov_phrases (phrase);

create table markov_neighbors (
    phrase_id   integer not null references markov_phrases (id) on update cascade on delete cascade,
    neighbor_id integer not null references markov_phrases (id) on update cascade on delete cascade,
    occurrences integer not null default 1,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);
alter table markov_neighbors add primary key (phrase_id, neighbor_id);

create table markov_sentence_forms (
    id          serial not null primary key,
    nick_id     integer not null references nicks (id) on update cascade on delete cascade,
    structure   text not null,
    used_count  integer not null default 1,
    created_at  timestamp with time zone not null default now(),
    updated_at  timestamp with time zone
);

--
-- MEMOS
--
create table memo_memos (
    memo_id      serial not null primary key,
    from_nick_id integer not null references nicks (id) on update cascade on delete cascade,
    to_nick_id   integer not null references nicks (id) on update cascade on delete cascade,
    message      text not null,
    created_at   timestamp with time zone not null default now(),
    delivered_at timestamp with time zone
);
create index memo_memos_delivered_at_idx on memo_memos (delivered_at);

--
-- SKILLS
--
create table skills_skills (
    skill_id    serial not null primary key,
    name        text not null,
    created_by  integer references nicks (id) on update cascade on delete set null,
    created_at  timestamp with time zone not null default now()
);
create unique index skills_lower_name_idx on skills_skills (lower(name));

create table skills_levels (
    level_id    serial not null primary key,
    name        text not null,
    sort_order  integer not null default 0
);
create unique index skills_levels_lower_name_idx on skills_levels (lower(name));
insert into skills_levels (name, sort_order) values
    ('Novice',0),
    ('Intermediate',1),
    ('Advanced',2),
    ('Expert',3),
    ('Creator',4);

create table skills_nicks (
    skill_id        integer not null references skills_skills (skill_id) on update cascade on delete cascade,
    nick_id         integer not null references nicks (id) on update cascade on delete cascade,
    skill_level_id  integer not null references skills_levels (level_id) on update cascade on delete cascade
);
alter table skills_nicks add primary key (skill_id, nick_id);

--
-- URL TITLES
--
create table urltitle_urls (
    url_id       serial not null primary key,
    channel_id   integer not null references channels (id) on update cascade on delete cascade,
    nick_id      integer not null references nicks (id) on update cascade on delete cascade,
    title        text,
    original_url text not null,
    final_url    text not null,
    linked_at    timestamp with time zone not null default now()
);
create index urltitle_urls_original_url_idx on urltitle_urls (original_url);
create index urltitle_urls_final_url_idx on urltitle_urls (final_url);
create index urltitle_urls_title_idx on urltitle_urls (title);

--
-- GITHUB API
--
create table github_repos (
    repo_id     serial not null primary key,
    owner_name  text not null,
    repo_name   text not null,
    created_at  timestamp with time zone not null default now(),
    polled_at   timestamp with time zone,
    last_pr     integer,
    last_issue  integer
);
create unique index github_repos_owner_repo_idx on github_repos (owner_name, repo_name);

create table github_repo_channels (
    repo_id     integer not null references github_repos (repo_id) on update cascade on delete cascade,
    channel_id  integer not null references channels (id) on update cascade on delete cascade
);
alter table github_repo_channels add primary key (repo_id, channel_id);

commit;
