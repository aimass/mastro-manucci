# README #

Mastro Manucci is a simple, high performance and lightweight General Ledger Microservice.

It provides a write-once+read-only simple double-entry accounting system that can also track changes in state and link
longer-lived transactions. The API is designed to facilitate the integration of systems that are built around
Event Driven Process Chains and/or Workflow systems, or with simpler systems that just need a double entry GL to bolt-on
to their existing stack.

# SYNOPSIS #

```shell script
docker-compose build
docker-compose up
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

The Journal is the core of the system. It is heavily protected by security, audit and integrity rules and the information
contained in it is write once and cannot be altered in any way. This is also true for other tables of the system
as well.


## BOOKS ##

Books allow the system to have detailed views on a single account. Books can also act as sub-accounts as many books can
reference a single COA entry. For example customers and vendors can have individual books, all mapping to single COA
AR and AP accounts. The combination of COA headers, accounts and Books can model basically any business to as much
detail as needed whilst keeping the main COA simple, effective and clean.

## TRANSACTIONS AND DOCUMENTS ##



# Notes for Developers and Hackers #

## Temporarily Installing a CPAN Module to Test
To temporarily install a CPAN module:
```shell script
./install Foo::Bar
```
This will install the CPAN module on your running Mojo code. But be aware that if you down/up you will need
to install gain. For permanent install edit the cpanfile.

## To get the Mojo Container shell
```shell script
./shell
```

## To get the Postgres shell
```shell script
./shell db
```

## DB Users
If you are in the DB shell you don'' need to user passwords.
```shell script
psql -U moonshot_user mastro_manucci
psql -U moonshot_admin mastro_manucci
```

## Quick Tests
```shell script
./test A350_API_Ledger.t :: rtp_use_case
```



# Features

## Simple Model
Based on the very basic accounting principles of Journal, Chart of Accounts, Account Books
and Documents.

Binary versions of DIA:

http://dia-installer.de

Macports:
port install dia (requires XQuartz)


## Scalable Data Model with Automatic Data Partitioning
Blah

## Full Audit and Security



# LICENSE #

Copyright 2021 The p2ee Project

GL Design based on The p2ee Project  Copyright 2006-2023  GNU General Public License version 2.0 (GPLv2)
borrowing models and accounting standards from the SQL-Ledger Project, licensed
under the GNU GENERAL PUBLIC LICENSE Version 2 : https://www.sql-ledger.com/cgi-bin/nav.pl?page=misc/COPYING