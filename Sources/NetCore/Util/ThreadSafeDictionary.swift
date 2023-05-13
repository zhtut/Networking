//
//  ThreakSafeDictionary.swift
//  Pods
//
//  Created by zhtg on 2023/5/10.
//

import Foundation

open class ThreadSafeDictionary {

    private var dict = [String: Any]()
    private let queue = DispatchQueue(label: "com.SafeDict", attributes: .concurrent)

    public typealias DictionaryType = Dictionary<String, Any>

    open func object(for key: String) -> Any? {
        var result: Any?
        queue.sync {
            result = dict[key]
        }
        return result
    }

    open func set(_ value: Any?, for key: String) {
        queue.async(flags: .barrier) {
            self.dict[key] = value
        }
    }

    @discardableResult
    open func removeValue(forKey key: String) -> Any? {
        var value: Any?
        queue.async(flags: .barrier) {
            value = self.dict.removeValue(forKey: key)
        }
        return value
    }

    open func removeAll(keepingCapacity keepCapacity: Bool = false) {
        queue.async(flags: .barrier) {
            self.dict.removeAll(keepingCapacity: keepCapacity)
        }
    }

    @discardableResult
    open func remove(at index: DictionaryType.Index) -> DictionaryType.Element {
        var element: Dictionary<String, Any>.Element!
        queue.async(flags: .barrier) {
            element = self.dict.remove(at: index)
        }
        return element
    }

    open subscript(key: String) -> Any? {
        get {
            object(for: key)
        }
        set(newValue) {
            set(newValue, for: key)
        }
    }

    open var count: Int {
        var count: Int!
        queue.sync {
            count = dict.count
        }
        return count
    }

    open var isEmpty: Bool {
        var isEmpty: Bool!
        queue.sync {
            isEmpty = dict.isEmpty
        }
        return isEmpty
    }

    open var values: Dictionary<String, Any>.Values {
        var values: Dictionary<String, Any>.Values!
        queue.sync {
            values = dict.values
        }
        return values
    }

    open var keys: Dictionary<String, Any>.Keys {
        var keys: Dictionary<String, Any>.Keys!
        queue.sync {
            keys = dict.keys
        }
        return keys
    }

    open func enumerated() -> EnumeratedSequence<[String: Any]> {
        var enumerated: EnumeratedSequence<[String: Any]>!
        queue.sync {
            enumerated = dict.enumerated()
        }
        return enumerated
    }
}
