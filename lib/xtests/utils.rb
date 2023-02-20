# encoding: UTF-8
# frozen_string_literal: true

MODE_TEST = true

# Pour définir les paramètres de la ligne de commande
def set_argv(ary)
  ary = [ary] unless ary.is_a?(Array)
  ARGV.clear 
  ary.each do |e| ARGV << e end
end

# Pour redéfinir la valeur de _NOW_, ce qui permet de faire des
# tests dans le futur, dans le passé, etc.
# Note : quelle que soit la valeur on met toujours les secondes à 0
def redefine_now(jour = nil)
  jour ||= Time.now.at('0:00')
  TheNow.now = jour.adjust(sec:0)
end

##
# @return {String} Le contenu du journal de bord du cron
# 
def cron_log
  if File.exist?(MyTaches.cronlog_path)
    File.read(MyTaches.cronlog_path)
  else
    ''
  end
end

# Pour détruire toutes les tâches créées pour les tests
def reset_taches
  File.delete(MyTaches.cronlog_path) if File.exist?(MyTaches.cronlog_path)
  MyTaches::Tache.reset
  MyTaches::Model.reset
  if MyTaches::Tache.taches_folder.match?('TEST')
    [
      MyTaches::Tache.taches_folder,
      MyTaches::Model.taches_folder,
      MyTaches::Model.models_folder,
      MyTaches::ArchivedTache.folder,
    ].each do |pth|
      `rm -rf "#{pth}"`
      `mkdir -p "#{pth}"`
    end
  else
    raise "Il y a un problème avec le test… Le dossier des tâches n'est pas le bon…".rouge
  end
end

def get_tache(tkid)
  MyTaches::Tache.get(tkid)
end
def get_taches(ary)
  ary.map do |tkid| get_tache(tkid) end
end

# @return Array de Mytaches::Tache, liste des tâches
# courantes
def all_taches(params = nil)
  MyTaches::Tache.all(params)
end

# Instance une tâche valide avec les données
# +dtache+
# Par défaut, elle n'est pas sauvée
def tache(dtache = nil, saveit = false)
  dtache ||= {}
  dtache.key?(:todo) || dtache.merge!(todo: "Tâche #{(Time.now + rand(100000)).to_i}")
  if dtache.key?(:start) && dtache[:start].is_a?(Time)
    dtache.merge!(start: dtache[:start].jj_mm_aaaa_hh_mm)
  end
  if dtache.key?(:end) && dtache[:end].is_a?(Time)
    dtache.merge!(end: dtache[:end].jj_mm_aaaa_hh_mm)
  end
  i = MyTaches::Tache.new(dtache)
  MyTaches::Tache.add(i)
  i.save if saveit
  return i
end

# Crée x tâches liées (dans l'ordre) en faisant les checks
# préliminaires
def create_x_taches_linked(x, params = nil)
  tks = create_taches(x, params || {})
  tka, tkb, tkc = tks
  (0...x-1).each do |idx|
    tks[idx].link_to(tks[idx + 1])
  end
  tks.each { |tk| tk.save }
  MyTaches::Tache.set_taches_prev

  # * check préliminaire *
  (0...x).each do |idx|
    if idx > 0
      assert_equal(tks[idx - 1].id, tks[idx].prev_id)
      assert_true(tks[idx].prev?)
    end
    if idx < x - 1
      assert_true(tks[idx].suiv?)
      assert_equal(tks[idx + 1].id, tks[idx].suiv.id)
      assert_true(tks[idx].suiv?)
    end
  end

  return tks
end

def create_taches_with_time_et_duree(nb = 10, params = nil)
  taches = create_taches(nb, params)
  assert_equal(nb, all_taches.count)
  assert_equal(MyTaches::Tache, taches.first.class)
  taches[0].tap do |tk|
    tk.data.merge!(
      cate:  'aaa',
      start:  _NOW_.moins(4).jours.jj_mm_aaaa,
      duree:  '10d'
    )
  end
  taches[1].tap { |tk|
    tk.data.merge!(
      cate:  'aaa',
      start:  _NOW_.plus(1).jours.jj_mm_aaaa
      # durée implicite : 1 jour
    )
  }
  if nb > 2
    taches[2].tap { |tk|
      tk.data.merge!(
        cate:  'aaa',
        start:  _NOW_.moins(7).jour.jj_mm_aaaa,
        duree:  '8d'
      )
    }
  end
  if nb > 3
    taches[3].tap { |tk|
      tk.data.merge!(
        cate:  'bbb',
        start: _NOW_.moins(7).jours.plus(120).secondes.jj_mm_aaaa,
        duree: '2s'
      )
    }
  end
  if nb > 4
    taches[4].tap { |tk|
      tk.data.merge!(
        cate:  'aaa',
        start: _NOW_.plus(1).minute.jj_mm_aaaa,
        duree: '1s'
      )
    }
  end
  if nb > 5
    taches[5].tap { |tk|
      tk.data.merge!(
        cate:  'ccc',
        # start implicit : nil
        duree: '3d'
      )
    }
  end
  if nb > 6
    taches[6].tap { |tk|
      tk.data.merge!(
        cate:  'aaa',
        # start implicit : nil
        duree: '10s'
        # end implicit : nil
      )
    }
  end
  if nb > 7
    taches[7].tap { |tk|
      tk.data.merge!(
        cate:  'aaa',
        # start implicit : nil
        # end implicit : nil
      )
    }
  end
  if nb > 8
    taches[8].tap { |tk|
      tk.data.merge!(
        cate:  'bbb',
        # start implicit : nil
        # end implicit : nil
      )
    }
  end
  if nb > 9
    taches[9].tap { |tk|
      tk.data.merge!(
        cate:  'ccc',
        # start implicit : nil
        # end implicit : nil
      )
    }
  end
  
  return taches      
end

# Instancie une tâche de modèle avec les données +dtache+
# Rappel : une tâche de modèle est une instance MyTache::Model::Tache
# qui hérite de MyTaches::Tache
# 
# @return L'instance de la tâche créée
# 
def tache_model(dtache, saveit = false)
  dtache.key?(:todo) || dtache.merge!(todo: "Tâche #{(Time.now + rand(100000)).to_i}")
  i = MyTaches::Model::Tache.new(dtache)
  i.save if saveit
  return i  
end


# Pour créer des tâches de types todo:"Tâche n°1", id:'t1'
# 
# @param  params {Hash}
#     Si :index est true, on indexe les identifiants dans l'ordre,
#     Sinon, on prend des identifiants au hasard
def create_taches(nombre, params = nil)
  params ||= {}
  id_equal_index = params.delete(:index) === true
  reset_taches if params[:reset]
  nombre.times.map do |i|
    id  = id_equal_index ? "t#{i}" : get_new_id_tache
    idx = id_equal_index ? "n°#{i}"  : "##{id}"
    task_data = {todo:"Tâche #{idx}", id:"#{id}", cate: (params[:categorie]||params[:cate])}
    MyTaches::Tache.new(task_data).save.tap do |tk|
      MyTaches::Tache.add(tk)
    end
  end
end

def get_new_id_tache
  while true
    alea = 100 + rand(1000000)
    nid = "TK#{alea}"
    pth = File.join(MyTaches::Tache.taches_folder,"#{nid}.yaml")
    return nid unless File.exist?(pth)
  end
end

def hdate(time)
  time.strftime('%d/%m/%Y %H:%M')
end


def get_uniq_model_id
  idmdl = nil
  while true
    alea  = 100 + rand(100000)
    idmdl = "MTK#{alea}"
    p = File.join(MyTaches::Model.models_folder,"#{idmdl}.yaml")
    File.exist?(p) || break
  end
  return idmdl 
end

##
# Création d'un modèle
# 
# @param data {Hash} Les données à utiliser
#         si Nil, un modèle simple sera créé, avec quelques
#         tâches.
# 
def create_modele(data = nil)
  not(data.nil?) || begin
    idmdl = get_uniq_model_id
    data = {
      id:   idmdl,
      name: "Le modèle #{idmdl}",
      categorie: "Une catégorie pour #{idmdl}",
      taches_ids: ["#{idmdl}-001","#{idmdl}-002","#{idmdl}-003"]
    }
  end

  # ID du modèle
  data.key?(:id) || data.merge!(id: get_uniq_model_id)

  data_taches = data.delete(:data_taches) || {}

  # On doit retirer les tâches (qui seront ajoutées
  # au modèle par la méthode add_tache)
  taches_ids = data.delete(:taches_ids) || begin
    ["#{data[:id]}-001","#{data[:id]}-002","#{data[:id]}-003"]
  end

  # ON instancie le modèle de suite de tâche
  new_model = MyTaches::Model.new(data)

  # On crée les tâches
  taches_ids.each do |tache_id|
    data_tache = data_taches[tache_id] || {}
    data_tache.merge!(id: tache_id)
    data_tache[:todo] ||= "Tâche #{tache_id}"
    tk = tache_model(data_tache)
    new_model.add_tache(tk)
    tk.save
  end

  new_model.save(not(data.key?(:dynamic_values)))

  # Actualiser (notamment pour que Model::all soit à jour)
  MyTaches::Model.reset

  return new_model
end
alias :create_model :create_modele

def make_4_taches_et_currente
   reset_taches
   tkav  = tache(todo:"T1", id:'tkav', suiv: 'ct')
   ct    = tache(todo:"CT", id:'ct', suiv:'tkap')
   tkap  = tache(todo:'T2', id:'tkap')
   t3    = tache(todo:'T3', id:'t3')
   t4    = tache(todo:'T4', id:'t4')
   MyTaches::Tache.set_taches_prev
   return [ct, tkav, tkap, t3, t4]      
 end

def rappel(arg)
  MyTaches::Rappel.new(arg)
end

def now_at(heure)
  h,m,s = heure.split(':').map{|n|n.to_i}
  Time.new(_NOW_.year,_NOW_.month,_NOW_.day,h,m,0)
end


