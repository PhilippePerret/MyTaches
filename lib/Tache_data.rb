# encoding: UTF-8
module MyTaches

class BadDataError < StandardError; end

class Tache

  # @return TRUE si les données sont valides
  # false dans le cas contraire
  # 
  def data_valid?
    # 
    # Chevauchement de temps ?
    #
    if start_time && prev? 
      if prev.start_time && prev.start_time > start_time
        raise BadDataError.new("La tâche '#{todo}' commence avant la tâche précédente '#{prev.todo}'.")
      elsif prev.end_time && prev.end_time > start_time
        raise BadDataError.new("La tâche '#{todo}' commence avant le fin de la tâche précédente '#{prev.todo}'.")
      end
    end

    if end_time && suiv? 
      if suiv.start_time && suiv.start_time < end_time
        raise BadDataError.new("La tâche '#{todo}' termine après le début de la tâche suivante '#{suiv.todo}'…")
      elsif suiv.end_time && suiv.end_time < end_time
        raise BadDataError.new("La tâche '#{todo}' termine après la fin de sa tâche suivante '#{suiv.todo}'…")
      end
    end
  rescue BadDataError => e
    puts e.message.rouge
    return false
  else
    return true
  end

  # --- Data volatiles ---

  def start_time
    @start_time ||= estimate_start_time
  end

  def end_time
    @end_time ||= estimate_end_time
  end

  # L'unité de durée
  def duree_unite
    @duree_unite ||= decompose_duree[:unite]
  end

  # La quantité de l'unité de durée
  def duree_quant
    @duree_quant ||= decompose_duree[:quant]
  end

  # @return la péremption exprimée par raccourci comme
  # '1d' pour 1 jour, '2w' pour '2 semaines', etc.
  def peremption
    formate_delai(calc_peremption)
  end

  def reste
    formate_delai(calc_reste)    
  end

  # --- Data fixes ---

  def id
    @id ||= data[:id] ||= id_on_the_fly
  end
  def id=(value)
    @id = data[:id] = value
  end

  def todo
    data[:todo]
  end

  def categorie
    @categorie ||= data[:cate]
  end
  def categorie=(value)
    @categorie = data[:cate] = value
  end

  def sous_categorie
    data[:scate]
  end
  alias :scate :sous_categorie

  def start
    data[:start]
  end

  def start=(value)
    value = value.jj_mm_aaaa_hh_mm if value.is_a?(Time)
    data[:start] = value
    reset
    return self # chainage
  end

  def duree
    @duree ||= data[:duree]
  end

  def duree=(value)
    @duree = data[:duree] = value
    return self # chainage
  end

  def last_rappel
    data[:last_rappel] && Time.at(data[:last_rappel].to_i)
  end

  def model_id
    data[:model_id]
  end

  def suiv
    if data[:suiv]
      get_tache(data[:suiv])
    elsif parallel?
      parallels.each do |tkid|
        next if tkid == id
        tk = get_tache(tkid)
        if tk.nil?
          puts "[Task ##{id}] Impossible de trouver la tâche parallèle #{tkid.inspect}…".rouge
        else
          if tk.data[:suiv]
            return tk.suiv
          end
        end
      end
      return nil
    end
  rescue Exception => e
    puts "Une erreur est survenue avec #{self} : #{e.message}".rouge
    return nil
  end
  alias :suivante :suiv

  # Méthode qui permet de choisir de façon transparente une tâche
  # de modèle ou une tâche normale (rappel : elles ont des classes
  # différentes, même si la première hérite de la seconde)
  def get_tache(tk_id)
    self.class.get_tache(tk_id)
  end

  def suiv=(value)
    data.merge!(suiv: value)
    @suiv = nil
    return self # chainage
  end

  def prev
    @prev ||= prev_id && get_tache(prev_id)
  end
  def prev=(value)
    @prev = value
  end

  def parallels
    @parallels ||= data[:parallels]
  end

  def prev_id
    @prev_id
  end
  def prev_id=(value)
    @prev_id = value
    @prev = nil
  end

  def detail
    @detail || data[:detail]
  end
  def detail=(value)
    @detail = value
  end

  def open
    data[:open]
  end

  def exec
    data[:exec]
  end

  def app
    data[:app]
  end

  def path
    @path ||= File.join(Tache.taches_folder,"#{id}.yaml")
  end

end #/class Tache
end #/module MyTaches

