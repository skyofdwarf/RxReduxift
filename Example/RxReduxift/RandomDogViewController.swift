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
import RxCocoa

extension String: Error {}

enum CommonError: Error {
    case userCancelled
}

enum RandomDogAction: Action {
    case fetch(breed: String?)
    case cancel(Canceller)
    
    case fetching(Canceller)
    case result(Result<UIImage?, Error>)
}

extension RandomDogAction: Doable {
    func `do`(_ dispatch: @escaping StoreDispatcher) -> Reaction {
        switch self {
        case let .fetch(breed):
            let disposable = ImageService.fetchImageUrl(for: breed)
                .flatMap { ImageService.fetchImage(url: $0) }
                .observeOn(MainScheduler.instance)
                .do(onNext: { (image) in
                    dispatch(RandomDogAction.result(.success(image)))
                }, onError: { (error) in
                    dispatch(RandomDogAction.result(.failure(error)))
                })
                .subscribe()

            return RandomDogAction.fetching({ disposable.dispose() })

        case .cancel(let canceller):
            // Calling canceller causes Observable to be disposed
            canceller()

            // Simulate delayed cancelling
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                dispatch(RandomDogAction.result(.failure(CommonError.userCancelled)))
            }

            return self

        default:
            break
        }
        return self
    }
}

struct ImageService {
    static func fetchImageUrl(for breed: String?) -> Observable<String> {
        return Observable.create { (observer) -> Disposable in
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
                    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        observer.onError("failed to parse json from response")
                        return
                }
                
                if let imageUrl = json["message"] as? String {
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

    static func fetchImage(url: String) -> Observable<UIImage?> {
        return Observable.create { (observer) -> Disposable in
            if let url = URL(string: url), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                observer.onNext(image)
                observer.onCompleted()
            }
            else {
                observer.onError("failed to download image data from: \(url)")
            }

            return Disposables.create()
        }
        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
}

struct RandomDogState: State {
    var image: UIImage?
    var alert: String = ""

    var fetching = false
    var cancelling = false
    var canceller: Canceller?
}

extension RandomDogState {
    static func reduce(_ state: RandomDogState, _ action: Action) -> RandomDogState {
        var state = state

        switch action {
        case RandomDogAction.fetching(let canceller):
            state.fetching = true
            state.cancelling = false
            state.canceller = canceller

        case RandomDogAction.result(let result):
            state.fetching = false
            state.cancelling = false
            state.canceller = nil

            switch result {
            case .success(let image):
                state.image = image
            case .failure(let error):
                state.alert = error.localizedDescription
            }

        case RandomDogAction.cancel:
            state.fetching = true
            state.cancelling = true
            state.canceller = nil

        default:
            break
        }
        return state
    }

}

class RandomDogViewController: UIViewController {
    @IBOutlet weak var dogImageView: UIImageView!
    
    var indicator: UIActivityIndicatorView!
    
    var fetchButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    
    let db = DisposeBag()
    let store = RxStore(state: RandomDogState(), middlewares: [DoableMiddleware(),
                                                               LogMiddleware("[ACTION]", { (tag, action, getState) in
                                                                print("\(tag) <\(action)>")
                                                               }),
                                                               LazyLogMiddleware("[STATE]", { (tag, action, getState) in
                                                                print("\(tag) \(getState())")
                                                               })
    ])
    
    var breed: String?
    
    deinit {
        print("\(String(describing: self)) - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        title = breed ?? "Random Dog"
        
        buildUI()
        bindState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        store.dispatch(RandomDogAction.fetch(breed: breed))
    }
}

extension RandomDogViewController {
    func buildUI() {
        buildIndicator()
        buildBarButtons()
    }

    func buildIndicator() {
        indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.hidesWhenStopped = true
        indicator.color = .red
        
        view.addSubview(indicator)
        view.bringSubviewToFront(indicator)
        
        indicator.center = view.center
    }
    
    func buildBarButtons() {
        fetchButton = UIBarButtonItem(title: "Fetch",
                                      style: .plain,
                                      target: nil,
                                      action: nil)
        
        cancelButton = UIBarButtonItem(title: "Cancel",
                                       style: .plain,
                                       target: nil,
                                       action: nil)
        
        navigationItem.rightBarButtonItems = [ fetchButton, cancelButton ]
    }
}

extension RandomDogViewController {
    func bindState() {
        bindStateInput()
        bindStateOutput()
    }

    func bindStateInput() {
        fetchButton.rx.tap.bind { [unowned self] in
            self.store.dispatch(RandomDogAction.fetch(breed: self.breed))
        }
        .disposed(by: db)

        cancelButton.rx.tap.bind { [unowned self] in
            guard let canceller = self.store.currentState.canceller else { return }
            self.store.dispatch(RandomDogAction.cancel(canceller))
        }
        .disposed(by: db)
    }

    func bindStateOutput() {
        // action
        store.action
            .bind(to: rx.action)
            .disposed(by: db)

        // image
        store.state
            .map{ $0.image }
            .bind(to: rx.image)
            .disposed(by: db)

        // fetching
        store.state
            .map{ $0.fetching }
            .bind(to: indicator.rx.isAnimating)
            .disposed(by: db)

        // buttons
        store.state
            .map{ !$0.fetching && !$0.cancelling }
            .bind(to: fetchButton.rx.isEnabled)
            .disposed(by: db)

        store.state
            .map{ $0.fetching && !$0.cancelling }
            .bind(to: cancelButton.rx.isEnabled)
            .disposed(by: db)
    }
}

extension RandomDogViewController {
    func alert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { [unowned alert] (actin) in
            alert.dismiss(animated: true, completion: nil)
        })
        
        present(alert, animated: true, completion: nil)
    }
}

// MARK: Reactive

extension Reactive where Base: RandomDogViewController {
    var action: Binder<Action> {
        return Binder(base) { (base, action) in
            switch action {
            case BreedListAction.result(let result):
                switch result {
                case .failure(let error):
                    base.alert(error.localizedDescription)
                default:
                    break
                }
            default:
                break
            }
        }
    }

    var image: Binder<UIImage?> {
        return Binder(base) { (base, image) in
            base.dogImageView.image = image
        }
    }

    var selection: Binder<String> {
        return Binder(base) { (base, breed) in
            if let vc = base.storyboard?.instantiateViewController(withIdentifier: "randomdog") as? RandomDogViewController {
                vc.breed = breed
                base.show(vc, sender: nil)
            }
        }
    }
}
