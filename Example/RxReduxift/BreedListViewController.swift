//
//  BreedListViewController.swift
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

enum BreedListAction: Action {
    case fetch(breed: String?)
    case cancel(Canceller)
    
    case fetching(Canceller)
    case result(Result<[String], Error>)
}

extension BreedListAction: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.fetch, .fetch):
            return true
        case (.fetching, .fetching):
            return true
        case (.result, .result):
            return true
        default:
            return false
        }
    }
}

extension BreedListAction: Doable {
    func `do`(_ dispatch: @escaping StoreDispatcher) -> Reaction {
        switch self {
        case .fetch(let breed):
            let disposable = BreedService.fetch(breed: breed)
                .debug()
                .do(onNext: { (breeds) in
                    dispatch(BreedListAction.result(.success(breeds)))
                }, onError: { (error) in
                    dispatch(BreedListAction.result(.failure(error)))
                })
                .subscribe()

            return BreedListAction.fetching({ disposable.dispose() })

        case .cancel(let canceller):
            canceller()

        default:
            break
        }

        return self
    }
}

struct ListState: State {
    var breeds: [String] = []

    var fetching = false
    var cancelling = false
    var canceller: Canceller?

    var alert = ""
}

extension ListState {
    static func reduce(_ state: ListState, _ action: Action) -> ListState {
        var state = state
        switch action {
        case BreedListAction.result(let result):
            state.fetching = false
            state.cancelling = false
            state.canceller = nil

            switch result {
            case .success(let breeds):
                state.breeds = breeds
            case .failure(let error):
                state.alert = error.localizedDescription
            }

        case BreedListAction.fetching(let canceller):
            state.fetching = true
            state.cancelling = false
            state.canceller = canceller

        case BreedListAction.cancel:
            state.fetching = true
            state.cancelling = true
            state.canceller = nil

        default:
            break
        }

        return state
    }
}

struct BreedService {
    static func fetch(breed: String?) -> Observable<[String]> {
        return Observable.create { (observer) -> Disposable in
            let urlString: String = { breed in
                if let breed = breed {
                    return "https://dog.ceo/api/breeds/\(breed)/list"
                }
                else {
                    return "https://dog.ceo/api/breeds/list/all"
                }
            }(breed)
            
            guard let url = URL(string: urlString) else {
                observer.onError("failed to create a url for breed: \(breed ?? "No breed")")
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
                
                if let breeds = json["message"] as? [String: Any] {
                    print("breeds: \(breeds)")
                    observer.onNext(Array(breeds.keys))
                    observer.onCompleted()
                }
                else {
                    print("no breeds")
                    observer.onNext([])
                }
            })
            
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
}


/// Example to use predefined DictionaryState
class BreedListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    var indicator: UIActivityIndicatorView!
    var fetchButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    
    let db = DisposeBag()
    let store = RxStore(state: ListState(), middlewares: [DoableMiddleware(),
                                                          LogMiddleware("[LOG]", { (tag, action, getState) in
                                                            print("\(tag) <\(action)>")
                                                          })])
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        title = "RxReduxift"

        buildUI()
        bindState()
    }
}


extension BreedListViewController {
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

extension BreedListViewController {
    func bindState() {
        bindStateInput()
        bindStateOutput()
    }

    func bindStateInput() {
        fetchButton.rx.tap.bind { [unowned self] in
            self.store.dispatch(BreedListAction.fetch(breed: nil))
        }
        .disposed(by: db)

        cancelButton.rx.tap.bind { [unowned self] in
            guard let canceller = self.store.currentState.canceller else { return }
            self.store.dispatch(BreedListAction.cancel(canceller))
        }
        .disposed(by: db)
    }

    func bindStateOutput() {
        // action
        store.action
            .bind(to: rx.action)
            .disposed(by: db)

        // list
        let breeds: Observable<[String]> = store.state
            .map { $0.breeds }
            .distinctUntilChanged()
            .share()

        tableView.rx.methodInvoked(#selector(UIView.didMoveToWindow))
            .take(1)
            .flatMap { _ -> Observable<[String]> in breeds }
            .bind(to: tableView.rx.items(cellIdentifier: "BreedCell")) { (row, breed, cell) in
                cell.textLabel?.text = breed
        }.disposed(by: db)

        // selection
        self.tableView.rx.itemSelected.withLatestFrom(breeds) { (ip, breeds) in
            return breeds[ip.row]
        }
        .bind(to: rx.selection)
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
    
    func alert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { [unowned alert] (actin) in
            alert.dismiss(animated: true, completion: nil)
        })
        
        present(alert, animated: true, completion: nil)
    }
}

// MARK: Reactive

extension Reactive where Base: BreedListViewController {
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

    var selection: Binder<String> {
        return Binder(base) { (base, breed) in
            if let vc = base.storyboard?.instantiateViewController(withIdentifier: "randomdog") as? RandomDogViewController {
                vc.breed = breed
                base.show(vc, sender: nil)
            }
        }
    }
}

