SET
search_path TO :"nspace", :"apinspace", public;

create table coa
(
    id          serial,
    account     text                                   not null,
    alias       text,
    description text                                   not null,
    type        account_type                           not null,
    drcr        account_drcr                           not null,
    heading     boolean                 default false,
    created     timestamp with time zone default now() not null,
    primary key (id)
);

comment on table coa is 'Chart of Accounts';
comment on column coa.account is 'Account Number';
comment on column coa.alias is 'GAAP, IFRS, etc.';
comment on column coa.description is 'Description';
comment on column coa.type is 'ASSET, etc.';
comment on column coa.drcr is 'System DrCr';
comment on column coa.heading is 'Header/Group Account';

create table journal
(
    id              bigserial,
    uid             uuid         default gen_random_uuid()      not null,
    postdate        timestamp with time zone default now()      not null,
    reference       text,
    description     text,
    debit           numeric(20, 4)                              not null,
    credit          numeric(20, 4)                              not null,
    coa_id          bigint                                      not null,
    parent_id       bigint,
    transaction_id  bigint                                      not null,
    created         timestamp with time zone default now()      not null,
    primary key (id)
);

alter table journal add constraint fk_journal_coa_id foreign key (coa_id) references coa (id);
create index fkidx_journal_coa_id on journal (coa_id);

comment on table journal is 'Core System Journal';
comment on column journal.uid is 'UUID for API';
comment on column journal.postdate is 'Post date';
comment on column journal.reference is 'Optional Ref';
comment on column journal.description is 'Optional Desc';
comment on column journal.debit is 'Debit amount';
comment on column journal.credit is 'Credit amount';
comment on column journal.coa_id is 'CoA Account ID';
comment on column journal.parent_id is 'Parent of Txn group';
comment on column journal.transaction_id is 'Transaction ID FK';


create table entity_subtype
(
    id       smallserial,
    name     text,
    primary key (id)
);

comment on table entity_subtype is 'User defined subtypes for Entities';

create table entity
(
    id                  bigserial,
    uid                 uuid         default gen_random_uuid()             not null,
    name                text                                               not null,
    reference           text                                               not null,
    type                entity_type                                        not null,
    entity_subtype_id   smallint,
    link                jsonb,
    notes               text,
    created             timestamp with time zone default now()             not null,
    primary key (id)
);

alter table entity add constraint fk_entity_subtype_id foreign key (entity_subtype_id) references entity_subtype (id);
create index fkidx_entity_subtype_id on entity (entity_subtype_id);

comment on table entity is 'People and Organizations';
comment on column entity.uid is 'UUID for API';
comment on column entity.name is 'Name of the entity';
comment on column entity.reference is 'Entity identifier';
comment on column entity.type is 'PERSON, etc.';
comment on column entity.entity_subtype_id is 'User defined entity subtype';
comment on column entity.link is 'Ext sys link data (e.g. LDAP, etc.)';
comment on column entity.notes is 'Optional notes';


create table subacct_type
(
    id       smallserial,
    name     text,
    primary key (id)
);

comment on table subacct_type is 'User defined types for Sub Accounts';

create table subacct
(
    id                   bigserial,
    uid                  uuid                     default gen_random_uuid() not null,
    account              text                                               not null,
    subacct_type_id      smallint                                           not null,
    coa_id               integer                                            not null,
    entity_id            bigint                                             not null,
    notes                text,
    created              timestamp with time zone default now()             not null,
    primary key (id)
);

alter table subacct add constraint fk_subacct_coa_id foreign key (coa_id) references coa (id);
alter table subacct add constraint fk_subacct_subacct_type_id foreign key (subacct_type_id) references subacct_type (id);
alter table subacct add constraint fk_subacct_entity_id foreign key (entity_id) references entity (id);

create index fkidx_subacct_coa_id on subacct (coa_id);
create index fkidx_subacct_subacct_type_id on subacct (subacct_type_id);
create index fkidx_subacct_entity_id on subacct (entity_id);

comment on table subacct is 'Sub/Auxiliary Accounts';
comment on column subacct.uid is 'UUID for API';
comment on column subacct.account is 'Account Number';
comment on column subacct.subacct_type_id is 'STANDARD, TRANSIT, etc.';
comment on column subacct.coa_id is 'CoA Account ID FK';
comment on column subacct.entity_id is 'Entity ID FK';
comment on column subacct.notes is 'Optional notes';


create table transaction_state
(
    id       smallserial,
    name     text,
    alias_to integer,
    primary key (id)
);

comment on table transaction_state is 'Transaction States';

create table transaction
(
    id            bigserial,
    uid           uuid                     default gen_random_uuid() not null,
    type          transaction_type                                   not null,
    coa_id        integer,
    subacct_id    bigint,
    amount        numeric(20, 4),
    state_id      smallint                                           not null,
    reference     text                                               not null,
    description   text,
    postdate      timestamp with time zone default now()             not null,
    link          jsonb,
    notes         text,
    created       timestamp with time zone default now()             not null,
    primary key (id)
);

alter table transaction add constraint fk_transaction_subacct_id foreign key (subacct_id) references subacct (id);
alter table transaction add constraint fk_transaction_coa_id foreign key (coa_id) references coa (id);
alter table transaction add constraint fk_transaction_transaction_state_id foreign key (state_id) references transaction_state (id);

create index fkidx_transaction_transaction_coa_id on transaction (coa_id);
create index fkidx_transaction_transaction_state_id on transaction (state_id);
create index fkidx_transaction_subacct_id on transaction (subacct_id);

comment on table transaction is 'Transactions on the Ledger';
comment on column transaction.uid is 'UUID for API';
comment on column transaction.type is 'AR,AP,GL';
comment on column transaction.coa_id is 'EITHER Account of this Tx';
comment on column transaction.subacct_id is 'OR SubAcct of this Tx';
comment on column transaction.amount is 'Optional Total for AP/AR';
comment on column transaction.state_id is 'Current State';
comment on column transaction.reference is 'Transaction identifier';
comment on column transaction.description is 'Optional description';
comment on column transaction.postdate is 'Txn Posted Date';
comment on column transaction.link is 'Ext sys link data (e.g. Invoicing, etc.)';
comment on column transaction.notes is 'Additional notes';

create table transaction_line
(
    id               bigserial,
    transaction_id   bigint,
    coa_id           integer,
    subacct_id       bigint,
    amount           numeric(20, 4)                         not null,
    reference        text,
    description      text,
    notes            text,
    created          timestamp with time zone default now() not null,
    primary key (id)
);

alter table transaction_line add constraint fk_transaction_line_transaction_id foreign key (transaction_id) references transaction (id);
alter table transaction_line add constraint fk_transaction_line_subacct_id foreign key (subacct_id) references subacct (id);
alter table transaction_line add constraint fk_transaction_line_coa_id foreign key (coa_id) references coa (id);

create index fkidx_transaction_line_transaction_id on transaction_line (transaction_id);
create index fkidx_transaction_line_coa_id on transaction_line (coa_id);
create index fkidx_transaction_line_subacct_id on transaction_line (subacct_id);

comment on column transaction_line.transaction_id is 'Transaction ID FK';
comment on column transaction_line.coa_id is 'EITHER Account of this Tx';
comment on column transaction_line.subacct_id is 'OR SubAcct of this Tx';
comment on column transaction_line.amount is 'Amount';
comment on column transaction_line.reference is 'Optional Line identifier';
comment on column transaction_line.description is 'Optional description';
comment on column transaction_line.notes is 'Additional notes';

create table transaction_history
(
    id            bigserial,
    transaction_id   bigint,
    state_from_id smallint,
    state_to_id   smallint,
    notes         text,
    data_in       jsonb,
    data_out      jsonb,
    created       timestamp with time zone default now() not null,
    primary key (id)
);

alter table transaction_history add constraint fk_transaction_history_transaction_id foreign key (transaction_id) references transaction (id);
alter table transaction_history add constraint fk_transaction_transaction_history_state_from_id foreign key (state_from_id) references transaction_state (id);
alter table transaction_history add constraint fk_transaction_transaction_history_state_to_id foreign key (state_to_id) references transaction_state (id);

create index fkidx_transaction_history_transaction_id on transaction_history (transaction_id);
create index fkidx_transaction_history_state_from_id on transaction_history (state_from_id);
create index fkidx_transaction_history_state_to_id on transaction_history (state_to_id);

comment on table transaction_history is 'Documents txn state changes';



