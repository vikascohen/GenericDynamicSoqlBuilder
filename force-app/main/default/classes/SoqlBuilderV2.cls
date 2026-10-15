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
    // Predicate tree: explicit grouping and boolean precedence, never raw WHERE fragments.
    private class PredicateNode {
        String atom;
        String op;
        PredicateNode left;
        PredicateNode right;
        PredicateNode(String atom) { this.atom = atom; }
        PredicateNode(String op, PredicateNode left, PredicateNode right) {
            this.op = op; this.left = left; this.right = right;
        }
        String render() {
            if (atom != null) return atom;
            return '(' + left.render() + ' ' + op + ' ' + right.render() + ')';
        }
    }
    private class PredicateFrame {
        PredicateNode root;
        String joinWith = 'AND';
        String parentJoin;
    }
    private List<PredicateFrame> frames = new List<PredicateFrame>{new PredicateFrame()};
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
    private PredicateFrame currentFrame() { return frames[frames.size() - 1]; }
    private void appendNode(PredicateNode node) {
        PredicateFrame frame = currentFrame();
        frame.root = frame.root == null ? node : new PredicateNode(frame.joinWith, frame.root, node);
        frame.joinWith = 'AND';
    }
    private void appendPredicate(String expression) { appendNode(new PredicateNode(expression)); }
    public SoqlBuilderV2 orNext() {
        if (currentFrame().root == null) throw new QueryException('OR requires a preceding predicate in this group');
        currentFrame().joinWith = 'OR';
        return this;
    }
    public SoqlBuilderV2 beginGroup() {
        PredicateFrame parent = currentFrame();
        PredicateFrame child = new PredicateFrame();
        child.parentJoin = parent.joinWith;
        frames.add(child);
        parent.joinWith = 'AND';
        return this;
    }
    public SoqlBuilderV2 endGroup() {
        if (frames.size() == 1) throw new QueryException('Unmatched group end');
        PredicateFrame child = frames.remove(frames.size() - 1);
        if (child.root == null) throw new QueryException('Empty predicate group');
        PredicateFrame parent = currentFrame();
        parent.joinWith = child.parentJoin;
        appendNode(child.root);
        return this;
    }
    private String whereClause() {
        if (frames.size() != 1) throw new QueryException('Unclosed predicate group');
        PredicateNode root = currentFrame().root;
        return root == null ? '' : ' WHERE ' + root.render();
    }
    private Schema.DisplayType fieldType(String field) {
        checkedField(field);
        return fieldMap.get(field).getDescribe().getType();
    }
    private Boolean isTextType(Schema.DisplayType t) {
        return t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea ||
            t == Schema.DisplayType.Email || t == Schema.DisplayType.Phone ||
            t == Schema.DisplayType.Url;
    }
    private Boolean isOrderedType(Schema.DisplayType t) {
        return t == Schema.DisplayType.Integer || t == Schema.DisplayType.Double ||
            t == Schema.DisplayType.Currency || t == Schema.DisplayType.Percent ||
            t == Schema.DisplayType.Date || t == Schema.DisplayType.DateTime ||
            t == Schema.DisplayType.Time;
    }
    private void requireOperator(String field, String operatorName, Boolean supported) {
        if (!supported) throw new QueryException(operatorName + ' is not supported for ' +
            objectName + '.' + field + ' (' + String.valueOf(fieldType(field)) + ')');
    }
    public SoqlBuilderV2 whereGreaterThan(String field, Object value) {
        if (value == null) throw new QueryException('Comparison value cannot be null');
        requireOperator(field, 'GREATER THAN', isOrderedType(fieldType(field)));
        appendPredicate(checkedField(field) + ' > ' + bind(value));
        return this;
    }
    public SoqlBuilderV2 whereLessThan(String field, Object value) {
        if (value == null) throw new QueryException('Comparison value cannot be null');
        requireOperator(field, 'LESS THAN', isOrderedType(fieldType(field)));
        appendPredicate(checkedField(field) + ' < ' + bind(value));
        return this;
    }
    public SoqlBuilderV2 whereLike(String field, String pattern) {
        if (pattern == null) throw new QueryException('LIKE pattern cannot be null');
        requireOperator(field, 'LIKE', isTextType(fieldType(field)));
        appendPredicate(checkedField(field) + ' LIKE ' + bind(pattern));
        return this;
    }
    public SoqlBuilderV2 whereEquals(String field, Object value) {
        String f = checkedField(field);
        appendPredicate(f + (value == null ? ' = NULL' : ' = ' + bind(value)));
        return this;
    }
    public SoqlBuilderV2 whereNotEquals(String field, Object value) {
        String f = checkedField(field);
        appendPredicate(f + (value == null ? ' != NULL' : ' != ' + bind(value)));
        return this;
    }
    public SoqlBuilderV2 whereIn(String field, Set<Id> values) {
        String f = checkedField(field);
        if (values == null || values.isEmpty()) throw new QueryException('IN values must not be empty');
        Schema.DisplayType fieldType = fieldMap.get(field).getDescribe().getType();
        if (fieldType != Schema.DisplayType.Id && fieldType != Schema.DisplayType.Reference) throw new QueryException('whereIn currently supports Id/reference fields only');
        appendPredicate(f + ' IN ' + bind(values));
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
        sql += whereClause();
        if (!ordering.isEmpty()) sql += ' ORDER BY ' + String.join(ordering, ', ');
        if (maxRows != null) sql += ' LIMIT ' + maxRows;
        if (offsetRows != null) sql += ' OFFSET ' + offsetRows;
        return sql;
    }
    public List<SObject> execute(AccessLevel mode) {
        if (mode == null) throw new QueryException('Explicit access mode required');
        return Database.queryWithBinds(buildSql(), bindings, mode);
    }
    /** Count matching rows without retrieving full records. */
    public Integer countMatches(AccessLevel mode) {
        if (mode == null) throw new QueryException('Explicit access mode required');
        String sql = 'SELECT COUNT() FROM ' + objectName + whereClause();
        return Database.countQueryWithBinds(sql, bindings, mode);
    }
    /** Use in batch start() for streaming larger datasets. */
    public Database.QueryLocator queryLocator(AccessLevel mode) {
        if (mode == null) throw new QueryException('Explicit access mode required');
        return Database.getQueryLocatorWithBinds(buildSql(), bindings, mode);
    }
    public Map<String, Object> getBindings() {
        return bindings.clone();
    }
}
