import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(state: self.state)) {
                    Text("Counter demo")
                }
                NavigationLink(destination: EmptyView()) {
                    Text("Favorite primes")
                }
            }
            .navigationBarTitle("State management")
        }
        .frame(width: 450, height: 550)
    }
}

private func ordinal(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter.string(for: n) ?? ""
}

// ObservableObject
import Combine

class AppState: ObservableObject {
    @Published var count = 0
//    var count = 0 {
//        willSet {
//            self.objectWillChange.send()
//        }
//    }

//    var didChange = PassthroughSubject<Void, Never>()
}

struct CounterView: View {
    @ObservedObject var state: AppState

    var body: some View {
//        self.$count // Binding<Int>
        VStack {
            HStack {
                Button(action: {
                    self.state.count -= 1
                }) {
                    Text("-")
                    }
                Text("\(self.state.count)")
                Button(action: {
                    self.state.count += 1
                }) {
                    Text("+")
                }
            }
            Button(action: {}) {
                Text("Is this prime?")
            }
            Button(action: {}) {
                Text("What is the \(ordinal(self.state.count)) prime?")
            }
        }
        .font(.title)
        .navigationTitle("Counter Demo")
    }
}

import PlaygroundSupport


PlaygroundPage.current.setLiveView(ContentView(state: AppState()))
