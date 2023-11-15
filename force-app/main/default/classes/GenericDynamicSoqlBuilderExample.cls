// 15th Nov 2023  Vikas Cohen Vasudevan  Added support of Sosl and querycache
public class GenericDynamicSoqlBuilderExample {
    
    private static GenericDynamicSoqlBuilder genericSqlBuilder = new GenericDynamicSoqlBuilder();
    public static account getOneRandomAccountWithEveryField()
    {
        genericSqlBuilder.clear();
        //Build dynamic Soql string
        genericSqlBuilder.addSelectSql().addAllFields('Account').addlimitVal('1');
        system.debug(genericSqlBuilder.BuildSql());
        return database.query(genericSqlBuilder.buildSql());
    }
    
    public static account getOneRandomAccountWithfewField()
    {
        genericSqlBuilder.clear();
        list<string> fieldNames = new list<string>{'id', 'Name'};
            //Build dynamic Soql string
            genericSqlBuilder.addSelectSql().addFields(fieldNames).addFromObject('Account').addlimitVal('1');
        system.debug(genericSqlBuilder.BuildSql());
        return database.query(genericSqlBuilder.buildSql());
    }
    public static account getOneRandomAccountWithSimplewhereClause()
    {
        genericSqlBuilder.clear();
        list<string> fieldNames = new list<string>{'id', 'Name'};
            list<string> whereClause = new list<string>{'id <> null ', 'and Name <> null'};    
                //Build dynamic Soql string
                genericSqlBuilder.addSelectSql().addFields(fieldNames).addFromObject('Account').addWhereClause(whereClause).addlimitVal('1');
        system.debug(genericSqlBuilder.BuildSql());
        return database.query(genericSqlBuilder.buildSql());
    }
    //If we want to filter out where clause with null values then we cannot use addWhereClause it wont suppose null check 
    public static list<account> getOneRandomAccountWitheWhereClauseAndNullCheck()
    {
        genericSqlBuilder.clear();
        list<string> fieldNames = new list<string>{'id', 'Name'};
            list<string> Name = new list<string>{'Vikas Account','Muller Household'};// 
                //Build dynamic Soql string
                genericSqlBuilder.addSelectSql().addFields(fieldNames).addFromObject('Account').addWhereClause(null)
                .addStartBracket()
                .addCondition('Id != null',false)
                .donullcheck(Name) //This will check if name list is null if it is it will excluse entire where clause till addResetNullCheck()
                .addAndCondition('name', name,genericSqlBuilder.getStringType(),false,genericSqlBuilder.getInSign())//
                .addResetNullCheck()
                .addEndBracket();
        system.debug(genericSqlBuilder.BuildSql());
        return database.query(genericSqlBuilder.buildSql());
    }
    
    //If we want to filter out where clause with null values then we cannot use addWhereClause it wont suppose null check 
    public static list<account> getOneRandomAccountWitheWhereClausewithNullValueSet()
    {
        genericSqlBuilder.clear();
        list<string> fieldNames = new list<string>{'id', 'Name'};
            list<string> Name ; 
        //Build dynamic Soql string
        genericSqlBuilder.addSelectSql().addFields(fieldNames).addFromObject('Account').addWhereClause(null)
            .addStartBracket()
            .addCondition('Id != null',false)
            .donullcheck(Name) //This will check if name list is null if it is it will excluse entire where clause till addResetNullCheck()
            .addAndCondition('name', name,genericSqlBuilder.getStringType(),false,genericSqlBuilder.getInSign())//
            .addResetNullCheck()
            .addEndBracket();
        system.debug(genericSqlBuilder.BuildSql());
        return database.query(genericSqlBuilder.buildSql());
    }
    
    public static void addedSoslSupport()
    {
        genericSqlBuilder.clear();
        List<List<SObject>> searchResults;
        genericSqlBuilder
            .addSoslSearch('test account')
            .addSoslSearchInObjects('account', new list<string>{'Name'}, true)
            .addSoslSearchInObjects('contact', new list<string>{'FirstName','LastName'},true)
            .addSoslSearchInObjects('opportunity', new list<string>{'Name'},false)
            .soslResult(searchResults);
        
        String soslQuery = genericSqlBuilder.BuildSql();
        
        System.debug('Dynamic SOSL: ' + soslQuery);
        System.debug('Search Results: ' + searchResults);
    }
    
    public static void addedquryCacheStore()
    {
        
        genericSqlBuilder.clear();
        
        // Use methods to build the dynamic SOQL query
        genericSqlBuilder.addSelectSql()
            .addFields(new List<String>{'Id', 'Name'})
            .addFromObject('Account')
            .addLimitVal('1');
        
        // Get the built query
        String dynamicQuery = genericSqlBuilder.BuildSql();
        String cacheKey = 'exampleQuery';
        // Execute the query using Database.query
        List<SObject> queryResult = Database.query(dynamicQuery);
        genericSqlBuilder.GetQueryStore().cacheQuery(cacheKey, dynamicQuery, queryResult, 60);
        
        // Process the query result (replace this with your actual logic)
        for (SObject record : queryResult) {
            System.debug(record);
            system.debug(genericSqlBuilder.GetQueryStore().getCachedResult(cacheKey));  
        }
    }
    
    
    
}
