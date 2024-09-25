-- ADDITIONAL OPTIMIZATION INDEXES

--FIXME: optimize indexes

SET search_path TO :"nspace", :"apinspace", public;

-- COA
create unique index coa_account_idx on coa (account);

-- UUIDs

-- jsonb indexes
create index entity_link_idx on entity using gin (meta);
create index transaction_link_idx on transaction using gin (meta);
create index transaction_history_data_in_idx on transaction_history using gin (data_in jsonb_path_ops);
create index transaction_history_data_out_idx on transaction_history using gin (data_out jsonb_path_ops);


