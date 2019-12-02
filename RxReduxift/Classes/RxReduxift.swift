//
//  RxReduxift.swift
//  RxReduxift
//
//  Created by YEONGJUNG KIM on 11/02/2019.
//

import Foundation
import Reduxift
import RxSwift

public class RxStore<StateType: State> {
    private let store: Store<StateType>
    private let subscription: BehaviorSubject<(StateType, Action)>
    private let db = DisposeBag()

    public var state: Observable<StateType> { subscription.asObservable().map { $0.0 } }
    public var action: Observable<Action> { subscription.asObservable().map { $0.1 } }

    public init(state initialState: StateType,
                reducer: @escaping Reducer<StateType> = StateType.reduce,
                middlewares: [Middleware<StateType>] = [])
    {
        self.subscription = BehaviorSubject(value: (initialState, Never.do))

        self.store = Store(state: initialState,
                           reducer: reducer,
                           middlewares: middlewares)

        self.store.subscribe { [weak self] (state, action) in
            guard let self = self else { return }

            if let observable = action as? Observable<Any> {
                observable.subscribe().disposed(by: self.db)
            }

            self.subscription.onNext((state, action))
        }
    }

    public func dispatch(_ action: Action) {
        self.store.dispatch(action)
    }
}
