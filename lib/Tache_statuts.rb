# encoding: UTF-8
 module MyTaches
class Tache

  # @return TRUE si on doit notifier cette tâche
  # 
  # On doit notifier cette tâche quand :
  #   - elle ne possède pas de tâches précédentes non terminées
  #   - son départ s'est fait dans le quart d'heure précédent
  #   - son départ est dans le passé mais elle n'a pas encore été
  #     notifiée
  #   - son départ est dans le passé, elle a été notifiée, mais elle
  #     définit un rappel et ce rappel tombe maintenant.
  # 
  # @define Définit aussi la raison de cette notification, si 
  # nécessaire (p.e. "Rappel" ou "Démarrage" ou "Échéance de fin")
  def notify?
    # 
    # On ne doit pas notifier la tâche si elle a une tâche 
    # précédente (en activité)
    # 
    return false if prev?
    # 
    # On ne doit pas notifier la tâche si elle est dans le futur
    # 
    return false if futur?

    if not(start_notified?)
      if start_just_now?
        @raison_notify      = "échéance début"
        @notif_log_message  = 'NOTIF START'
        set_start_notified
        return true
      elsif start_time && start_time < _NOW_
        @raison_notify      = "départ dépassé"
        @notif_log_message  = 'NOTIF START'
        set_start_notified
        return true
      end
    end
    end_just_now? && not(end_notified?) && begin
      @raison_notify        = "échéance fin"
        @notif_log_message  = 'NOTIF END'
      set_end_notified
      return true
    end
    rappel? && begin
      @raison_notify      = "rappel"
      @notif_log_message  = 'RAPPEL'
      return true
    end

    return false
  end

  def raison_notify
    @raison_notify
  end

  # @return TRUE si le début a été notifié
  def start_notified?
    data[:start_notified] == true
  end

  # @return TRUE si la fin a été notifié
  def end_notified?
    data[:end_notified] == true
  end

  # @return TRUE si la tâche est liée
  def linked?
    prev? || suiv?
  end

  # @return TRUE si la tâche a des tâches parallèles
  def parallel?
    not(parallels.nil?) && parallels.any?
  end

  # @return TRUE si la tâche +tk_id+ (ou la tâche) est
  # parallèle à la tache courante
  def parallel_to?(tk_id)
    return false if not(parallel?)
    tk_id = tk_id.id if tk_id.is_a?(Tache)
    parallels.include?(tk_id)
  end
  
  # @return TRUE si la tâche doit être rappelée
  # 
  def rappel?
    return !!(data[:rappel] && irappel.is_time?(last_rappel))
  end

  def current_quarter_hour?(thetime)
    thetime.between?(now - (7.5 * 60), now + (7.5 * 60))
  end

  # @return TRUE si l'échéance de départ de la tâche se situait dans
  # le quart-d'heure précédent
  def start_just_now?
    start_time && current_quarter_hour?(start_time)
  end

  # @return TRUE si l'échéance de fin se situait dans le dernier
  # quart-d'heure
  def end_just_now?
    end_time && current_quarter_hour?(end_time)
  end

  def today?
    :TRUE == @istoday ||= true_or_false(times? && start_time && start_time.between?(_NOW_.at('0:00'), _NOW_.at('23:59')))
  end

  # Renvoie true si la date ne définit aucun temps et qu'elle n'est
  # liée à aucune autre.
  def lost?
    :TRUE == @isout ||= true_or_false(no_time? && prev?)
  end

  def current?
    :TRUE == @iscurrent ||= true_or_false(check_if_current)
  end

  def out_of_date?
    :TRUE == @isoutofdate ||= true_or_false(check_if_out_of_date)
  end

  def near?(delai = nil)
    if delai.nil?
      :TRUE == @isproche ||= true_or_false(Tache.check_if_proche(self))
    else
      Tache.check_if_proche(self, delai)
    end
  end
  alias :proche? :near?

  def futur?
    :TRUE == @isfuture ||= true_or_false(check_if_futur)
  end

  def far? # très lointaine
    :TRUE == @islointaine ||= true_or_false(Tache.check_if_lointaine(self))
  end
  alias :echeance_lointaine? :far?

  # @return TRUE si c'est une tâche qui n'a pas de temps
  # définis, donc qui dépend d'autres tâches
  def no_time?
    data[:start].nil?
  end

  def times?
    data[:start]
  end

  def suiv?
    not(suiv.nil?)
  end
  alias :suivante? :suiv?

  def prev?
    not(prev.nil?)
  end

  # @return true si la tâche se trouve après la
  # tâche +tk+ (c'est-à-dire après sa fin)
  def after?(tk)
    start_time && tk.end_time && start_time > tk.end_time
  end
  def start_after?(tk)
    start_time && tk.start_time && start_time > tk.start_time
  end
  def before?(tk)
    start_time && tk.start_time && start_time < tk.start_time
  end
  def end_before?(tk)
    end_time && tk.end_time && end_time < tk.end_time
  end

  def unite_mois?
    duree && duree_unite == 's'
  end

  def unite_annee?
    duree && duree_unite == 'y'
  end

  # @return TRUE si la tâche est une tâche de modèle de
  # tâche.
  def in_model?
    not(data[:model_id].nil?)
  end

  def archived?
    self.class == MyTaches::ArchivedTache
  end
  

private


  def check_if_out_of_date
    # Pour qu'une tâche soit dépassée, il faut que son temps de
    # fin soit défini (soit explicitement, soit par d'autres valeurs)
    # et que ce temps de fin soit passé
    # puts "Tâche #{id} : end_time = #{end_time.inspect}"
    end_time && end_time < _NOW_
  end

  def check_if_current
    not(no_time?) && start_time < _NOW_
  end

  # @return true si c'est une future tâche. 
  # Une tâche est future lorsqu'elle :
  #   - possède un temps de début et qu'il est plus tard
  #   - ne possède pas de temps de début
  def check_if_futur
    not(start_time) || (start_time && start_time > _NOW_)
  end

  def self.check_if_lointaine(tk)
    @@demarrage_lointain ||= begin
      delai = Tache.calc_duree_seconds(CONFIGURATION.get(:lointaine_if) || '1s')
      _NOW_ + delai
    end
    tk.times? && tk.start_time && tk.start_time > @@demarrage_lointain
  end

  def self.check_if_proche(tk, delai = nil)
    # 
    # Le délai de proximité. On ne prend pas les tâches
    # qui commence plus loin que ça.
    @@max_time_proximite ||= begin
      Tache.calc_duree_seconds(CONFIGURATION.get(:delai_proche) || '1w')
    end
    max_time = _NOW_ + (delai || @@max_time_proximite)
    not(tk.no_time?) && tk.start_time && tk.start_time.between?(_NOW_, max_time)
  end

end #/Tache
end #/module MyTaches
