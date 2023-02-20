# encoding: UTF-8
# frozen_string_literal: true



# Classe pour la liste des tâches, héritée de Array
class TaskArray < Array

  ##
  # @return la liste classée en fonction des paramètres ci-dessous
  # 
  # @param  params {Hash}
  #         :key    La clé de classement (:todo, :start, :end)
  #         :dir    La direction : :asc (défaut) ou :desc
  #         :alt_key  {Symbol} La clé alternative de classement (appliquée
  #                   avant :key)
  #         :alt_dir  {Symbol} Direction pour la clé alternative
  #         ---
  #         :force_all  {Boolean} Si true, on prend vraiment toutes
  #                     les tâches en compte, même si elles ne possèdent
  #                     pas l'information requise.
  # 
  def sorted(params = nil)
    #
    # Étude des paramètres
    # 
    params ||= {key: :start, dir: :asc}
    params.key?(:key) || params.merge!(key: :start)
    params.key?(:dir) || params.merge!(dir: :asc)

    ascendant = not(params[:dir] == :desc)
    force_all = params[:force_all] == true
    
    params[:key] != :cate || raise("On ne peut pas classer par la catégorie. Utiliser 'Tache.all.group_by(&:categorie)'.")

    # 
    # La liste qui sera renvoyée
    # 
    ary = self
    # 
    # La liste des tâches exclues
    # (seront jointes si force_all)
    #
    ary_force_all = []

    # 
    # Exclusion en fonction de la clé de classement
    # (note : si :force_all est activé, la liste des
    #  exclusion sera adjointe à la fin de la liste)
    case params[:key]
    when :start
      ary = ary.reject do |tk| 
        not_ok = tk.start_time.nil?
        not_ok && ary_force_all.push(tk)
        not_ok
      end
      sortproc = ->(tk){ tk.start_time }
    when :end
      ary = ary.reject do |tk| 
        not_ok = tk.end_time.nil?
        not_ok && ary_force_all.push(tk)
        not_ok
      end
    end

    # 
    # Procédure de classement à utiliser
    # 
    def_value =
      case params[:key]
      when :start, :end
        _NOW_ + (ascendant ? - 600.jours : 600.jours)
      else nil
      end
    sortproc = get_proc_per_key_sort(params[:key], def_value)

    # Procédure de classement alternatif à utiliser
    # 
    if params[:alt_key]
      alt_ascendant = not(params[:alt_dir]==:desc)
      def_value =
        case params[:alt_key]
        when :start, :end 
          _NOW_ + (alt_ascendant ? - 600.jours : 600.jours )
        else nil
        end
      alt_sortproc = get_proc_per_key_sort(params[:alt_key], def_value)
    end

    ary = 
      if params[:alt_key]
        # 
        # Classement à double clé
        # 
        ary.sort_by do |tk|
          alt_sortproc.call(tk)
        end.each do |tk|
          puts "Alt #{tk.id}"
        end.sort_by do |tk|
          sortproc.call(tk)
        end
      else
        # 
        # Classement simple normal
        # 
        ary.sort_by do |tk|
          sortproc.call(tk)
        end
      end      

    if ascendant
      ary
    else
      ary.reverse
    end + (force_all ? ary_force_all : [])
  end

  ##
  # @return {Hash} La liste des tâches classées par catégorie
  #         C'est une table avec en clé la catégorie et
  #         et valeur la liste des tâches, classées par
  #         ordre croissant (du passé vers le futur)
  # 
  # @param params {Hash} Paramètres
  #         :all    Si TRUE (défaut), on renvoie toutes les tâches. Sinon
  #                 on ne retourne que celle qui ont un temps
  #         :key    La clé de classement. :start par défaut.
  # 
  def per_categorie(params = nil)
    params ||= {}
    params.key?(:key) || params.merge!(key: :start)
    params.merge!(force_all: params.key?(:all) ? params[:all] : true)
    MyTaches::Tache.all.sorted(params)
            .group_by(&:categorie)
            .sort_by{|cate_id,tks| cate_id}
            .to_h
  end


private

  def get_proc_per_key_sort(key, def_value = nil)
    case key
    when :todo
      return ->(tk){ tk.todo }
    when :start
      return ->(tk){
        tk.start_time || def_value
      }
    when :end
      return ->(tk){
        tk.end_time || def_value
      }
    end

    return nil
  end

end
