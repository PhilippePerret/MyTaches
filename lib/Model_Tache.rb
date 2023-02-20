# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class MyTaches::Model::Tache
  ----------------------------
  Gestion des tâches qui appartiennent à des modèles de suite
  de tâche, principalement (exclusivement ?) pour l'édition

=end
module MyTaches
class Model
class Tache < MyTaches::Tache

  def self.count # pour les tests
    Dir["#{Model.taches_folder}/*.yaml"].count
  end

  def self.get(id)
    @@table ||= {}
    @@table[id] || begin
      pth = File.join(Model.taches_folder,"#{id}.yaml")
      if File.exist?(pth)
        inst = new(YAML.load_file(pth))
        @@table.merge!(id => inst)
      end
    end
    @@table[id]
  end

  attr_reader :data
  def initialize(data)
    @data = data
  end

  # --- Opérations ---

  # Pour éditer la tâche de modèle
  # 
  # Note : on utilise Tableizor
  def edit(params = nil)
    self.edit_data = data.dup
    tb = Tableizor.new(
      titre:  "Édition de la tâche de modèle",
      object: self,
      data_method: :edit_data,
      properties: [
        {name:'À faire'             ,prop: :todo},
        {name:'Durée'               ,prop: :duree},
        {name:'Rappel'              ,prop: :rappel},
        {name:'Ouvrir'              ,prop: :open},
        {name:'Code à exécuter'     ,prop: :exec},
        {name:'Picto/Application'   ,prop: :app}
      ]
    )
    
    # 
    # On l'édite, on la checke et on la sauve si tout est
    # OK.
    # Noter qu'elle n'est pas ajoutée à la liste des tâches seules
    # et qu'elle ne se trouve pas dans le même dossier.
    # 
    check&.save if tb.edit

    return self # pour le chainage
  end

  ##
  # Destruction de la tâche de modèle
  # 
  # Contrairement à une tâche normale, on détruit simplement son
  # fichier
  #
  # @return TRUE si l'opération s'est bien passée
  # 
  def destroy
    File.delete(path) if File.exist?(path)

    return not(File.exist?(path))
  end

  # --- Données ----
  def id
    @id ||= data[:id] || begin
      tid = "#{model_id}-#{Time.now.to_i}"
      tid_init = tid.freeze
      iid = 0
      while File.exist?(path_for(tid))
        iid += 1
        tid = "#{tid_init}#{iid}"
      end
      data.merge!(id: tid)
      tid
    end
  end

  def todo=(value)
    @todo = data[:todo] = value
  end

  def id=(value)
    data.merge!(id: value)
    @id = nil
  end

  def model_id
    @model_id ||= data[:model_id]
  end
  def model_id=(value)
    @model_id = data[:model_id] = value
  end

  def path
    @path ||= path_for(id)
  end

  def path_for(this_id)
    File.join(Model.taches_folder,"#{this_id}.yaml")
  end

end #/class Tache  
end #/class Model
end #/module MyTaches
