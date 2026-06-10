//
//  MahaDBModel.swift
//  Pods
//
//  Created by mahaLive on 2024/10/21.
//

import Foundation
import SQLite
import HandyJSON

/// 数据库基类
open class MahaDBModel : HandyJSON {
    
    public required init() {}
    
    public var pkID : Int64 = -1
    
    public static func tableName() -> String {
        let tableName = self.className().replacingOccurrences(of: ".Type", with: "")
        return tableName
    }
    
    /// 自定义主键
    open class func customPKColumns() -> [String] {[]}

    /// 需要忽略的列
    open class func ignoreColumns() -> [String] {[]}
    
}

/// 增删改查
extension MahaDBModel{
    
    @discardableResult
    public func saveOrUpdate() -> Bool {
        var isExist = false
        // 先查询是否存在改数据
        if let whereStr = genWhereByPK()  { // 有主键ID
            let tableName = Self.tableName()
            let sql = "select * from \(tableName) \(whereStr)"
            if let data = Self.select(sql).first {
                self.pkID = data.pkID
                isExist = true
            }
        }
        if isExist { // 更新
            return update()
        }else{ // 插入
            return save()
        }
    }
    
    @discardableResult
    public func save() -> Bool {
        let db = MahaDBManager.shared
        var colums = Self.columnsType()
        if colums.isEmpty {
            return false
        }
        let ignoreColumns = Self.ignoreColumns()
        colums = colums.filter({$0.name != Self.primaryKeyColumn() && !ignoreColumns.contains($0.name)}) // 过滤掉主键
        let tableName = Self.tableName()
        var sql = "insert into \(tableName)"
        let keys : [String] = colums.map({$0.name})
        sql += " (\(keys.joined(separator: ","))) "
        sql += "values ("
        for colum in colums {
            let value = valueFrom(colum.name) ?? ""
//            MahaLog.recordInfo("name=\(colum.name)--value=\(value)")
            sql += "'\(value)',"
        }
        // 去掉最后的,
        sql += "@"
        sql = sql.replacingOccurrences(of: ",@", with: "")
        sql += ");"
        let isOK = db.executeSQL(sql: sql)
        return isOK
    }
    
    ///  主键删除
    @discardableResult
    public func delete() -> Bool {
        let db = MahaDBManager.shared
        let tableName = Self.tableName()
        if let whereStr = genWhereByPK() {
            let sql = "delete from \(tableName) \(whereStr)"
            let isOK = db.executeSQL(sql: sql)
            return isOK
        }
        return false
    }
    
    // 通过主键更新
    public func update() -> Bool {
        var colums = Self.columnsType()
        if colums.isEmpty {
            return false
        }
        let ignoreColumns = Self.ignoreColumns()
        let pkName = Self.primaryKeyColumn()
        colums = colums.filter({$0.name != pkName && !ignoreColumns.contains($0.name)}) // 过滤掉主键
        let tableName = Self.tableName()
        var updateStr = "update \(tableName) set "
        for colum in colums {
            let value = valueFrom(colum.name) ?? ""
            updateStr += " \(colum.name) = '\(value)' ,"
        }
        // 去掉最后的,
        updateStr += "@"
        updateStr = updateStr.replacingOccurrences(of: ",@", with: "")
        updateStr += " where \(pkName) = \(pkID);"
        let db = MahaDBManager.shared
        return db.executeSQL(sql: updateStr)
    }
    
    public static func selectByID(_ id : Int64) -> Self? {
        let tableName = tableName()
        let idName = primaryKeyColumn()
        let sql = "select * from \(tableName) where \(idName) = \(id) limit 1;"
        return select(sql).first
    }
    
    public static func selectAll<T:MahaDBModel>() -> [T] {
        let tableName = tableName()
        let sql = "select * from \(tableName) ;"
        return select(sql)
    }
    
    /// 条件查询
    public static func selectByWhereStr<T:MahaDBModel>(whereStr : String) -> [T] {
        let tableName = tableName()
        var whereStr = whereStr
        if whereStr.isEmpty {
            whereStr = "1 = 1";
        }
        let sql = "select * from \(tableName) where \(whereStr);"
        return select(sql)
    }
    
    /// 条件查询 增加按某个字段的顺序
    public static func selectByWhereStrOrderBy<T:MahaDBModel>(whereStr : String,orderBy : String, isASC : Bool) -> [T] {
        let tableName = tableName()
        var whereStr = whereStr
        if whereStr.isEmpty {
            whereStr = "1 = 1";
        }
        let asc = isASC ? "ASC" : "DESC"
        let sql = "select * from \(tableName) where \(whereStr) ORDER BY \(orderBy) \(asc);"
        return select(sql)
    }
    
    /// 查询 根据字典查询 键 : 值
    public static func selectByMap<T:MahaDBModel>(dict : [String:Any]) -> [T] {
        let aSqlArr = dict.map { key,value in
            "\(key) = \(value)"
        }
        let whereStr =  aSqlArr.joined(separator: " and ")
        return selectByWhereStr(whereStr: whereStr)
    }
    
    /// 查询 根据字典查询 键 : 值  增加 按某个字段 的顺序查询
    public static func selectByMapByOrder<T:MahaDBModel>(dict : [String:Any],orderBy : String, isASC : Bool) -> [T] {
        let aSqlArr = dict.map { key,value in
            "\(key) = \(value)"
        }
        let whereStr =  aSqlArr.joined(separator: " and ")
        return selectByWhereStrOrderBy(whereStr: whereStr,orderBy: orderBy, isASC: isASC)
    }
    
    public static func select<T:MahaDBModel>(_ sql : String) -> [T] {
        var results = [T]()
        let db = MahaDBManager.shared
        if let statement = db.executeQuery(query: sql) {
            for row in statement {
                let columnNames = statement.columnNames
                if row.count != columnNames.count {
                    break
                }
                var dict : [String:Any] = [:]
                for (index,columnName) in columnNames.enumerated() {
                    let value = row[index]
                    dict[columnName] = value
                }
                
                if let obj = T.deserialize(from: dict) {
                    results.append(obj)
                }
            }
        }
        return results
    }
    
    /// 执行sql
    public static func executeSQL(sql: String) -> Bool {
        let db = MahaDBManager.shared
        return db.executeSQL(sql: sql)
    }

    private func genWhereByPK() -> String? {
        var selectDict = [String:Any]()
        let columns = Self.customPKColumns()
        if pkID >= 0 || columns.count > 0  { // 有主键ID
            if pkID >= 0 {
                let pkKey = Self.primaryKeyColumn()
                selectDict[pkKey] = pkID
            }
            for column in columns {
                let value = valueFrom(column)
                selectDict[column] = value
            }
//            let tableName = Self.tableName()
            var whereStr = " where "
            for data in selectDict {
                whereStr += " \(data.key) = \(data.value) and "
            }
            whereStr += ";"
            // 将最后一个and替换
            whereStr = whereStr.replacingOccurrences(of: "and ;", with: ";");
            return whereStr
        }
        return nil
    }
}


extension MahaDBModel {
    
    static func primaryKeyColumn() -> String { "pkID" }//自动增长ID 自己不要设置了
    
    private static  func className() -> String {
        let mirror  = Mirror(reflecting: self)
        return String(describing: mirror.subjectType)
    }
    
    static func columnsType() -> [MahaDBColumn] {
        let selfProtocol = self.init()
        
        let mirror  = Mirror(reflecting: selfProtocol)
        
        // 如果有父类，递归调用
        var columns = [MahaDBColumn]()
        if let superclassMirror = mirror.superclassMirror {
            for case let (label?, value) in superclassMirror.children {
                let column = createColumn(label: label, value: value)
                columns.append(column)
            }
        }
        
        for case let (label?, value) in mirror.children {
            let column = createColumn(label: label, value: value)
            columns.append(column)
        }
        return columns
    }
    
    private static func createColumn(label : String,value : Any) ->  MahaDBColumn {
        var column = MahaDBColumn()
        column.name = label
        if label == primaryKeyColumn() {
            column.autoincrement = true
            column.isPrimaryKey = true
        }
        let valueMirror  = Mirror(reflecting: value)
        switch valueMirror.subjectType {
        case is Data.Type:
            column.type = "Data"
        case is Optional<Data>.Type:
            column.type = "Data"
        case is Date.Type:
            column.type = "Date"
        case is Optional<Date>.Type:
            column.type = "Date"
        case is String.Type:
            column.type = "String"
        case is Optional<String>.Type:
            column.type = "String"
        case is Float.Type:
            column.type = "Float"
        case is Optional<Float>.Type:
            column.type = "Float"
        case is Float32.Type:
            column.type = "Float"
        case is Optional<Float32>.Type:
            column.type = "Float"
        case is Float64.Type:
            column.type = "Float"
        case is Optional<Float64>.Type:
            column.type = "Float"
            // check https://forums.developer.apple.com/thread/5026
            //            case is Float80.Type:
            //                column.type = "float"
            //                break
            //            case is Optional<Float80>.Type:
            //                column.type = "float"
            //                break
            
        case is Double.Type:
            column.type = "Double"
        case is Optional<Double>.Type:
            column.type = "Double"
        case is Int.Type:
            column.type = "Int"
        case is Optional<Int>.Type:
            column.type = "Int"
        case is Int8.Type:
            column.type = "Int"
        case is Optional<Int8>.Type:
            column.type = "Int"
        case is Int16.Type:
            column.type = "Int"
        case is Optional<Int16>.Type:
            column.type = "Int"
        case is Int32.Type:
            column.type = "Int"
        case is Optional<Int32>.Type:
            column.type = "Int"
        case is Int64.Type:
            column.type = "Int"
        case is Optional<Int64>.Type:
            column.type = "Int"
        case is Bool.Type:
            column.type = "Bool"
        case is Optional<Bool>.Type:
            column.type = "Bool"
        default:
            column.type = "String"
        }
        return column
    }
    
    public  func valueFrom(_ key: String) -> Any? {
        let mirror = Mirror(reflecting: self)
        for case let (label?, value) in mirror.children {
            if label == key {
                return value
            }
        }
        //父类
        if let parent = mirror.superclassMirror {
            for case let (label?, value) in parent.children {
                if label == key {
                    return value
                }
            }
        }
        return nil
    }
}
