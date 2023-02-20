# MyTaches

Application pour gérer les tâches à afficher en notifications

## Principe

Le principe est surtout de gérer les tâches avec trois définitions possibles du temps :

* une date de début,
* une durée de tâche,
* une date de fin

Chacune de ces valeurs est optionnelle. Si une tâche indépendante (i.e. non liée à une tâche précédente) définit la valeur 'date de fin' seulement, ça signifie que la tâche doit être achevée pour cette date. Si une tâche indépendante ne définit que la valeur 'date de début' seulement, ça signifie que la tâche doit être commencée à ce moment-là. Si elle définit aussi une durée, cela définit automatiquement la date où la tâche doit être finie.

Ce programme ne doit faire que signaler les tâches à commencer et les tâches à terminer, avec un système de rappel.

Il peut aussi afficher les tâches en cours (fichier HTML sur le bureau). Ces tâches en cours reprennent les tâches précédentes non exécutées.

Le grand avantage de MyTaches est surtout de pouvoir déclencher n'importe quel code à partir d'une tâche.
