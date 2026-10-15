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
}
