# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class MyTaches::Modele
  ----------------------
  Gestion des modèles de tâches
  Un "modèle de tâche" est une suite type de tâche

  Un modèle se définit par des tâches dont les propriétés peuvent
  être 1) figées (on ne peut pas les modifier à l'insertion du
  modèle) 2) dynamique (certaines valeurs sont réglées en fonction
  de valeurs locales) 3) éditables (on doit les définir à 
  l'insertion). C'est chaque modèle qui définit la nature de chaque
  propriété.
    [
      {
        id: { value: '%{id}-%{index}', type: DYNAMIQUE},
        todo: {
          value:"Première tâche du modèle",
          type: FIXED
        }, 
        duree: {value: '3d', type: MODIFIABLE},
        categorie: {value:'%{categorie}', default:'%{categorie}', type:DYNAMIQUE},
        open: {value:<>, type:FIXED},
        exec: {value:<>, type:FIXED},
        app:  {value:<>, type:FIXED}
      }
    ]
  

=end
module MyTaches
class Model

require_relative 'Model_Tache'

#####################################################################
#
#   CLASS
#
#####################################################################

  def self.get(model_id)
    all.each do |model|
      return model if model.id == model_id
    end

    return nil
  end

  ##
  # Appelée par la commande 'task model'
  # 
  def self.run
    clear
    method = Q.select("Que veux-tu faire avec les modèles ?") do |q|
      q.choice 'Créer un nouveau modèle', :create
      q.choice 'Détruire un modèle', :destroy, {disabled: (count > 0 ? nil : '(aucun modèle)')}
      q.choice 'Modifier un modèle', :modify,  {disabled: (count > 0 ? nil : '(aucun modèle)')}
      q.choice 'Renoncer', nil
    end || return
    send(method)
  rescue TTY::Reader::InputInterrupt
    clear
    puts "\nOpération abandonnée.".orange
    raise ExitWithoutError
  end

  ##
  # Pour choisir un modèle de tâches
  # 
  # @param   params {Hash}
  #     :enable_cancel    Menu 'Renoncer'
  #     :enable_new       Menu pour créer un nouveau modèle
  # 
  def self.choose(question = nil, params = nil)
    params ||= {}
    begin
      menus_models = all_for_tty(params) 
      if menus_models.count == 0
        clear
        puts "Aucun modèle de suite de tâches trouvé…\n\n".orange
        return nil
      end
      model = Q.select("#{question||'Modèle'} :".jaune) do |q|
        q.choices menus_models
        q.per_page  menus_models.count
      end
      return if model.nil?
      if model == :new
        model = edit(Model.new)
      end

      return model
    rescue TTY::Reader::InputInterrupt
      clear
      puts "\nOpération abandonnée.".orange
      raise ExitWithoutError
    end
  end

  ##
  # Pour pouvoir choisir la tâche d'un modèle (surtout lorsqu'il 
  # n'est pas encore enregistré)
  # 
  # Retourne la tâche ou nil
  # 
  def self.choose_task_of_model(model_id, question = nil, params = nil)
    # 
    # On prend toutes les tâches de ce modèle
    # 
    tty_tasks = 
      Dir["#{taches_folder}/*.yaml"].map do |pth|
        dtache = YAML.load_file(pth)
        next if dtache[:model_id] != model_id
        dtache
      end.compact.map do |dtache|
        {name: dtache[:todo], value: dtache[:id]}
      end
    #
    # On peut renoncer
    # 
    tty_tasks << {name:'Aucune', value: nil}
    #
    # On demande d'en choisir une
    # 
    tk_id = Q.select("#{question||'Choisir la tâche'} :".jaune) do |q|
      q.choices tty_tasks
      q.per_page tty_tasks.count
    end
    if tk_id.nil?
      nil
    else
      Model::Tache.get(tk_id)
    end
  end

  ##
  # Pour la création d'un modèle
  #
  def self.create
    edit(new)
  end

  ##
  # Pour afficher le modèle
  # 
  def self.show(model)
    model ||= choose("Modèle à afficher") || return
    model.show
  end
  class << self
    alias :display :show
  end

  ##
  # Pour la destruction d'un modèle
  # 
  def self.destroy(model = nil)
    model ||= choose("Modèle à détruire") || return
    clear
    if Q.yes?("Êtes-vous certain de vouloir détruire le modèle « #{model.name} » (et toutes ses tâches) ?".jaune)
      if model.destroy
        puts "Modèle (et ses tâches) détruit avec succès.".vert
      end
    else
      puts "Abandon de la procédure de destruction.".bleu
    end
  end

  ##
  # Pour la modification d'un modèle
  # 
  def self.modify
    model = choose("Modèle à modifier") || return
    edit(model)    
  end

  ##
  # Pour l'édition d'un modèle
  # 
  # @return {Model} Le modèle édité
  # 
  def self.edit(model)
    model || return
    clear
    # 
    # Pour savoir si c'est un nouveau modèle
    # 
    is_new = model.name.nil?
    # 
    # Le nom (unique) du modèle
    # 
    model.name = ask_for_a_model_name(model)
    # 
    # La catégorie du modèle
    # 
    if not(model.categorie.nil?)
      unless Q.yes?("Doit-on garder la même catégorie ? (#{model.categorie})")
        model.categorie = nil
      end
    end
    model.categorie ||= MyTaches::Tache.choose_categorie("Catégorie", {enable_new:true})
    # 
    # Les tâches du modèle
    # 
    while true
      # 
      # On affiche les tâches actuelles
      # 
      #
      clear
      model.display(index: true)
      # 
      # On choisit l'opération suivante et on l'exécute
      # 
      disabled = model.taches.count > 0 ? nil : '(aucune tâche)'
      case Q.select('') do |q|
          q.choice 'Créer une nouvelle tâche', :new_tache
          q.choice 'Enregistrer le modèle', :finir
          q.choice 'Modifier la tâche…', :mod_tache, disabled: disabled
          q.choice 'Paralléliser deux taches…', :sync_taches, disabled: disabled
          q.choice 'Déplacer une tâche', :move, disabled:  disabled
          q.choice 'Supprimer une tâche', :destroy, disabled:  disabled
          q.choice 'Renoncer', nil
          q.per_page 10
        end
      when NilClass
        clear
        return nil
      when :finir
        break
      when :new_tache
        model.id || raise("L'ID du modèle doit être défini…")
        model.add_tache(edit_tache(Tache.new(model_id:model.id)))
      when :mod_tache
        while true
          tache = model.choose_a_task("Index de la tâche à modifier")
          tache && edit_tache(tache) && break
        end
      when :sync_taches
        paralleliser_deux_taches(model)
      when :destroy
        while true
          tache = model.choose_a_task("Index de la tâche à détruire")
          tache && model.destroy_tache(tache) && break
        end
      when :move
        model.move_taches || return
      end
    end #/ boucle pour la création des tâches
    # 
    # Enregistrement du modèle
    # 
    if model.save
      clear
      puts "Modèle de suite de tâche enregistré.".vert
    else
      puts "Impossible d'enregistrer le modèle de suite de tâches…".rouge
    end

    return model
  end

  ##
  # Méthode appelée quand on choisit le menu "Paralléliser deux tâches"
  # Elle permet de choisir deux tâche pour les paralléliser.
  def self.paralleliser_deux_taches(model)
    tka = model.choose_a_task("Index de la première tâche à paralléliser", none_enabled:true)
    tka || return
    tkb = model.choose_a_task("Index de la deuxième tâche à paralléliser", none_enabled:true)
    tkb || return
    if tka.id == tkb.id
      raise "Impossible de choisir la même tâche !".rouge
    end
    desolidarise_tasks(tka, tkb)
    if tka.parallelize_with(tkb, true)
      puts "Les tâches '#{tka.todo}' et '#{tkb.todo}' sont parallélisées.".vert
      sleep 2 unless test?
    end
  end

  def self.desolidarise_tasks(tka, tkb)
    if tka.prev? && tka.prev_id == tkb.id
      tkb.unlink_from(tka).save
    elsif tka.suiv? && tka.suiv.id == tkb.id
      tka.unlink_from(tkb).save
    end
  end

  ##
  # Édition d'une tâche de modèle
  #
  # Note : l'édition d'une tâche de modèle diffère de l'édition
  # normale d'une tâche. Tous les champs ne sont pas à remplir et
  # il faut définir les champs fixes, modifiables, dynamtiques, etc.
  # 
  # @return {MyTaches::Tache} La tâche modifiée
  # 
  def self.edit_tache(tache)
    require_relative 'Model_Tache'
    tache.edit
    return tache
  end

  ##
  # Retourne la liste de tous les modèles définis, pour
  # un choix avec TTY-Prompt
  def self.all_for_tty(params = {})
    ary = all.map do |model|
      {name: model.name, value: model}
    end
    if params[:enable_new]
      ary << {name:'Nouveau modèle de suite de tâches…', value: :new}
    end
    if params[:enable_cancel]
      ary << {name:'Renoncer', value: nil}
    end
    return ary
  end

  # @return Le nombre de modèle de suite de tâches
  def self.count
    all.count
  end

  ##
  # @return Array d'instances de tous les modèles
  # 
  def self.all
    @@all ||= begin
      Dir["#{models_folder}/*.yaml"].map do |pth|
        new(YAML.load_file(pth))
      end
    end
  end

  def self.models_folder
    @@models_folder ||= mkdir(File.join(APP_FOLDER,"#{'lib/TEST' if test?}_MODELES_"))
  end

  def self.taches_folder
    # @@taches_folder ||= begin
      mkdir(File.join(models_folder,'taches')).tap do |p|
        File.exist?(p) || raise("Impossible de créer le fichier #{p.inspect}…")
      end
    # end
  end

  # Seulement pour les tests, pour le moment
  def self.reset
    @@all = nil
    @@models_folder = nil
    @@taches_folder = nil
  end

  # Demande un nom (unique) et le retourne
  def self.ask_for_a_model_name(model)
    while true
      name = Q.ask("Nom du #{model.name ? '' : 'nouveau '}modèle : ".jaune, default:model.name) || return
      if name_uniq?(model.name, model.id)
        return name
      else
        puts "Le nom de modèle doit être unique.".rouge
      end
    end
  end

  def self.name_uniq?(name, model_id)
    all.each do |mdl|
      next if mdl.id == model_id
      return false if mdl.name == name
    end
    return true
  end

#####################################################################
#
#   INSTANCE MyTaches::Model
#
#####################################################################

    attr_reader :data
    
    def initialize(data = nil)
      @data   = data || {name:nil, taches_ids:[]}
      (@data.key?(:taches_ids) && @data[:taches_ids].is_a?(Array)) || @data.merge!(taches_ids: [])
    end

    # Surtout pour les tests
    def reset
      @taches = nil
    end

    ##
    # Pour choisir une des tâches du modèle
    # 
    # @param  params {Hash|Nil}
    # 
    #   return_index:     Si true la méthode retourne l'index (0-start)
    #                     sinon (défaut) l'instance de la tâche
    # 
    # 
    def choose_a_task(question, params = nil)
      params ||= {}
      while true
        tindex = Q.ask("#{question||'Index de la tâche'} : ".jaune) || ''
        if tindex.numeric?
          tindex = tindex.to_i
          if tindex == 0
            if params[:zero_enabled] && params[:return_index]
              return -1
            elsif params[:none_enabled]
              return params[:return_index] ? 0 : nil
            end
          end
          tache = taches[tindex - 1]
        else
          STDOUT.write("\rIl faut fournir un nombre !".rouge)
        end
        if tache.nil?
          STDOUT.write("\rPas de tâche à cet index (0-start) !".rouge)
          return nil
        else
          return params[:return_index] ? tindex - 1 : tache
        end
      end
    rescue TTY::Reader::InputInterrupt
      clear
      puts "\nOpération abandonnée.".orange
      raise ExitWithoutError
    end

    # --- Helpers ---

    ##
    # Affichage du modèle
    #
    # @param params {Hash}
    #   :index    Si true, on ajoute un numéro de listing
    # 
    # Note : en mode test, c'est le tableau affiché qui 
    # est renvoyé, et pas écrit en console.
    # 
    def show(params = nil)
      clear
      params ||= {}
      @output = []
      output "Modèle de suite de tâches « #{name} » [#{id}]".as_title.bleu
      tb = CLITable.new(
        header: ['Idx','Todo','Durée','Id'],
        # max_lengths: {2 => 50},
        flex_column: 2,
        header_color: :bleu
      )
      taches.each_with_index do |tk, idx|
        tb << [idx+1, tk.todo, tk.f_duree, tk.id]
      end
      output tb.display
      output "\n\n"

      return @output.join("\n") if test?
    end
    alias :display :show

    def output(str)
      if test?
        @output << str
      else
        puts str
      end
    end

    # --- Opérations ---

    def save(check_dyn_values = true)

      # 
      # Vérification des données (et notamment les valeurs
      # dynamiques)
      check_values(check_dyn_values) || return
      # 
      # Enregistrer les données dans le fichier YAML
      # 
      File.delete(path) if File.exist?(path)
      File.open(path,'wb') do |f|
        f.write data.to_yaml
      end

      # En cas de création, pour actualiser les listes et les
      # tables.
      self.class.reset

      return File.exist?(path)
    end

    def check_values(check_dyn_values)
      # puts "-> check_values(#{check_dyn_values.inspect})"
      # 
      # Vérification de l'unicité du nom
      # 
      Model.name_uniq?(name, id) || raise("Le nom du modèle (#{name.inspect} devrait être unique…")
      # 
      # Vérification et renseignement des valeurs dynamiques
      # 
      check_dynamic_values if check_dyn_values

      return true
    end

    def check_dynamic_values
      liste_dyn_keys = []
      taches.each do |tache|
        next if not(tache.todo.match?(/\%\{.+?\}/))
        # La tâche définit des valeurs dynamiques
        tache.todo.scan(/\%\{(.+?)\}/).to_a.each do |dyn_key|
          liste_dyn_keys << dyn_key.first
        end
      end
      liste_dyn_keys.uniq!
      return true if liste_dyn_keys.empty?
      # 
      # On passe en revue chaque clé dynamique
      # 
      liste_dyn_keys.each do |dyn_key|
        next if dynamic_values.key?(dyn_key)
        # 
        # C'est une nouvelle clé dynamique
        # 
        quest = Q.ask("Quelle question poser pour la clé %{#{dyn_key}} ? ".jaune)
        defo  = Q.ask("Valeur par défaut pour cette question (rien si aucune)".jaune)
        #
        # On l'ajoute à la données de valeurs dynamiques
        # 
        # Note : peut-être qu'il faudra pourvoir définir le
        # type de la donnée plus tard.
        # Possibilité par exemple 
        # 
        data[:dynamic_values].merge!(dyn_key => {what:quest, default:defo})
      end      

      return true
    end


    ##
    # Pour ajouter une tâche
    # 
    def add_tache(tache)
      taches.push(tache)
      tache.model_id = id
      data[:taches_ids] << tache.id
      # Liéer les tâches dans l'ordre
      link_taches
    end

    ##
    # Pour déplacer les tâches
    # 
    # (note : sera sauvée ensuite)
    # 
    def move_taches
      index_from = choose_a_task("Indice de la tâche à déplacer", return_index: true)
      moved_tache     = taches.delete_at(index_from)
      data[:taches_ids].delete_at(index_from)
      self.display(index: true)
      if index_from > 1
        index_prev = choose_a_task("Déplacer cette tâche AVANT la tâche d'indice", return_index:true, zero_enabled:true)
      else
        index_prev = choose_a_task("Déplacer cette tâche APRÈS la tâche d'indice", return_index:true, zero_enabled:true)
        index_prev += 1
      end

      taches.insert(index_prev, moved_tache)
      data[:taches_ids].insert(index_prev, moved_tache.id)

      # 
      # Pour relier les tâches
      # 
      link_taches

      return true
    end

    # Détruit le modèle et toutes ses tâches et
    # @return true si l'opération s'est bien passée
    def destroy
      # 
      # Détruire toutes ses tâches
      # 
      taches.each do |tache| tache.destroy end
      File.delete(path) if File.exist?(path)

      return not(File.exist?(path))
    end

    def destroy_tache(tache)
      tache.destroy
      data[:taches_ids].delete(tache.id)
      @taches = nil
      save
      return true
    end

    # --- Données fixes ---

    def id
      data[:id] ||= "mod#{Time.now.to_i}"
    end
    def id=(value)
      data.merge!(id: value)
    end

    def name
      data[:name]
    end
    def name=(value)
      data.merge!(name: value)
    end
    
    def categorie
      data[:categorie]
    end
    def categorie=(value)
      data.merge!(categorie: value)
    end

    def dynamic_values
      data[:dynamic_values] ||= {}
    end

    def taches
      @taches ||= begin
        (data[:taches_ids] || []).map do |tache_id|
          pth = File.join(Model.taches_folder,"#{tache_id}.yaml")
          if File.exist?(pth)
            Tache.new(YAML.load_file(pth))
          end
        end.compact
      end
    end

    def path
      @path ||= File.join(Model.models_folder,"#{id}.yaml")
    end

  private

    def link_taches
      taches.each do |tache|
        tache.reset
        tache.data[:suiv] = nil
      end.each_with_index do |tache, idx|
        prev_tache = taches[idx - 1]
        next_tache = taches[idx + 1]
        prev_tache.data[:suiv]  = tache.id if idx > 0
        next_tache.prev_id      = tache.id if next_tache
      end
    end

end #/class Model
end #/module MyTaches
