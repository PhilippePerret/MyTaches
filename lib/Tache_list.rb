# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
class Tache
class << self

    # = main =
    # 
    # Affichage d'une liste de tâches
    # 
    # WARNING: ce n'est pas la méthode qui est appelée quand on fait
    # seulement 'task', mais la méthode invoquée au 'task list'
    # Pour la méthode répondant simplement au 'task', cf. 
    # Tache::etat_des_lieux dans le fichier Tache_class.rb
    # 
    def display_list(filtre = nil)
      # 
      # Préparer le filtre
      # 
      unless filtre.nil?
        filtre[:from] = Time.at(filtre[:from]) if filtre[:from].is_a?(Integer)
        filtre[:to]   = Time.at(filtre[:to])   if filtre[:to].is_a?(Integer)
      end

      filtre ||= {} # pour simplifier

      clear
      tb = nil
      show_current  = cli?('--current')
      show_outs     = cli?('--out')
      show_futur    = cli?('--futur')
      show_linked   = cli?('--linked')
      show_all = filtre.empty? && !(show_current||show_outs||show_futur||show_linked)

      # 
      # Affichage spécial des tâches liées
      # 
      return display_linked if show_linked

      params = {}
      params.merge!(start_after:  filtre[:from]) if filtre[:from]
      params.merge!(end_before:   filtre[:to]) if filtre[:to]
      
      lst = all(params).select do |tache|
        show_all || (show_current && tache.current?) || (show_futur && tache.futur?) || (show_outs && tache.out?)
      end
      if lst.empty?
        puts "Aucune tâche de ce type n'est à afficher.".orange
        return
      end

      # 
      # La table pour afficher toutes les tâches
      # 
      tb = CLITable.new(
        header: ['Tâche', "COMMENCER LE", "TERMINER\nAVANT LE", 'DURÉE', 'ID'],
        header_color: :bleu,
        max_lenghts: {1 => 50},
        gutter: 3
      )
      lst.group_by do |tache|
        tache.categorie
      end.each do |groupe, taches|
        tb << ['']
        tb << [(groupe||'Divers').upcase, nil]
        taches.each do |tache|
          tb << ["  #{tache.todo}", formate_date(tache.start_time), formate_date(tache.end_time), tache.duree, tache.id]
        end
      end
      tb << ['']
      tb.display
      puts "\n\n"
      MyTaches.memorise_commande_liste
    end


    ##
    # Affichage des tâches liées
    # 
    def display_linked
      clear
      lines = []
      lines << "\n\nAffichage des tâches liées".upcase.underline.bleu

      lst = {} # pour éviter les doublons
      all.select do |tache|
        tache.suiv || tache.prev
      end.each do |tache|
        # puts "TRAITE #{tache.id} / #{tache.prev && tache.prev.id} / #{tache.suiv && tache.suiv.id}"
        if tache.prev
          tache.prev.set_suiv(tache)
          lst.merge!(tache.prev.id => tache.prev)
        end
        if tache.suiv
          tache.suiv.set_prev(tache)
          lst.merge!(tache.suiv.id => tache.suiv)
        end
        lst.merge!(tache.id => tache)
      end

      # 
      # Options pour l'affichage de la tâche
      # 
      no_id = not(cli?('--id'))
      
      # 
      # On ne prend que les premières tâches de suites
      # 
      lst.values.select do |tache|
        tache.prev.nil?
      end.map do |tache|
        lines << tache.lines_linked_task(no_id: no_id)
      end

      less(lines.join("\n").strip)
    end

end #/<< self
end #/class Tache
end #/module MyTaches
