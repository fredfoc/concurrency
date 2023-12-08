# EcticLoader


## But 

EcticLoader est un projet de test pour s'amuser avec Swift Concurrency.

Dans un premier temps, le projet est présenté tel quel et on constate qu'il y a un problème de freeze de l'interface lorsque l'on tente de lancer un "Big Load".

Nous analyserons ce freeze avec Instruments pour voir ce qui se passe.

Nous répondrons à différentes questions telles que : Pourquoi faut-il utiliser @MainActor sur la class Loader ? Pourquoi les Tasks freeze le main thread ? Comment fixer ce problème.

Dans un second temps, nous optimiserons le code pour qu'il profite du thread Pool, de la notion d'Actor, de Task.detached, de nonisolated, etc.