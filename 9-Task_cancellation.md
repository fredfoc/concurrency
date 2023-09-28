# `Task` cancellation

Contrairement à `Combine`, dès qu'on crée une `Task`, elle s'exécute, même si vous n'avez gardez aucune référence dessus ou si l'entité qui l'a créée est déréférencée (en `Combine`, un cancellable référencé par une entité est automatiquement cancel au déinit de l'entité).

C'est normal, la structured concurrency en Swift n'est pas construite de la même façon que `Combine`. Dès qu'une `Task` est créée, elle est rattachée en gros au `Cooperative Thread Pool` qui va s'occuper d'orchestrer tout ça entre les threads, les opérations suspendues et les continuations.

Il est cependant possible d'annuler une `Task`.

Exemple :

```swift
let task = Task {
    await asyncRandomD6()
}
task.cancel()
```

## Fonctionnement

En annulant une `Task` l'annulation se répercute sur les `Task` enfants de cette `Task`.

Exemple :

```swift
func fetchImage() async throws -> UIImage? {
    let imageTask = Task { () -> UIImage? in
        let imageURL = URL(string: "https://source.unsplash.com/random")!
        print("Starting network request...")
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return UIImage(data: imageData)
    }
    // Cancel the image request right away:
    imageTask.cancel()
    return try await imageTask.value
}
```

*source: https://www.avanderlee.com/concurrency/tasks/*

Dans le code suivant, la méthode `fetchImage()` tente de charger une image random sur une URL. Pour le principe de reflexion, on a ajouté la ligne `imageTask.cancel()`.

Il est intéressant de noté que `try await URLSession.shared.data(from: imageURL)` reçoit la demande de cancellation et comme le cancel est implémenté dans la méthode `data(from: imageURL)` de `URLSession`, alors on reçoit un print du genre : 

```
Starting network request...
Image loading failed: Error Domain=NSURLErrorDomain Code=-999 "cancelled"
```

Cependant, on notera que la `Task`, bien que cancel, s'est quand même lancée ! (oui, nous avons un `Starting network request...`)

C'est tout à fait normal. C'est au développeur.euse de gérer l'annulation dans son code (la `Task` ne décide pas d'elle-même quand elle doit s'arrêter.).

## Gestion du cancel

### Task.checkCancellation()

Pour gérer le cancel, on peut utiliser la méthode globale : `try Task.checkCancellation()`

```swift
func fetchImage() async throws -> UIImage? {
    let imageTask = Task { () -> UIImage? in

    	/// Throw an error if the task was already cancelled.
    	try Task.checkCancellation()

        let imageURL = URL(string: "https://source.unsplash.com/random")!
        print("Starting network request...")
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return UIImage(data: imageData)
    }
    // Cancel the image request right away:
    imageTask.cancel()
    return try await imageTask.value
}
```

Dans ce cadre, on obtiendra la réponse suivante : `Image loading failed: CancellationError()`.

### Task.isCancelled

On peut aussi utiliser : `Task.isCancelled`

```swift
func fetchImage() async throws -> UIImage? {
    let imageTask = Task { () -> UIImage? in

    	guard Task.isCancelled == false else {
	        // Perform clean up
	        print("Image request was cancelled")
	        return nil
	    }

        let imageURL = URL(string: "https://source.unsplash.com/random")!
        print("Starting network request...")
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return UIImage(data: imageData)
    }
    // Cancel the image request right away:
    imageTask.cancel()
    return try await imageTask.value
}
```

L'avantage c'est que ça vous laisse la possibilité de faire quelque chose si la `Task` est cancel (c'est un peu moins violent que le précédent si on veut :-)).

On peut cascader les checks de cancellation dans le code en fonction des différents `await` rencontrés. C'est même une pratique recommandée ! (mais pas assez appliquée...)

Exemple :

```swift
func metaDataContractURLRequest(for id: String) -> URLRequest {...}
func contractURLRequest(for id: String) -> URLRequest {...}
func createContract(_ data: Data, _ metaData: Data) throws -> Contract {...}

struct Contract: Decodable {...}
struct ContractMetaData: Decodable {...}

func fetchContracts(for ids: [String]) async throws -> [String: Contract]? {
    var contracts: [String: Contract] = [:]
    guard Task.isCancelled == false else {
        // Perform clean up
        print("task was cancelled")
        return nil
    }
    for id in ids {
    	try Task.checkCancellation()
        let (metaData, _) = try await URLSession.shared.data(for: metaDataContractURLRequest(for: id))
        try Task.checkCancellation()
        let (data, _) = try await URLSession.shared.data(for: contractURLRequest(for: id))
        try Task.checkCancellation()
        let contract = try createContract(data, metaData)
        contracts[id] = contract
    }
    return contracts
}
```

### withTaskCancellation

## TaskGroup cancellation

la cancellation sur une `TaskGroup` peut être plus funky :-).

Prenons un exemple :



*source : https://www.hackingwithswift.com/quick-start/concurrency/how-to-cancel-a-task-group