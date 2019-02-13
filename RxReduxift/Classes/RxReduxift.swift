//
//  RxReduxift.swift
//  RxReduxift
//
//  Created by YEONGJUNG KIM on 11/02/2019.
//

import Foundation
import Reduxift
import RxSwift

public typealias RxDictionaryStore = RxStore<DictionaryState>


public class RxStore<S: State> {
    private let store: Store<S>
    public let state: BehaviorSubject<S>
    
    public let db = DisposeBag()
    
    public init(state: S, reducer: @escaping Store<S>.Reducer, middlewares: [Middleware<S>]) {
        self.store = Store(state: state, reducer: reducer, middlewares: middlewares)
        self.state = BehaviorSubject(value: state)
        
        self.store.subscribe(self)
    }
    
    public var currentState: S {
        return try! self.state.value()
    }
    
    public func dispatch(_ action: Action) -> Any {
        return self.store.dispatch(action)
    }
}

extension RxStore: StoreSubscriber  {
    public func store(didChangeState state: S, action: Action) {
        self.state.onNext(state)
    }
}
