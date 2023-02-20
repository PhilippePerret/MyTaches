# MyTaches<br />Manuel développeur

## Débuggage

Pour débugger facilement une portion du programme, mettre :

~~~ruby

CONFIG.debug = true

~~~

Après cette indication, tous les 'puts' seront envoyés vers le fichier `./output` de l'application.

Si on veut garder ces puts, on peut utiliser la formule :

~~~ruby

debug? && puts("Je suis le message dans ./output")

~~~

> Noter qu'il ne faut pas mettre de couleur si on ne veut pas être embêté par des codes durs à lire.

Pour terminer à un endroit précis le débuggage :

~~~ruby

CONFIG.debug = false

~~~

## Les rappels

Les rappels permettent de définir quand il faut rappeler une tâche à faire.

Ils sont définis par une ligne du type :

~~~ruby
<x><unite>::[<indice jour ou jour> ]<heure>:<minute>
~~~

Par exemple :

~~~ruby
3d::11:30
# => Rappel tous les 3 jours à 11:30
~~~

Fonctionnement général du test du rappel

> Note : le rappel est une instance de class `MyTaches::Rappel`.

~~~
* Au premier fonctionnement, le :last_rappel de la tâche 
  n'est pas défini, c'est un traitement spécial qui est
  appliqué :
  - on calcule le temps du prochain rappel. 
    Note : même s'il est passé, on le retourne, ce qui provo-
    quera toujours une première notification.
* La tâche est notifiée si son :next_time est inférieur au
  temps courant.
    if next_time < _NOW_ => rappel? est true => notifier
* En enregistre le temps de dernière notification (_NOW_) dans
  la donnée de la tâche, en secondes (:last_rappel)
* Au prochain check, deux comportements sont 
* Au prochain check, on calcule le next-time en fonction du
  last-time enregistré.
  Ce next-time est égal à :
    last-time + nombre-unités x valeur-secondes-unité
    Et on prend ensuite le bon moment en fonction des autres
    information :
    - si c'est une jour, on prendre l'heure
    - si c'est une semaine, on prend l'indice du jour-semaine
      et l'heure
    - si c'est un mois, on prend l'indice du jour-mois et
      l'heure
    - etc.
~~~

## Liasons entre tâches

Les liaisons entre tâches sont très importantes pour gérer souplement les échéances. Ces liaisons sont gérées avec la propriété :suiv (et uniquement celle-là, même si la propriété volatile :prev_id est utilisée).

Noter qu'à chaque modification de liaison la méthode `Tache::set_taches_prev` doit être invoquée pour régler la propriété volatile `@prev_id`.


## Méthodes de classement et de tri

La méthode `Tache::all` permet d'obtenir pratiquement toutes les tâches que l'on veut grâce à son filtre puissant à ajouter en paramètre.

Combinée à la méthode `sorted`, on peut obtenir une liste filtrée et triée.

~~~ruby
Tache::all(filtre).sorted(params)
# => Liste de tâches filtrées et triées
~~~

~~~ruby

Tache.all
# => Retourne toutes les tâches, sans distinction
#    Noter que la liste retournée est une extension de la class Array

Tache.all(start_after: <time>)
# => Tous les tâches qui commencent après le temps donné
#    Même chose avec :start_before, end_before, end_after

Tache.all(categorie: <catégorie)
# => Toutes les tâches de cette catégorie

Tache.all(categorie: /masque/)
# => Toutes les tâches dont la catégorie correspond au masque

Tache.all(todo: /filtre/)
# => Toutes les tâches dont le todo répond au masque

Tache.all(current: true)
# => Toutes les tâches courantes
#     Idem pour :
#       :no_time      Les tâches sans temps défini
#       :out_of_date  Les tâches périmées
#       :futur        Les futures tâches

Tache.all(duree_min: <string durée>)
# => Toutes les tâches ayant au moins cette durée
#    Idem pour :duree_max
# Note : la durée doit être exprimée par '2d', '4s' etc.

Tache.all(linked: true)
# => Toutes les tâches liées
#    Ou déliées si linked: false

~~~

## Estimation des temps

Simplifications :

- maintenant, :end n'existe plus
- les valeurs sont calculées dès leur modification (pas encore sûr de l'adopter définitivement)

## Tâches parallèles

Les tâches parallèles permettent de jouer plusieurs tâches en même temps.

Cette notion n'est pertinente que lorsqu'on a une suite de tâches à exécuter. Par exemple, on a la suite :

~~~
  tâche 1
  tâche 2
  tâche 3
~~~

Toutes ces tâches sont liées par un :suiv et ne définissent que leur durée. "tâche 1" définit son temps de départ. On a par exemple :

~~~

  tâche 1 (4 jours) - start : 26 mai à 10:00
  tâche 2 (3 jours)
  tâche 3 (9 jours)

~~~

Une tâche parallèle "tâche 4" peut être mise en parallèle de la tâche 2 :

~~~

  tâche 1 (4 jours) - start : 26 mai à 10:00
  tâche 2 (3 jours) // tâche 4 (6 jours)
  tâche 3 (9 jours)

~~~

Hormis le fait que ces deux tâches 2 et 4 sont lancées en même temps, dès la fin de la tâche 1, la tâche 3 ne sera lancée que lorsque les deux tâches seront achevées, même si la tâche 2 est plus longue que prévu.

