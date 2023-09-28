# Paralléliser son code (async let binding)

## Exemple

Vous devez récupérer des contrats depuis une API. Voici le code actuel :

```swift
func metaDataContractURLRequest(for id: String) -> URLRequest {...}
func contractURLRequest(for id: String) -> URLRequest {...}
func createContract(_ data: Data, _ metaData: Data) throws -> Contract {...}

struct Contract: Decodable {...}
struct ContractMetaData: Decodable {...}

func fetchContracts(for ids: [String]) async throws -> [String: Contract] {
    var contracts: [String: Contract] = [:]
    for id in ids {
        let (metaData, _) = try await URLSession.shared.data(for: metaDataContractURLRequest(for: id))
        let (data, _) = try await URLSession.shared.data(for: contractURLRequest(for: id))
        let contract = try createContract(data, metaData)
        contracts[id] = contract
    }
    return contracts
}
```

Le code précédent est déjà asynchrone, ce qui est une bonne nouvelle (il est facile à comprendre !).

Cependant, il n'est pas parallélisé et, si le nombre de contrats est très grand, il n'utilisera pas les avantages de la concurrency totalement (et prendra plus de temps à s'exécuter).

Les `try await` se produisent l'un à la suite de l'autre.

## async let binding

Une façon simple de le rendre parallèle est de modifier les deux appels à `URLSession` :

```swift
func fetchContracts(for ids: [String]) async throws -> [String: Contract] {
    var contracts: [String: Contract] = [:]
    for id in ids {
        async let (metaData, _) = URLSession.shared.data(for: metaDataContractURLRequest(for: id))
        async let (data, _) = URLSession.shared.data(for: contractURLRequest(for: id))
        let contract = try await createContract(data, metaData)
        contracts[id] = contract
    }
    return contracts
}
```

De cette manière, les deux appels à `URLSession` se font en parallèle.


*Remarque* : `async var` n'existe pas et on comprend pourquoi !

```swift
func fetchUsername() async -> String {
    // complex networking here
    "Taylor Swift"
}

async var username = fetchUsername()
username = "Justin Bieber"
print("Username is \(username)")
```
Dans ce code, comment prédire la valeur de `username`...

(Source : https://www.hackingwithswift.com/quick-start/concurrency/why-cant-we-call-async-functions-using-async-var)

## Asynchronous Sequence

Lorsque vous récupérez le résultat d'un webservice, en général vous récupérez la totalité en un seul bloc, il n'est alors pas possible de rendre le traitement parallèle.

Exemple : 
```swift
func listPhotos(inGallery name: String) async throws -> [String] {
    try await Task.sleep(until: .now + .seconds(2), clock: .continuous)
    return ["IMG001", "IMG99", "IMG0404"]
}
```

On attendra tout le tableau avant de traiter les images.

Cependant, il existe certaines structures qui permettent de traiter chaque élément dès son arrivée.

Exemple :
```swift
let handle = FileHandle.standardInput
for try await line in handle.bytes.lines {
    print(line)
}
```

Ici, `lines` est une `AsyncLineSequence` qui implémente le protocole `AsyncSequence`.

On ne rencontre pas souvent ce comportement mais quand il existe, autant l'utiliser :-).

Il est par contre possible de le créer (par exemple pour un smart loading avec un refresh automatique de la UI).

Exemple :

```swift
struct RemoteDataSequence: Sequence {
    var urls: [URL]

    func makeIterator() -> RemoteDataIterator {
        RemoteDataIterator(urls: urls)
    }
}

struct RemoteDataIterator: IteratorProtocol {
    var urls: [URL]
    fileprivate var index = 0

    mutating func next() -> Data? {
        guard index < urls.count else {
            return nil
        }

        let url = urls[index]
        index += 1

        // If a download fails, we simply move on to
        // the next URL in this case:
        guard let data = try? Data(contentsOf: url) else {
            return next()
        }

        return data
    }
}

```

*source : https://swiftbysundell.com/articles/async-sequences-streams-and-combine/*

## TaskGroup

Exemple :
```swift
func randomUInt() -> UInt64 {
    1_000_000 * UInt64.random(in: 1...6)
}

func fetchData(_ id: Int) async {
    try? await Task.sleep(nanoseconds: randomUInt())
    print("data :\(id)")
}

for id in 1...20 {
    await fetchData(id)
}
```

Dans ce code, le fetch de chaque `id` se fait séquentiellement (mais un autre bout de code peut s'exécuter pendant le chargement complet grace à la présence du `await`). D'ailleurs le `print` donne ceci :

```
data :1
data :2
data :3
...
data :20
```

Pour avoir plus de flexibilité sur ce sujet, il est possible d'utiliser les `TaskGroup` comme suit :

```swift
await withTaskGroup(of: Void.self) { taskGroup in
    for id in 1...20 {
        taskGroup.addTask { await fetchData(id) }
    }
}
```

Le fetch n'est plus séquentiel et le `print` donne ceci :
```
data :14
data :4
data :10
data :11
data :9
data :18
...
data :5
data :16
data :20
data :8
```

Les `TaskGroup` sont des types de `Task` primitifs, ils fonctionnent donc de la même manière qu'une `Task`, notamment pour ce qui touche à la propagation de la `Cancellation`.

*Source : https://developer.apple.com/documentation/swift/taskgroup*
