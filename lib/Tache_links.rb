# encoding: UTF-8
module MyTaches
class Tache

  ##
  # QUATRIÈME nouvelle méthode pour gérer les liaisons
  # 
  # Cette nouvelle version s'appuie sur une table @edit_data qui 
  # ne contient QUE les données modifiées. Même si on a édité la
  # donnée, si on lui a donné la même valeur, sa clé a été retirée
  # de edit_data
  # 
  # Lire le manuel développeur pour des indications sur les liaisons.
  # 
  def traite_links

    debugit = debug? || verbose?

    debugit && puts("--> traite_links — Je traite les liaisons…")

    ed = {}
    ed.merge!(prev: edit_data[:prev]) if edit_data.key?(:prev)
    ed.merge!(suiv: edit_data[:suiv]) if edit_data.key?(:suiv)
    debugit && puts("ed : #{ed.inspect}")
    # sleep 3

    # 
    # Rien à faire si les liens n'ont pas été modifiés
    # 
    return if ed.count == 0

    # 
    # ANALYSE DE LA TÂCHE SUIVANTE
    # 
    if ed.key?(:suiv)
      
      # => La tâche suivante doit être retirée ou changée

      # 
      # Dans touts les cas, nil ou définie, la suiv actuelle
      # doit être supprimée si elle est définie
      # Rappel : la nouvelle liaison :suiv ne peut pas être celle
      # définie actuellement, même si l'utilisateur l'a choisie 
      # par erreur
    
      unlink_suiv = suiv?.dup.freeze

      # La tâche précédente doit être définie si elle
      # est définie dans les nouvelles données

      relink_suiv = not(ed[:suiv].nil?)

    else
      unlink_suiv = false
      relink_suiv = false
    end

    # 
    # ANALYSE DE LA TÂCHE PRÉCÉDENTE
    # 
    if ed.key?(:prev)

      # => La tâche précédente doit être retirée ou changée

      # 
      # Dans tous les cas, nil ou définie, la prev actuelle
      # doit être supprimée si elle est définie
      # Rappel : la nouvelle prev ne peut pas être celle
      # actuelle, même si l'utilisateur l'a choisie par 
      # erreur

      unlink_prev = prev?.dup.freeze

      # La tâche précédente doit être définie si elle
      # est définie dans les nouvelles données

      relink_prev = not(ed[:prev].nil?)

    else

      unlink_prev = false
      relink_prev = false

    end

    if unlink_prev && unlink_suiv

      # <= Il faut retirer la tâche de son lien entre
      #    la précédente et la suivante
      # => Il faut recoller précédente et suivante

      prev.link_to(suiv).save
      self.prev_id = nil
      debug? && puts("=> prev_id de #{self.id} mis à nil")
      unlink_from(suiv)

    elsif unlink_prev

      # <= Il faut seulement retirer le lien avec précédente
      # => On supprime le :suiv de la précédente

      prev.unlink_from(self).save
      prev.link_to(suiv).save if suiv?
      self.prev_id = nil
      debug? && puts("=> prev_id de #{self.id} mis à nil")

    elsif unlink_suiv

      # <= Il faut supprimer la liaison avec la suivante
      # => On supprime le :suiv de la tâche courante

      unlink_from(suiv)

    end

    # 
    # Liaisons à créer
    # 

    # link_to(ed[:suiv]) if relink_suiv

    if relink_prev
      tache_prev = Tache.get(ed[:prev])
      if tache_prev.suiv?
        ed.merge!(suiv: tache_prev.suiv.id)
      end
    end

    if relink_suiv
      tache_suiv = Tache.get(ed[:suiv])
      if tache_suiv.prev?
        ed.merge!(prev: tache_suiv.prev_id)
      end
    end

    debug? && puts("ed avant redéfinitions : #{ed.inspect}")

    # 
    # Redéfinitions
    # 
    relink_prev = not(ed[:prev].nil?)
    relink_suiv = not(ed[:suiv].nil?)

    Tache.get(ed[:prev]).link_to(self).save if relink_prev
    link_to(ed[:suiv]) if relink_suiv

    debugit && puts("<-- traite_links")

    return true
  end


  ##
  # Méthode pour lier deux tâches (la tâche courante à la tâche
  # +tache+). La tâche +tache+ sera la +where+ (:prev ou :suiv) de
  # la tâche courante
  # 
  # Notes
  # -----
  #   * Deux cas peuvent survenir :
  #     1) +tache+ avait déjà une tâche précédente => il faut INSÉRER
  #        la tâche courante entre les deux.
  #        Ce cas est appelé une INSERTION
  #     2) +tache+ n'avait pas de tâche précédente => rien d'autre
  #        n'est à faire. 
  # 
  def link_to(tache)
    tache = Tache.get(tache) if tache.is_a?(String)
    debug? && begin
      puts("=> Tache[#{id}][:suiv] mise à #{tache.id} (#{id} -> #{tache.id})")
    end
    # Si c'est une tâche parallèle à la tâche courante, c'est 
    # une impossibilité
    if parallel? && parallels.include?(tache.id)
      raise "Une tâche ne peut pas suivre une tâche parallèle."
    end
    # Si la tâche est la tâche précédente
    if prev_id == tache.id
      # Pour éviter la boucle infinie
      tache.data[:suiv] = nil
      tache.reset
      prev_id = nil
      reset
    end
    data.merge!(suiv: tache.id)
    return self # chainage
  end

  ##
  # Méthode pour délier la tâche courante de la tâche +tache+ (qui
  # peut être un identifiant) liée par :suiv
  # 
  def unlink_from(tache)
    tache = get_tache(tache) if tache.is_a?(String)
    debug? && puts("Déliaison de #{self.id} <-> #{tache.id}")
    data.merge!(suiv: nil)
    reset
    tache.reset
    return self # chainage
  end

  ##
  # Méthode qui supprime tout lien avec d'autres tâches
  # Ces liens peuvent être : 
  #   - liées en tant que tâche suivante/précédante
  #   - tâches parallèles
  def desolidarise
    deparallelize if parallel?
    unlink_from(suiv).save if suiv?
    prev.unlink_from(self).save if prev?
  end

end #/class Tache
end #/module MyTaches
