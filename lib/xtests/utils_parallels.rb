# encoding: UTF-8


def deux_paralleles_et_une_suivante
  return x_paralleles_et_une_suivante(2)
end
def x_paralleles_et_une_suivante(nombre)
  tkparallels = []
  nombre.times do
    tkpar_id = get_new_id_tache
    tk = tache(id:tkpar_id, todo:"Tâche parallèle #{tkpar_id}").save
    tkparallels << tk
  end

  tksuiv_id = get_new_id_tache
  tksuiv = tache(id:tksuiv_id, todo:"La tâche suivante").save
  tkparallels.first.send(:suiv=, tksuiv_id).save

  MyTaches::Tache.init
  
  tkpara_ids = tkparallels.map do |tk|
    tk.id
  end
  
  taches_returned = 
    tkparallels.map do |tk|
      get_tache(tk.id)
    end.each do |tk|
      tk.data[:parallels] = tkpara_ids
      tk.save
    end.each do |tk|
      # * checks préliminaires *
      assert_true(tk.parallel?)
      assert_true(tk.suiv?)
      assert_equal(tksuiv_id, tk.suiv.id)
    end

  tksuiv = get_tache(tksuiv_id)
  taches_returned << tksuiv

  # * check préliminaire *  
  assert_nil(tksuiv.start)
  assert_equal(tkparallels.first.id, tksuiv.prev_id)

  return taches_returned
end
