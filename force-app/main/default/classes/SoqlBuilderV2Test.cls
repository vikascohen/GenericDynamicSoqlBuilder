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
    @IsTest static void nestedGroupsPreserveMeaning() {
        insert new List<Account>{new Account(Name='TreeAlpha', AnnualRevenue=100), new Account(Name='TreeBeta', AnnualRevenue=200), new Account(Name='TreeGamma', AnnualRevenue=300)};
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'})
            .beginGroup()
                .whereEquals('Name', 'TreeAlpha')
                .orNext().beginGroup()
                    .whereEquals('Name', 'TreeBeta')
                    .whereGreaterThan('AnnualRevenue', 150)
                .endGroup()
            .endGroup()
            .whereLessThan('AnnualRevenue', 250);
        System.assertEquals(2, b.execute(AccessLevel.SYSTEM_MODE).size());
        System.assertEquals(2, b.countMatches(AccessLevel.SYSTEM_MODE));
    }
    @IsTest static void groupCannotBorrowPriorOr() {
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereEquals('Name','A')
            .orNext().beginGroup().whereEquals('Name','B').whereEquals('Name','C').endGroup();
        System.assert(b.buildSql().contains(' OR '));
    }
    @IsTest static void operatorTypeValidation() {
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereLike('AnnualRevenue','%100%'); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected, 'LIKE must reject numeric fields');
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereGreaterThan('Name','A'); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected, 'Ordering comparison must reject text fields');
        rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereLessThan('IsDeleted',true); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected, 'Ordering comparison must reject boolean fields');
    }
    @IsTest static void textLikeAndNumericComparisonsStillExecute() {
        insert new Account(Name='TypedFilter',AnnualRevenue=125);
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereLike('Name','Typed%')
            .whereGreaterThan('AnnualRevenue',100).whereLessThan('AnnualRevenue',200);
        System.assertEquals(1,b.execute(AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void reusableFiltersExecuteOnMultipleQueries() {
        insert new List<Account>{new Account(Name='ReusableOne',AnnualRevenue=150),
            new Account(Name='ReusableTwo',AnnualRevenue=350),
            new Account(Name='Unrelated',AnnualRevenue=150)};
        SoqlBuilderV2.Filter shared = SoqlBuilderV2.matching('Name','Reusable%')
            .andFilter(SoqlBuilderV2.gt('AnnualRevenue',100))
            .andFilter(SoqlBuilderV2.lt('AnnualRevenue',200));
        SoqlBuilderV2 a = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereFilter(shared);
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Name'}).whereFilter(shared);
        System.assertEquals(1,a.execute(AccessLevel.SYSTEM_MODE).size());
        System.assertEquals(1,b.countMatches(AccessLevel.SYSTEM_MODE));
        System.assertEquals(3,a.getBindings().size());
        System.assertEquals(3,b.getBindings().size());
    }
    @IsTest static void reusableOrFilterPreservesPrecedence() {
        insert new List<Account>{new Account(Name='ReusableAlpha'),new Account(Name='ReusableBeta'),new Account(Name='Other')};
        SoqlBuilderV2.Filter either = SoqlBuilderV2.eq('Name','ReusableAlpha')
            .orFilter(SoqlBuilderV2.eq('Name','ReusableBeta'));
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
            .selectFields(new List<String>{'Id'}).whereFilter(either).whereLike('Name','Reusable%');
        System.assertEquals(2,b.execute(AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void reusableFilterRejectsBadField() {
        Boolean rejected = false;
        try { SoqlBuilderV2.fromObject('Account').whereFilter(SoqlBuilderV2.eq('NotAField',1)); }
        catch (SoqlBuilderV2.QueryException e) { rejected = true; }
        System.assert(rejected);
    }
    @IsTest static void parentFieldQueryExecutes() {
        Account a = new Account(Name='RelatedAccount'); insert a;
        Contact c = new Contact(LastName='RelatedContact', AccountId=a.Id); insert c;
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Contact')
            .selectFields(new List<String>{'Id'})
            .selectParentFields(new List<String>{'Account.Name'})
            .whereEquals('Id',c.Id);
        List<SObject> rows = b.execute(AccessLevel.SYSTEM_MODE);
        System.assertEquals(1,rows.size());
        System.assertEquals('RelatedAccount',rows[0].getSObject('Account').get('Name'));
    }
    @IsTest static void parentFieldValidationRejectsInjection() {
        Boolean failed = false;
        try { SoqlBuilderV2.fromObject('Contact').selectParentFields(new List<String>{'Account.Name FROM Account'}); }
        catch (SoqlBuilderV2.QueryException e) { failed = true; }
        System.assert(failed);
    }
    @IsTest static void accessModeMustBeExplicit() {
        SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account').selectFields(new List<String>{'Id'});
        Integer rejected = 0;
        try { b.execute(null); } catch (SoqlBuilderV2.QueryException e) { rejected++; }
        try { b.countMatches(null); } catch (SoqlBuilderV2.QueryException e) { rejected++; }
        try { b.queryLocator(null); } catch (SoqlBuilderV2.QueryException e) { rejected++; }
        System.assertEquals(3,rejected);
    }
    @IsTest static void userModeWithRunAs() {
        Account a = new Account(Name='SecurityRunAs'); insert a;
        User u = new User(Alias='secusr', Email='secusr@example.com',
            EmailEncodingKey='UTF-8', LastName='Security',
            LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            TimeZoneSidKey='America/Los_Angeles',
            ProfileId=UserInfo.getProfileId(),
            Username='secusr.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        insert u;
        System.runAs(u) {
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
                .selectFields(new List<String>{'Id'}).whereEquals('Id',a.Id);
            System.assertEquals(1,b.execute(AccessLevel.USER_MODE).size());
            System.assertEquals(1,b.countMatches(AccessLevel.USER_MODE));
        }
    }
    @IsTest static void restrictedProfileDeniesUserMode() {
        Profile minimum = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User u = new User(Alias='limited', Email='limited@example.com',
            EmailEncodingKey='UTF-8', LastName='Limited', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles',
            ProfileId=minimum.Id,
            Username='limited.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        insert u;
        Account a = new Account(Name='SecurityTarget'); insert a;
        System.runAs(u) {
            System.assertEquals(false, Schema.sObjectType.Account.isAccessible());
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('Account')
                .selectFields(new List<String>{'Id','Name'}).whereEquals('Id',a.Id);
            Boolean denied = false;
            try { b.execute(AccessLevel.USER_MODE); }
            catch (System.QueryException e) { denied = true; }
            System.assert(denied, 'USER_MODE must enforce restricted object access');
            System.assertEquals(1,b.execute(AccessLevel.SYSTEM_MODE).size());
        }
    }
    @IsTest static void restrictedFieldDeniedInUserMode() {
        Profile minimum = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User u = new User(Alias='flduser', Email='flduser@example.com',
            EmailEncodingKey='UTF-8', LastName='FieldRestricted', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles',
            ProfileId=minimum.Id,
            Username='flduser.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        insert u;
        System.runAs(u) {
            System.assert(Schema.sObjectType.User.isAccessible(), 'User object must be readable');
            String restrictedField;
            for (String fieldName : Schema.sObjectType.User.fields.getMap().keySet()) {
                Schema.DescribeFieldResult d = Schema.sObjectType.User.fields.getMap().get(fieldName).getDescribe();
                if (!d.isAccessible()) {
                    restrictedField = d.getName();
                    break;
                }
            }
            System.assertNotEquals(null, restrictedField, 'A restricted User field is required for this test');
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('User')
                .selectFields(new List<String>{'Id',restrictedField}).whereEquals('Id',u.Id);
            Boolean denied = false;
            try { b.execute(AccessLevel.USER_MODE); }
            catch (System.QueryException e) { denied = true; }
            System.assert(denied, 'USER_MODE must enforce field access');
            System.assertEquals(1,b.execute(AccessLevel.SYSTEM_MODE).size());
        }
    }
    @IsTest static void parentRelationshipRespectsFieldSecurity() {
        Profile minimum = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User u = new User(Alias='relfls', Email='relfls@example.com',
            EmailEncodingKey='UTF-8', LastName='RelRestricted', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles',
            ProfileId=minimum.Id, ManagerId=UserInfo.getUserId(),
            Username='relfls.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        insert u;
        System.runAs(u) {
            System.assert(Schema.sObjectType.User.isAccessible());
            String restrictedField;
            for (String name : Schema.sObjectType.User.fields.getMap().keySet()) {
                Schema.DescribeFieldResult d = Schema.sObjectType.User.fields.getMap().get(name).getDescribe();
                if (!d.isAccessible()) { restrictedField = d.getName(); break; }
            }
            System.assertNotEquals(null, restrictedField);
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('User')
                .selectFields(new List<String>{'Id'})
                .selectParentFields(new List<String>{'Manager.' + restrictedField})
                .whereEquals('Id',u.Id);
            Boolean denied = false;
            try { b.execute(AccessLevel.USER_MODE); }
            catch (System.QueryException e) { denied = true; }
            System.assert(denied, 'USER_MODE must enforce parent field security');
            System.assertEquals(1,b.execute(AccessLevel.SYSTEM_MODE).size());
        }
    }
    @IsTest static void privateSharingRestrictsUserMode() {
        Profile standard = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User owner = new User(Alias='ownprobe', Email='ownprobe@example.com',
            EmailEncodingKey='UTF-8', LastName='ProbeOwner', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles', ProfileId=standard.Id,
            Username='owner.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        User reader = new User(Alias='readprob', Email='readprobe@example.com',
            EmailEncodingKey='UTF-8', LastName='ProbeReader', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles', ProfileId=standard.Id,
            Username='reader.' + String.valueOf(Crypto.getRandomInteger()) + '@example.com');
        insert new List<User>{owner, reader};
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'SoqlSharingProbeReader' LIMIT 1];
        insert new List<PermissionSetAssignment>{
            new PermissionSetAssignment(AssigneeId=owner.Id, PermissionSetId=ps.Id),
            new PermissionSetAssignment(AssigneeId=reader.Id, PermissionSetId=ps.Id)
        };
        SoqlSharingProbe__c record;
        System.runAs(new User(Id=UserInfo.getUserId())) {
            record = new SoqlSharingProbe__c(Name='PrivateProbe', OwnerId=owner.Id);
            insert record;
        }
        System.runAs(owner) {
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('ERModel__SoqlSharingProbe__c')
                .selectFields(new List<String>{'Id'}).whereEquals('Id',record.Id);
            System.assertEquals(1,b.execute(AccessLevel.USER_MODE).size());
        }
        System.runAs(reader) {
            System.assert(Schema.sObjectType.SoqlSharingProbe__c.isAccessible());
            SoqlBuilderV2 b = SoqlBuilderV2.fromObject('ERModel__SoqlSharingProbe__c')
                .selectFields(new List<String>{'Id'}).whereEquals('Id',record.Id);
            System.assertEquals(0,b.execute(AccessLevel.USER_MODE).size());
            System.assertEquals(0,b.countMatches(AccessLevel.USER_MODE));
        }
    }
}
