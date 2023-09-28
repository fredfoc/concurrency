# @MainActor

## MainActor

Il existe un `actor` spécial qu'on appelle le `MainActor`. `MainActor` est un `actor` global. Il s'exécute uniquement sur le `main` thread. Il implémente le protocol `GlobalActor`.

On l'utilise donc pour performer des actions sur le main thread (toutes les opérations de UI ou reliées à la UI en général). Il permet d'éviter certains problèmes liés à des taches effectuées en background ou à des `actor` qui seraient joués sur les background threads.

## GlobalActor

```swift
public protocol GlobalActor {

    /// The type of the shared actor instance that will be used to provide
    /// mutually-exclusive access to declarations annotated with the given global
    /// actor type.
    associatedtype ActorType : Actor

    /// The shared actor instance that will be used to provide mutually-exclusive
    /// access to declarations annotated with the given global actor type.
    ///
    /// The value of this property must always evaluate to the same actor
    /// instance.
    static var shared: Self.ActorType { get }

    /// The shared executor instance that will be used to provide
    /// mutually-exclusive access for the global actor.
    ///
    /// The value of this property must be equivalent to `shared.unownedExecutor`.
    static var sharedUnownedExecutor: UnownedSerialExecutor { get }
}
```

Ceci est la définition du protocol `GlobalActor`.

En termes d'utilisation, on écrit plutôt ceci :

```swift
@globalActor
actor MainStorage {
    static let shared = MainStorage()
}

@MainStorage
final class MainStorageFetcher {
    // ..
}
```

Ceci revient à renforcer l'usage du "contexte" de `MainStorage` de manière globale sur votre code. Les instances de la classe `MainStorageFetcher` seront synchronisées avec `MainStorage`.

On peut marquer une classe avec un `GlobalActor`, seulement si :
- elle n'a pas de superclasse
- ou elle a une superclasse mais la superclasse est marquée avec le même `GlobalActor`
- ou elle hérite de `NSObject`

Une sous-classe marquée avec un `GlobalActor` doit être isolée dans le même `actor` que sa superclass !.

Si vous souhaitez qu'un élément ne soit pas exécuté sur le `GlobalActor` choisi, il suffit de le marquer comme `nonisolated`.

## Utilisation `@MainActor`

`MainActor` est donc un acteur global défini par défaut dans l'implémentation de Swift concurrency. On peut l'utiliser partout où il est nécessaire d'être synchronisé avec le main thread.

En écrivant ceci :
```swift
@MainActor
final class HomeViewModel {
    // ..
}
```

On est certain que **toutes** les opérations de `HomeViewModel` seront effectuées et synchronisées sur le main thread. Encore une fois, si vous souhaitez qu'un élément ne soit pas exécuté sur le `MainActor`, il suffit de le marquer comme `nonisolated`.

Si vous souhaitez qu'un élément spécifique s'exécute sur le `MainActor`, sans marquer toute la classe, alors il suffit de le marquer comme tel en utilisant `@MainActor`.

Exemples :

```swift
final class HomeViewModel {
    @MainActor var images: [UIImage] = []

    @MainActor func updateViews() {
        // Perform UI updates..
    }

    func updateData(completion: @MainActor @escaping () -> ()) {
        Task {
            await someHeavyBackgroundOperation()
            await completion()
        }
    }
}
```

On notera qu'on peut marquer un `block`.

On peut même marquer un protocol :-).

```swift
@MainActor
protocol MyProtocol {
    
}
```

## Utilisation de `MainActor` directement

`MainActor` est aussi fourni avec une méthode pour l'appeler directement.

Exemple :

```swift
Task {
    await someHeavyBackgroundOperation()
    await MainActor.run {
        // Perform UI updates
    }
}
```
 Ceci rappelle (et remplace) le célèbre : `DispatchQueue.main.async { }` :-).

 ```swift
 final class NameStorage {
    private var name: String = ""
    func updateName() {
        Task {
            await MainActor.run {
                name.append("Truc")
            }
        }
    }
}
```

Attention, `MainActor.run{}` capture `self` implicitement (oui, il va falloir s'y habituer...! Moi ça m'énerve déjà mais bon, je suis vieux !).

```swift
await MainActor.run {[weak self] in
    self?.name.append("Truc")
}
```

## `GlobalActor` et thread

```swift
@globalActor
actor MainStorage {
    static let shared = MainStorage()
}

class Fetcher {
    @MainStorage
    func fetch() {
        
    }
}

class FetcherCoordinator {
    func coordinate() {
        let fetcher = Fetcher()
        fetcher.fetch()  // /!\ Call to global actor 'MainStorage'-isolated instance method 'fetch()' in a synchronous nonisolated context
    }
}
```

Le message d'erreur du compilateur `Call to global actor 'MainStorage'-isolated instance method 'fetch()' in a synchronous nonisolated context` est maintenant super intéressant (contrairement à un système de completion block ou de dispatchqueue - que nous aurions pu trouver avec le thread sanitizer mais alors seulement au run).

On ne peut pas appeler `fetcher.fetch()` dans un context synchrone et non isolé.

Une façon de répondre à ceci est de créer une `Task` :

```swift
func coordinate() {
    Task {
        let fetcher = Fetcher()
        await fetcher.fetch()
    }
}
```

ou bien, comme le suggère l'IDE, d'indiquer le forçage vers le `GlobalActor` correct :

```swift
@MainStorage
func coordinate() {
    let fetcher = Fetcher()
    fetcher.fetch()
}
```

Cependant, il existe des possibilités que même en indiquant le forçage vers un `GlobalActor`, celui-ci ne soit pas réel au moment du run.

Exemple :

```swift
class Machine {
    @MainStorage
    func distribute() {
        
    }
}

class Coordinator {
    init() {
        URLSession.shared.dataTask(with: URL(string: "https://jsonplaceholder.typicode.com/todos/1")!) { data, response, error in
            if let data = data {
                if let todos = try? JSONDecoder().decode([Todo].self, from: data) {
                    return
                }
            }
            let machine = Machine()
            machine.distribute()  // /!\ Call to global actor 'MainStorage'-isolated instance method 'distribute()' in a synchronous nonisolated context; this is an error in Swift 6
        }.resume()
    }
}
```

Ce code compile parfaitement. Xcode indique toutefois `Call to global actor 'MainStorage'-isolated instance method 'distribute()' in a synchronous nonisolated context; this is an error in Swift 6`. Attention donc à ces warnings qui vous indiquent que votre code n'est pas thread safe :-). mais ça sera terminé avec Swift 6... !

## MainActor/GlobalActor inference

Il y a 5 règles d'inférence sur un `GlobalActor` :

### Inférence par sous-classes

Si une classe est marquée par un `GlobalActor`, alors ses sous-classes héritent de ce `GlobalActor`.

### Inférence par override

Si une méthode d'une classe est marquée par un `GlobalActor`, alors tout override de cette méthode hérite de ce `GlobalActor`.

### Inférence par propertyWrapper

Si un `propertyWrapper` est marqué par un `GlobalActor`, alors toute utilisation de ce `propertyWrapper` est marqué implicitement avec le `GlobalActor`.

### Inférence par méthode de protocol

Si une méthode d'un `protocol` est marquée par un `GlobalActor`, alors, dans toute implémentation de ce `protocol`, cette méthode sera marqué implicitement avec le `GlobalActor`, sauf si l'implémentation se fait en dehors de la déclaration de conformance (alors il faudra marquée l'implémentation explicitement).

Exemple :

```swift
// A protocol with a single `@MainActor` method.
protocol DataStoring {
    @MainActor func save()
}

// A struct that does not conform to the protocol.
struct DataStore1 { }

// When we make it conform and add save() at the same time, our method is implicitly @MainActor.
extension DataStore1: DataStoring {
    func save() { } // This is automatically @MainActor.
}

// A struct that conforms to the protocol.
struct DataStore2: DataStoring { }

// If we later add the save() method, it will *not* be implicitly @MainActor so we need to mark it as such ourselves.
extension DataStore2 {
    @MainActor func save() { }
}
```

*source : https://www.hackingwithswift.com/quick-start/concurrency/understanding-how-global-actor-inference-works*

### Inférence par protocol

Si un `protocol` est marqué par un `GlobalActor`, alors toute conformance à ce `protocol` est marqué implicitement avec le `GlobalActor` si vous déclarez cette conformance lors de la déclaration de la structure. Si vous la déclarez en dehors (dans une extension par exemple), alors, seules les méthodes seront marquées par ce `GlobalActor`.

Exemple :

```swift
// A protocol marked as @MainActor.
@MainActor protocol DataStoring {
    func save()
}

// A struct that conforms to DataStoring as part of its primary type definition.
struct DataStore1: DataStoring { // This struct is automatically @MainActor.
    func save() { } // This method is automatically @MainActor.
}

// Another struct that conforms to DataStoring as part of its primary type definition.
struct DataStore2: DataStoring { } // This struct is automatically @MainActor.

// The method is provided in an extension, but it's the same as if it were in the primary type definition.
extension DataStore2 {
    func save() { } // This method is automatically @MainActor.
}

// A third struct that does *not* conform to DataStoring in its primary type definition.
struct DataStore3 { } // This struct is not @MainActor.

// The conformance is added as an extension
extension DataStore3: DataStoring {
    func save() { } // This method is automatically @MainActor.
}
```