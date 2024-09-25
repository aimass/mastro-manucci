# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2023-12-01

### Added

- Journal entries API - Beta
- orderBy option. Defaults to post_date now (see Changed below)
- Individual accounting model tests
- Individual BAPI tests
- Refactored atransfers for individual transactions (cancel broken)
- rtransfer BAPI (cancel broken)
- ctransfer BAPI (cancel broken)

### Fixed

- Minor bugs
- Code cleanup, more consistency, better variable naming

### Changed

- Order now defaults to post date, optionally to created/id mainly for tests and backward compat.

### Removed

- Monolithic Model Tests
- Monolithic BAPI Tests

## [0.9.1] - 2023-12-08

### Added

- Remaining BAPI tests
- rtransfers Cancel
- ctransfers Cancel

### Fixed

- BAPI cleanup, better consistency and variable names
- Some amounts were quoted in metadata

### Changed

- Internal APIs are now 100% OpenAPI semantics
- Complete separation of public and private methods Transaction.pm
- Clear use and separation of marshalled and unmarshalled data 
- SQL related variable names in BAPIs now use _ (underscore) whilst API ones use camelCase. 
- mapTransactionResponse is now private, this should also solve the weird duplicate reference issue

### Removed

- All private methods are no longer exported or available outside their respective modules.
- mapTransactionResponse is no longer available and refactored into a new marshall/unmarshall pattern


## [0.9.5] - 2024-01-29

### Added

- OAuth2 Authorization
- JWT Validation

### Fixed

- Minor bugs

### Changed

### Removed

## [0.9.6] - 2024-01-29

### Added

- Filter form on balance screen

### Fixed

- Weirdness in balance enpoint parameter logic
- Fixed .69/.70 bug: replaced == with equal sub in commons to compare floating point values

### Changed

- Balance for subaccount no longer requires parent account in query params 
- BAPIs that used query for ALL subaccounts now query specific balances

### Removed

- General balance validations from some BAPIs, now specific per subaccount.

## [1.0.0]

### Added

- Complete Journal Entries API
- Journal Screen and links between balance, journal and transactions
- OAuth2 support
- Login Screen with OAuth2 Authorization Flow

### Fixed

- Inconsistencies in journal and balance endpoints for subaccount and subaccountdesc
- Enrollment balance bug in test release because of the changes above
- Pagination logic in journal screen
- Added at least enrollments BAPI non-zero balance check to avoid regressions in future balacne API changes

### Changed

- Journal and Balance endpoints had some minor changes and bug fixes
- Journal returns additional information about last query: offset, starting_after, total_rows, and criteria

### Removed

- Bogus coa menu option until that option is coded

## [1.0.1]

### Added

- Section 6 of GAAP for Interest Income
- Show entities in balance

### Fixed

- Inconsistency balance endpoint for accountDesc and subaccountDesc


