//
//  main.swift
//  Syracuse
//
//  Created by B054WO on 03/10/2023.
//

import Foundation

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

func checkRandomSyracuse() async -> [String] {
    (1...100_000)
        .map { $0*Int.random(in: 1...300) }
        .map {testSyracuse($0)}
}

await checkRandomSyracuse()
print(testSyracuse(6))
