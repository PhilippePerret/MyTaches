# encoding: UTF-8
#

# Pour les erreurs de filtre
class Lfe < StandardError; end

require_relative 'TaskArray'

module MyTaches
  
require_relative 'Tache_instance'
require_relative 'Tache_calculs'
require_relative 'Tache_Model'
require_relative 'Tache_parallel'
require_relative 'Tache_helpers'
require_relative 'Tache_Rappel'
require_relative 'Tache_statuts'
require_relative 'Tache_links'
require_relative 'Tache_data'
require_relative 'Tache_display'
require_relative 'Tache_edition'
require_relative 'Tache_run'


class Tache
class << self
####################################################################
#
#   CLASSE
#
####################################################################
  attr_reader :all, :table

  ##
  # Pour notifier toutes les tâches qui le doivent
  # 
  def notify
    debug? && puts("-> Tache::notify (nombre de tâches : #{all.count})")
    # 
    # Boucle sur toutes les tâches non filtrées
    # 
    all.each do |tache|
      if debug?
        msg = "Étude de la tâche '#{tache.todo}'. À notifier ? #{tache.notify?.inspect}".jaune
        if cron?
          log(msg)
        else
          puts msg
        end
      end #/only si débug

      tache.notify if tache.notify?
    
    end
    debug? && puts("<- Tache::notify")
  end

  ##
  # Initialisation de l'app
  #
  def init
    # 
    # Compteurs à zéro
    # 
    reset
    # 
    # Chargement des tâches
    # 
    Tache.load

    return true
  end

  def reset
    @all    = TaskArray.new
    @table  = {}
    @taches_folder = nil # pour les tests
  end

  ##
  # Retourne la tâche d'identifiant +task_id+
  # 
  def get(task_id)
    (@table||{})[task_id]
  end

  ##
  # Pour choisir une tâche
  # @return l'instance {MyTaches::Tache} choisie
  # 
  # @param  params {Hash}
  #         :enable_cancel    Si true, on peut renoncer et renvoyer
  #                           nil
  #         :categorie        {String} La catégorie de la tâche à
  #                           choisir. Seule les tâches de cette 
  #                           catégorie seront affichées.
  def choose(question = nil, params = nil)
    params ||= {}
    clear if params[:clear]
    if not(params[:categorie])
      choix_par = Q.select("Choisir…".jaune) do |q|
        q.choices [
          {name:"Par catégorie", value: :categorie},
          {name:"Par liste complète", value: :list},
          {name:'Renoncer', value: nil}
        ]
        q.per_page 4
      end
      case choix_par
      when NilClass then 
        nil
      when :categorie
        params.merge!(categorie: choose_categorie)
      when :model
        # rien à faire ici
      end
    end
    tty_taches = tty_all(params).dup
    tty_taches << {name:"Aucune", value:nil} if params[:none]
    Q.select(((question||"Choisir la tâche").jaune), tty_taches, per_page:(params[:per_page]||tty_taches.count), filter:true, show_help:false, echo:false) do |q|
      if params[:enable_cancel]
        q.choice [{name: 'Renoncer', value: nil}]
      end
    end
  rescue TTY::Reader::InputInterrupt
    clear
    puts "\nOpération abandonnée.".orange
    raise ExitWithoutError
  end

  ##
  # Pour choisir une catégorie
  # 
  # Noter qu'une catégorie n'est pas une instance. C'est un simple
  # string.
  # 
  # @param  params {Hash}
  #         :enable_new   Si true, on peut créer une nouvelle
  #                       catégorie.
  #         :enable_any   Si true (par défaut), on peut ne pas choisir 
  #                       de catégorie
  # 
  def choose_categorie(question = nil, params = nil)
    params ||= {}
    params.key?(:enable_new) || params.merge!(enable_new: true)
    params.key?(:enable_any) || params.merge!(enable_any: true)
    cate = Q.select((question||"Choisir la catégorie :").jaune, categories, per_page:10) do |q|
      q.choice("Nouvelle catégorie", :new) if params[:enable_new]
      q.choice("- Aucune -",   nil)  if params[:enable_any]
    end
    cate = ask_or_null("Nouvelle catégorie :") if cate == :new

    return cate
  end

  ##
  # Retourne un Array contenant les menus pour choisir des tâches,
  # en appliquant les options +params+
  # 
  # @param params {Hash|Nil}
  #   :categorie  Si définie, on prend les tâches de cette catégorie
  #   Dans tous les autres cas, on prend toutes les tâches
  # 
  def tty_all(params = nil)
    ary = []
    params ||= {}
    all(params).sort_by do |tache|
      tache.start_time.to_i
    end.group_by do |tache|
      tache.categorie
    end.map do |categorie, groupe|
      ary << {name: "#{categorie||'DIVERS'}".upcase, disabled:''}
      groupe.each do |tache|
        ary << {name: "  #{tache.todo}", value: tache}
      end
    end

    return ary
  end

  def count
    all.count
  end
  
  ##
  # {TaskArray} Retourne toutes les instances de tâches, filtrées ou non
  # Note : {TaskArray} hérite de Array en lui adjoignant de 
  # nouvelles méthodes comme :sorted
  # 
  # @param  params {Hash|Nil} Filtre des tâches
  #   :todo         {Regex} Les tâches doivent répondre à cette expression régulière
  #   :categorie    {String} La catégorie exacte recherchée
  #                 {Regexp} La catégorie doit matcher à cette expression régulière
  #   :no_time      {Boolean} Seulement les tâches sans temps
  #   :current      {Boolean} Seulement les tâches courantes 
  #   :out_of_date  {Boolean} Seulement les tâches périmées
  #   :futur        {Boolean} Seulement les tâches futures
  # 
  #   :start_after  {Time} Tâches commençant après ce temps
  #   :start_before {Time} Tâches commençant avant ce temps
  #   :end_after    {Time} Tâches finissant après ce temps
  #   :end_before   {Time} Tâches finissant avant ce temps
  # 
  #   :duree_min    {Duree} Tâches de durée au moins égale
  #   :duree_max    {Duree} Tâches de durée inférieure ou égale
  # 
  #   Toutes les valeurs comme :
  #     :current, :out, :out_of_date, :no_time, etc.
  # 
  #   :linked       {Boolean} Si true, seulement les tâches liées,
  #                 si false, seulement les tâches non liées
  # 
  def all(params = nil)
    return @all if params.nil? || params.empty?

    ##############
    ##  FILTRE  ##
    ##############
    # 
    # Le filtrage fonctionne en trois temps distincts :
    # 1. On filtre les tâches qui correspondent à la 
    #    catégorie choisie, au todo contenant tel ou tel
    #    texte, au temps définis par :start_before ou autre
    #    filtre similaire, etc.
    #    C'est le : filtre par exclusion
    # 
    # 2. Sur la liste des tâches retenues, on applique
    #    les options de type --current, --futur, etc.
    #    C'est le : filtre par inclusion
    # 
    # 3. On ajoute les options supplémentaires comme :
    #    --linkeds pour ajouter les tâches liées aux tâches
    #    retenues, --ids pour mettre les identifiants ou
    #    encore --notify pour notifier les tâches qui 
    #    doivent l'être.
    # 

    filtre_exclusifs = filtre_by_exclusion(params)
    filtre_inclusifs = filtre_by_inclusion(params)

    if false && test?
      ecrit("Params: #{params.inspect}")
      ecrit("Nombre procédure exclusives : #{filtre_exclusifs.count}")
      ecrit("Nombre procédure inclusives : #{filtre_inclusifs.count}")
    end

    liste = Array.new
    if filtre_exclusifs
      all.each do |tache|
        begin
          filtre_exclusifs.each do |procedure|
            procedure.call(tache)
          end
          liste << tache
        rescue Lfe => e
          # puts "Tâche #{tache.id} exclue : #{e.message}"
        rescue Exception => e
          raise e
        end
      end 
    else
      liste = all.dup
    end

    ary = TaskArray.new

    if filtre_inclusifs.any?
      liste.each do |tache|
        filtre_inclusifs.each do |procedure|
          if procedure.call(tache)
            ary << tache
            break
          end
        end
      end
    else
      liste.each do |tache| ary << tache end
    end

    return ary
  end


  ##
  # Filtre par inclusion
  # 
  # 
  # Par exemple, si les options contiennent '--current' et
  # '--proches', il faut afficher les tâches courantes ET
  # les tâches proches.
  # 
  def filtre_by_inclusion(params)

    procedures = []

    if params[:all]
      procedures << ->(tk) { true }
    end

    if params[:near]
      procedures << ->(tk){ 
        tk.near?( params[:near] === true ? nil : params[:near])
      }
    end
    
    if params[:futur]
      procedures << ->(tk) { tk.futur? }
    end

    if params[:far]
      procedures << ->(tk) { tk.far? }
    end

    if params[:today]
      procedures << ->(tk) { tk.today? }
    end

    if params[:no_time]
      procedures << ->(tk) { tk.no_time? }
    elsif params[:no_time] === false
      procedures << ->(tk) { not(tk.no_time?) }
    end

    if params[:out]
      procedures << ->(tk) { tk.out_of_date? }
    end

    if params[:linked]
      procedures << ->(tk){ tk.linked? }
    end

    if params[:lost]
      procedures << ->(tk) { tk.lost? }
    end

    if params[:current]
      procedures << ->(tk) { tk.current? }
    end

    return procedures
  end


  def filtre_by_exclusion(params)
    procedures = []
    
    # - Filtre par le :todo -
    
    todo = params[:todo]
    if todo
      procedures << ->(tk) { 
        raise Lfe.new("Le :Todo ne matche pas") unless tk.todo.match?(todo) 
      }
    end

    # - Filtre par la categorie (:cate)

    cate = params[:categorie] || params[:cate]
    if cate
      case cate
      when String
        procedure = ->(tk) { 
          tk.categorie == cate || raise(Lfe.new("Pas la bonne catégorie"))
        }
      when Regexp
        procedure = ->(tk) { 
          (tk.categorie||'').match?(cate) || raise(Lfe.new("Catégorie ne matche pas"))
        }
      else
        raise Lfe.new("Impossible de définir la catégorie par #{cate}…".rouge)
      end
      procedures << procedure
    end

    # - Filtre par la date -
    if params.key?(:start_before)
      procedures << ->(tk){
        raise Lfe.new("pas de temps de début")    if tk.start_time.nil?
        raise Lfe.new("commence après ce temps")  if tk.start_time > params[:start_before]
      }
    end
    if params.key?(:start_after)
      procedures << ->(tk){ 
        raise Lfe.new("pas de temps de départ")  if tk.start_time.nil?
        raise Lfe.new("commence avant ce temps") if tk.start_time < params[:start_after]
      }
    end
    if params.key?(:end_before)
      procedures << ->(tk){
        raise Lfe.new("pas de temps de fin")  if tk.end_time.nil?
        raise Lfe.new("fini après ce temps")  if tk.end_time > params[:end_before]
      }
    end
    if params.key?(:end_after)
      procedures << ->(tk){
        raise Lfe.new("pas de temps de fin") if tk.end_time.nil?
        raise Lfe.new("fini avant ce temps") if tk.end_time < params[:end_after]
      }
    end
    # - Durée -
    if params.key?(:duree_min)
      procedures << ->(tk){
        v = params[:duree_min]
        raise Lfe.new("pas de durée définie")    if tk.duree.nil? || tk.duree_seconds.nil?
        raise Lfe.new("durée inférieure à #{v}") if tk.duree_seconds < Tache.calc_duree_seconds(v)
      }
    end
    if params.key?(:duree_max)
      procedures << ->(tk){
        v = params[:duree_max]
        raise Lfe.new("pas de durée définie")    if tk.duree.nil? || tk.duree_seconds.nil?
        raise Lfe.new("durée supérieure à #{v}") if tk.duree_seconds > Tache.calc_duree_seconds(v)
      }
    end

    # - filtre par liaison -
    if params.key?(:linked)
      procedures << ->(tk){
        if params[:linked] === true 
          raise Lfe.new("non liée à une autre tâche") if not(tk.linked?)
        else
          raise Lfe.new("liée à une autre tâche") if tk.linked?
        end
      }
    end

    return procedures    
  end


  def categories
    tbl = {}
    all.map do |tache|
      cate = tache.data[:cate]
      next if cate.nil?
      next if tbl.key?(cate)
      tbl.merge!( cate => true)
      {name: cate, value: cate}
    end.compact
  end

  ##
  # Ajout de la tâche 
  #
  # Cette méthode procède aussi aux opérations suivantes :
  #   - si :suiv ou :prev sont définis, on définit la valeur opposée
  #     des tâches correspondantes, si elles sont déjà initialisées
  #     Noter que la méthode Tache.load s'en charge aussi
  #   - elle s'assure qu'il n'y ait pas deux tâches avec le même
  #     identifiant.
  #   - elle s'assure que la tâche possède un :todo
  # 
  # @return TRUE si la tâche a pu être ajoutée
  # 
  def add(tache)
    return if tache.nil?
    tache = new(tache) if tache.is_a?(Hash)
    return if tache.id == 'modele'
    tache.todo || raise(ERRORS[:todo_is_required])
    indiceid = 0
    while @table.key?(tache.id)
      indiceid += 1
      tache.id = "#{tache.id}-#{indiceid}"
    end
    # 
    # Si la propriété data[:suiv] est définie, il faut régler aussi la
    # propriété volatile :prev_id de l'instance suivante
    # 
    if tache.data[:suiv] && @table.key?(tache.data[:suiv])
      get(tache.data[:suiv]).prev_id = tache.id
    end
    @all << tache
    @table.merge!(tache.id => tache)
    return true
  end

  def sup(tache)
    @all = @all.reject{ |tk| tk.id == tache.id }
    @table.delete(tache.id)
  end

  ##
  # Chargement de toutes les tâches du fichier _TACHES_.yaml
  #
  def load
    # 
    # Chargement de tous les fichiers YAML des tâches
    # 
    Dir["#{taches_folder}/*.yaml"].map do |pth|
      dtache = YAML.load_file(pth)
      next if dtache.nil? || dtache[:id] == 'modele'
      add(dtache)
    end
    #
    # On définit les :prev_id de toutes les tâches suivantes
    # 
    set_taches_prev
  end

  ##
  # Après des déplacements de tâches on appelle cette méthode
  # pour s'assurer qu'il n'existe pas de boucle de tâches
  # infinie comme dans :
  #   T5 -> T3 -> T2 -> T5
  def avoid_infinite_tasks_loop
    all.each do |tache|
      tache_id = tache.id
      tasuiv = tache
      while tasuiv = tasuiv.suiv
        if tasuiv.suiv && tasuiv.suiv.id == tache_id
          tasuiv.suiv.unlink_from(tache_id).save
        end
      end
    end
  end

  def set_taches_prev
    all.each do |tache|
      tache.reset
      tache.prev_id = nil
    end.select do |tache|
      not(tache.data[:suiv].nil?) && not(tache.suiv.nil?)
    end.each do |tache|
      tache.suiv.reset
      tache.suiv.prev_id = tache.id
    end
  end

  def taches_folder
    @taches_folder ||= mkdir(File.join(APP_FOLDER,"#{'lib/TEST' if test?}__TACHES__"))
  end

  def folder_archives
    @folder_archives ||= mkdir(File.join(APP_FOLDER,"#{'lib/TEST_' if test?}xbackups",'taches_achevees'))
  end

end #/<< self

  private

    def self.destroy_old_boards
      Dir["#{Dir.home}/Desktop/Taches_*.html"].each do |p|
        File.delete(p)
      end
    end

    # --- HELPERS ---

    def self.header_today_board
      <<-HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tâches du #{formate_date(_NOW_)}</title>
    <style>
body {
  width:980px;
  font-size:20pt;
  font-family:Palatino;
}
/* TACHE  */
div.tache {
  margin-left: 4em;
  margin-bottom: 8px;
}
div.tache div.todo {}
div.tache div.todo span.tache_id {font-size: 12pt;margin-right:1em;}
div.tache div.todo.out-of-date {color: red; font-weight: bold;}
div.tache div.todo.lointaine {color:green;}
div.tache:not(:active) div.infos {display:none;}
div.tache:active div.infos{display: block;}
div.tache div.infos {
  font-size: 0.85em;
  line-height:  1.5em;
}
div.tache div.infos > span {
  display: block;
  margin-left: 2em;
}
/* CATÉGORIE */
div.categorie {
  font-size: 14pt;
  font-weight: bold;
  font-family: 'Arial Narrow';
  font-style: italic;
  margin:  24px 0 12px 2em;
}
/* AIDE */
div#aide {
  font-size: 14pt;
  margin-top: 3em;
}
div#aide code {
  background-color: #555;
  color: white;
  padding: 2px 14px;
  margin-right: 0.5em;
}
div#aide ul li {
  margin-bottom: 8px;
}
div#aide code:before {
  content: '> ';
}
    </style>
  </head>
  <body>
      HTML
    end
    
    def self.footer_today_board
      html_help + '</body></html>'
    end

    def self.html_help
      require_relative 'Tache_aide'
      AIDE_HTML
    end

end #/class Tache
end #/module MyTache
