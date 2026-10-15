/**
 * Metadata validated, bind based SOQL builder. No arbitrary raw WHERE fragments.
 * One instance represents one query; execution mode must be selected explicitly.
 */
public inherited sharing class SoqlBuilderV2 {
    public class QueryException extends Exception {}
    private String objectName;
    private Schema.DescribeSObjectResult objectDescribe;
    private Map<String, Schema.SObjectField> fieldMap;
    private List<String> selected = new List<String>();
    private List<String> predicates = new List<String>();
    private Map<String, Object> bindings = new Map<String, Object>();
    private List<String> ordering = new List<String>();
    private Integer maxRows;
    private Integer offsetRows;
    private Integer nextBind = 0;

    private SoqlBuilderV2(String apiName) {
        Map<String, Schema.SObjectType> objects = Schema.getGlobalDescribe();
        if (String.isBlank(apiName) || !objects.containsKey(apiName)) {
            throw new QueryException('Unknown sObject: ' + apiName);
        }
        objectDescribe = objects.get(apiName).getDescribe();
        objectName = objectDescribe.getName();
        fieldMap = objectDescribe.fields.getMap();
    }
    public static SoqlBuilderV2 fromObject(String apiName) {
        return new SoqlBuilderV2(apiName);
    }
    private String checkedField(String name) {
        if (String.isBlank(name) || !fieldMap.containsKey(name)) {
            throw new QueryException('Unknown field on ' + objectName + ': ' + name);
        }
        return fieldMap.get(name).getDescribe().getName();
    }
    public SoqlBuilderV2 selectFields(List<String> names) {
        if (names == null || names.isEmpty()) throw new QueryException('At least one field required');
        for (String name : names) {
            String checked = checkedField(name);
            if (!selected.contains(checked)) selected.add(checked);
        }
        return this;
    }
    private String bind(Object value) {
        String key = 'p' + nextBind++;
        bindings.put(key, value);
        return ':' + key;
    }
    public SoqlBuilderV2 whereEquals(String field, Object value) {
        String f = checkedField(field);
        predicates.add(f + (value == null ? ' = NULL' : ' = ' + bind(value)));
        return this;
    }
    public SoqlBuilderV2 whereNotEquals(String field, Object value) {
        String f = checkedField(field);
        predicates.add(f + (value == null ? ' != NULL' : ' != ' + bind(value)));
        return this;
    }
    public SoqlBuilderV2 whereIn(String field, List<Object> values) {
        String f = checkedField(field);
        if (values == null || values.isEmpty()) throw new QueryException('IN values must not be empty');
        predicates.add(f + ' IN ' + bind(values));
        return this;
    }
    public SoqlBuilderV2 orderBy(String field, Boolean descending) {
        ordering.add(checkedField(field) + (descending == true ? ' DESC' : ' ASC'));
        return this;
    }
    public SoqlBuilderV2 limitTo(Integer count) {
        if (count == null || count < 1 || count > 50000) throw new QueryException('LIMIT must be between 1 and 50000');
        maxRows = count;
        return this;
    }
    public SoqlBuilderV2 offsetBy(Integer count) {
        if (count == null || count < 0 || count > 2000) throw new QueryException('OFFSET must be between 0 and 2000');
        offsetRows = count;
        return this;
    }
    public String buildSql() {
        if (selected.isEmpty()) throw new QueryException('SELECT fields are required');
        String sql = 'SELECT ' + String.join(selected, ', ') + ' FROM ' + objectName;
        if (!predicates.isEmpty()) sql += ' WHERE ' + String.join(predicates, ' AND ');
        if (!ordering.isEmpty()) sql += ' ORDER BY ' + String.join(ordering, ', ');
        if (maxRows != null) sql += ' LIMIT ' + maxRows;
        if (offsetRows != null) sql += ' OFFSET ' + offsetRows;
        return sql;
    }
    public List<SObject> execute(AccessLevel mode) {
        if (mode == null) throw new QueryException('Explicit access mode required');
        return Database.queryWithBinds(buildSql(), bindings, mode);
    }
    public Map<String, Object> getBindings() {
        return bindings.clone();
    }
}
