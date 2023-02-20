# Manuel pour les tests de MyTaches


## Écrire un message en console

Que ce soit à l'intérieur des tests ou dans le programme lui-même, on utilise la méthode `ecrit` pour écrire un retour en console.

Cela tient au fait que le `puts` est détourné, en mode test, pour obtenir le texte qui sera écrit dans la sortie standard. Avec par exemple, dans les tests :

~~~ruby

result = MyTaches.run

~~~

`result` ci-dessus contient tout le texte qui a été envoyé en console.


## Utilisation des tâches

On crée une tâche avec : 

~~~

tk = tache(<data>).save

~~~

La sauvegarder permet de l'utiliser en étant préparée, notamment quand il y a des `:suiv` (tâches liées) et qu'on n'a pas envie d'utiliser `MyTaches::Tache.set_taches_prev` dans la méthode de test. On fait alors :

~~~ruby

tache(id:'tk1', ...).save
tache(id:'tk2', ..., suiv:'tk3').save
tache(id:'tk3', ...).save

MyTaches::Tache.init
tk1 = get_tache('tk1')
tk2 = get_tache('tk2')
tk3 = get_tache('tk3')

# ... tests ...
~~~
