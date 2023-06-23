-- ADDITIONAL OPTIMIZATION INDEXES

SET search_path TO :"nspace", :"apinspace", public;

-- COA
create unique index coa_account_idx on coa (account);

-- debtor and creditor UUID and reference
CREATE UNIQUE INDEX subacct_uid_idx ON subacct (uid);
CREATE UNIQUE INDEX subacct_subacct_idx ON subacct (account);

-- jsonb indexes
create index entity_link_idx on entity using gin (link);
create index transaction_history_data_in_idx on transaction_history using gin (data_in jsonb_path_ops);
create index transaction_history_data_out_idx on transaction_history using gin (data_out jsonb_path_ops);

