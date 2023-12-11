//
//  ContentView.swift
//  EcticLoader
//
//  Created by B054WO on 06/12/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject var loader = Loader()
    var body: some View {
        VStack {
            HStack {
                Button("Small Load") {
                    loader.load(1)
                }
                Button("Big Load") {
                    loader.load(1000)
                }
                Button("Print logs") {
                    loader.printLogs()
                }
            }
            Text(loader.logString)
            List(loader.elements) { element in
                LoaderView(element: element)
            }
        }
        .padding()
    }
}

struct LoaderView: View {
    @ObservedObject var element: LoadingElement
    var body: some View {
        HStack {
            Text(element.id.uuidString)
            Spacer()
            ProgressView(value: element.progression, total: 100)
        }
    }
}

final class LoadingElement: Identifiable, ObservableObject {
    let id = UUID()
    @Published var progression: Float = 0
}

import StupidPackage

@MainActor
final class Loader: ObservableObject {
    @Published var elements = [LoadingElement]()
    var logs = [UUID: String?]()
    @Published var logString = ""
    init() {
        (0 ... 10).forEach { _ in
            let element = LoadingElement()
            self.elements.append(element)
        }
    }

    func load(_ speed: UInt32) {
        elements.forEach { element in
            self.logs[element.id] = "\(element.id.uuidString) in progress"
            Task {
                await load(element, speed)
            }
        }
        printLogs()
    }

    func printLogs() {
        logString = logs.values
            .compactMap { $0 }
            .joined(separator: "-")
    }

    private func load(_ element: LoadingElement, _ speed: UInt32) async {
        for index in 0 ... 100 {
            StupidPackage.aStupidOperation(speed)
            element.progression = Float(index)
            if index == 100 {
                logs[element.id] = nil
                printLogs()
            }
        }
    }
}
