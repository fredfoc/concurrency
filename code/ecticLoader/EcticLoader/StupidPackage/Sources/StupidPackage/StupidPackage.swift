// The Swift Programming Language
// https://docs.swift.org/swift-book


public func aStupidOperation(_ speed: UInt32) {
    let top = Int.random(in: 1000 ... (10000 * Int(speed)))
    var value = [Int]()
    for index in 0...top {
        value.append(index)
    }
}
