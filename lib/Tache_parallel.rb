# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
  class Model
    class Tache
      def self.get_tache(tache_id)
        Model::Tache.get(tache_id)
      end
    end
  end #/class Model

class Tache
  def self.get_tache(tache_id)
    Tache.get(tache_id)
  end

# @new_parallel_task
def traiter_new_parallel_task(sauver = :all_but_me)
  @new_parallel_task = nil if new_parallel_task == :none # utile (n'est-ce pas le cas où il faut déparalléliser ?)
  # Déparalléliser si elle était parallélisée
  deparallelize(sauver = :all_but_me) if parallel?
  parallelize_with(new_parallel_task, sauver = :all_but_me)
end

# @return liste Array des tâches parallélisées, cette
# tâche comprise
def parallelized_tasks
  return nil if not(parallel?)
  parallels.map do |tk_id| self.class.get_tache(tk_id) end
end

# Pour paralléliser la tâche courante avec la tache
# +tache+
# 
# @return self pour le chainage
# 
def parallelize_with(tache, sauver = false)
  tache = get_tache(tache) if tache.is_a?(String)
  tache.id != id || raise( BadDataError.new("On ne peut pas paralléliser une tâche avec elle-même."))
  if suiv? && data[:suiv] == tache.id
    raise BadDataError.new("Impossible de paralléliser avec la tâche suivante.")
  elsif prev? && prev_id == tache.id
    raise BadDataError.new("Impossible de paralléliser avec la tâche précédente.")
  end
  add_parallel(tache.id)
  parallelized_tasks.each do |tk|
    saveit = sauver === true || (sauver == :all_but_me && tk.id != id)
    tk.set_parallels(parallels.dup, saveit)
  end
  return self # pour le chainage
rescue BadDataError => e
  puts e.message.rouge
  sleep 2 unless test?
  return false
end

# Pour déparalléliser une tâche qui était parallèle
# 
# @return self pour le chainage
# 
def deparallelize(sauver = false)
  parallel? || raise("Cette tâche #{id} n'est pas parallélisée.")
  taches_paralleles = parallelized_tasks.dup.freeze
  # 
  # Si la tâche suivante est définie dans cette tâche-ci, il faut
  # la reporter dans les autres tâches avant destruction car les
  # autres tâches ne la définissent peut-être pas.
  if data[:suiv]
    taches_paralleles.each do |tk|
      next if tk.id == id
      tk.send(:suiv=, data[:suiv]).save
      tk.suiv.prev_id = tk.id
    end
  end
  new_parallels = parallels.dup
  new_parallels.delete(id)
  new_parallels = nil if new_parallels.count < 2
  taches_paralleles.each do |tk|
    next if tk.id == id # on passe celle-ci, qui sera vide
    saveit = sauver === true  || (sauver == :all_but_me && tk.id != id)
    tk.set_parallels(new_parallels, saveit)
  end
  set_parallels(nil, sauver === true) # toujours vide 
end

def set_parallels(parals, sauver = false)
  @parallels = data[:parallels] = parals
  save.reset if sauver
end

private

  def add_parallel(tache_id)
    @parallels ||= [id]
    @parallels << tache_id
  end

end #/Tache
end #/module MyTaches
