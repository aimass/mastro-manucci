
-- Provides GAPP Section 6, primarily for interest income right now

BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000007-gaap-section-six' );

-- adds OTHER account type mostly for heading accounts that are under 'other' in COAs such as GAAP section 6
ALTER TYPE account_type ADD VALUE 'OTHER' AFTER 'EXPENSE';
-- add NA (Not Applicable) for heading accounts that their children could be either Dr or Cr
ALTER TYPE account_drcr ADD VALUE 'NA' AFTER 'CR';

-- alter types need to be commited before first use
COMMIT;
BEGIN;

-- add GAAP section 6
INSERT INTO coa (account, description, type, drcr, heading)
VALUES
-- OTHER headers
('6','Other Income and Expenses','OTHER','NA',TRUE),
('6.1',	'Other Revenue and Expenses','OTHER','NA',TRUE),
('6.1.1','Other Revenue','INCOME','CR',TRUE),
('6.1.2','Other Expenses','EXPENSE','DR',TRUE)
;


COMMIT;