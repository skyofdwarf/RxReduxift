//
//  ObservablePayloadMiddleware.swift
//  Reduxift
//
//  Created by YEONGJUNG KIM on 17/02/2019.
//

import Foundation
import Reduxift

public func ObservablePayloadMiddleware<S: State>() -> Middleware<S> {
    return CreateMiddleware { (state, dispatch, next, action) in
        if let observable = action.payload as? Action.ObservablePayload {
            // do not call `next(action)`
            return observable(dispatch)
        }
        else {
            return next(action)
        }
    }
}
