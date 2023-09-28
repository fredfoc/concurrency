# Async

## Ecriture

```swift
func randomD6() -> Int {
    Int.random(in: 1...6)
}
```

La version async de cette méthode s'écrit :

```swift
func asyncRandomD6() async -> Int {
    Int.random(in: 1...6)
}
```

La seule différence est la présence du `async` dans la signature. Cependant, en ajoutant `async` nous disons que ce code devient asynchrone et ne peut donc plus être utilisé dans du code synchrone. Nous ne disons pas que ce code est forcément asynchrone, mais seulement qu'il pourrait l'être. C'est le systsème qui décidera quoi en faire.

## Usage

```swift
let result = randomD6()
let asyncResult = await asyncRandomD6()
```

La seule différence est la présence du `await`. Que signifie le `await` ?

L'exécution d'une fonction synchrone bloque le thread sur lequel elle est joué (ce qui peut causer des problèmes de performances ou, lorsque nous sommes sur le main thread, provoquer un freeze de l'interface utilisateur). L'exécution d'une fonction asynchrone peut se suspendre afin que d'autres opérations puissent se passer. Le système choisira lui-même ce qu'il est opportun de faire. Avec `await` nous indiquons que potentiellement l'exécution pourra être suspendue, le temps de réaliser les différentes opérations.

> **`await` vient de asynchronous wait :-)**

`await` établit un contrat avec le runtime en lui disant : "je ne bloque pas le thread :-)" aussi transposable en "tu peux me suspendre je peux attendre :-)" (contrairement à Dispatchqueue qui dit : "crée moi un thread pour que je m'exécute et attends ma réponse !"). 

Lorsqu'une fonction est suspendue, elle ne bloque pas le thread sur lequel elle est jouée.

Créer une fonction asynchrone (en utilisant `async`) et l'appeler (en utilisant `await`) ne signifie pas forcément que cette fonction sera suspendue (et donc toujours asynchrone). C'est le système qui décidera !

## Où et comment appeler une fonction async

Une fonction `async` ne peut s'appeler que dans un contexte `async`. On ne peut pas écrire `await` dans une fonction synchrone.

Par exemple :

```swift
func testRandom() -> Int {
    let asyncResult = await asyncRandomD6() // 'async' call in a function that does not support concurrency
}
```

 Pour résoudre ce problème, il existe deux manières simples :
1. rendre la méthode qui appelle `async` (structured concurrency). Exemple : 

```swift
func testRandom() async -> Int {
    await asyncRandomD6()
}
```

1. créer une `Task` (unstructured concurrency). Exemple : 

```swift
func testRandom() {
    Task {
        await asyncRandomD6()
    }
}
```

## Async et throw

La notion `async` est fortement liée à `throw` et idéalement, une fonction `async` devrait aussi renvoyer potentiellement des erreurs, ce qui permet une écriture plus fluide du code.

Exemple :

```swift
struct MyError: Error {}

func returnRandom() async throws -> Int {
    let result = await asyncRandomD6()
    guard result < 3 else {
        throw MyError()
    }
    return result
}

func testRandom() {
    do {
        try await returnRandom()
    } catch {
        print(error)
    }
}
```

Rem. : `async` précède `throws`, mais `try` précède `await`. C'est voulu, entre autre pour éviter le débat sur l'ordre, mais aussi pour "dérouler" le processus dans le bon sens : *async -> throws -> catch error -> await*

## Async et thread

Une tâche asynchrone (écrite avec `async`) interagit avec le thread courant sans que vous ayez besoin d'agir vous-mêmes avec ce thread (c'est construit dans le langage). C'est `Swift` qui va choisir quoi faire avec votre fonction et son exécution. Il se peut qu'elle soit interrompue sur un thread x, puis reprise sur un thread y. Vous n'aurez aucune garantie sur le thread utilisé (sauf pour le main thread avec la notion de `MainActor` mais nous la verrons plus tard ou sur un contexte spécifique renforcé par un `GlobalActor`).

Ceci peut créer des problèmes d'atomicité sur vos données !. Il est donc obligatoire de ne pas utiliser de données liées au thread (elles ne seront pas assurées d'en sortir vivantes), pas de locks par exemple (si vous utilisez un lock sur un thread dans un `await` et que vous atterissez dans un autre thread à la fin du `await`, ce lock sera perdu et le thread du début locké à tout jamais...)

Une tâche `async` est en fait sortie du stack lié au thread (Swift crée une stack par thread) pour être positionnée dans le heap sous forme d'une `continuation`. De cette manière, le stack du thread n'est pas bloqué en attendant la completion de la tâche. Pour qu'une tâche `async` se termine, il faut que toutes ses dépendances se terminent. Lorsqu'une dépendance se termine, elle revient sur le stack du thread qui va alors examiner s'il y a des tâches parentes en attente (des continuations). Si pas, alors elle sera définie comme totalement complète et le code se poursuit. On voit bien qu'il n'y a plus de création de threads multiples mais bien suspension/continuation avec un seul thread en cours.

J'imagine que, dans le futur, nous aurons donc des problèmes de heap corrompu (mais plus d'explosion de thread ou de stack floodé...).

Il est obligatoire de ne pas utiliser les `unsafe primitive` (tels que les semaphore par exemple).

```swift
func update() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await fetchData(30)
        semaphore.signal()
    }
    semaphore.wait()
}
```

Pour éviter que le `Cooperative Thread Pool` ne soit bloqué par de telles choses, vous pouvez ajouter une variable dans votre `scheme` dans la phase de `run` : `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`

![LIBDISPATCH_COOPERATIVE_POOL_STRICT](images/libdispatch.png)

## Async et performance

Les tâches en `async` demandent plus de ressources que les tâches en `sync` ! Et oui, vous gagnez en maintenabilité, en robustesse et en structure, mais vous perdez en allocation mémoire (le heap est plus cher que le stack :-), mais nos devices ont beaucoup de mémoire et peu de coeurs... Un peu comme le capitalisme, ou les dictateurs, ou les dirigeants du CAC40).

Il convient donc de bien évaluer la gestion de performance d'une app quand vous la passez en structured concurrency.
