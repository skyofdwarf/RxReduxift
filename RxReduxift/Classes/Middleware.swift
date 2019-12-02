//
//  ObservablePayloadMiddleware.swift
//  Reduxift
//
//  Created by YEONGJUNG KIM on 17/02/2019.
//

import Foundation
import Reduxift
import RxSwift

//public func ObservablePayloadMiddleware<StateType: State>() -> Middleware<StateType> {
//    return CreateMiddleware { (state, dispatch, next, action) in
//        if let observable = action.payload as? Action.ObservablePayload {
//            // do not call `next(action)`
//            return observable(dispatch)
//        }
//        else {
//            return next(action)
//        }
//    }
//}
//
//public func ObservableActionMiddleware<StateType: State>() -> Middleware<StateType> {
//    return CreateMiddleware { (state, dispatch, next, action) in
//        if let observable = action as? Observable<Any> {
//            let disposable = observable.subscribe()
//            return next(disposable)
//        }
//        else {
//            return next(action)
//        }
//    }
//}
