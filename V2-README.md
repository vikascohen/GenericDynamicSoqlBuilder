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

## Native execution capabilities

V2 delegates execution to Salesforce's native bind-aware APIs. `execute(mode)` retrieves rows, `countMatches(mode)` counts matching records without loading them, and `queryLocator(mode)` returns a batch-friendly `Database.QueryLocator`. Pass `AccessLevel.USER_MODE` for permission-aware execution. Do not assume `countMatches()` respects row pagination; it intentionally counts matching records before LIMIT/OFFSET. The query locator uses the configured SELECT query.

## Differentiation and design direction

Salesforce already supplies bind-aware execution, and fflib supplies selector/query factory patterns. V2 targets smaller teams and metadata-driven applications that need safe, validated query composition without an enterprise framework dependency. Planned: typed predicate AST, operator/type compatibility checks, reusable filter specifications, relationship path validation, security tests under restricted users and CI. These are not yet implemented.

Validation: 10 Apex tests passed in `warden-validation` on 15 October 2026. Salesforce reported 100% test-run coverage; this is not a security certification or a claim that every edge case is tested.

## Typed predicate tree

Boolean predicates now compose through internal `PredicateNode` and `PredicateFrame` structures. Grouping is represented as a tree, rather than modifying existing string fragments. The renderer emits explicit parentheses to preserve the intended order. The public fluent API remains compatible. Nested group execution is covered by Salesforce Apex tests. This is a predicate tree, not yet a fully typed field/operator expression model; operator/type validation remains a separate planned feature.

Validation: 12 Apex tests passed in `warden-validation` on 15 October 2026, with 100% reported test-run coverage. The suite is not an exhaustive correctness or security assessment.
