# Sendable et Nonisolated access

## Sendable

Maintenant que nous avons vu comment fonctionnent les `Actor` et comment ils résolvent tous nos problèmes de concurrency (oui tous !).

Si on y réfléchit bien, se pose le problème de comment diable peut-on donc faire sortir une valeur d'un `Actor` si il est totalement protégé. Comment leak-t-il donc puisqu'il faut bien qu'il leake pour qu'on puisse y lire quelque chose ?

C'est ici qu'entre en jeu le protocol `Sendable`.

`Sendable` est un protocol vide :

```swift
public protocol Sendable { }
```

Il indique les type de structure qui peuvent quitter un `Actor` sans problème. Il n'a pas besoin d'implémentation et seuls quelques éléments peuvent l'utiliser :

- `Actors` (par défaut)
- Value types (`Int` par exemple)
- `final classes` qui n'ont pas de propriété mutable (que des let...)
- `Functions` et `closures` (en les marquant avec `@Sendable`)

Certains éléments de code s'y conforment implicitement et parfois il faudra être explicite :

Exemples :

```swift
// Implicitly conforms to Sendable
struct Article {
    var views: Int
}

// Does not implicitly conform to Sendable
class Article {
    var views: Int
}
```

```swift
// No implicit conformance to Sendable because Value does not conform to Sendable
struct Container<Value> {
    var child: Value
}

// Container implicitly conforms to Sendable as all its public properties do so too.
struct Container<Value: Sendable> {
    var child: Value
}
```

```swift
/// User is immutable and therefore thread-safe, so can conform to Sendable
final class User: Sendable {
    let name: String

    init(name: String) { self.name = name }
}
```

*source : https://www.avanderlee.com/swift/sendable-protocol-closures/*

La conformance doit aussi se faire dans le même fichier afin que le compilateur puisse vérifier ! (oui, il est paresseux... Enfin moi je trouve... Je me demande d'ailleurs pourquoi. On aurait pu parcourir l'AST et renforcer la conformance mais bon, j'imagine qu'il y a de bonnes raisons :-))

### @unchecked

Vous pouvez rendre une `class` coonforme à `Sendable` si vous pensez qu'elle l'est et que le compilateur n'a pas besoin de la checker (vous êtes plus smart que lui et certain.e de votre code).

Exemple :
```swift
extension DispatchQueue {
    static let userMutatingLock = DispatchQueue(label: "person.lock.queue")
}

final class MutableUser: @unchecked Sendable {
    private var name: String = ""

    func updateName(_ name: String) {
        DispatchQueue.userMutatingLock.sync {
            self.name = name
        }
    }
}
```
*source : https://www.avanderlee.com/swift/sendable-protocol-closures/*

Evidemment, ce genre de code en PR doit être revu avec beaucoup de calme et de précision (et si j'étais vous je poserai des tas de questions à la personne qui a écrit ça...).

Vous pouvez aussi utiliser `@unchecked` dans le cadre d'une `class` non final ou si vous utilisez un `struct` avec des attributs `internal` dans un package et que vous voulez le rendre `Sendable`.

Exemple de struct :
```swift
//inside TestPackage
public struct Article {
    internal var title: String // the title is internal and not visible outside the module
}

//Inside your app
import TestPackage

extension Article: Sendable { } // /!\ Conformance to 'Sendable' must occur in the same source file as struct 'Article'; use '@unchecked Sendable' for retroactive conformance

``` 

Pour fixer ça on met :

```swift
import TestPackage

extension Article: @unchecked Sendable { }
```

Exemple de non final class :

```swift
class User: @unchecked Sendable {
    let name: String

    init(name: String) { self.name = name }
}
```
*source : https://www.avanderlee.com/swift/sendable-protocol-closures/*

## Nonisolated access

Par défaut, tout élément d'un `Actor` est isolated (sauf s'il est non mutable comme la variable `name` ci-après).

```swift
actor DocumentStorage {
    let name: String
    private var documents = [Document.ID: Document]()
    func store(_ document: Document) {
        documents[document.id] = document
    }
}
```

Cependant, il est possible d'indiquer au compilateur que pour certaines méthodes, nous savons qu'elles sont sans danger et qu'elles ne nécessitent pas d'être protégées (isolées). Exemple :

```swift
func printName() {
    print("name")
}
```

Le simple fait d'écrire cette méthode dans un `actor` nécessitera ceci : `await storage.printName()`.

Cependant, on peut indiquer que la méthode est "non isolée" :

```swift
nonisolated func printName() {
    print("name")
}
```

et qu'elle peut être utilisée comme suis : `storage.printName()`.

Dans le pire des cas, le compilateur vous indiquera que vous ne pouvez pas utiliser un élément dans un contexte `sync` s'il est isolé dans un `actor` !

Ne peuvent être marqué comme `nonisolated` que des types qui sont `Sendable` !