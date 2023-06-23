--TODO: add additional rules to guarantee integrity, regardlkess of code bugs
-- (1) avoid cascade deletes on COA
-- (2) validate direct journal entries to comply with double entry

--Transaction: enforce if AP then coa_id OR subacct_id
--Transaction enforce if GL then coa_id, subacct_id and amount are null


