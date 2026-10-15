# V2 (in progress)

Salesforce API 67.0. The existing `GenericDynamicSoqlBuilder` remains available for legacy callers; new applications should use `SoqlBuilderV2`.

```apex
List<SObject> accounts = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{'Id', 'Name'})
    .whereEquals('Name', 'O\'Brien')
    .limitTo(100)
    .execute(AccessLevel.USER_MODE);
```

Values use `Database.queryWithBinds`, identifiers are validated against Describe metadata, and execution mode is explicit. `SYSTEM_MODE` bypasses user CRUD/FLS checks and should be used only where intended. The API currently supports top-level fields, equality, inequality, IN, AND, ordering, LIMIT and OFFSET. Nested predicates, relationship traversal, SOSL separation, comprehensive permission tests, and deployment validation remain to be completed. Do not treat the legacy builder as injection-safe for raw query fragments.

## Predicate groups (API 67)

```apex
List<SObject> records = SoqlBuilderV2.fromObject('Account')
    .selectFields(new List<String>{'Id', 'Name'})
    .beginGroup()
        .whereEquals('Name', 'Alpha')
        .orNext().whereEquals('Name', 'Beta')
    .endGroup()
    .whereLike('Name', '%a%')
    .execute(AccessLevel.USER_MODE);
```

Additional predicates: `whereGreaterThan`, `whereLessThan`, `whereNotEquals`, `whereLike`, `whereIn` (currently accepts `Set<Id>` for Id/reference fields only). Groups must be balanced. Comparisons reject null values; equality explicitly supports null. Nested grouping uses explicit parentheses. V2 test suite: 8 tests passed in `warden-validation` on 15 October 2026, 100% test-run coverage reported by Salesforce. This is not a claim of full security or integration coverage. The query model remains mutable and additional permission and edge-case testing is planned.
