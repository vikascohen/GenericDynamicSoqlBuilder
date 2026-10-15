# Generic Dynamic SOQL Builder

A Salesforce Apex repository containing the original `GenericDynamicSoqlBuilder` and a newer, metadata-validated, bind-aware query builder named **`SoqlBuilderV2`**.

**Recommended for new development:** `SoqlBuilderV2` on the [`Version-2` branch](https://github.com/vikascohen/GenericDynamicSoqlBuilder/tree/Version-2). The original builder is retained for existing consumers; it has a different API and should not be assumed to provide V2's validation or bind-safety guarantees.

## Why V2?

Dynamic SOQL is useful when object names, fields and filters are selected at runtime, but constructing query text manually creates risks: malformed identifiers, injection through interpolated values, incorrect Boolean precedence, and unexpected security behaviour. V2 validates object and field identifiers against Salesforce Describe metadata, binds filter values with native Salesforce APIs, and makes the execution access mode explicit.

This is a lightweight Apex library, not a replacement for Salesforce's native query engine or a complete data-access policy framework.

## Requirements

- Salesforce Apex, API version **67.0** for V2.
- Deploy `force-app/main/default/classes/SoqlBuilderV2.cls` and its metadata; deploy `SoqlBuilderV2Test.cls` when running the test suite.
- The repository's additional custom object and permission set are used by sharing tests. Deploy the project metadata together if you intend to run all tests.
- Salesforce CLI and an authenticated target org are useful for deployment and verification.

```bash
sf project deploy start --target-org YOUR_ORG --source-dir force-app/main/default
sf apex run test --target-org YOUR_ORG --tests SoqlBuilderV2Test --wait 10 --code-coverage
```

## Quick start

```apex
List<SObject> accounts = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{'Id', 'Name', 'AnnualRevenue'})
    .whereEquals('Name', 'O\'Brien')
    .orderBy('Name', false)
    .limitTo(100)
    .execute(AccessLevel.USER_MODE);
```

`USER_MODE` applies Salesforce user-level data-access checks. `SYSTEM_MODE` is available when deliberately required; it does **not** guarantee bypass of record sharing in every calling context because the builder is declared `inherited sharing`. Choose the mode and calling context deliberately.

## Composable filters

```apex
SoqlBuilderV2.Filter target = SoqlBuilderV2.matching('Name', 'Acme%')
    .andFilter(SoqlBuilderV2.gt('AnnualRevenue', 100000));

List<SObject> rows = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{'Id', 'Name'})
    .whereFilter(target)
    .execute(AccessLevel.USER_MODE);
```

Filters are query-independent specifications. They can be combined using `andFilter` and `orFilter`, then validated and bound for each builder instance. The filter factories are `eq`, `ne`, `gt`, `lt` and `matching` (LIKE).

### Explicit grouping

```apex
List<SObject> rows = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{'Id', 'Name'})
    .beginGroup()
        .whereEquals('Name', 'Alpha')
        .orNext().whereEquals('Name', 'Beta')
    .endGroup()
    .whereGreaterThan('AnnualRevenue', 50000)
    .execute(AccessLevel.USER_MODE);
```

The internal predicate tree renders parentheses to preserve grouping. Groups must be balanced.

## Parent relationship fields

```apex
List<SObject> contacts = SoqlBuilderV2.fromObject('Contact')
    .selectFields(new List<String>{'Id', 'LastName'})
    .selectParentFields(new List<String>{'Account.Name'})
    .limitTo(50)
    .execute(AccessLevel.USER_MODE);
```

Parent relationship selection supports **one hop**, with relationship and target field validation. Polymorphic relationships, child subqueries, multi-hop paths and relationship paths in WHERE or ORDER BY are not supported.

## End-to-end example: a complex account search

Imagine a sales operations screen that must retrieve active business accounts matching **either** a strategic name pattern **or** a combination of revenue and industry criteria. The screen also excludes accounts with missing names, restricts results to a selected set of owners, and applies sorting and pagination. All filter values are runtime inputs; object and field names are checked against Salesforce metadata.

### 1. Build and execute the query in Apex

```apex
Set<Id> ownerIds = new Set<Id>{ UserInfo.getUserId() };
String strategicPattern = 'Acme%';
Decimal minimumRevenue = 250000;

// Reusable filter: strategic accounts OR large technology accounts.
SoqlBuilderV2.Filter businessRules = SoqlBuilderV2.matching('Name', strategicPattern)
    .orFilter(
        SoqlBuilderV2.gt('AnnualRevenue', minimumRevenue)
            .andFilter(SoqlBuilderV2.eq('Industry', 'Technology'))
    );

SoqlBuilderV2 query = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{
        'Id', 'Name', 'Industry', 'AnnualRevenue', 'OwnerId', 'CreatedDate'
    })
    .whereFilter(businessRules)
    .whereNotEquals('Name', null)
    .whereIn('OwnerId', ownerIds)
    .whereEquals('IsDeleted', false)
    .orderBy('AnnualRevenue', true)
    .orderBy('Name', false)
    .limitTo(50)
    .offsetBy(0);

// Inspect the generated SOQL and named bind values.
System.debug(query.buildSql());
System.debug(query.getBindings());

// Execute with user-level object, field and record access enforcement.
List<SObject> results = query.execute(AccessLevel.USER_MODE);

// Counts all matching rows, independently of LIMIT and OFFSET.
Integer matchingRecords = query.countMatches(AccessLevel.USER_MODE);
```

The reusable filter can be applied to another builder instance. A new instance creates its own named bind parameters, so the filter does not depend on a previously generated query string.

### 2. Generated SOQL

`buildSql()` produces **SOQL, not database SQL**. The following is the equivalent generated statement, formatted for readability. The actual builder emits a single-line statement and may include additional parentheses around individual filter-tree branches.

```sql
SELECT Id, Name, Industry, AnnualRevenue, OwnerId, CreatedDate
FROM Account
WHERE (
    (Name LIKE :p0 OR (AnnualRevenue > :p1 AND Industry = :p2))
    AND Name != NULL
    AND OwnerId IN :p3
    AND IsDeleted = :p4
)
ORDER BY AnnualRevenue DESC, Name ASC
LIMIT 50 OFFSET 0
```

The predicate tree renders additional parentheses but preserves this logic. The named bind map is conceptually:

| Bind | Runtime value | Type |
| --- | --- | --- |
| `p0` | `Acme%` | String |
| `p1` | `250000` | Decimal |
| `p2` | `Technology` | String |
| `p3` | `{ UserInfo.getUserId() }` | Set of Ids |
| `p4` | `false` | Boolean |

These values are **not interpolated into SOQL text**. The builder passes the statement and the bind map to `Database.queryWithBinds` with the specified `AccessLevel`. The `countMatches` operation separately generates a `SELECT COUNT()` query using the same WHERE predicates; it does not include the ordering or pagination clauses.

### 3. Equivalent relational SQL for comparison only

The following illustrates how the logical filter might look in a conventional relational database. **It is not SQL generated or executed by this Apex library.** Salesforce uses SOQL and its own data model and access-control semantics.

```sql
SELECT id, name, industry, annual_revenue, owner_id, created_date
FROM accounts
WHERE (
       name LIKE :p0
       OR (annual_revenue > :p1 AND industry = :p2)
      )
  AND name IS NOT NULL
  AND owner_id IN (:owner_id_1)
  AND is_deleted = FALSE
ORDER BY annual_revenue DESC, name ASC
LIMIT 50 OFFSET 0;
```

In this illustrative SQL, `:owner_id_1` represents the single user ID supplied in the Apex example. A conventional SQL engine generally uses `IS NOT NULL` rather than SOQL's `!= NULL` syntax, and column/table names are illustrative rather than actual Salesforce storage names. Ordinary SQL does not automatically reproduce Salesforce sharing, CRUD or field-level security enforcement.

### 4. What this example demonstrates

- Reusable nested **AND/OR** filters with explicit precedence.
- Metadata-validated field names and runtime type checking for common bind values.
- Parameter binding for strings, decimals, Boolean values and ID sets.
- Null predicates, multiple sort fields, LIMIT and OFFSET.
- Separate query inspection, row retrieval and match counting.
- Explicit `USER_MODE` execution rather than relying on implicit security behaviour.

**Practical constraints:** The owner ID set must not be empty; the example uses the current user's ID. `whereIn` currently supports only ID/reference fields. `OFFSET` is limited to 2,000. The query is an example of supported APIs, not a claim that every Salesforce org has the same data, field permissions or matching records.

## API at a glance

| Purpose | API |
| --- | --- |
| Create builder | `fromObject(String)` |
| Select fields | `selectFields(List<String>)`, `selectParentFields(List<String>)` |
| Filter | `whereEquals`, `whereNotEquals`, `whereGreaterThan`, `whereLessThan`, `whereLike`, `whereIn` |
| Boolean composition | `orNext`, `beginGroup`, `endGroup`, `whereFilter(Filter)` |
| Sort and paginate | `orderBy(String, Boolean)`, `limitTo(Integer)`, `offsetBy(Integer)` |
| Inspect query | `buildSql()`, `getBindings()` |
| Execute | `execute(AccessLevel)` |
| Count matching records | `countMatches(AccessLevel)` |
| Batch-oriented locator | `queryLocator(AccessLevel)` |

`whereIn` currently accepts `Set<Id>` on ID or reference fields. `limitTo` accepts 1 to 50,000 and `offsetBy` accepts 0 to 2,000. `countMatches` counts matching rows independent of SELECT pagination.

## Validation and security model

- Object and field names are checked against Describe metadata; callers cannot pass arbitrary raw WHERE fragments through the V2 fluent API.
- Values are supplied to `Database.queryWithBinds`, `Database.countQueryWithBinds` or `Database.getQueryLocatorWithBinds`.
- Equality and ordered comparisons validate common runtime bind-value types, including IDs/references, text, Boolean, dates, times and numeric fields. Null is supported for equality and inequality; ordered comparisons reject null.
- Operator compatibility is checked for LIKE and ordered comparisons.
- `USER_MODE` is tested against restricted object access, restricted field access, parent-field access and private record sharing.

**Important limitations:** This is not a complete type system or a security certification. ID/reference predicates currently accept strings without independently verifying their ID format. Some less-common Salesforce field types use permissive fallback validation. V2 does not currently impose explicit predicate-count, nesting-depth or generated-query-length limits. Callers should bound untrusted filter complexity themselves until those safeguards are implemented.

## Verification

On **15 October 2026**, `SoqlBuilderV2Test` completed **30/30 Apex tests**, with **97% Salesforce-reported test-run coverage**, in the `warden-validation` org (test run `707aj00001LZB5u`). This is **not** organisation-wide coverage, a production performance benchmark or proof of exhaustive correctness. Tests include bind-value compatibility, grouped and reusable filters, relationship selection, permission enforcement and a 30-level nested-filter governor check.

The current verified V2 commit at the time of this README update is [`7fb36fa`](https://github.com/vikascohen/GenericDynamicSoqlBuilder/commit/7fb36fa). The test environment has an `ERModel` namespace, and the private-sharing test currently references a namespaced custom object explicitly; adapting that test for arbitrary namespaces remains future work.

## Roadmap

- Defensive limits for filter complexity, nesting and query length.
- High-volume performance and governor-limit benchmarks.
- Broader Salesforce field-type and edge-case validation.
- Namespace-portable test fixtures and automated CI.
- Further security review and documentation of supported query patterns.

## Legacy builder

The original `GenericDynamicSoqlBuilder` remains in this repository for backwards compatibility and includes its own query-building examples. Its raw string-fragment features should **not** be treated as equivalent to V2's metadata validation and bind-aware execution. Migrate new integrations to `SoqlBuilderV2` where its currently supported query shapes are sufficient.

See [V2-README.md](V2-README.md) for additional historical V2 design notes.
