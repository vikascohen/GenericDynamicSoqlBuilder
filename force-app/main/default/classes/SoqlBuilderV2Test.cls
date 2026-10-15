@IsTest
private class SoqlBuilderV2Test {
    @IsTest static void safeQueryExecutes() {
        Account a = new Account(Name = 'O\'Brien');
        insert a;
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id', 'Name'})
            .whereEquals('Name', 'O\'Brien')
            .orderBy('Name', false).limitTo(10);
        System.assert(b.buildSql().contains('Name = :p0'));
        System.assertEquals('O\'Brien', b.getBindings().get('p0'));
        System.assertEquals(1, b.execute(AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void rejectsInvalidIdentifiersAndLimits() {
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account WHERE Name != NULL'); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').selectFields(new List<String>{'Name FROM Contact'}); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').selectFields(new List<String>{'Id'}).limitTo(-1); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
    }
    @IsTest static void rejectsIncompleteQuery() {
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account').buildSql(); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
    }
    @IsTest static void groupedPredicatesExecute() {
        insert new List<Account>{new Account(Name='Alpha'), new Account(Name='Beta'), new Account(Name='Gamma')};
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id', 'Name'})
            .beginGroup().whereEquals('Name', 'Alpha').orNext().whereEquals('Name', 'Beta').endGroup()
            .whereLike('Name', '%a%').limitTo(10);
        System.assert(b.buildSql().contains('(Name = :p0 OR Name = :p1) AND Name LIKE :p2'));
        System.assertEquals(2, b.execute(AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void invalidGroupsRejected() {
        Boolean failed = false;
        try { SoqlBuilderV2.fromObject('Account').selectFields(new List<String>{'Id'}).beginGroup().buildSql(); }
        catch (SoqlBuilderV2.QueryException e) { failed = true; }
        System.assert(failed);
    }
    @IsTest static void comparisonsNullAndOrdering() {
        insert new List<Account>{new Account(Name='RevenueA', AnnualRevenue=200), new Account(Name='RevenueB', AnnualRevenue=800)};
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id', 'Name', 'AnnualRevenue'})
            .whereGreaterThan('AnnualRevenue', 100)
            .whereLessThan('AnnualRevenue', 500)
            .whereNotEquals('Name', null)
            .orderBy('AnnualRevenue', true).limitTo(5).offsetBy(0);
        System.assertEquals(1, b.execute(AccessLevel.SYSTEM_MODE).size());
        System.assertEquals(2, b.getBindings().size());
    }
    @IsTest static void invalidOperatorStateRejected() {
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account').orNext(); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').endGroup(); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').beginGroup().endGroup(); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
    }
    @IsTest static void inAndNullValidation() {
        Account a = new Account(Name='InList'); insert a;
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereIn('Id', new Set<Id>{a.Id});
        System.assertEquals(1, b.execute(AccessLevel.SYSTEM_MODE).size());
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereIn('Id', new Set<Id>()); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereGreaterThan('AnnualRevenue', null); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
    }
    @IsTest static void countMatchesUsesSameFilters() {
        insert new List<Account>{new Account(Name='CountOne'),new Account(Name='CountTwo')};
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereLike('Name','Count%');
        System.assertEquals(2, b.countMatches(AccessLevel.SYSTEM_MODE));
        System.assertEquals(2, b.execute(AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void queryLocatorCanBeCreated() {
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).limitTo(10);
        System.assertNotEquals(null,b.queryLocator(AccessLevel.SYSTEM_MODE));
    }
}
