//
//  MahaDBManager.swift
//
//
//  Created by maha-l on 2024/5/16.
//

import Foundation
import SQLite.Swift
import MahaLogCore

public class MahaDBManager {
    
    public static let shared = MahaDBManager()
        
    private var dbConnection: Connection?
        
    public func connectionToDB(dbPath: String) {
        do {
            dbConnection = try Connection(dbPath)
        } catch {
            // MahaLog.record("sql--Error connecting to database: \(error)")
            dbConnection = nil
            
        }
        
    }
    
    @discardableResult
    public func createTable(table: MahaDBModel.Type) -> Bool{
        _createTable(table: table)
    }
    
    
    private func _alertTable(table: MahaDBModel.Type,tableName : String? = nil,tableColumns : [MahaDBColumn]? = nil) {
        var cTableName = String()
        var columns : [MahaDBColumn] = []
        if tableName != nil {
            cTableName = tableName!
        }else{
            cTableName = table.tableName()
        }
        if tableColumns != nil {
            columns = tableColumns!
        }else{
            columns = table.columnsType()
            let ignoreColumns = table.ignoreColumns()
            columns = columns.filter({!ignoreColumns.contains($0.name)}) // 过滤掉需要忽略的键
        }
        
        let oldColumns = getTableColumns(table: table,tableName: tableName)
        
        /// 如果旧表中有字段 在新模型中找不到 需要重新创建
        var isNeedResetTable = false
        for (key,_) in oldColumns {
            if columns.contains(where: {$0.name == key}) == false {
                isNeedResetTable = true
                break
            }
        }
        
        if isNeedResetTable { // 需要重新建表
            let tempTableName = "\(cTableName)_temp"
            /// 创建临时表
            _createTable(table: table,tableName: tempTableName,isUpdateTable: false)
            let newColumns = columns.map { column in
                column.name
            }
            // 3. 复制数据
            let copyDataQuery = "INSERT INTO \(tempTableName) (\(newColumns.joined(separator: ", "))) SELECT \(newColumns.joined(separator: ", ")) FROM \(cTableName);"
            executeSQL(sql: copyDataQuery)

            // 4. 删除旧表
            let dropTableQuery = "DROP TABLE \(cTableName);"
            executeSQL(sql: dropTableQuery)

            // 5. 将新表重命名为旧表名
            let renameTableQuery = "ALTER TABLE \(tempTableName) RENAME TO \(cTableName);"
            executeSQL(sql: renameTableQuery)
            return
        }
        
        // 判断 新增的列
        let newColumns = columns.filter { column in
            let data: Void? = oldColumns[column.name]
            return data == nil
        }
        
//        MahaLog.recordInfo("sql==newColumns====\(newColumns)")
        if newColumns.isEmpty == false { // 存在新增的列 需要自动更新数据库
            let cTable = Table(cTableName)
            // 执行 ALTER TABLE 语句
            for column in newColumns {
                if let aStr = addColumnExpression(table: cTable, column: column) {
                    executeSQL(sql: aStr)
                }
            }
        }
    }
    
    /// 获取表中存在的列
    private func getTableColumns(table: MahaDBModel.Type,tableName : String? = nil) -> [String:Void] {
        var cTableName = String()
        if tableName != nil {
            cTableName = tableName!
        }else{
            cTableName = table.tableName()
        }
        var tableOldColumns : [String:Void] = [:]
        let query = "pragma table_info(\(cTableName))"// "PRAGMA table_info(MHLaunchScreenModel);"
        if let statement = executeQuery(query: query) {
            for row in statement {
                if row.count >= 2 ,let cName = row[1] as? String{ // 第一列是列名
                    tableOldColumns[cName] = Void()
                }
//                MahaLog.recordInfo("row=\(row)")
            }
        }
//        MahaLog.recordInfo("row==111==\(tableOldColumns)")
        return tableOldColumns
    }
    
    
    //返回带数据
    public func executeQuery(query: String) -> Statement? {
        guard let db = dbConnection else { return nil }
        do {
//            MahaLog.recordInfo("sql=\(query)")
            let statement = try db.prepare(query)
            // MahaLog.record("sql--ok=\(query)")
            return statement
        } catch {
            // MahaLog.record("sql--err=\(error)--sql=\(query)")
        }
        return nil
    }
    
    //查询
//    public func executeUpdate(query: String, completion: @escaping (Bool, Error?) -> Void) {
//        do {
//            try dbConnection?.run(query)
//            completion(true, nil)
//        } catch {
//            MahaLog.recordInfo("Error executing update: \(error)")
//            completion(false, error)
//        }
//    }
    
    // 新增的通用 executeSQL 方法
    @discardableResult
    public func executeSQL(sql: String) -> Bool {
        guard let db = dbConnection else { return false }
        do {
            
            try db.execute(sql)
            // MahaLog.record("sql--ok=\(sql)")
        } catch {
            // MahaLog.record("sql--err=\(error)--sql=\(sql)")
            return false
        }
        return true
    }
    
}


extension MahaDBManager {
    
    @discardableResult
    private func _createTable(table: MahaDBModel.Type,tableName : String? = nil,isUpdateTable : Bool = true) -> Bool {
        guard let db = dbConnection else { return false }
        var cTableName = String()
        if tableName != nil {
            cTableName = tableName!
        }else{
            cTableName = table.tableName()
        }
        
        // 获取 需要创建的列
        var columns = table.columnsType()
        let ignoreColumns = table.ignoreColumns()
        columns = columns.filter({!ignoreColumns.contains($0.name)}) // 过滤掉不需要的键
        
        let cTable = Table(cTableName)
        
        do {
            let query = cTable.create(ifNotExists: true) { t in
                for column in columns {
                    addColumn(t: t, column: column)
                }
            }
            // MahaLog.record("sql==\(query)")
            try db.run(query)
            // MahaLog.record("sql==Table '\(cTableName)' created successfully")
        } catch {
            // MahaLog.record("sql==Table '\(cTableName)'--Error creating table: \(error)")
            return false
        }
        if isUpdateTable {
            _alertTable(table: table,tableName: cTableName,tableColumns: columns)
        }
        return true
    }
    
    private func addColumnExpression(table: Table, column: MahaDBColumn) -> String? {
        switch column.type {
        case "Int":
            let expression = SQLite.Expression<Int64>(column.name)
            return table.addColumn(expression, defaultValue: 0)
        case "String":
            let expression = SQLite.Expression<String>(column.name)
            return table.addColumn(expression, defaultValue: "")
        case "Float", "Double":
            let expression = SQLite.Expression<Double>(column.name)
            return table.addColumn(expression, defaultValue: 0)
        case "Bool":
            let expression = SQLite.Expression<Bool>(column.name)
            return table.addColumn(expression, defaultValue: false)
        case "Date":
            let expression = SQLite.Expression<Date>(column.name)
            return table.addColumn(expression, defaultValue: Date())
        case "Data":
            let expression = SQLite.Expression<Data>(column.name)
            return table.addColumn(expression, defaultValue: Data())
        default:
            fatalError("Unsupported data type: \(column.type)")
        }
    }
    
    private func addColumn(t: TableBuilder, column:MahaDBColumn) {
        switch column.type {
        case "Int":
            let expression = SQLite.Expression<Int64>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        case "String":
            let expression = SQLite.Expression<String>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        case "Float", "Double":
            let expression = SQLite.Expression<Double>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        case "Bool":
            let expression = SQLite.Expression<Bool>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        case "Date":
            let expression = SQLite.Expression<Date>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        case "Data":
            let expression = SQLite.Expression<Data>(column.name)
            defineColumn(t: t, expression: expression, primaryKey: column.isPrimaryKey, autoincrement: column.autoincrement)
        default:
            fatalError("Unsupported data type: \(column.type)")
        }
        
    }
    
    private func defineColumn<T: Value>(t: TableBuilder, expression: SQLite.Expression<T>, primaryKey: Bool, autoincrement: Bool) {
        if primaryKey {
             if autoincrement {
                 if let expression = expression as? SQLite.Expression<Int64> {
                     t.column(expression, primaryKey: .autoincrement)
                 } else {
                     fatalError("Only Int64 can be autoincrement primary key")
                 }
             } else {
                 t.column(expression, primaryKey: true)
             }
         } else {
             t.column(expression)
         }
    }
    
}
