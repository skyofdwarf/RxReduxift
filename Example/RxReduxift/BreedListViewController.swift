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
    case reload([String])
    case alert(String)
}

extension BreedListAction {
    var payload: Any? {
        switch self {
        case let .fetch(breed):
            return async { (dispatch) in
                let urlString = "https://dog.ceo/api/breeds/\((breed != nil) ? breed! + "/list": "list/all")"
                
                guard let url = URL(string: urlString) else {
                    _ = dispatch(.alert("failed to create a url for breed: \(breed ?? "no brred")"))
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

                    if let breeds = json.message as Any? as? [String: Any] {
                        print("breeds: \(breeds)")
                        _ = dispatch(.reload(Array(breeds.keys)))
                    }
                    else {
                        print("no breeds")
                        _ = dispatch(.reload([]))
                    }
                })

                task.resume()

                return {
                    task.cancel()

                    print("fetching cancelled")
                }
            }
            
        case let .reload(breeds):
            return breeds
        case let .alert(msg):
            return msg;
        }
        
    }
}



class BreedListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    let db = DisposeBag()
    
    lazy var store: RxDictionaryStore = createStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.title = "RxReduxift"

        buildBarButtons()
        
        observeBreeds(from: self.store.state)
        observeAlertMessage(from: self.store.state)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}

extension BreedListViewController {
    func createStore() -> RxDictionaryStore {
        let breedsReducer = BreedListAction.reduce([]) { (state, action) in
            if case let .reload(items) = action {
                return items
            }
            else {
                return state
            }
        }
        
        let alertReducer = BreedListAction.reduce("") { (state, action) in
            if case let .alert(msg) = action {
                return msg
            }
            else {
                return state
            }
        }
        
        let reducer = DictionaryStore.reduce { (state, action) in
            return [ "description": "RxReduxift Example App",
                     "data": [ "dogs": [ "breeds": breedsReducer(state.data?.dogs?.breeds, action),
                                         "shout": "bow" ],
                               "cats": "NA" ],
                     "alert": alertReducer(state.alert, action),
            ]
        }
        
        return RxDictionaryStore(state: reducer([:], NamedAction("init state")),
                                 reducer: reducer,
                                 middlewares:[ MainQueueMiddleware(),
                                               FunctionMiddleware({ print("log: \($1)") }),
                                               AsyncActionMiddleware() ])
    }
}

extension BreedListViewController {
    func buildBarButtons() {
        let fetchButton = UIBarButtonItem(title: "Fetch",
                                          style: .plain,
                                          target: nil,
                                          action: nil)

        self.navigationItem.rightBarButtonItem = fetchButton
        
        fetchButton.rx.tap.bind { [weak self] in
            _ = self?.store.dispatch(BreedListAction.fetch(breed: nil))
            }.disposed(by: self.db)
    }
    
    func alert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { [unowned self] (actin) in
            _ = self.store.dispatch(BreedListAction.alert(""))
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func observeBreeds(from state: Observable<DictionaryState>) {
        
        let breeds = state.map { (state) in
            return state.data?.dogs?.breeds as Any? as! [String]
            }
            .distinctUntilChanged()
            .share()
        
        breeds.bind(to: self.tableView.rx.items(cellIdentifier: "BreedCell")) { (row, breed, cell) in
                cell.textLabel?.text = breed
            }.disposed(by: self.store.db)
        
        self.tableView.rx.itemSelected.withLatestFrom(breeds) { (ip, breeds) in
            return breeds[ip.row]
            }
            .subscribe(onNext: { [weak self] breed in
                if let vc = self?.storyboard?.instantiateViewController(withIdentifier: "randomdog") as? RandomDogViewController {
                    vc.breed = breed
                    
                    self?.show(vc, sender: nil)
                }
            }).disposed(by: self.store.db)
    }
    
    func observeAlertMessage(from state: Observable<DictionaryState>) {
        state.map { state in
            return state.alert as Any? as! String
            }
            .filter({ !$0.isEmpty })
            .subscribe(onNext: { [weak self] msg in
                print("next alert: \(msg)")
                self?.alert(msg)
            }).disposed(by: self.store.db)
    }
}
