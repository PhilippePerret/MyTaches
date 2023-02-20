# encoding: UTF-8
#
# auto-testé
#

module MyTaches
class Tache

####################################################################
#
#   INSTANCE
#
####################################################################

  # En cas d'édition
  attr_accessor :edit_data

  # Si la tâche appartient à un modèle de suite de tâches
  attr_writer :model_id

  attr_reader :data
  def initialize(data)
    @data = data
  end

  def save
    data_valid? || return
    File.open(path,'wb') do |f| f.write data.to_yaml end
    self.edit_data  = nil

    return self # pour chainage
  end

  # Pour marquer que le départ a été notifié
  # 
  # Mais ça ne sera enregistré que si la tâche a bien été notifiée.
  # 
  def set_start_notified
    data[:start_notified] = true
  end

  # Pour marquer que la fin a été notifiée
  # 
  # Mais ça ne sera enregistré que si la tâche a bien été notifiée.
  # 
  def set_end_notified
    data[:end_notified] = true
  end

  def destroy
    File.exist?(path) || raise("La tâche '#{path}' est introuvable…")
    File.delete(path)
    on_destroy
    return !File.exist?(path)
  end

  def on_destroy
    Tache.sup(self)
    on_suppression
  end


  ##
  # Appelée quand on marque la tâche accomplie
  # 
  def on_mark_done
    if parallel?
      # 
      # Cas d'une tâche parallèle : il faut la déparalléliser
      # et on ne modifie pas le :start de la tâche suivante (si elle
      # existe) tant que d'autres tâches parallèles sont en cours (ce
      # qui est forcément le cas si cette tâche est encore parallèle)
      # 
      deparallelize(sauver = true)
    elsif suiv?
      suiv.change_start(_NOW_)
    end
    on_suppression
  end

  def on_suppression
    reset_required = parallel? || prev? || suiv?
    if suiv? && prev?
      prev.link_to(suiv)
      unlink_from(suiv).save
    elsif suiv?
      unlink_from(suiv).save
    elsif prev?
      prev.unlink_from(self).save
    end
    Tache.set_taches_prev if reset_required
  end

  def change_start(new_time)
    new_time_str = new_time.jj_mm_aaaa_hh_mm
    if parallel?
      parallelized_tasks
    else
      [self]
    end.each do |tk| 
      tk.send(:start=, new_time_str)&.save&.reset 
    end
  end

  # --- Helpers ---
  # Cf. le fichier Tache/helpers.rb

  # --- Actions ---

  #
  # Pour notifier de la tâche
  # 
  # La méthode procède aussi à l'enregistrement de la date
  # de dernier rappel
  #
  alias :main_notify :notify
  def notify
    params = {
      title:"TASK #{scate} (#{raison_notify})",
      sender: 'phil.app.MyTaches' # sera changé ci-dessous si :app
    }
    data[:app].nil?  || params.merge!(sender:   data[:app])
    data[:open].nil? || params.merge!(open:     data[:open])
    data[:exec].nil? || params.merge!(execute:  data[:exec])
    data[:cate].nil? || params.merge!(subtitle: data[:cate])
    # 
    # Produire la notification
    # 
    main_notify(todo, params)
    # 
    # Enregistrer la date de dernier rappel
    # 
    data.merge!(last_rappel: Time.now.to_i)
    save
    # 
    # Log de cron
    # 
    if cron?
      Cron.log("#{@notif_log_message} [#{id}] #{todo}")
    end
  end

  # --- States ---
  # Cf. Tache_statuts.rb


  # --- Data volatiles ---

  # @return Instance {MyTaches::Rappel} du rappel éventuel
  def irappel
    @irappel ||= data[:rappel] && Rappel.new(data[:rappel])
  end

  # @return la péremption exprimée en langage humain
  # p.e. '1 heure' ou '2 semaines et 3 jours'
  def f_peremption
    Tache.human_delai(calc_peremption)
  end

  def self.semaines_jours_heures(secs)
    sems = secs / 1.semaine
    rest = secs % 1.semaine
    jrs  = rest / 1.jour
    rest = rest % 1.jour
    hrs  = rest / 1.heure
    
    return {semaines: sems, jours: jrs, heures: hrs}    
  end

  def set_suiv(stache)
    data.merge!(suiv: stache.id)
    return self # pour chainage
  end

  def set_prev(ptache)
    self.prev_id = ptache.id
    return self # pour chainage
  end

  # --- Data ---
  # cf. Tache_data.rb


  # Pour tout recalculer
  def reset
    @id                   = nil
    @path                 = nil
    @prev                 = nil
    @duree                = nil
    @irappel              = nil
    @isout                = nil
    @isfuture             = nil
    @isoutofdate          = nil
    @haslointaineeche     = nil
    @start_time           = nil
    @end_time             = nil
    @parallels            = nil
  end

  private

    # Méthode appelée quand on a changé d'identifiant
    # Il faut détruire l'ancien fichier et redéfinir le path
    # ainsi que modifier dans toutes les données qui utilisent la
    # tâche en tâche suivante ou précédente.
    def self.traite_changement_id(tache, new_id)
      current_prev_id = tache.prev_id.freeze
      current_suiv_id = tache.data[:suiv] ? tache.data[:suiv].freeze : nil
      old_path = tache.path.freeze
      File.delete(old_path) if File.exist?(old_path)
      tache.reset
      tache.data[:id] = new_id
      tache.save # sauver avec le nouveau nom
      if current_prev_id
        current_prev = get(current_prev_id)
        current_prev.data.merge!(suiv: new_id)
        current_prev.save
      end
      CONFIG.debug = false
      set_taches_prev
      return true
    end

    def id_on_the_fly
      'IDTASK'+"#{(data[:start]||data[:end]||data[:duree]||rand(Time.now.to_i))}".gsub(/[^0-9]/,'')
    end


end #/class Tache


ERRORS = {} unless defined?(ERRORS)
ERRORS.merge! conflict_2_links: <<-TEXT
Conflit dans les liaisons.
  Tâche: %{id}
  Précédente : %{prev}
    Suivante de précédente : %{suiv_de_prev}
  Suivante   : %{suiv}
    Précédente de suivante : %{prev_de_suiv}
TEXT

end #/module MyTache
