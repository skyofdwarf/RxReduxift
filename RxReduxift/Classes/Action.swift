//
//  Action.swift
//  RxReduxift
//
//  Created by YEONGJUNG KIM on 17/02/2019.
//

import Foundation
import Reduxift
import RxSwift

extension Reduxift.Action {
    public typealias ObservablePayload = (@escaping Dispatcher) -> RxSwift.Disposable
    public typealias GenericObservable<A: Action, O> = (@escaping GenericDispatcher<A>) -> RxSwift.Observable<O>
    
    /// creates observable payload
    ///
    /// - Parameter action: closure to create an observable
    /// - Returns: dispach closure to subscribe and return a disposable
    public func observable<O>(_ action: @escaping GenericObservable<Self, O>) -> Action.ObservablePayload {
        return { dispatch -> Disposable in
            return action(dispatch).subscribe()
        }
    }
    
    /// creates observable action
    ///
    /// - Parameter action: closure to create an observable
    /// - Returns: ObservableAction
    public static func observable<O>(_ action: @escaping GenericObservable<Self, O>) -> Action.ObservablePayload {
        return { dispatch -> Disposable in
            return action(dispatch).subscribe()
        }
    }
}

