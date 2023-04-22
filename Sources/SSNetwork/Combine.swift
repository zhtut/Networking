//
//  NSObjectSubscription.swift
//  GoodMood
//
//  Created by zhtg on 2023/4/22.
//  Copyright © 2023 Buildyou Tech. All rights reserved.
//

import Foundation
import ObjectiveC
import Combine

private var NSObjectSubscribersSetKey = 0
private var NSObjectSubscriptionKey = 0

public protocol CancellableObject {
    var subscription: AnyCancellable? { get set }
    var subscriptionSet: Set<AnyCancellable>  { get set }
}

class SetObject: NSObject {
    var set: Set<AnyCancellable> = []
    weak var object: NSObject?
}

private var setObjects = [SetObject]()

public extension CancellableObject {
    
    /// 保存单个可取消的订阅
    var subscription: AnyCancellable? {
        get {
            objc_getAssociatedObject(self, &NSObjectSubscriptionKey) as? AnyCancellable
        }
        set {
            objc_setAssociatedObject(self, &NSObjectSubscriptionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 保存一组订阅的集合
    var subscriptionSet: Set<AnyCancellable> {
        get {
            if let set = objc_getAssociatedObject(self, &NSObjectSubscribersSetKey) as? Set<AnyCancellable> {
                return set
            }
            let set = Set<AnyCancellable>()
            objc_setAssociatedObject(self, &NSObjectSubscribersSetKey, set, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return set
        }
        set {
            objc_setAssociatedObject(self, &NSObjectSubscribersSetKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension NSObject: CancellableObject {

}
