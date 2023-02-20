# encoding: UTF-8
=begin

Pour tester la commande 'task' seule

=end
class TaskCommandTest
class << self

  # Les 15 tâches qui permettent de faire les 
  # tests
  attr_reader :tasks
  attr_reader :indexes
  attr_reader :id_to_idx
  attr_reader :tableau

  def create_tasks
    reset_taches
    tks = create_taches(15)

    @indexes = {
      far:          [0,3],
      futur:        [0,2,3,4,7,9,10,11,12,13,14],
      proche:       [2,4,7,10],
      current:      [1,5,6,8],
      today:        [7,8,10],
      out_of_date:  [1,6],
      out:          [9,11,12,13,14]
    }
    # Lointaines
    tks[0].data.merge!(start: _NOW_.plus(50).jours)
    tks[3].data.merge!(start: _NOW_.plus(32).jours)
    # Aujourd'hui
    tks[8].data.merge!(start: _NOW_.moins(1).heure, duree:'4h')
    tks[10].data.merge!(start:_NOW_.at('23:30'), duree:'1h')
    # Courantes
    tks[5].data.merge!(start: _NOW_.moins(1).jour, duree:'3d')
    # Périmées (et courantes)
    tks[1].data.merge!(start: _NOW_.moins(10).jours, duree:'5d')
    tks[6].data.merge!(start: _NOW_.moins(1).mois, duree:'4d')
    # Proches
    tks[2].data.merge!(start: _NOW_.plus(6).jours)
    tks[4].data.merge!(start: _NOW_.plus(2).jours)
    tks[7].data.merge!(start: _NOW_.plus(2).heures)

    # On les enregistre toutes
    # ecrit("\n")
    @id_to_idx = {}
    tks.each_with_index do |tk, idx| 
      @id_to_idx.merge!(tk.id => idx)
      tk.save
    end

    @tasks = tks

    return tks    
  end

  # @param foo  {Array} d'index de tâche 
  #             {Array} de symboles (:proches, :currents, etc.)
  #             {Symbol} :all pour tous
  # 
  def check_affichage_de(foo)
    MyTaches.reset_out_lines
    @tableau = MyTaches.run
    if foo == :all
      foo = (0..14).to_a
    end
    if foo.first.is_a?(Symbol)
      lst = []
      foo.each do |symb|
        lst += indexes[symb]
      end
      foo = lst.uniq
    end
    ids = foo.map { |idx| tasks[idx].id }
    tasks.each do |tk|
      if ids.include?(tk.id)
        tableau.match?(tk.todo) || begin
          on_error(ids)
          raise("Le tableau devrait contenir #{tk.todo.inspect}…")
        end
      else
        not(tableau.match?(tk.todo)) || begin
          on_error(ids)
          raise("Le tableau ne devrait pas contenir #{tk.todo}")
        end
      end
    end        
  end

  # En cas d'erreur, on affiche toutes les données utiles
  # 
  def on_error(ids)
    ecrit "\n\nIdentifiants et index des tâches".rouge
    tasks.each_with_index do |tk, idx|
      ecrit("Tâche #{idx} : #{tk.id}".bleu)
    end
    ecrit("Tableau affiché:\n#{tableau}".rouge)
    ecrit "\nTâches à trouver dans le tableau ci-dessus :".rouge
    ids.each do |id|
      ecrit "#{id} (#{id_to_idx[id]})".bleu
    end

  end

end #/<< self
end #/class TaskCommandTest


# @param
def check_affichage_de(foo)
  TaskCommandTest.check_affichage_de(foo)
end


def create_tasks_for_task_command
  return TaskCommandTest.create_tasks
end
