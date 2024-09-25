# Mastro Manucci LedgeX (MMLX) #
High Performance Double Entry Ledger µService

*Unleash the Power of Precision & Speed in Financial Record Keeping!*

Dive into the future of accounting with **Mastro Manucci High-Performance Ledger Service (MMHLS)** – where innovation meets tradition. This isn't just a ledger service; it's your financial fortress, engineered for the 21st century.

## Why MMHLS?

- **Real-Time, Double-Entry Magic**: Say goodbye to outdated ledgers. MMHLS operates on cutting-edge, real-time double-entry, ensuring your books are not just kept, but masterfully maintained.
- **Hyper-Concurrency & TPS**: Built tough for high traffic, MMHLS laughs in the face of thousands of transactions per second, keeping your data flowing smoothly, no matter the volume.
- **Scalable & Robust**: From startups to enterprises, MMHLS grows with you, handling vast data with elegance and efficiency.
- **RESTful Microservice Architecture**: Seamlessly integrate MMHLS into your ecosystem. It's designed to play well with others, ensuring your systems sing in harmony.

MMHLS isn't just about numbers; it's about empowering your business with a ledger service that's as dynamic and agile as your operations. Welcome to the next generation of ledger services—where performance isn't just a feature, it's our middle name.



---
*Feel free to explore the repository for installation instructions, usage examples, and how to contribute to the project!*
# SYNOPSIS #

```shell script
./task local 
./task up
```

To reset the database and start over
```shell script
docker-compose down; docker-compose up
```
This will reset the DB and re-run the DDL and Setup/Demo data but will not destroy the service image.

# FEATURES #

## GENERAL LEDGER ##

The General Ledger is composed of a Chart of Accounts (COA) and a single Journal. The COA is meant to be kept simple
to reflect a company's high-level balance accounts, and also supports header (or summary) accounts for grouping. Each
COA record has a main account number and can also have an alias to provide an alternative (or even grouping) identifier
such as a GIFI account number for reporting.

The main COA is not meant to model detail accounts or sub-accounts. These can be modelled through Books (see Books below).

Every account on the COA has to have a type which can be:

* ASSET
* LIABILITY
* EQUITY
* INCOME
* EXPENSE

Internally each COA entry has a DrCr type, which instructs the system on how to properly register a journal entry for it.
For example, Dr accounts balance will increase through the Debit column, whilst Cr accounts balance will increase
through the Credit column. The DRCR column is automatically set based on the account type.

## GENERIC SYSTEM COA ##

The system provides a simple generic COA on the first startup. After that, implementations can alter the COA through
the APIs. Usually, adjustments to the COA should be made as early as possible in the implementation because after the
accounts have any transactions, the system imposes restrictions on altering or deleting them.

## JOURNAL ##

At the heart of MMLX is the Journal, where every transaction is not just recorded but 
enshrined with unalterable integrity. This core system component is fortified by:

* **Ironclad Security**: With robust access controls, ensuring only the right 
  hands can touch the data.
* **Immutable Audit Trails**: Each entry and modification is logged, creating a 
  verifiable history of all financial activities.
* **Data Sanctity**: Once data enters the Journal, it becomes immutable. Like 
  inscriptions on stone, it remains untouched, upholding the principle of write 
  once, never alter across all system tables. This commitment to integrity 
  ensures your financial history is as accurate as the day it was recorded.

## SUB ACCOUNTS ##

Sub-accounts allow detailed journal entries for entities. A bub-accounts must be tied to a single entity and one entity can have 
one or more sub-accounts. Each sub-account must also be tied to a single COA account. All journal entries always refer to
a single COA account and optionally to a sub-account.


## TRANSACTIONS AND DOCUMENTS ##

MMLX is provided with a generic master-detail transaction document. This 
generic construct can be used to model transaction artifacts such as 
Customer Invoices, Sales Invoices, Purchase Orders etc. The actual 
implemenations are written in business specific APIs called BAPIS.

Transactions can be grouped together to form complex parent-child and/or 
multi-step transactions allowing the Ledger's transaction document to model 
exactly your business workflows.

## EXTENDING AND CUSTOMIZING WITH BAPIs ##

MMLX has an external REST API which is defined in OpenAPI v3. Every 
interaction with the ledger engine can be performed
with the REST API. This API provides an extension and customization mechanism called BAPI (Business Application Interface).
Users can create a BAPI by uploading a Perl module into the Bapi directory. The /bapi endpoint will dynamically load and
execute the BAPI code without a need to restart the system.

The BAPI code has access to every method in the OpenAPI spec, but instead of using HTTP, the BAPI code can use the internal
APIs using the exported methods of Ledger.pm. All the methods in Ledger.pm are already wrapped with SQL transaction blocks.
Thus, simple BAPIs act as macros to automate repetitive uses of the REST API, but using the internals APIs and taking
full advantage of custom Perl code.

### Advanced BAPIs ###

For more advanced customizations, BAPIs also have access to exported methods of the Ledger sub-modules such as Balance.pm,
Entity.pm, Journal.pm, SubAcct.pm and Transaction.pm. When using these methods, it is the BAPI's code responsibilty to wrap 
procedural code in SQL transaction blocks. Finally, BAPIs also have access to the database connetion and can execute
arbitrary SQL code. Nevertheless, it is recommended that this is only used for querying data, and always use the exported
Ledger methods for any writing.  

## GENERAL GUIDELINES FOR BAPI CODE ##

### Variable Naming ###

As mentioned above, all REST and internal APIs use the same semantics defined in the OpenAPI Specification. All public 
methods and variables use camelCase. All internal ledger engin code uses lower case underscore variable names and methods
(except for publicyly exported methods and parameters mentioned above).

When writing BAPI code we recommend you follow the same . For REST and internal APIs use camelCase variables in your custom code as well as the camelCase names defined in the 
OpenAPI Specification. For SQL code and variables that hold SQL column data directly use lower case underscore standard
as emplyed in the database schema. 


## Prerequisites

```
TAP::Parser::SourceHandler::pgTAP
```

# LICENSE #

Copyright 2006-2021 The p2ee Project

GL Design based on The p2ee Project  Copyright 2006-2023  GNU General Public License version 2.0 (GPLv2)
also borrowing ideas from the SQL-Ledger Project, licensed under the GNU GENERAL PUBLIC LICENSE Version 2 : 
https://www.sql-ledger.com/cgi-bin/nav.pl?page=misc/COPYING