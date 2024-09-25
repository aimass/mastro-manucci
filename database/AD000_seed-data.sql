
SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO coa (account, description, type, drcr, heading)
VALUES
-- ASSET headers
('1','Assets','ASSET','DR',TRUE),
('1.1','Cash and Financial Assets','ASSET','DR',TRUE),
('1.1.1','Cash and Cash Equivalents','ASSET','DR',TRUE),
('1.1.3','Restricted Cash and Financial Assets','ASSET','DR',TRUE),
-- ASSETS real
('1.1.3.110','Total available cash in FBO',	'ASSET','DR',false),
('1.1.3.115','FBO Witheld Cash (in transit outbound)','ASSET','DR',false),
('1.1.3.120','FBO Incoming Cash (in transit inbound)','ASSET','DR',false),
('1.1.3.210','Total available cash at FRBNY','ASSET','DR',false),
('1.1.3.215','FRBNY Withheld Cash (in transit outbound)','ASSET','DR',false),
('1.1.3.220','FRBNY Incoming Cash (in transit inbound)','ASSET','DR',false),
-- ASSET headers
('1.2','Receivables and Contracts','ASSET','DR',TRUE),
('1.2.1','Accounts, Notes and Loans Receivable','ASSET','DR',TRUE),
-- ASSETS real
('1.2.1.1','Customer Invoices','ASSET','DR',false),
-- LIABILITY headers
('2','Liabilities','LIABILITY','CR',TRUE),
('2.2','Accruals, Deferrals and Other Liabilities','LIABILITY','CR',TRUE),
('2.2.5','Other Liabilities','LIABILITY','CR',TRUE),
-- LIABILITIES real
('2.2.5.1','Customer Transit Accounts','LIABILITY','CR',false),
-- LIABILITY headers
('2.3','Financial Labilities','LIABILITY','CR',TRUE),
('2.3.1','Notes Payable','LIABILITY','CR',TRUE),
-- REVENUE headers
('4','Revenue','INCOME','CR',TRUE),
('4.1',	'Recognized Point of Time','INCOME','CR',TRUE),
('4.1.2','Services','INCOME','CR',TRUE),
-- REVENUE real
('4.1.2.10','Customer Revenue','INCOME','CR',false),
('4.1.2.10.100.010','Customer A Revenue','INCOME','CR',false),
('4.1.2.10.110.010','Customer B Revenue','INCOME','CR',false)
;

-- WARNING: DO NOT DELETE/CHANGE THESE. You  can add new ones as aliases to these (intermediate states)
INSERT INTO transaction_state (name) VALUES
                                      ('DRAFT'),
                                      ('APPROVED'),
                                      ('IN_PROGRESS'),
                                      ('COMPLETE'),
                                      ('CANCELED'),
                                      ('REVERSED')
;

-- YMMV
INSERT INTO entity_subtype (name) VALUES
                                    ('CUSTOMER'),
                                    ('VENDOR'),
                                    ('PARTNER')
;

-- YMMV
INSERT INTO subacct_type (name) VALUES
                                      ('STANDARD'),
                                      ('RESTRICTED'),
                                      ('TRANSIT'),
                                      ('FBO'),
                                      ('JOINT'),
                                      ('BUDGET'),
                                      ('CC')
;

