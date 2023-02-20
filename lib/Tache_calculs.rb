# encoding: UTF-8

module MyTaches
class Tache

  def estimate_start_time
    return date_from(start) if start
    stime = define_start_time_with_previous
    return stime if stime
    stime = define_start_time_with_next
    return stime if stime
    return nil
  end

  def define_start_time_with_previous
    tk = cherche_start_time_in_previous || return
    stime = tk.start_time
    while tk.id != id
      stime = calc_end_time_from(stime, tk.duree || '1d')
      tk = tk.suiv
    end
    return stime
  end

  def cherche_start_time_in_previous
    tk = self
    while tk = tk.prev
      return tk if tk.start
    end
    return nil
  end

  ##
  # On essaie de définir le temps de départ d'après le
  # temps des tâches suivantes.
  # 
  def define_start_time_with_next
    tk = cherche_start_time_in_next || return
    stime = tk.start_time
    while tk && tk.prev
      stime = calc_start_time_from(stime, tk.prev.duree||'1d')
      break if tk.prev.id == id
      tk = tk.prev
    end
    return stime
  end

  def cherche_start_time_in_next
    tk = self
    while tk = tk.suiv
      return tk if tk.start
    end
    return nil
  end

  # @return L'estimation du temps de fin
  # Note : maintenant, la donnée :end n'est plus
  # enregistrée
  def estimate_end_time
    if start_time && duree
      calc_end_time_from(start_time, duree)
    elsif start_time
      calc_end_time_from(start_time, '1d')
    else
      nil
    end
  end

  def calc_end_time_from(stime, duree)
    if unite_mois?
      stime.plus(duree_quant).mois
    elsif unite_annee?
      stime.plus(duree_quant).annees
    else
      stime + Tache.calc_duree_seconds(duree)
    end
  end

  def calc_start_time_from(etime, duree)
    if unite_mois?
      etime.moins(duree_quant).mois
    elsif unite_annee?
      etime.moins(duree_quant).annees
    else
      etime - Tache.calc_duree_seconds(duree)
    end
  end


  def duree_seconds
    @duree_seconds ||= begin
      if duree && not(unite_mois? || unite_annee?)
        Tache.calc_duree_seconds(duree)
      elsif start_time && duree
        if unite_mois?
          start_time.plus(duree_quant).mois
        elsif unite_annee?
          start_time.plus(duree_quant).annees
        end.to_i - start_time.to_i
      elsif duree
        nil
      else
        24 * 3600 # Dans tous les autres cas : 1 jour
      end
    end
  end
  alias :duree_secondes :duree_seconds

  # Essayer une méthode sans erreur pour trouver le start
  # d'une tâche
  def remonter_chaine_start
    begin
      tk = tk.prev? && tk.prev
      if tk.end_time
      end
    end while tk
  end


  # Calcul et retourne la date de péremption de la tâche en
  # semaines, jours et heures
  def calc_peremption
    unless not(out_of_date?)
      Tache.semaines_jours_heures((_NOW_ - end_time).to_i)
    end
  end

  def calc_reste
    if out_of_date?
      {semaines:0, jours:0, heures:0}
    else
      Tache.semaines_jours_heures(reste_secondes)
    end
  end

  def reste_secondes
    (end_time - _NOW_).to_i
  end
  alias :reste_seconds :reste_secondes


  # Décompose unité de durée et quantité
  def decompose_duree
    hduree = Tache.decompose_duree(duree)
    @duree_unite = hduree[:unite]
    @duree_quant = hduree[:quant]

    return hduree
  end

  def self.decompose_duree(value)
    dur = value.split('')
    unite = dur.pop
    quant = dur.join('').to_i
    return {quant:quant, unite:unite}
  end

  def self.calc_duree_seconds(value)
    hduree = decompose_duree(value)
    unite = hduree[:unite]
    quant = hduree[:quant]
    case unite
    when 'w' then quant * 7.jours
    when 'd' then quant.jours
    when 'h' then quant.heures
    when 'm' then quant.minutes
    when 's' then quant * 30.jours
    when 'y' then quant.annees
    else raise "Unité inconnue : #{unite}"
    end    
  end


end# /Tache
end#/module MyTaches
