# Introduction

The Mastro Manucci database model is a simple yet powerful double entry ledger model.

# Chart of Accounts: COA

The coa table houses the main chart of accounts. It comes preloaded with a sample COA, but is intended to be customized
by the user for the specific application.

## Important Fields

### Account

This field holds the account number. It's an alphanumerical field that will be ordered lexicographically when listing or
displaying the COA. It has no particular format, although it is recommended to follow a simple numerical scheme or some
universal numbering scheme such as GAAP or IFRS.

### Alias

The model allows for an alternate account numbering scheme for reports and balances. The alias field is intended for
this. For example, your internal numbering scheme caould be a simple numbering scheme whilst the alias field would house
GAAP account number equivalents.

### Desription

Description of the account. For example 'Accounts Receivable' or 'Cash on Hand'.

### Type

The account type is an enumeration that represent the five types of accounts: 'ASSET', 'LIABILITY', 'EQUITY', 'INCOME',
'EXPENSE'.

### DRCR

This is a system field that is directly dependent on the account type. It allows the system to understand if the account
balance should increase through the debit or credit columns.

### Heading

The heading flag indicates that it's Header or Group account. Use headers to separate account groups such as Assets,
Liabilities, Expenses, etc.

# Entities: People, Organzations and Other Entities

An entity represents a person or an organization, for example customers, suppliers and partners. Normally, these
entities are owned and managed by an external system such as an LDAP directory. Thus, only minimal information is
maintained about these entities in the ledger, namely reference and name (for easy reporting ). The link field is
intended to hold metdata information to link to external systems. Alternatively, if this is a stand-alone system, or if
no other owner of this data exists, the link field can be used to store structued information about the entity.

Entities may have one or more subaccounts. In most cases an entity will have a single subaccount. For example in a
retail business, a customer will most likely have a single AR subaccount. But if your modelling a bank, for example, a
customer may have an AP subaccount to hold balances, and may also have an AR account to track invoicing to that
customer. In almost all cases, an entity will have at most two subaccounts, usually an AR and an AP. Nevertheless, the
database model allows for more than two, and the modelling of more complex business requiremets.

## Important Fields

### Name

Simple string name for the entity to facilitate reports on the ledger.

### Reference

Identifier for the entity, for example, customer number, or other unique identifier for the entity.

### Type

The type is either PERSON, ORGANIZATION or OTHER. In most cases, an entity is either an organization or a person. OTHER
is inteded to model subaccounts (and/or auxiliary accounts) that are not related to people or organizations.

### Entity SubType ID

This is a user-defined value list in the entity_subtype table. This allows to further group entities into groups that
make sense for the business, for example CUSTOMER, VENDOR, or PARTNER.

### Link

The link field is a JSONB field that is intended to link the entity to an external system, or if no such system exists,
it can hold detailed data about the entity.

### Notes

User defined and optional additional notes about the entity. May be used to hold any type os text data.

# Subaccounts

The subacct table holds the subaccounts. Each subaccount must be associated to a single entity, and a single account in
the CoA. In this model, subaccounts act as auxiliary books and must be associated to a single entity, although as
mentioned above, and entity can own one or more subaccounts. It is not possible to associate a subaccount to more than
one entity.

Subaccounts themselves don't hold any transactions, every single transaction occurs in the system journal and only
there. Subaccounts are provided as a way to filter journal transactions from the point of view of a single subaccount.
Soubaccounts can be grouped through the customizable list subacct_type_id, which can be used for example, for simple
cost center modelling.

## Important Fields

### Account

This field holds the account number. It's an alphanumerical field that will be ordered lexicographically when listing or
displaying the COA. It has no particular format, although it is recommended to follow a simple numerical scheme or some
universal numbering scheme such as GAAP or IFRS.

### SubAcctTypeId

This field maps to a list in the subacct_type table. It serves the purpose of grouping subaccounts into types and help
create more detailed reporting, or as mentioned above, for simple cost center reporting.

### CoAId

This field connects the subaccount to its parent account in the Chart of Accounts (CoA). A subaccount can only map to a
single parent in the CoA.

### EntityId

This field connects the the subaccount to it's entity. A subaccount can only be ownned by a single entity.

### Notes

Optional notes about the subaccount.

# Transactions

Transactions, along with the Journal are the core of the ledger system. Transactions are the only vehicle by which
entries are created in the journal. The transaction and transaction_line tables tie the whole model together as well as
the relationship between journal entries and the subaccounts.

## States

Transactions support different states. The system core states are:

* DRAFT
* APPROVED
* IN_PROGRESS
* COMPLETE
* CLOSED
* CANCELED

These should not be changed because they directly impact how the system operates. If the implementation
requires additional (or different) states, they can be added as aliases to the core system states.






