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

struct RandomDogState: State {
    var imageUrl: String = ""
    var alert: String = ""
}

enum RandomDogAction: Action {
    case fetch(breed: String?)
    case reload(url: String)
    case alert(String)
    case clearAlert
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
                let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                    guard error == nil else {
                        _ = dispatch(.alert("failed to load breeds: \(error!)"))
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
                        _ = dispatch(.reload(url: imageUrl))
                    }
                    else {
                        print("no image url")
                        _ = dispatch(.alert("no image url"))
                    }
                })
                
                task.resume()
                
                return {
                    task.cancel()
                    
                    _ = dispatch(.alert("fetching cancelled"))
                }
            }
            
        case let .reload(url):
            return url
            
        case let .alert(msg):
            return msg
        case .clearAlert:
            return ""
        }
    }
}



class RandomDogViewController: UIViewController {
    @IBOutlet weak var dogImageView: UIImageView!
    lazy var store: RxStore<RandomDogState> = createStore()
    var canceller: Action.AsyncCanceller?
    
    var breed: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        let cancelButton = UIBarButtonItem(title: "Cancel",
                                           style: .plain,
                                           target: self,
                                           action: #selector(RandomDogViewController.cancelButtonDidClick))
        let fetchButton = UIBarButtonItem(title: "Fetch",
                                          style: .plain,
                                          target: self,
                                          action: #selector(RandomDogViewController.fetchButtonDidClick))
        
        self.navigationItem.rightBarButtonItems = [ fetchButton, cancelButton ]
        
        observeDogImage(from: self.store.state)
        observeAlertMessage(from: self.store.state)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.reload()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @objc func cancelButtonDidClick(_ sender: Any?) {
        self.canceller?()
        self.canceller = nil
    }
    
    @objc func fetchButtonDidClick(_ sender: Any?) {
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
            case let .reload(url):
                state.imageUrl = url
            case let .alert(msg):
                state.alert = msg
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
    
    func alert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { [unowned self] (actin) in
            _ = self.store.dispatch(RandomDogAction.clearAlert)
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func reload() {
        self.canceller = self.store.dispatch(RandomDogAction.fetch(breed: self.breed)) as? Action.AsyncCanceller
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
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] msg in
                self?.alert(msg)
            }).disposed(by: self.store.db)
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
