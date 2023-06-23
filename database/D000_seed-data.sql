-- Bare bones functional COA
-- DO NOT DELETE OR MODIFY BASE ACCOUNTS, namely:
-- 1010, 2010, 3010, 4010, 5010
-- As a general rules, it's better to add to the COA rather than remove or modify the basic one.
INSERT INTO coa (account, description, type, drcr, heading)
VALUES
-- *** ASSETS *** (DR)
('1000'  ,'CURRENT ASSETS'         ,'ASSET'     ,'DR'  ,TRUE),
('1010'  ,'Accounts Receivable'    ,'ASSET'     ,'DR'  ,false),
('1020'  ,'Cash on Hand'           ,'ASSET'     ,'DR'  ,false),
-- INVENTORY
('1500'  ,'INVENTORY ASSETS'       ,'ASSET'     ,'DR'  ,TRUE),
('1510'  ,'Inventory General'      ,'ASSET'     ,'DR'  ,false),

-- *** LIABILITIES *** (CR)
('2000'  ,'CURRENT LIABILITIES'    ,'LIABILITY' ,'CR'  ,TRUE),
('2010'  ,'Accounts Payable'       ,'LIABILITY' ,'CR'  ,false),

-- *** CAPITAL *** (CR)
('3000'  ,'CAPITAL'                ,'EQUITY'    ,'CR'  ,TRUE),
('3010'  ,'Common Stock'           ,'EQUITY'    ,'CR'  ,false),

-- *** INCOME *** (CR)
('4000'  ,'INCOME'                 ,'INCOME'    ,'CR'  ,TRUE),
('4010'  ,'Revenue'                ,'INCOME'    ,'CR'  ,false),

-- *** EXPENSE *** (DR)
('5000'  ,'GENERAL EXPENSES'       ,'EXPENSE'   ,'DR'  ,TRUE),
('5010'  ,'General Expense'        ,'EXPENSE'   ,'DR'  ,false),
('5020'  ,'Professional Services'  ,'EXPENSE'   ,'DR'  ,false),
('5030'  ,'Income Taxes'           ,'EXPENSE'   ,'DR'  ,false),
('5040'  ,'Operating Expenses'     ,'EXPENSE'   ,'DR'  ,false),
-- COGS
('5500'  ,'COST OF GOODS SOLD'     ,'EXPENSE'   ,'DR'  ,TRUE),
('5510'  ,'Purchases'              ,'EXPENSE'   ,'DR'  ,false),
('5600'  ,'PAYROLL'                ,'EXPENSE'   ,'DR'  ,TRUE),
('5610'  ,'Wages & Salaries'       ,'EXPENSE'   ,'DR'  ,false)
;

-- WARNING: DO NOT DELETE/CHANGE THESE. You  can add new ones as aliases to these (intermediate states)
INSERT INTO transaction_state (name) VALUES
                                      ('DRAFT'),
                                      ('APPROVED'),
                                      ('IN_PROGRESS'),
                                      ('COMPLETE'),
                                      ('CLOSED'),
                                      ('CANCELED')
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
                                      ('TRANSIT'),
                                      ('FBO'),
                                      ('JOINT'),
                                      ('BUDGET'),
                                      ('CC')
;

