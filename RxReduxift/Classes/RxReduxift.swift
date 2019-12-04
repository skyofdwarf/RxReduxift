//
//  RxReduxift.swift
//  RxReduxift
//
//  Created by YEONGJUNG KIM on 11/02/2019.
//

import Foundation
import Reduxift
import RxSwift
import RxRelay

/// Reacitve Reduxift
///
public class RxStore<StateType: State> {
    private let store: Store<StateType>
    private let subscription: BehaviorRelay<(StateType, Action)>

    /// Observable for state
    public var state: Observable<StateType> { subscription.map { $0.0 } }

    /// Observable for action
    public var action: Observable<Action> { subscription.map { $0.1 } }

    /// Get current state
    public var currentState: StateType { subscription.value.0 }

    /// Create `RxStore` instance which wrapping `Reduxift.Store` and subscription
    ///
    /// - Parameters:
    ///   - initialState: initial state
    ///   - reducer: root state reducer
    ///   - middlewares: middlewares
    public init(state initialState: StateType,
                reducer: @escaping Reducer<StateType> = StateType.reduce,
                middlewares: [Middleware<StateType>] = [])
    {
        subscription = BehaviorRelay(value: (initialState, Never.do))

        store = Store(state: initialState,
                      reducer: reducer,
                      middlewares: middlewares)

        store.subscribe { [weak self] (state, action) in
            guard let self = self else { return }

            self.subscription.accept((state, action))
        }
    }

    /// Dispatches action
    /// - Parameter action: action to dispatch
    public func dispatch(_ action: Action) {
        store.dispatch(action)
    }
}
