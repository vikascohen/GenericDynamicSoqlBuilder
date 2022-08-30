// 
// * 1.0    1st March 2022	   Vikas Vasudevan     Initial version

//                                                            
//                                                           
// 
@istest
public class GenericDynamicSoqlBuilderTest { 
    @isTest
    static void buildSimpleSoqlTest()
    {
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        list<string> field = new list<string>{'id'};
            list<string> Whereclause = new list<string>{'id!=null'};
                genericSqlBuilder.clear();
        genericSqlBuilder.addSelectSql().addFields(field).addFromObject('Account').addWhereClause(Whereclause);
        string soql = genericSqlBuilder.buildSql();
        system.Test.starttest();
        system.assert(soql=='select id from Account where id!=null', soql);
        system.test.stopTest();
        
        
    }
    @isTest
    static void buildComplexAndSoqlTest()
    {
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        list<string> field = new list<string>{'id'};
            list<string> Whereclause = new list<string>();  
        list<object> testdate = new list<object>{date.valueOf('2022-02-02')};
            genericSqlBuilder.clear();
        genericSqlBuilder.addCondition('id!=null', true).addAndCondition('createddate', testdate,genericSqlBuilder.getdatetype(),true,genericSqlBuilder.getInSign());
        string WhereClauseSTR = genericSqlBuilder.buildSql();
        whereclause.add(WhereClauseSTR);
        genericSqlBuilder.clear();
        genericSqlBuilder.addSelectSql().addFields(field).addFromObject('Account').addWhereClause(Whereclause);
        string soql = genericSqlBuilder.buildSql();
        system.Test.starttest();
        system.assert(soql=='select id from Account where ( id!=null) and (createddate in (2022-02-02))', soql);
        system.test.stopTest();
        
        
    }
    @isTest
    static void buildComplexOrSoqlTest()
    {
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        
        list<string> field = new list<string>{'id'};
            list<string> Whereclause = new list<string>();  
        list<object> testname = new list<object>{1};
            genericSqlBuilder.clear();
        genericSqlBuilder.addStartBracket().addCondition('id!=null', true).addorCondition('name', testname,genericSqlBuilder.getIntType(),true,genericSqlBuilder.getInSign())
            .addorCondition('name', '1',genericSqlBuilder.getIntType(),true,genericSqlBuilder.getequalsign()).addendBracket();
        string WhereClauseSTR = genericSqlBuilder.buildSql();
        whereclause.add(WhereClauseSTR);
        genericSqlBuilder.clear();
        genericSqlBuilder.addSelectSql().addFields(field).addFromObject('Account').addWhereClause(Whereclause);
        string soql = genericSqlBuilder.buildSql();
        system.Test.starttest();
        system.assert(soql=='select id from Account where  (( id!=null) or (name in (1)) or (name = 1) )', soql);
        system.test.stopTest();
        
        
    }
    
    @isTest
    static void generiSoqlTypeTest()
    {
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        genericSqlBuilder.getStringType();
        genericSqlBuilder.getDateType();
        genericSqlBuilder.getIntType();
        genericSqlBuilder.getDatetimeType();
        genericSqlBuilder.getBooleanType();
        genericSqlBuilder.getDoubleTYPE();
        genericSqlBuilder.addDateFormat('yyy-mm-dd');
        string Val;
        genericSqlBuilder.addAndClause().addOrclause().addInVal().addComma().getAddString().getOrString().addnull().addNotEqual()
            .doNullCheck(val).addResetNullCheck().addAndCondition('test', true).addOrCondition('test',true);
        genericSqlBuilder.buildSql();        
        Val = genericSqlBuilder.buildSql()+ genericSqlBuilder.getGreaterThanSign()+
            genericSqlBuilder.getLessThanSign()+ genericSqlBuilder.getGreaterThanEqualSign()+
            genericSqlBuilder.getLessThanEqualSign();
        system.Test.startTest();
        system.assert(Val ==' and or in , and or null != and (test) or (test)><>=<=', Val);
        system.test.stopTest();
    }
    
     @isTest
    static void generiSoqlWhereTest()
    {	 
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        list<object> testlist = new list<object>{'1'};
        genericSqlBuilder.addCondition('test','test',  genericSqlBuilder.getStringType(), true, 'in');
        genericSqlBuilder.clear();
        genericSqlBuilder.addEqualVal().addWhereFieldVal(testlist,genericSqlBuilder.getintType()).addWhereFieldVal('1', genericSqlBuilder.getinttype())
        .addlimitVal('1').addCondition('test','1',  genericSqlBuilder.getIntType(), true, 'in').addCondition('test', testlist, genericSqlBuilder.getIntType(), true, 'in')    
        .addAndCondition('test', testlist, genericSqlBuilder.getintType(), true, 'in').addAndCondition('test', '1', genericSqlBuilder.getintType(), true, 'in');
        system.Test.startTest();
        system.assert(genericSqlBuilder.buildSql()==  ' = 1 1 limit 1 (test in 1 ) (test in (1)) and (test in (1)) and (test in 1 )',genericSqlBuilder.buildSql()) ;
        system.Test.stopTest();
        
       
    }
    
    @istest
    static void generiSoqlWherebooleanTest()
    {
        GenericDynamicSoqlBuilder   genericSqlBuilder = new GenericDynamicSoqlBuilder();
        
        list<string> fieldname = new list<string>{'id'};
        system.Test.startTest();    
        genericSqlBuilder.addSelectSql().addFields(fieldName).addFromObject('Account').addWhereClause(null).
            addCondition('Is_Active__c', 'true', genericSqlBuilder.getBooleanType(), false, '=');
        system.assert(genericSqlBuilder.buildSql()=='select id from Account where Is_Active__c = true ');
        system.Test.stopTest();
        
    }
   
    
}