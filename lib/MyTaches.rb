# encoding: UTF-8
module MyTaches

  def self.cronlog_path
    @@cronlog_path ||= File.join(APP_FOLDER,'cron.log')
  end
 
  def self.run

    # puts "CLI.main_command : #{CLI.main_command.inspect}"
    self.init

    # puts "CLI.main_command_name : #{CLI.main_command_name}"
    # puts "CLI.main_command : #{CLI.main_command}"
    # exit

    #
    # Initiation de l'app
    # --------------------
    # Procède à un check des tâches et de tout ce qu'il y a à
    # faire pour que l'application soit à jour
    # Seulement pour la liste des commandes définies
    # 
    if ['add','+','create','del','-','display','done','edit','essai','list',
      'model','modele','mod','modify', 'noop','run', 'sup','show',
      'today', nil
      ].include?(CLI.main_command)
      Tache.init
    end

    # puts "ARGV: #{ARGV.inspect}".jaune

    # 
    # L'objet courant défini par un identifiant en ligne de
    # commande.
    # Ça peut être une tâche courante, une tâche archivée, un
    # modèle de suite de tâche, etc.
    # 
    # On le met en variable de classe pour qu'il soit accessible
    # par les tests
    self.current_objet = get_objet_in_command_line


    case CLI.main_command
    when 'try', 'essai'
      # 
      # Pour essayer du code 
      # 
      clear
      puts "Programmer un code à essayer ici :\n#{__FILE__}:#{__LINE__}".bleu
      return 
    when 'noop'
      # Pour les tests, pour jouer MyTaches.run mais sans rien
      # faire (tout en initialisant quand même Tache)
    when NilClass
      if cron?
        Tache.notify
      else
        res = Tache.etat_des_lieux
        return res if test?
      end
    when 'list', 'today'
      require_relative 'Tache_list'
      filtre =
        case CLI.main_command
        when 'list'   then nil
        when 'today'  then {from:_NOW_, to:_NOW_+JOUR}
        end
      res = Tache.display_list(filtre)
      return res if test?
    when 'add', 'create', '+'
      create_tache_or_modele
      redisplay_list_if_enabled
    when 'done', 'ok'
      Tache.mark_done(current_objet)
      redisplay_list_if_enabled
    when 'show', 'display'
      choose_an_objet('Afficher') if current_objet.nil?
      current_objet || return
      res = current_objet.show
      return res if test?
    when 'mod', 'edit', 'modify'
      if for_model?
        Model.edit(Model.choose('Modèle à éditer', enable_new: false))
      else
        choose_an_objet('Modifier') if current_objet.nil?
        current_objet && current_objet.class.edit(current_objet)
        redisplay_list_if_enabled
      end
    when 'run', 'joue'
      Tache.run_code(current_objet)
    when 'sup', 'del', '-'
      if for_model?
        Model.destroy
      else
        choose_an_objet('Détruire') if current_objet.nil?
        current_objet && current_objet.class.destroy(current_objet)
        redisplay_list_if_enabled
      end
    when 'model', 'modele'
      Model.run
    when 'help', 'aide'
      require_relative 'Tache_aide'
      Tache.display_help
    when 'manuel'
      require_relative 'Tache_aide'
      Tache.open_manuel
    when 'open'
      case CLI.components[0]
      when 'manuel'
        require_relative 'Tache_aide'
        Tache.open_manuel
      else
        if CLI.option(:dev)
          puts "Je dois apprendre à ouvrir ce dossier".jaune
          `subl -n "#{APP_FOLDER}"`
        else
          puts "Je ne sais pas ce qu'il faut ouvrir…".rouge
        end
      end
    else
      puts "Je ne sais pas comment traiter la commande '#{CLI.main_command}'.".jaune
    end

    # Pour ne pas être obligé de le faire partout
    puts "\n\n"

    # Pour les tests qui enchainent des appels à MyTaches.run en
    # mode semi-intégration (et donc définissent le contenu de
    # ARGV à la volée)
    if test?
      ARGV.pop while ARGV.any?
      return @out_lines.join("\n")
    end


  end

  def self.choose_an_objet(question, params = nil)
    clear
    self.current_objet = nil
    case Q.select("#{question} : ".jaune) do |q|
        q.choice 'Une tâche'            ,:tache
        q.choice 'Un modèle'            ,:model
        q.choice 'Une tâche archivée'   ,:archived
        q.choice 'La configuration'     ,:config
        q.choice "Renoncer"             , nil
        q.per_page 5
      end 
    when NilClass
      return
    when :tache
      self.current_objet = Tache.choose("#{question} la tâche") || return
    when :model
      self.current_objet = Model.choose("#{question} le modèle", enable_new: false) || return
    when :archived
      self.current_objet = ArchivedTache.choose("#{question} la tâche archivée") || return
    when :config
      raise "Je ne sais pas encore choisir la configuration."
    end

  end

  class << self
    attr_accessor :current_objet # tâche, modèle, tâche archivée
    attr_reader :out_lines
    # En mode test, consigne les sorties console dans @out_lines
    def add_out_lines(str)
      @out_lines ||= []
      @out_lines << str
    end
    def reset_out_lines
      @out_lines = []      
    end
  end

  def self.init
    CONFIG.reset
    self.current_objet = nil
    @out_lines = []
  end

  def self.get_objet_in_command_line
    self.current_objet = nil
    ARGV.reject do |arg|
      arg.start_with?('-')
    end.each do |arg|
      if arg.start_with?('id=')
        objet = can_be_objet_id?(arg.split('=')[1])
        return objet if objet
      end
    end.reject do |arg|
      arg.match?('=')
    end.each do |arg|
      objet = can_be_objet_id?(arg)
      return objet if objet
    end

    return nil
  end

  def self.can_be_objet_id?(id)
    fname = "#{id}.yaml"
    
    # Tâche active ?
    pth = File.join(Tache.taches_folder,fname)
    return Tache.get(id) if File.exist?(pth)
    
    # Tâche archivée ? (done)
    pth = File.join(Tache.folder_archives,fname)
    return ArchivedTache.get(id) if File.exist?(pth)
    
    # Modèle de suite de tâche ?
    pth = File.join(Model.models_folder,fname)
    return Model.get(id) if File.exist?(pth)

    # Tâche de modèle de tache ?
    pth = File.join(Model.taches_folder, fname)
    return Model::Tache.get(id) if File.exist?(pth)

    return nil
  end

  def self.create_tache_or_modele
    operation = :create_model if for_model? 
    operation ||= Q.select(nil) do |q|
          q.choice 'Créer une tâche unique', :tache
          q.choice 'Créer des tâches d’après un modèle de suite de tâches', :insert_model
          q.choice 'Créer un nouveau modèle de suite de tâches', :create_model
        end
    case operation
    when :create_model
      Model.create
    when :tache
      Tache.create      
    when :insert_model
      Tache.insert_from_model
    end
  rescue TTY::Reader::InputInterrupt
    clear
    puts "\nOpération abandonnée.".orange
    raise ExitWithoutError
  end

  def self.for_model?
    cli?(['model','modele'])
  end


  # Pour enregistrer la commande qui a demandé une liste, pour
  # la remettre si nécessaire après certaines commande comme 'add',
  # ou 'done'
  def self.memorise_commande_liste
    File.write(memo_list_command_path, "#{ARGV.join(' ')}:::#{Time.now.to_i}")
  end

  # Après une commande de type 'done', ou 'add', cette méthode 
  # affiche la liste précédemment affichée si c'est le cas (si une
  # liste a été affichée dans l'heure précédente)
  def self.redisplay_list_if_enabled
    full_command, time = get_last_command_liste
    full_command || return # pas de mémorisation
    return if time < Time.now.to_i - 3600 # trop vieille liste
    # 
    # Dans le cas contraire, on redonne la liste
    # 
    ARGV.clear
    full_command.split(' ').each { |e| ARGV << e }
    CLI.parse(ARGV)
    MyTaches.run
  end

  # @return la dernière commande liste complète ainsi que son temps
  # d'utilisation ({Integer})
  def self.get_last_command_liste
    return [nil, nil] if not(File.exist?(memo_list_command_path))
    full_command, time = File.read(memo_list_command_path).split(':::')
    time = time.to_i
    return [full_command, time]
  end

  def self.memo_list_command_path
    @memo_list_command_path ||= File.join(APP_FOLDER,'.list_command')
  end

end #/module MyTache
