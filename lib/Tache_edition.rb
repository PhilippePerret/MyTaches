# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
class Tache

# Pour la création et la modification avec Tableizor
TACHES_PROPERTIES = [
  {name:'Tâche à faire'       ,prop: :todo},
  {name:'Catégorie'           ,prop: :cate},
  {name:'Identifiant'         ,prop: :id},
  {name:'Commence le…'        ,prop: :start},
  {name:'Doit s’achever le…'  ,prop: :end},
  {name:'À une durée de…'     ,prop: :duree},
  {name:'Rappel'              ,prop: :rappel},
  {name:'Description'         ,prop: :detail},
  {name:'Tâche précédente'    ,prop: :prev},
  {name:'Tâche suivante'      ,prop: :suiv},
  {name:'Parallèle à'         ,prop: :parallels},
  {name:'Ouvrir le file…'     ,prop: :open},
  {name:'Code à exécuter'     ,prop: :exec},
  {name:'Icône/Application'   ,prop: :app}
]

#####################################################################
#
#   CLASSE
#
#####################################################################

class << self
  def create
    clear
    ok = false
    newtache = new({})
    if newtache.edit("à créer")
      if newtache.check&.save
        add(newtache)
        newtache.traiter_new_parallel_task(true) if newtache.new_parallel_task
        clear
        puts "\nNouvelle tâche #{newtache.id} créée avec succès.".vert
        ok = true
      else
        puts "La nouvelle tâche n'a pas pu être créée.".rouge
      end
      puts "\n\n"
    end
    return ok
  end
  
  # Pour marquer la tâche d'identifiant +tache_id+ faite
  # Et définir le temps de la suivante si elle existe
  def mark_done(tache)
    tache = get_tache_from(tache, 'Tâche à marquer achevée') || return
    if Q.yes?("Es-tu certain de vouloir marquer la tâche \n\t« #{tache.todo} »\n… comme achevée ?".jaune)
      if acheve_tache(tache)
        puts "Tâche '#{tache.id}' marquée achevée.".vert
        tache.on_mark_done
      else
        puts "La tâche '#{tache.id}' n'a pas pu être marquée achevée.".rouge
      end
    end
  end

  def edit(tache = nil)
    tache = get_tache_from(tache,'Tâche à modifier') || return
    ok = false
    if tache.edit("à modifier")
      if tache.check&.save
        tache.traiter_new_parallel_task(true) if tache.new_parallel_task
        clear
        puts "Tâche '#{tache.id}' modifiée avec succès.".vert
        ok = true
      else
        puts "# Impossible de modifier la tâche '#{tache.id}'…".rouge
      end
      puts "\n\n"
    end

    return ok
  end

  def destroy(tache)
    tache = get_tache_from(tache, 'Tâche à supprimer') || return
    if Q.yes?("Es-tu certain de vouloir détruire la tâche\n\t« #{tache.todo} »\n? Pour l'archiver, utilise plutôt la commande 'done'.".jaune)
      if tache.destroy
        clear
        puts "Tâche '#{tache.id}' détruite avec succès.".vert
      else
        puts "La tâche '#{tache.id}' n'a pas pu être détruite.".rouge
      end
      puts "\n\n"
    end
  end


  def get_tache_from(tache, question)
    tache = get(tache) if tache.is_a?(String)
    tache ||= Tache.choose(question,{clear:true}) || return
  end

end # << self

#####################################################################
#
#   INSTANCE
#
#####################################################################

# Pour gérer les tâches parallèles dans les modèles
attr_reader :new_parallel_task

# 
# Méthode générale d'édition de la tâche (pour la modification et
# la création)
#
def edit(pour)
  init_edition
  # 
  # Si c'est une modification, on ajoute l'item "Allonger la durée"
  # 
  table_properties = TACHES_PROPERTIES.dup
  # 
  # Tableau pour édition
  # 
  tb = Tableizor.new(titre:"Données de la tâche #{pour}", 
    object: self,
    properties:table_properties,
    data_method: :edit_data
  )
  return tb.edit # true/false
end

def init_edition
  self.edit_data = {}  
end

#
# S'assure que les données minimum sont fournies, pour ne
# pas enregistrer de mauvaises valeurs.
# 
def check
  # 
  # Si tout est bon, on peut merger avec les nouvelles données
  # 
  if confirm_prov_data
    if debug? || verbose?
      puts "\nconfirm_prov_data retourne true".bleu
      sleep 1
    end

    # 
    # Quelques modifications des données en fonction des nouvelles
    # données
    # 
    if data[:start] != edit_data[:start] && data[:start_notified]
      data.delete(:start_notified)
    end
    if data[:end] != edit_data[:end] && data[:end_notified]
      data.delete(:end_notified)
    end

    #
    # Pour éviter le travail inutile, on supprime de :edit_data
    # les données inchangées
    # 
    edit_data.each do |k, v|
      next if k == :prev
      edit_data.delete(k) if edit_data[k] == data[k]
    end

    #
    # Il faut faire un premier traitement dans le cas où :end
    # est défini, car cette propriété n'existe plus que pour 
    # l'édition. Elle doit être transformée en :start en fonction
    # de la durée. Noter que si la durée n'est pas définie, et que le
    # temps de départ non plus, alors on prend
    # le :start à maintenant et on calcule la durée jusqu'à la date
    # de fin
    # 
    if edit_data.key?(:end)
      sduree = edit_data[:duree]||data[:duree]
      etime  = date_from(edit_data.delete(:end))
      if sduree
        edit_data.merge!(start: (etime - Tache.calc_duree_seconds(sduree)).jj_mm_aaaa_hh_mm)
      elsif edit_data[:start]
        st = date_from(edit_data[:start])
        jrs = ((etime - st)/JOUR).round
        edit_data.merge!(duree: "#{jrs}d")
      elsif data[:start]
        st = date_from(data[:start])
        jrs = ((etime - st)/JOUR).round
        edit_data.merge!(duree: "#{jrs}d")
      else
        edit_data.merge!(
          # start: _NOW_,
          start: _NOW_.jj_mm_aaaa,
          duree: "#{((etime - _NOW_)/JOUR).round}d"
        )
      end
    end

    # 
    # Pour traiter plus tard le changement d'identifiant, il faut
    # mémoriser le nouvel identifiant.
    # 
    new_id = edit_data.key?(:id) ? edit_data.delete(:id) : nil

    # 
    # Avant de merger, on traite les changements de liaisons
    # (car on a besoin de connaitre) les liaisons actuelles avant
    # de les modifier
    # 
    traite_links

    # 
    # Un ultime check pour s'assurer qu'il n'y aura
    # pas de boucle infinie
    # 
    Tache.avoid_infinite_tasks_loop

    # 
    # Actualisation nécessaire des prev_id
    # 
    Tache.set_taches_prev

    # 
    # On peut supprimer l'éventuel propriété :prev
    # 
    # Note debug : si ici :edit_data se retrouve avec
    # la valeur nil, c'est que dans la méthode traite_links plus
    # haut on a sauvé la tâche courante ce qui provoque la remise à
    # rien de edit_data. Attention, ça peut être un effet pervers de
    # tache.de.tache qui se trouve être la tâche elle-même.
    # 
    edit_data.delete(:prev) if edit_data.key?(:prev)

    #
    # On n'a pas besoin de la propriété :parallels qui ne
    # sert que pour afficher les parallèles.
    # 
    edit_data.delete(:parallels)
    
    #
    # S'il faut déparalléliser la tâche
    # 
    if edit_data.delete(:deparallelize)
      deparallelize(sauver = :all_but_me)
    end

    # 
    # S'il faut paralléliser la tâche
    # 
    # Note : pour un modèle, il faut le faire après, sinon
    # la tâche n'est peut-être pas encore créée
    #
    if edit_data.key?(:parallelize_with)
      @new_parallel_task = edit_data.delete(:parallelize_with) || :none
      traiter_new_parallel_task if not(in_model?)
    else
      @new_parallel_task = nil
    end

    # Serviront pour l'actualisation des tâches parallèles en cas
    # de changement de temps (cf. plus bas)
    edata4paral = edit_data.dup

    # 
    # MERGE DES NOUVELLES DONNÉES avec les données actuelles
    #
    # Noter que :edit_data ne contient QUE les données actualisées
    # et rien d'autre
    # 
    data.merge!(edit_data) if not(edit_data.empty?)

    #
    # Traiter un changement d'identifiant (impact sur le fichier)
    #
    new_id && Tache.traite_changement_id(self, new_id)

    # 
    # Pour tout recalculer en cas de changement
    #
    # ATTENTION : ne surtout pas le mettre avant le traitement de
    # changement d'identifiant (ci-dessus), car cela ferait perdre
    # le prev_id dont on a besoin pour changer éventuellement le
    # :suiv de la tâche précédente.
    reset

    # 
    # Actualisation à nouveau des prev_id (seulement pour le
    # reset précédent…)
    # 
    Tache.set_taches_prev

    #
    # Actualisation immédiate de toutes les valeurs de temps
    # pour les tâches parallèles, précédentes et suivantes
    # 
    if edata4paral[:start] || edata4paral[:duree]
      start_has_changed = edata4paral.key?(:start)
      duree_has_changed = edata4paral.key?(:duree)

      stime = date_from(edata4paral[:start]||data[:start])
      dur   = edata4paral[:duree]||data[:duree]

      cdata = edata4paral.dup # car save efface edit_data

      if parallel? && start_has_changed
        parallelized_tasks.each do |tk|
          tk.set_start_time(cdata[:start])
        end
      end
    end


    clear

    return self
  else
    if debug?||verbose?
      puts "confirm_prov_data retourne false".bleu
      sleep 2
    end
  end
end

def set_start_time(time)
  time = time.jj_mm_aaaa_hh_mm if time.is_a?(Time)
  set(:start, time)
end

def set_duree(sduree)
  set(:duree, sduree)
end

def set(prop, value)
  data.merge!(prop => value)
  save.reset
end

#
# @return TRUE si les données contenues dans edit_data sont conformes
# aux attentes.
# La méthode est appelée aussi bien lors d'une validation finale 
# avant enregistrement que lors de toute modification de propriété
# sensible.
# 
def confirm_prov_data(prop = nil)
  pd = edit_data.dup
  # pd.each do |k,v| v = nil if v == UNDEFINED end
  (pd[:todo]||data[:todo]).nil? && raise(ERRORS[:todo_is_required])
  # 
  # Les vérifications dans le cas d'un changement de temps
  # 
  if pd[:start] || pd[:end] || pd[:duree]
    # Tout d'abord, si :start et :end sont déjà définis et
    # que :duree est redéfini, on supprime le :end
    stime = pd[:start] || data[:start]
    etime = pd[:end]   || data[:end]
    dtime = pd[:duree] || data[:duree]
    if stime && etime && dtime
      edit_data.merge!(end: nil)
      etime = nil
    end
    stime = date_from(stime) if stime
    etime = date_from(etime) if etime
    if stime && etime
      stime < etime || begin
        edit_data[prop||:end] = nil
        raise(ERRORS[:end_before_start])
      end
      if dtime
        sduree = Tache.calc_duree_seconds(dtime)
        etime.to_i - stime.to_i == sduree || begin
          edit_data[prop||:duree] = nil
          if prop == :duree
            raise(ERRORS[:duree_doesnt_match])
          else
            raise(ERRORS[:time_doesnt_match_with_duree])
          end
        end
      end
    end

    #
    # Si la tâche éditée possède une tâche suivante et qu'il y a
    # un changement de temps
    # 
    if (suivante = Tache.get(edit_data[:suiv]||data[:suiv]))
      if stime
        if suivante.start_time && stime > suivante.start_time
          raise(ERRORS[:cant_start_after_next_task])
        end
        if suivante.end_time && stime > suivante.end_time
          raise(ERRORS[:cant_start_after_next_task])
        end
      end
      if etime
        if suivante.start_time && etime > suivante.start_time
          raise(ERRORS[:cant_end_after_next_task])
        end
        if suivante.end_time && etime > suivante.end_time
          raise(ERRORS[:cant_end_after_next_task])
        end
      end
    end
    if (precedente = Tache.get(edit_data[:prev]||prev_id))
      if stime
        if precedente.start_time && stime < precedente.start_time
          raise(ERRORS[:cant_start_before_prev_task])
        end
        if precedente.end_time && stime < precedente.end_time
          raise(ERRORS[:cant_start_before_prev_task])
        end
      end
      if etime
        if precedente.end_time && etime < precedente.end_time
          raise(ERRORS[:cant_end_before_prev_tast])
        end
        if precedente.start_time && etime < precedente.start_time
          raise(ERRORS[:cant_end_before_prev_tast])
        end
      end
    end

  end #/fin de si un changement de temps
rescue Exception => e
  msg = e.message
  puts msg.rouge
  if debug? # || test?
    puts e.backtrace.join("\n").rouge
    # exit 1 if test?
  end
  return false
else
  return true  
end

def edit_todo
  edit_data.merge!(todo: ask_or_null("À faire :", default:edit_data[:todo]||data[:todo]))
  confirm_prov_data || return
end
def edit_cate
  cate = Tache.choose_categorie("Une catégorie", enable_new: true) || return
  edit_data.merge!(cate: cate)
end
def edit_scate
  edit_data.merge!(titre: ask_or_null("Sous-catégorie optionnelle :", default:edit_data[:scate] || data[:scate]))
end
def edit_id
  edit_data.merge!(id: ask_or_null("Identifiant (si tâche liée) :", default: edit_data[:id] || data[:id]))
end
def edit_start
  edit_data.merge!(start: ask_for_a_date_with_time("Commence le… à…"))
  confirm_prov_data(:start) || begin
    edit_data.delete(:start)
    return
  end
end
def edit_end
  for_data_end = ask_for_a_date_with_time("Doit être terminée pour le… à…")
  edit_data.merge!(end: for_data_end)
  confirm_prov_data(:end) || begin
    edit_data.delete(:end)
    return
  end
end

#
# Édition de la durée
# 
# C'est un traitement spécial dans le sens où on peut, avec cette
# méthode, définir la durée autant que procéder à un ajout/retrait
# de temps. Et même définir une durée variable pour un modèle de 
# suite de tâches.
# 
# Les différentes situations :
#   * rien n'est défini, ni :duree, ni :start, ni :end
#     => le menu pour retirer ou ajouter n'apparaissent pas
#   * un :start ou/et un :end est défini
#     => le menu "ajout/retrait" apparait et l'utilisateur
#        peut choisir toutes les unités
#   * une :duree est défini
#     => Les menus ajout/retrait apparait 
#        Quand l'un des deux apparait, on passe à la quantité
#        pour définir l'ajout de même unité
# 
def edit_duree
  sign_add = nil
  menu_unites = TTY_UNITES.dup
  if duree != '%'
    if end_defined? || duree_defined?
      menu_unites.insert(0, {name:'Pour un retrait',  value: :sub})
      menu_unites.insert(0, {name:'Pour un ajout',    value: :add})
    end
  end
  if in_model?
    # Si la tâche appartient à un modèle de suite de tâches
    menu_unites.insert(0, {name:'Durée variable (pour modèle)',  value: :variable})
  end
  # ecrit("menu_unites: #{menu_unites.inspect}")
  while true
    add_question = 
      if sign_add == :add
        " (POUR AJOUT)"
      elsif sign_add == :sub
        " (POUR RETRAIT)"
      else
        ''
      end
    # 
    # Définition de l'unité (ou "variable" pour modèle)
    # 
    unite_duree = Q.select("Unité de durée#{add_question} : ".jaune, menu_unites, per_page:TTY_UNITES.count, show_help:false)
    for_ajout_ou_retrait = [:add, :sub].include?(unite_duree)
    # ecrit "unite_duree: #{unite_duree.inspect}"
    if unite_duree == :variable
      edit_data.merge!(duree: '%')
      return true
    elsif for_ajout_ou_retrait
      if duree
        sign_add    = unite_duree
        unite_duree = Tache.decompose_duree(duree)[:unite]
        break
      else
        # Quand les temps sont définis, on va pouvoir choisir 
        # n'importe quelle unité
        sign_add = sign_add == unite_duree ? nil : unite_duree
      end
    else
      break
    end
  end
  prov_duree =
    unless unite_duree.nil?
      question = "Combien de #{HUNITES[unite_duree]}s"
      case sign_add
      when :add
        question = "#{question} doit-on ajouter"
      when :sub
        question = "#{question} doit-on retirer"
      end
      quan_duree = ask_or_null("#{question} ?") || return
      unless quan_duree.nil?
        "#{quan_duree}#{unite_duree}"
      end
    end
  # 
  # Si c'est un retrait ou une durée
  # 
  # puts "sign_add: #{sign_add.inspect}".jaune
  # puts "prov_duree : #{prov_duree.inspect}".jaune
  case sign_add
  when :add
    ajoute_duree(duree, prov_duree)
  when :sub
    retire_duree(duree, prov_duree)
  else
    edit_data.merge!(duree: prov_duree)
  end
  confirm_prov_data || return
end

# Une des difficultés est le fait que la quantité peut avoir une
# unité différente de la durée initiale…
def ajoute_duree(duree_init, duree_new, operator = :+)
  if duree_init
    # Quand c'est la durée qui est définie (même si le :start)
    # est défini
    hduree = Tache.decompose_duree(duree_init)
    hnew   = Tache.decompose_duree(duree_new)
    quantite = hduree[:quant].send(operator, hnew[:quant])
    edit_data.merge!(duree: "#{quantite}#{hduree[:unite]}")
  elsif end_defined?
    # Quand c'est le :end qui est défini
    secondes_add = Tache.calc_duree_seconds(duree_new)
    new_time = date_from(edit_data[:end] || data[:end]).send(operator, secondes_add)
    edit_data.merge!(end: new_time.jj_mm_aaaa_hh_mm)
  elsif start_defined?
    # Quand c'est le :start qui est défini, seul, on n'a que besoin
    # de jouer sur la durée
    edit_data.merge!(duree: duree_new)
  else
    raise "Impossible d'ajouter ou de retirer du temps (ni :start ni :end n'est défini)…"
  end
end

def retire_duree(duree_init, quantite)
  return ajoute_duree(duree_init, quantite, :-)
end

# @return true si le :start/:end est défini, soit déjà, soit au cours
# de l'édition
def start_defined?
  edit_data[:start]||data[:start]
end

def end_defined?
  edit_data[:end]||data[:end]
end

def duree_defined?
  edit_data[:duree]||data[:duree]
end

# Permet de définir la fréquence de rappel de la tâche.
# 
#   rappel tous les (heures/jours/semaines/mois/année)
#   à un jour/heures précise
#   OU liste de dates
# 
# Si c'est une liste de dates, la propriété :rappel sera une liste
# array avec les dates exprimées par 'JJ/MM/AAAA HH:MM'
# Sinon, c'est un String composé de :
#   '<type fréquence>::<jour ou indice>/<HH:MM>'
# Le contenu exact dépend de chaque fréquence :
#   Pour une fréquence jour ('d' => tous les jours à…) :
#       'xd::HH:MM'
#   Pour une fréquence semaine ('1w')
#       'xw::<indice du jour lundi = 1>/HH:MM'
#   Pour un mois ('1s')
#       'xs::<numéro jour du moi>/HH:MM'
#   Pour une heure ('h' => "toutes les heures à…")
#       'xh::<minute de l’heure>'
#   Pour les années ('y')
#       'y::JJ/MM/AAAA HH:MM'
# 
def edit_rappel
  rap = nil
  case Q.select("Rappel".jaune) do |q|
      rap_frequences = [
        {name:'par fréquence (tous les jours, tous les mois…)', value: :frequence},
        {name:'par liste de dates précises', value: :dates},
        {name:'Pas de rappel', value: nil}
      ]
      q.choices rap_frequences
      q.per_page rap_frequences.count
    end
  when :frequence
    Q.select("Rappeler…".jaune) do |q|
      q.choice 'tous les x JOURS à…',     'd'
      q.choice 'tous les x SEMAINES le…', 'w'
      q.choice 'tous les x MOIS le…',     's'
      q.choice 'tous les x HEURES à…',    'h'
      q.choice 'tous les x MINUTES',      'm'
      q.choice 'tous les x ANNÉES le…',   'y'
      q.per_page 6
    end.tap do |ufreq|
      # puts "ufreq : #{ufreq.inspect}"
      #
      # Le nombre de jours (tous les nb jours) de semaines (toutes
      # les nb semaines) etc.
      nb = Q.slider("Tous les combiens de #{HUNITES[ufreq]}s", default:1, min:1, max:52)
      moment =
        case ufreq
        when 'h' # toutes les heures
          Q.slider("À quelle minute de l'heure ?".jaune, min:0, max:59, default: 0)
        when 'w' # toutes les semaines
          ijour = choisir_indice_jour_semaine   || return
          heure = choisir_une_heure             || return
          "#{ijour} #{heure}"
        when 'd'
          choisir_une_heure || return
        when 's' # mois
          ijour = choisir_indice_jour_mois  || return
          heure = choisir_une_heure         || return
          "#{ijour} #{heure}"
        when 'm' # minutes
          ''
        when 'y'
          ijour = choisir_jour_annee  || return
          heure = choisir_une_heure   || return
          "#{ijour} #{heure}"
        end
      rap = "#{nb}#{ufreq}::#{moment}"
    end
  when :dates
    rap = []
    while true
      rap << ask_for_a_date_with_time("Rappeler la tâche le :".jaune) || break
    end
  end
  edit_data.merge!(rappel: rap)
end

def edit_prev(prevtask = :undefined) # prevtask (pour les tests)
  pms = {none:true, per_page:10, categorie: edit_data[:cate] || data[:cate]}
  if prevtask == :undefined
    if prev_id && Q.yes?("Voulez-vous supprimer le lien avec la tâche précédente « #{prev.todo} » ?".jaune)
      prevtask = nil
    else
      prevtask = Tache.choose("Tâche avant « #{edit_data[:todo]||data[:todo]} »", pms) || return
    end
  end
  if prevtask && parallel?
    if parallels.include?(prevtask.id)
      puts "C'est une tâche parallèle. On ne peut pas la choisir comme tâche précédente.".rouge
      return
    end
  end
  if self.before?(prevtask)
    puts "la tâche précédente ne peut pas commencer après."
    return
  end
  edit_data.merge!(prev: prevtask ? prevtask.id : nil)
end

def edit_suiv(suivtask = :undefined) # suivtask pour les tests
  pms = {none:true, per_page:10,categorie: edit_data[:cate] || data[:cate]}
  if suivtask == :undefined
    if data[:suiv] && Q.yes?("Voulez-vous supprimer le lien avec la tâche suivante « #{suiv.todo} » ?".jaune)
      suivtask = nil
    else
      suivtask = Tache.choose("Tâche après « #{edit_data[:todo] || data[:todo]} »", pms) || return
    end
  end
  # On ne peut pas choisir une tâche parallèle
  if suivtask && parallel?
    if parallels.include?(suivtask.id)
      puts "C'est une tâche parallèle. On ne peut pas la choisir comme tâche suivante.".rouge
      return
    end
  end
  if self.after?(suivtask)
    puts "la tâche suivante ne peut pas commencer avant."
    return
  end
  edit_data.merge!(suiv: suivtask ? suivtask.id : nil)
end

# Pour éditer les tâches parallèles
def edit_parallels(paratask = :undefined) # paratask pour les tests
  pms = {none:true, per_page:10, categorie: edit_data[:cate] || data[:cate]}
  # 
  # Pour choisir la tâche si elle n'est pas définie (par les tests)
  # 
  if paratask == :undefined
    paratask = 
      if in_model?
        Model.choose_task_of_model(data[:model_id],'Tâche parallèle')        
      else
        Tache.choose("Tâche parallèle à la tâche « #{edit_data[:todo] || data[:todo]} »", pms) || return
      end
  end
  if paratask.nil? && self.parallel?
    # Note : la valeur nil signifie qu'il faut déparalléliser la tâche
    edit_data.merge!(deparallelize: true)
  elsif paratask
    begin
      # On ne peut pas choisir la tâche elle-même
      if paratask.id == id
        raise BadDataError.new "On ne peut pas paralléliser la tâche avec elle-même, voyons…"
      end
      # On ne peut pas choisir la tâche précédente
      if prev_id && paratask.id == prev_id
        raise BadDataError.new "On ne peut pas choisir comme parallèle la tâche précédente."
      end
      # On ne peut pas choisir la tâche suivante
      if (edit_data[:suiv]||data[:suiv]) == paratask.id
        raise BadDataError.new "On ne peut pas choisir comme parallèle la tâche suivante."
      end
      if paratask.id == id
        raise BadDataError.new "On ne peut pas choisir comme parallèle la tâche elle-même."
      end
      if not(parallel?) || not(parallels.include?(paratask.id))
        edit_data.merge!(parallelize_with: paratask)
        edit_data.merge!(parallels: (parallels||[]))
        # Juste pour pouvoir les afficher dans l'éditeur
        paras = (data[:parallels]||[]) + (edit_data[:parallels]||[])
        paras << paratask.id
        edit_data.merge!(parallels: paras)
      end
    rescue BadDataError => e
      puts e.message.rouge
      sleep 3 unless test?
      return nil
    end
  end
end

def edit_detail
  # 
  # Tty-prompt a un bug qui empêche de mettre la valeur par défaut
  # On écrit la description actuelle pour la voir (on pourra toujours
  # faire un copié-collé)
  # 
  if edit_data[:detail] || data[:detail]
    puts "Description actuelle :\n#{(edit_data[:detail] || data[:detail])}"
  end
  desc = Q.multiline("Détail de la tâche", **{default: (edit_data[:detail] || data[:detail])})
  case desc
  when NilClass
  when Array
    edit_data.merge!(detail: desc.join(''))
  end
end

def edit_open
  while true
    openit = ask_or_null("Fichier ou dossier à ouvrir en cliquant sur la tâche :") || return
    edit_data.merge!(open: openit)
    return if edit_data[:open].nil? || File.exist?(edit_data[:open])
    puts "Ce lieu est introuvable…".rouge
  end
end
def edit_exec
  code = Q.multiline("Code à exécuter à l'échéance de la tâche :".jaune)
  code = code.join("\n") if code.is_a?(Array)
  edit_data.merge!(exec: code.strip)
  edit_data.delete(:exec) if edit_data[:exec] == ''
end
def edit_app
  appchosen = Q.select("Icône de quelle application ?") do |q|
    q.choices APPLICATIONS
    q.per_page 10
  end
  appchosen = ask_or_null("ID de l'application (consulter le manuel)") if appchosen == :other
  edit_data.merge!(app: appchosen)
end

def choisir_une_heure
  while true
    errs = []
    h = Q.ask("\rÀ quelle heure ? (H:MM)".jaune, default: '10:00') rescue nil
    /^[0-9]?[0-9](:[0-9][0-9])?$/.match?(h) || errs << 'Le format d’heure n’est pas valide ([H]H:MM)'
    if errs.empty?
      hs,ms = h.split(':')
      ms = '00' if ms.nil?
      h = "#{hs}:#{ms}"
      hs.numeric? || errs << 'L’heure doit être un nombre.'
      ms.numeric? || errs << 'Les minutes doivent être un nombre.'
      hs.to_i.between?(0,23) || errs << 'L’heure doit être comprise entre 0 et 23.'
      ms.to_i.between?(0,59) || errs << 'Les minutes doivent être comprises entre 0 et 59.'
    end
    return h if errs.empty?
    puts errs.join("\n").rouge
  end
end

def choisir_indice_jour_semaine
  Q.slider("Jour de la semaine", {'Lundi' => 1,'Mardi' => 2,'Mercredi' => 3,'Jeudi'=>4,'Vendredi'=>5,'Samedi'=>6,'Dimanche'=>7}, default:'Lundi') rescue nil
end

def choisir_indice_jour_mois(max = 28)
  Q.slider("Jour du mois", min:1, max:max, default:1) rescue nil
end

def choisir_jour_annee
  imois = Q.slider("Mois", 
    {'Janvier'=>1,'Février'=>2,'Mars'=>3,'Avril'=>4,'Mai'=>5,'Juin'=>6,'Juillet'=>7,'Aout'=>8,'Septembre'=>9,'Octobre'=>10,'Novembre'=>11,'Décembre'=>12},
    default:'Janvier'
  ) rescue nil
  max_mois = [nil,31,28,31,30,31,30,31,31,30,31,30,31][imois]
  ijour = choisir_indice_jour_mois(max_mois)
  "#{ijour.to_s.rjust(2,'0')}/#{imois.to_s.rjust(2,'0')}"
end

def ask_for_a_date_with_time(question)
  Tache.ask_for_a_date_with_time(question)
end

def self.ask_for_a_date_with_time(question)
  while true
    unedate = ask_or_null("#{question} (JJ/MM[/AAAA][ HH:MM]) :") || return
    unedate = replace_dim_in_date(unedate) # les 'auj', 'dem', etc.
    hdate = date_from_with_time(unedate)
    if hdate
      return hdate[:date_str]
    else
      puts "Date mal formatée.".rouge
    end
  end
rescue TTY::Reader::InputInterrupt => e
  puts "TTY interrompu#{" (ajouter l'objet -v pour avoir le détail)" unless verbose?}".rouge
  verbose? && puts(e.backtrace.join("\n").rouge)
end

REG_LETTRE = /[a-z]/
DIMS_DATE_TO_PROC = {
  /(auj|today)/ => ->{_NOW_.jj_mm_aaaa},
  /(demain|tomorrow|tom|dem)/ => ->{_NOW_.plus(1).jours.jj_mm_aaaa},
  /(hier|yesterday)/ => ->{_NOW_.moins(1).jours.jj_mm_aaaa},
  /(lundi|lun|monday|mon)/ => ->{lundi.jj_mm_aaaa},
  /(mardi|mar|tuesday|tues)/ => ->{mardi.jj_mm_aaaa},
  /(mercredi|mer|wednesday|wed)/ => ->{mercredi.jj_mm_aaaa},
  /(jeudi|jeu|thursday|thur)/ => ->{jeudi.jj_mm_aaaa},
  /(vendredi|ven|friday|fri)/ => ->{vendredi.jj_mm_aaaa},
  /(samedi|sam|saturday|sat)/ => ->{samedi.jj_mm_aaaa},
  /(dimanche|dim|sunday|sun)/ => ->{dimanche.jj_mm_aaaa},
}

def self.replace_dim_in_date(strd)
  # puts "\n-> replace_dim_in_date(#{strd.inspect})"
  DIMS_DATE_TO_PROC.each do |dimdate, procdate|
    strd = strd.sub(dimdate, procdate.call)
    return strd unless REG_LETTRE.match?(strd)
  end

  return strd
end

def self.acheve_tache(tache)
  tache.data.merge!(done_at: _NOW_.jj_mm_aaaa_hh_mm)
  tache.save
  path_archive = File.join(folder_archives,"#{tache.id}.yaml")
  FileUtils.move(tache.path, path_archive)
  return !File.exist?(tache.path) && File.exist?(path_archive)
end

TTY_UNITES = [
  {name:'minute'          ,value:'m'},
  {name:'heure'           ,value:'h'},
  {name:'jour'            ,value:'d'},
  {name:'mois'            ,value:'s'},
  {name:'semaine'         ,value:'w'},
  {name:'année'           ,value:'y'},
  {name:'Pas de durée'    ,value: nil}
]
HUNITES = {}
TTY_UNITES.each do |du|
  HUNITES.merge!(du[:value] => du[:name])
end

APPLICATIONS = [
  {name:'MyTaches'            ,value:'phil.app.MyTaches'},
  {name:'MonFlux'             ,value:'com.fluidapp.FluidApp2.MonFlux'},
  {name:'Safari'              ,value:'com.apple.Safari'},
  {name:'Text Edit'           ,value:'com.apple.TextEdit'},
  {name:'Typora'              ,value:'abnerworks.Typora'},
  {name:'Icare'               ,value:'phil.app.Icare'},
  {name:'Affinity Publisher'  ,value:'com.seriflabs.affinitypublisher'},
  {name:'Aperçu'              ,value:'com.apple.Preview'},
  {name:'Calculette'          ,value:'com.apple.calculator'},
  {name:'Calendrier'          ,value:'com.apple.iCal'},
  {name:'Firefox'             ,value:'org.mozilla.firefox'},
  {name:'Google Driver'       ,value:'com.google.drivefs'},
  {name:'Kindle/KDP'          ,value:'com.amazon.Kindle'},
  {name:'Mail'                ,value:'com.apple.mail'},
  {name:'Maison'              ,value:'com.apple.Home'},
  {name:'Messages'            ,value:'com.apple.MobileSMS'},
  {name:'Musique'             ,value:'com.apple.Music'},
  {name:'Notes'               ,value:'com.apple.Notes'},
  {name:'Pages'               ,value:'com.apple.iWork.Pages'},
  {name:'Rappels'             ,value:'com.apple.reminders'},
  {name:'Screenflow'          ,value:'net.telestream.screenflow10'},
  {name:'Scrivener'           ,value:'com.literatureandlatte.scrivener3'},
  {name:'Skype'               ,value:'com.skype.skype'},
  {name:'Sublime Text'        ,value:'com.sublimetext.4'},
  {name:'Xcode'               ,value:'com.apple.dt.Xcode'},
  {name:'Terminal'            ,value:'com.apple.Terminal'},
  {name:'Préférences'         ,value:'com.apple.systempreferences'},
  {name:'Autre…'              ,value: :other}
]

end #/class Tache
end #/module MyTaches
