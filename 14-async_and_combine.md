# Combine et async

On a déjà vu comment transformer un completion block en utilisant les continuations (et le refactoring de Xcode).

Il est possible de migrer du code en `Combine` vers du code `async` ou d'intégrer du code `async` vers du code `Combine` en utilisant le principe de `Future`.

Cet exemple (provenant de : https://swiftbysundell.com/articles/calling-async-functions-within-a-combine-pipeline/) est intéressant :

En premier lieu on crée une extension sur `Publisher` :

```swift
extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    let output = await transform(value)
                    promise(.success(output))
                }
            }
        }
    }
}
```

Ensuite, on peut intégrer cette méthode dans un publisher pour appeler une méthode `async`, récupérer son résultat et ensuite reprendre le flux de `Combine`.

```swift
[5, 4, 3, 2, 1, 0].publisher
    .map { $0 + 2 }
    .asyncMap {
        try? await Task.sleep(nanoseconds: 1000)
        return $0 + 2
    }
    .eraseToAnyPublisher()
```

Evidemment, il est possible que cela génère des conflits liés à l'isolation des `Actor`, mais le compilateur devrait vous les indiquer.

On peut évidemment créer d'autres extensions qui pourraient `throw` des erreurs par exemple ou gérer d'autres types de `Task`, des `TaskGroup`, etc.

## AsyncSequence

`Combine` intègre déjà le principe d'`AsyncSequence` :-).

On peut donc utiliser un publisher dans ce sens :

```swift
func remoteDataPublisher(
    forURLs urls: [URL],
    urlSession: URLSession = .shared
) -> AnyPublisher<Data, URLError> {
    urls.publisher
        .setFailureType(to: URLError.self)
        .flatMap(maxPublishers: .max(1)) {
            urlSession.dataTaskPublisher(for: $0)
        }
        .map(\.data)
        .eraseToAnyPublisher()
}
```

et ceci :

```swift
let publisher = remoteDataPublisher(forURLs: urls)

for try await data in publisher.values {
    ...
}
```

voir : https://swiftbysundell.com/articles/async-sequences-streams-and-combine/