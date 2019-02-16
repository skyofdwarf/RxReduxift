//
//  RandomgDogViewController.swift
//  Reduxift_Example
//
//  Created by skyofdwarf on 2019. 1. 30..
//  Copyright © 2019년 CocoaPods. All rights reserved.
//

import UIKit
import Reduxift
import RxReduxift
import RxSwift

extension String: Error {}

struct RandomDogState: State {
    var imageUrl: String = ""
    var alert: String = ""
    var fetching: Bool = false
}

enum RandomDogAction: Action {
    case fetch(breed: String?)
    case alert(String)
    
    case requestImageUrlFor(_ breed: String?)
    case receiveImageUrl(_ url: String)
}

extension RandomDogAction {
    var payload: Any? {
        switch self {
        case let .fetch(breed):
            return async { (dispatch) in
                let urlString = ((breed == nil) ?
                    "https://dog.ceo/api/breeds/image/random":
                    "https://dog.ceo/api/breed/\(breed!)/images/random")
                
                
                guard let url = URL(string: urlString) else {
                    _ = dispatch(.alert("failed to create a url of random dog for breed: \(breed ?? "no brred")"))
                    return nil
                }
                
                _ = dispatch(.requestImageUrlFor(breed))
                
                let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                    guard error == nil else {
                        print("error: \(error!)")
                        _ = dispatch(.alert(error!.localizedDescription))
                        return
                    }
                    
                    guard
                        let data = data,
                        let json = try? JSONSerialization.jsonObject(with: data, options: []) as! [String: Any] else {
                            _ = dispatch(.alert("failed to parse json from response"))
                            return
                    }
                    
                    if let imageUrl = json.message as Any? as? String {
                        print("image url: \(imageUrl)")
                        _ = dispatch(.receiveImageUrl(imageUrl))
                    }
                    else {
                        print("no image url")
                        _ = dispatch(.alert("no image url"))
                    }
                })
                
                task.resume()
                
                return {
                    task.cancel()
                }
            }
            
        case let .requestImageUrlFor(breed):
            return breed
            
        case let .receiveImageUrl(url):
            return url
            
        case let .alert(msg):
            return msg
        }
    }
    
    static func fetchImageUrlFor(breed: String?) -> Observable<String> {
        return Observable<String>.create { (observer) -> Disposable in
            let urlString = ((breed == nil) ?
                "https://dog.ceo/api/breeds/image/random":
                "https://dog.ceo/api/breed/\(breed!)/images/random")
            
            guard let url = URL(string: urlString) else {
                observer.onError("failed to create a url of random dog for breed: \(breed ?? "no brred")")
                return Disposables.create()
            }
            
            let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                guard error == nil else {
                    print("error: \(error!)")
                    observer.onError(error!.localizedDescription)
                    return
                }
                
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data, options: []) as! [String: Any] else {
                        observer.onError("failed to parse json from response")
                        return
                }
                
                if let imageUrl = json.message as Any? as? String {
                    print("image url: \(imageUrl)")
                    observer.onNext(imageUrl)
                    observer.onCompleted()
                }
                else {
                    print("no image url")
                    observer.onError("no image url")
                }
            })
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
    
    static func fetchImage(url: String) -> Observable<UIImage> {
        return Observable<UIImage>.create { (observer) -> Disposable in
            if let url = URL(string: url), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                observer.onNext(image)
                observer.onCompleted()
            }
            else {
                observer.onError("failed to download image data from: \(url)")
            }
            
            return Disposables.create()
        }
        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background)).share()
    }
}



class RandomDogViewController: UIViewController {
    @IBOutlet weak var dogImageView: UIImageView!
    
    var indicator: UIActivityIndicatorView!
    
    var fetchButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    
    let db = DisposeBag()
    
    
    lazy var store: RxStore<RandomDogState> = createStore()
    var canceller: Action.AsyncCanceller?
    
    var breed: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.title = self.breed ?? "Random Dog"
        
        buildIndicator()
        buildBarButtons()
        
        observeDogImage(from: self.store.state)
        observeAlertMessage(from: self.store.state)
        observeFetchingStatus(from: self.store.state)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.reload()
    }
}

extension RandomDogViewController {
    func createStore() -> RxStore<RandomDogState> {
        let reducer = RandomDogState.reduce { (state, action) in
            guard let action = action as? RandomDogAction else {
                return state
            }
            
            var state = state
            
            switch action {
            case .requestImageUrlFor:
                state.fetching = true
            case let .receiveImageUrl(url):
                state.imageUrl = url
                state.fetching = false
            case let .alert(msg):
                state.alert = msg
                state.fetching = false
            default:
                return state
            }
            return state
        }
        
        
        return RxStore<RandomDogState>(state: RandomDogState(),
                                       reducer: reducer,
                                       middlewares:[ MainQueueMiddleware(),
                                                     FunctionMiddleware({ print("log: \($1)") }),
                                                     AsyncActionMiddleware() ])
    }
}

extension RandomDogViewController {
    func buildIndicator() {
        self.indicator = UIActivityIndicatorView(style: .gray)
        self.indicator.hidesWhenStopped = true
        
        self.view.addSubview(self.indicator)
        self.view.bringSubviewToFront(self.indicator)
        
        self.indicator.center = self.view.center
    }
    
    func buildBarButtons() {
        self.fetchButton = UIBarButtonItem(title: "Fetch",
                                           style: .plain,
                                           target: nil,
                                           action: nil)
        
        self.cancelButton = UIBarButtonItem(title: "Cancel",
                                            style: .plain,
                                            target: nil,
                                            action: nil)
        
        self.navigationItem.rightBarButtonItems = [ self.cancelButton, self.fetchButton ]
        
        self.fetchButton.rx.tap.bind { [weak self] in
            self?.reload()
            }.disposed(by: self.db)
        
        self.cancelButton.rx.tap.bind { [weak self] in
            self?.cancel()
            }.disposed(by: self.db)
    }

    
    func alert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { [unowned self] (actin) in
            _ = self.store.dispatch(RandomDogAction.alert(""))
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func reload() {
        self.canceller = self.store.dispatch(RandomDogAction.fetch(breed: self.breed)) as? Action.AsyncCanceller
    }
    
    func cancel() {
        self.canceller?()
        clearCanceller()
    }
    
    func clearCanceller() {
        self.canceller = nil
    }
    
    func observeDogImage(from state: Observable<RandomDogState>) {
        state
            .map{ return $0.imageUrl }
            .distinctUntilChanged()
            .filter { !$0.isEmpty }
            .flatMapLatest({ RandomDogViewController.fetchImage(url: $0) })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.dogImageView.image = image
            }).disposed(by: self.store.db)
    }
    
    func observeAlertMessage(from state: Observable<RandomDogState>) {
        state
            .map { return $0.alert as Any? as! String }
            .distinctUntilChanged()
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] msg in
                self?.alert(msg)
            }).disposed(by: self.store.db)
    }
    
    func observeFetchingStatus(from state: Observable<RandomDogState>) {
        let fetching = state
            .map { return $0.fetching as Any? as! Bool }
            .distinctUntilChanged()
            .share()
        
        fetching
            .bind(to: self.cancelButton.rx.isEnabled)
            .disposed(by: self.db)
        
        fetching
            .map { return !$0 }
            .bind(to: self.fetchButton.rx.isEnabled)
            .disposed(by: self.db)
        
        fetching
            .bind(to: self.indicator.rx.isAnimating)
            .disposed(by: self.db)
    }
}

extension RandomDogViewController {
    static func fetchImage(url: String) -> Observable<UIImage?> {
        return Observable<UIImage?>.create { (observer) -> Disposable in
            if let url = URL(string: url), let data = try? Data(contentsOf: url) {
                observer.onNext(UIImage(data: data))
            }
            else {
                observer.onNext(nil)
            }
            
            return Disposables.create()
            }.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background)).share()
    }
    
}
