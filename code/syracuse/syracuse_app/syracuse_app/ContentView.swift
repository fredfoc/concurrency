//
//  ContentView.swift
//  syracuse_app
//
//  Created by B054WO on 03/10/2023.
//

import SwiftUI

class Syracuse {
    init() {
        Task {
            await checkRandomSyracuse("first")
        }
        Task {
            await checkRandomSyracuse("second")
        }
        print(testSyracuse(6))
    }
}

struct ContentView: View {
    @State var syracuse = Syracuse()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

func testSyracuse(_ number: Int, _ str: String? = nil) -> String {
    let path: String
    if let str {
        path = str
    } else {
        path = "\(number)"
    }
    if number == 1 {
        return path
    }
    if number % 2 == 0 {
        let newNumber = number / 2
        return testSyracuse(newNumber, "\(path),\(newNumber)")
    }
    let newNumber = number * 3 + 1
    return testSyracuse(newNumber, "\(path),\(newNumber)")
}

@discardableResult
func checkRandomSyracuse(_ marker: String) async -> [String] {
    (1...100)
        .map { $0*Int.random(in: 1...300) }
        .map {
            print(marker, "testing", $0)
            return testSyracuse($0)
            
        }
}
