begin;

create table skills_skills (
    skill_id    serial not null primary key,
    name        text not null,
    see_also    integer,
    created_by  integer not null,
    created_at  timestamp with time zone not null default now()
);

create unique index skills_skills_lower_name_idx on skills_skills (lower(name));
create index skills_skills_name_idx on skills_skills (name); -- for sorting, vs. skill uniqueness above
create index skills_skills_see_also_idx on skills_skills (see_also);
create index skills_skills_created_by_idx on skills_skills (created_by);

alter table skills_skills add foreign key (see_also) references skills_skills (skill_id) on update cascade on delete set null;
alter table skills_skills add foreign key (created_by) references nicks (id) on update cascade on delete cascade;

create table skills_levels (
    level_id    serial not null primary key,
    name        text not null,
    sort_order  integer not null default 0
);

create unique index skills_levels_lower_name_idx on skills_levels (lower(name));
create unique index skills_levels_sort_order_idx on skills_levels (sort_order);

alter table skills_levels add constraint skill_level_names check (name in ('Novice','Intermediate','Expert','Creator'));

insert into skills_levels (name, sort_order) values
    ('Novice',0),
    ('Intermediate',1),
    ('Expert',2),
    ('Creator',3)
;

create table skills_nicks (
    skill_id        integer not null,
    nick_id         integer not null,
    skill_level_id  integer not null
);
alter table skills_nicks add primary key (skill_id, nick_id);

create index skills_nicks_nick_id_idx on skills_nicks (nick_id);
create index skills_nicks_skill_level_id_idx on skills_nicks (skill_level_id);

alter table skills_nicks add foreign key (skill_id) references skills_skills (skill_id) on update cascade on delete cascade;
alter table skills_nicks add foreign key (nick_id) references nicks (id) on update cascade on delete cascade;
alter table skills_nicks add foreign key (skill_level_id) references skills_levels (level_id) on update cascade on delete cascade;

commit;
