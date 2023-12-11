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
                    loader.load(10)
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

@MainActor
final class LoadingElement: Identifiable, ObservableObject {
    let id = UUID()
    @Published var progression: Float = 0

    func setProg(_ value: Float) {
        progression = value
    }
}

import StupidPackage

@MainActor
final class Loader: ObservableObject {
    @Published var elements = [LoadingElement]()
    @Published var logString = ""
    
    var parallelLoader: ParallelLoader!
    
    init() {
        self.parallelLoader = ParallelLoader(loader: self)
        (0 ... 10).forEach { _ in
            let element = LoadingElement()
            self.elements.append(element)
        }
    }

    func load(_ speed: UInt32) {
        Task {
            await parallelLoader.load(elements, speed)
        }
    }

    func printLogs() {
        Task {
            logString = await parallelLoader.logs.values
                .compactMap { $0 }
                .joined(separator: "-")
        }
    }
}

actor ParallelLoader {
    var logs = [UUID: String?]()
    
    unowned let loader: Loader
        
    init(loader: Loader) {
        self.loader = loader
    }
    
    func updateLogs(_ id: UUID, _ value: String? = nil) {
        logs[id] = nil
    }
    
    func load(_ elements: [LoadingElement], _ speed: UInt32) {
        elements.forEach { element in
            Task {
                updateLogs(element.id, "\(element.id.uuidString) in progress")
                await load(element, speed)
            }
        }
        Task {
            await loader.printLogs()
        }
    }
    
    private nonisolated func load(_ element: LoadingElement, _ speed: UInt32) async {
        for index in 0 ... 100 {
            StupidPackage.aStupidOperation(speed)
            await element.setProg(Float(index))
            if index == 100 {
                await updateLogs(element.id)
                await loader.printLogs()
            }
        }
    }
}
