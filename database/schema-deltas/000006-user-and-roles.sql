
-- adds users and roles

BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000006-user-and-roles' );


create table auser
(
    id                    bigserial,
    username              text                                             not null unique,
    name                  text,
    given_name            text,
    family_name           text,
    sub                   text,
    aud                   text,
    accountid             text,
    iss                   text,
    email                 text,
    email_verified        boolean,
    zoneinfo              text,
    locale                text,
    phone_number          text,
    phone_number_verified boolean,
    created               timestamp without time zone default now()        not null,
    primary key (id)
);

comment on table auser is 'System Users';
comment on column auser.username is 'The unique username in our system';
comment on column auser.name is 'name claim';
comment on column auser.given_name is 'given_name claim';
comment on column auser.family_name is 'family_name claim';
comment on column auser.sub is 'sub claim';
comment on column auser.aud is 'aud claim';
comment on column auser.accountid is 'accountId claim';
comment on column auser.iss is 'iss claim';
comment on column auser.email is 'email claim';
comment on column auser.email_verified is 'email_verified claim';
comment on column auser.zoneinfo is 'zoneinfo claim';
comment on column auser.locale is 'locale claim';
comment on column auser.phone_number is 'phone_number claim';
comment on column auser.phone_number_verified is 'phone_number_verified claim';
comment on column auser.created is 'created claim';

create table arole
(
    id                    serial,
    name                  text                                             not null unique,
    description           text                                             not null,
    primary key (id)
);

comment on table arole is 'System Roles';
comment on column arole.name is 'Name of role';
comment on column arole.description is 'Description of role';

insert into arole (name, description) values ('viewer','View only user');

create table user_role
(
    auser_id              bigint      not null,
    arole_id              bigint      not null,
    primary key (auser_id,arole_id)
);

comment on table user_role is 'User Roles';
comment on column user_role.auser_id is 'User id';
comment on column user_role.arole_id is 'Role id';

alter table user_role add constraint fk_user_role_auser_id foreign key (auser_id) references auser (id);
alter table user_role add constraint fk_user_role_arole_id foreign key (arole_id) references arole (id);
-- no need to create fk indexes because both fields are pk

GRANT SELECT,INSERT,UPDATE,DELETE ON :"nspace".auser TO :rolename;
GRANT SELECT,INSERT,UPDATE,DELETE ON :"nspace".arole TO :rolename;
GRANT SELECT,INSERT,UPDATE,DELETE ON :"nspace".user_role TO :rolename;
GRANT SELECT,UPDATE ON :"nspace".auser_id_seq TO :rolename;
GRANT SELECT,UPDATE ON :"nspace".arole_id_seq TO :rolename;

COMMIT;