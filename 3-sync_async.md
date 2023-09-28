# Synchronous et asynchronous

## Synchronous

Par défaut, le code écrit en Swift est synchrone, ce qui signifie qu'il exécute les instructions les unes à la suite des autres.

Exemple : 

```swift
let a = 10
var b = 30
print(a + b) // Prints 40
b = 40
print(a + b) // Prints 50
```

Ce code est du code synchrone. Il s'exécute ligne par ligne. On est donc certain que le second print indiquera 50.

Dans la majeure partie des cas, nous écrivons du code synchrone et nous avons tendance à réfléchir de manière synchrone (en grande partie parce que notre notion du temps est synchrone : nous expérimentons le temps dans sa linéarité et sa continuité - même si cette dernière n'a finalement jamais été prouvée... -. En général, le temps fonctionne comme l'accumulation de grains de manière sérielle - même si je peux paralléliser des tâches, en général, je les lance de manière sérielle et je les pense comme telles par aillers... -).

Lors de l'exécution d'un code synchrone, le thread sur lequel se joue le code est bloqué jusqu'à ce que le code se termine.

## Asynchronous

En développement, il existe de nombreuses situations qui sont dites asynchrones, c'est à dire que des tâches vont s'effectuer sans forcément attendre leur réussite ou leur terminaison et sans forcément respecter un ordre défini.

Par exemple, je peux lancer le téléchargement d'une image en tâche de fond pendant que mon utilisateur regarde une vidéo et que je lui affiche une publicité à côté, tout en changeant un texte aléatoirement pour attirer son attention ailleurs...

Exemple de code asynchrone :

```swift
listPhotos(inGallery: "Summer Vacation") { photoNames in
    let sortedNames = photoNames.sorted()
    let name = sortedNames[0]
    downloadPhoto(named: name) { photo in
        show(photo)
        print("download")
    }
    print("list")
}
```

(code from : https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

Dans ce code, le block `{ photo in show(photo) }` s'effectuera en fonction de la méthode `downloadPhoto(named: name)` et le terme "list" s'affichera (à l'exécution) probablement avant le terme "download", même si le terme "download" apparait avant dans le code".

Lors de l'exécution d'un code asynchrone, le thread sur lequel se joue le code n'est pas bloqué. En l'occurence, dans notre exemple, le thread peut passer le completion block et poursuivre son exécution avec le `print("list")`.

## Thread safety

Le fait qu'un code soit synchrone ou asynchrone ne signifie rien en ce qui concerne le "thread safety".

Thread safety signifie que le code proposé est protégé contre les race conditions.

En pratique, il est très compliqué de savoir si un code est thread safe. Pour se faire, il faut vérifier que le code est exécuté dans une dispatch queue et/ou que les variables avec lesquelles il interagit sont "lockées" (protégées contre les race conditions). A titre d'exemple, le simple fait de lire une variable peut rendre votre code non thread safe !

En général, la présence de dispatch queue (ou de lock) permet de vérifier que le code est thread safe (mais ces dispatch queues peuvent parfois être terriblement bien cachées...)