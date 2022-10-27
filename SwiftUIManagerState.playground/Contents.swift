import Combine
import SwiftUI

struct AppState {
    var count = 0
    var favoritePrimes: [Int] = []
    var loggedInUser: User? = nil
    var activityFeed: [Activity] = []

    struct Activity {
        let timestamp: Date
        let type: ActivityType

        enum ActivityType {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }

    struct User {
        let id: Int
        let name: String
        let bio: String
    }
}

enum CounterAction {
    case decrTapped
    case incrTapped
}

enum PrimeModalAction {
    case saveFavoritePrimeTapped
    case removeFavoritePrimeTapped
}

enum FavoritePrimesAction {
    case deleteFavoritePrimes(IndexSet)
}

enum AppAction {
    case counter(CounterAction)
    case primeModal(PrimeModalAction)
    case favoritePrimes(FavoritePrimesAction)
}

func counterReducer(state: inout Int, action: AppAction) {
  switch action {
  case .counter(.decrTapped):
    state -= 1

  case .counter(.incrTapped):
    state += 1

  default:
    break
  }
}

func primeModalReducer(state: inout AppState, action: AppAction) {
  switch action {
  case .primeModal(.removeFavoritePrimeTapped):
    state.favoritePrimes.removeAll(where: { $0 == state.count })
    state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

  case .primeModal(.saveFavoritePrimeTapped):
    state.favoritePrimes.append(state.count)
    state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

  default:
    break
  }
}

func favoritePrimesReducer(state: inout FavoritePrimesState, action: AppAction) {
  switch action {
  case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
    for index in indexSet {
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      state.favoritePrimes.remove(at: index)
    }

  default:
    break
  }
}

extension AppState {
  var favoritePrimesState: FavoritePrimesState {
    get {
      return FavoritePrimesState(
        favoritePrimes: self.favoritePrimes,
        activityFeed: self.activityFeed
      )
    }
    set {
      self.activityFeed = newValue.activityFeed
      self.favoritePrimes = newValue.favoritePrimes
    }
  }
}

func combine<Value, Action>(
  _ reducers: (inout Value, Action) -> Void...
) -> (inout Value, Action) -> Void {

  return { value, action in
    for reducer in reducers {
      reducer(&value, action)
    }
  }
}

func pullback<LocalValue, GlobalValue, Action>(
  _ reducer: @escaping (inout LocalValue, Action) -> Void,
  value: WritableKeyPath<GlobalValue, LocalValue>
) -> (inout GlobalValue, Action) -> Void {
  return { globalValue, action in
    reducer(&globalValue[keyPath: value], action)
  }
}

let appReducer = combine(
  pullback(counterReducer, value: \.count),
  primeModalReducer,
  pullback(favoritePrimesReducer, value: \.favoritePrimesState)
)

final class Store<Value, Action>: ObservableObject {
    let reducer: (inout Value, Action) -> Void
    @Published private(set) var value: Value

    init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
        self.reducer = reducer
        self.value = initialValue
    }

    func send(_ action: Action) {
        self.reducer(&self.value, action)
    }
}

struct PrimeAlert: Identifiable {
    let prime: Int
    var id: Int { self.prime }
}

struct FavoritePrimesState {
    var favoritePrimes: [Int]
    var activityFeed: [AppState.Activity]
}

struct IsPrimeModalView: View {
    @ObservedObject var store: Store<AppState, AppAction>

    var body: some View {
        VStack {
            if isPrime(self.store.value.count) {
                Text("\(self.store.value.count) is prime 🎉")
                if self.store.value.favoritePrimes.contains(self.store.value.count) {
                    Button(action: {
                        self.store.send(.primeModal(.removeFavoritePrimeTapped))
                    }) {
                        Text("Remove from favorite primes")
                    }
                } else {
                    Button(action: {
                        self.store.send(.primeModal(.saveFavoritePrimeTapped))

                    }) {
                        Text("Save to favorite primes")
                    }
                }
            } else {
                Text("\(self.store.value.count) is not prime :(")
            }

        }
    }

    private func isPrime (_ p: Int) -> Bool {
        if p <= 1 { return false }
        if p <= 3 { return true }
        for i in 2...Int(sqrtf(Float(p))) {
            if p % i == 0 { return false }
        }
        return true
    }
}


struct CounterView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    @State var isPrimeModalShown: Bool = false
    @State var alertNthPrime: PrimeAlert?
    @State var isNthPrimeButtonDisabled = false

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.store.send(.counter(.decrTapped))
                }) {
                    Text("-")
                }

                Text("\(self.store.value.count)")
                Button(action: {
                    self.store.send(.counter(.incrTapped))
                }) {
                    Text("+")
                }
            }
            Button(action: { self.isPrimeModalShown = true }) {
                Text("Is this prime?")
            }
            Button(action: self.nthPrimeButtonAction) {
                Text("What is the \(ordinal(self.store.value.count)) prime?")
            }
            .disabled(self.isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationTitle("Counter Demo")
        .sheet(isPresented: self.$isPrimeModalShown){
            IsPrimeModalView(store: self.store)
        }
        .alert(item: self.$alertNthPrime) { alert in
            Alert(
                title: Text("The \(ordinal(self.store.value.count)) prime is \(alert.prime)"),
                dismissButton: .default(Text("Ok"))
            )
        }
    }

    func nthPrimeButtonAction() {
        self.isNthPrimeButtonDisabled = true
        nthPrime(self.store.value.count) { prime in
            self.alertNthPrime = prime.map(PrimeAlert.init(prime:))
            self.isNthPrimeButtonDisabled = false
        }
    }
}

struct FavoritePrimesView: View {
    @ObservedObject var store: Store<AppState, AppAction>

    var body: some View {
        List {
            ForEach(self.store.value.favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                self.store.send(.favoritePrimes(.deleteFavoritePrimes(indexSet)))
            })
            .navigationBarTitle(Text("Favorite Primes"))
        }
    }
}


struct ContentView: View {
    @ObservedObject var store: Store<AppState, AppAction>

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(store: self.store)) {
                    Text("Counter demo")
                }
                NavigationLink(destination: FavoritePrimesView(store: self.store)) {
                    Text("Favorite primes")
                }
            }
            .navigationBarTitle("State management")
        }
        .frame(width: 450, height: 550)
    }
}

import PlaygroundSupport

PlaygroundPage.current.setLiveView(
    ContentView(
        store: Store(initialValue: AppState(), reducer: appReducer)
        )
)
