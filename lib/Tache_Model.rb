# encoding: UTF-8
# frozen_string_literal: true

module MyTaches

require_relative 'Model'

class Tache

  ##
  #
  # Méthode principale pour insérer un modèle de suite de tâches
  # dans la todo list
  # 
  # La méthode se sert d'un modèle préalablement défini par 'task
  # create model'
  # 
  # @param  model {MyTache::Model}
  # @param  date_start {Time}
  # @param  dyn_values {Hash} Table des valeurs dynamiques
  # 
  def self.insert_from_model(
    model       = nil,
    suffix      = nil,
    date_start  = nil,
    dyn_values  = nil,
    confirmer   = true
  )

    clear
    model ||= Model.choose("Insérer la suite complète du modèle : ".jaune, enable_cancel: true, enable_new: true) || return
    
    #
    # Valeurs dynamiques à définir
    # 
    if dyn_values.nil? || dyn_values.empty?
      dyn_values = {}
      model.dynamic_values.each do |dim, hvalue|
        value = Q.ask("#{hvalue[:what]} : ".jaune, default: hvalue[:default])
        dyn_values.merge!(dim.to_sym => value)
      end
    end

    # 
    # On duplique les tâches
    # 
    taches = model.taches.dup

    # 
    # Demander la date de démarrage et l'affecter à la première
    # des tâches
    # 
    date_start ||= ask_for_a_date_with_time("Date de démarrage de la suite de tâche")

    #
    # On doit définir les durées variables
    # 
    taches.each do |tache|
      next if tache.data[:duree] != '%'
      puts "La durée de #{tache.todo.inspect} doit être définie.".bleu
      tache.data[:model_id] = nil # pour ne pas avoir le choix "durée variable"
      tache.edit_data = {}
      tache.edit_duree
      tache.data[:duree] = tache.edit_data[:duree]
      tache.reset # pour tache.duree
    end

    #
    # On définit les temps :start de chaque tâche
    # 
    next_time = date_from(date_start)
    taches.each_with_index do |tache, idx|
      tache.data[:start] = next_time.jj_mm_aaaa_hh_mm
      next_time = tache.end_time
    end

    #
    # Montrer ce que ça donne et demander confirmation de
    # la création
    # 
    if confirmer
      clear
      puts "\n\n"
      taches.map.with_index do |tache, idx|
        # puts "tache: #{tache.data.inspect}"
        tache.data[:suiv] = model.taches[idx + 1]&.id
        tache.prev_id     = model.taches[idx - 1].id if idx > 0
        todo = tache.todo % dyn_values
        indent = idx > 0 ? INDENT_OTHER_LINKED_TASK : INDENT_FIRST_LINKED_TASK
        puts "#{indent}#{PICTO_START_TASK}#{tache.f_start_simple} #{todo}"
        puts "#{INDENT_ALINK_LINKED_TASK}"
      end
      puts "#{INDENT_OTHER_LINKED_TASK}#{PICTO_END_TASK}#{taches.last.end_time.jj_mm_aaaa_hh_mm}"

      return if not(Q.yes?("\n\nOK ?".jaune))
    end
    
    #
    # Pour donner un identifiant unique aux tâches, on se
    # sert de la date courante
    # 
    suffix ||= _NOW_.strftime('%Y%m%d%H%M')

    # 
    # Création des tâches
    # (avec affectation d'un nouvel ID)
    # 
    taches.each do |tache|
      # On affecte tous les identifiants
      tache.id = "#{tache.id}-#{suffix}"
    end.each_with_index do |tache, idx|
      # 
      # Régler le todo (template)
      # 
      tache.todo = tache.todo % dyn_values
      # 
      # Régler la tâche suivante
      # 
      if model.taches[idx + 1]
        tache.suiv =  model.taches[idx + 1].id 
      end
      #
      # Créer la tâche
      # 
      ttache = MyTaches::Tache.new(tache.data).save
      MyTaches::Tache.add(ttache)
    end

    MyTaches::Tache.set_taches_prev

  end  


end #/class Tache
end #/module MyTaches
