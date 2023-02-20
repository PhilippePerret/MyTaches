# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
class Tache
  def self.display_help
    clear
    # puts Tache::AIDE_TEXT
    exec "echo \"#{AIDE_TEXT.gsub(/\"/,'\\"')}\" | less -r"
  end

  def self.open_manuel
    if cli?('--edit')
      open_manuel_md
    else
      if File.stat(manuel_pdf).mtime < File.stat(manuel_md).mtime
        puts "Il faudrait actualiser la version PDF du manuel.".jaune
        if Q.yes?("Dois-je ouvrir le fichier Markdown ?".jaune)
          open_manuel_md
          return
        end
      end
      open_manuel_pdf
    end
  end
  def self.open_manuel_pdf
    `open "#{manuel_pdf}"`
  end
  def self.open_manuel_md
    `open "#{manuel_md}"`
  end

  def self.manuel_pdf
    File.join(folder_manuel,'Manuel.pdf')
  end
  def self.manuel_md
    File.join(folder_manuel,'Manuel.md')
  end
  def self.folder_manuel
    File.join(APP_FOLDER,'Manuel')
  end

  DEL = '*' * 80
  AIDE_TEXT = <<-TEXT
#{"#{DEL}\n*  AIDE RAPIDE DE LA COMMANDE 'task'\n#{DEL}".bleu}

Pour une aide complète, utiliser plutôt le manuel :

#{'task manuel'.underline.jaune}

  Ouvre le manuel PDF.

#{'task'.underline.jaune}

  Sans option, affiche les tâches courantes, donc toutes les tâches
  en cours, même celles périmées.

  On peut ajouter une ou plusieurs des options suivantes pour
  afficher les tâches de différentes manières.

  #{'--current'.jaune}        les tâches courantes (défaut). Elle n'a de
                   sens qu'en combinaison avec d'autres options
  #{'--proche'.jaune}         pour voir seulement les échéances proches
  #{'--today'.jaune}          tâches du jour et seulement du jour
  #{'--out_of_date'.jaune}    tâches périmées (mais en cours)
  #{'--out'.jaune}            tâches sans temps définies
  #{'-proche=<durée>'.jaune}  pour voir les échéances à une durée
                   précise. Cette durée est exprimée en '2d' par
                   exemple.
  #{'--futur'.jaune}          pour voir seulement les tâches futures
  #{'--far'.jaune}            les tâches lointaines
  #{'--cate'.jaune}           pour voir les tâches d'une catégorie en par-
                   ticulier. On peut aussi la définir explicite-
                   ment :
  #{'-cate=La\ caté\ gorie'.jaune} On peut mettre seulement une partie

  #{'--cron'.jaune}           Pour simuler le travail du cron. Si des
                   tâches doivent être notifiées, elles le seront.

  OPTIONS D'AFFICHAGE
  
  #{'--id'.jaune}             pour voir les identifiants
  #{'--linked'.jaune}         mettre en exergue les relations

#{'task list'.underline.jaune}

  Liste les tâches voulues en fonction des options et des filtres.
  Est devenu un alias de 'task' seule.

#{'task add'.underline.jaune}

  Pour ajouter une nouvelle tâche.

#{'task create model'.underline.jaune}

  Pour créer un modèle.

#{'task done[ id=<id>]'.underline.jaune}

  Pour marquer une tâche accomplie. Si l'identifiant n'est pas
  fourni, on choisira la tâche dans la liste affichée.

#{'task mod[ id=<id>]'.underline.jaune}

  Pour modifier les données d'une tâche. Si l'identifiant n'est pas
  fourni, on choisira la tâche dans la liste affichée.

#{'task mod model'.underline.jaune}

  Pour modifier un modèle.

#{'task del[ id=<id>]'.underline.jaune}

  Pour supprimer une tâche de force (*). Si l'identifiant n'est pas
  fourni, on choisira la tâche dans la liste affichée.
  (*) Ici, contrairement à 'done' qui marque la tâche faite mais
  la déplace en archive, la tâche est complètement détruite, il n'en
  restera pas une trace.

#{'task try'.underline.jaune}

  Pour essayer du code rapidement. La jouer une première fois pour
  savoir où mettre le code à essayer.


  TEXT
  AIDE_HTML = <<-HTML
<div id="aide">
  <hr>
  <p><b>AIDE</b></p>
  <p><a target="_blank" href="#{File.join(APP_FOLDER,'Manuel','Manuel.pdf')}">Ouvrir le manuel</a>.</p>
</div>
  HTML


end #/Tache
end #/module MyTaches
