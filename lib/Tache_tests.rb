# encoding: UTF-8
#
# Test de la classe Tache
#
=begin

Pour retrouver rapidement les parties où sont testées les
choses :

test "CMD         # tests de la commande 'task'
test "TASK        # tests de la tâche en tant que telle
test "CHECK       # tests de la validité des données
test "PARAL       # tests des tâches parallèles
test "SHOW        # tests des affichages
test "MOD         # tests de la modification des données
test "DONE        # tests d'une tâche marquée accomplie
test "DUREE       # tests de la durée de la tâche
test "TEMPS       # tests des temps
test "ESTIM       # tests des estimations des start et end
test "LIST        # tests des listes 
test "STATUS      # tests des statuts de la tâche
test "LINK        # tests des liens entre tâches
test "OUT         # tests des tâches périmées
test "REM         # tests de la destruction d'une tâche
test "MODEL       # tests des modèles de suite de tâches
test "DATE        # tests des dates
test "RAPPEL      # tests des rappels
test "RUN         # tests des codes joués

=end


module MyTaches


  # Pour jouer ce module de tests seul
  require_relative 'xtests/required'

end #/module MyTache


#
if $0 == __FILE__



####################################################################
#
#   LES TESTS
#
####################################################################



  class TestTache < Test::Unit::TestCase

    # "Maintenant" sans les secondes
    # Toujours utile ?
    # TheNow.now = Time.now.at('0:00')


    def setup
      ARGV.clear
      redefine_now
    end

    def teardown
      redefine_now
    end

    # === COMMANDE SIMPLE ===

    test "CMD On peut jouer la commande 'task' pour voir le travail" do
      # -intégration-

      # * préparation *
      reset_taches
      tache(todo:"Une tâche pour aujourd'hui", start:_NOW_.moins(1).jour, duree:'2d').save
      tache(todo:"Une tâche pour plus tard", start:_NOW_.plus(1).semaine, duree:'1w').save
      tache(todo:"Une tâche sans temps", start:nil, duree:nil).save
      # * tests *
      # Premier test : la commande répond bien
      not_raised = true
      msg_raised = nil
      begin
        # 
        tableau = MyTaches.run
      rescue Exception => e
        msg_raised = e.message + "\n" + e.backtrace.join("\n")
        not_raised = false
      end
      if msg_raised
        ecrit("Message d'erreur levé : #{msg_raised}".rouge)
      end
      assert_true(not_raised)

      # - La commande affiche bien les tâches à voir
      #   et seulement les tâches à voir -
      assert_not_equal(nil, tableau)
      assert_not_equal('', tableau)

      assert_match(/TÂCHES À FAIRE/, tableau)
      assert_match(/Une tâche pour aujourd'hui/, tableau)
      assert_match(/Doit être achevée dans 1 jour/, tableau)
      assert_no_match(/Une tâche pour plus tard/, tableau)
      assert_no_match(/Une tâche sans temps/, tableau)
    end

    test 'CMD La commande `task` (ou `boulot`) ne produit aucune erreur' do
      res = run_alias('task')
      # ecrit(res)
      assert_match('TÂCHES À FAIRE', res)
      res = run_alias('boulot')
      # ecrit(res)
      assert_match('TÂCHES À FAIRE', res)
    end

    test "CMD MyTaches::get_objet_in_command_line retourne l'objet défini en ligne de commande" do
      
      # * préparation *
      reset_taches
      tks = create_taches(2)
      tka, tkb = tks
      mdl = create_modele
      tkmodel = mdl.taches.first
      MyTaches::Tache.acheve_tache(tka)
      tka.on_mark_done

      [
        # Quand c'est un ID de tâche
        [tkb.id, MyTaches::Tache],

        # Quand c'est un ID de modèle de suite de tâches 
        [mdl.id, MyTaches::Model],

        # Quand c'est un ID de tâche archivée
        [tka.id, MyTaches::ArchivedTache],

        # Quand c'est un ID de tâche de modèle de suite de tâches
        [tkmodel.id, MyTaches::Model::Tache],

        # Retourne nil dans le cas contraire
        ['-v', NilClass]

      ].each do |id, expected_class|
        # Par "id=<id>"
        CLI.main_command = 'noop'
        ARGV.clear
        ARGV << "id=#{id}"
        MyTaches.run
        assert_instance_of(expected_class, MyTaches.current_objet)
        unless MyTaches.current_objet.nil?
          assert_equal(id, MyTaches.current_objet.id)
        end
        # Par l'identifiant directement
        ARGV.clear
        ARGV << id
        MyTaches.run
        assert_instance_of(expected_class, MyTaches.current_objet)
        unless MyTaches.current_objet.nil?
          assert_equal(id, MyTaches.current_objet.id)
        end
      end

    end

    test "CMD Si le cron est en route, il faut traiter les tâches" do
      # -intégration-
      # 
      # On peut faire le test en enregistrant un journal de bord
      # des actions accomplies par le cron et en vérifiant que ça
      # fonctionne.
      # 

      # * préparation *
      reset_taches
      # Une tâche qui doit être notifiée dans 2 jours
      tkid = get_new_id_tache
      tk = tache(
        todo: "Une tâche à notifier", 
        id:tkid,
        start: _NOW_.plus(2).jours.at('10:20')
        ).save
      # On passe directement à 2 jours plus tard
      redefine_now(Time.now.plus(2).jours.at('10:24'))

      # * opération *
      CLI.main_command = nil
      set_argv('--cron')
      MyTaches.run
    
      # * check final *
      # On doit trouver l'action de notification dans le journal
      # de bord de l'application (cron.log)
      phrase = "#{Time.now.jj_mm_aaaa_hh_mm_ss} NOTIF START [#{tkid}]"
      assert_match(/#{Regexp.escape(phrase)}/, cron_log)

    end

    test "CMD 'task --all' permet de voir toutes les tâches" do
      # * préparation *
      reset_taches
      tks = create_taches(15)
      tks[0].data.merge!(start: _NOW_.plus(10).mois)
      tks[1].data.merge!(start: _NOW_.moins(10).jours, duree:'5d')
      tks[2].data.merge!(start: _NOW_.plus(10).jours)
      # On les enregistre toutes
      tks.each { |tk| tk.save }

      # * opération *
      CLI.main_command = nil
      set_argv('--all')
      tableau = MyTaches.run

      # * check final *
      tks.each do |tk|
        assert_match(/#{tk.todo}/, tableau)
      end

    end

    test "CMD 'task --all --cate' permet de voir toutes les tâches d'une catégorie choisie" do
      reset_taches
      tks = create_taches(10)
      liste_ids = [0,1,2,5,6,9]
      taches = liste_ids.map do |idx|
        tks[idx]
      end.each do |tk|
        tk.categorie = "Ma catégorie de tâches"
        tk.save
      end

      # * opération *
      CLI.main_command = nil
      set_argv(['--all','--cate'])
      Q.answers = [
        "Ma catégorie de tâches"
      ]
      result = MyTaches.run

      # * check *
      assert_instance_of(String, result)
      assert_match(/TÂCHES À FAIRE/, result)
      taches.each do |tk|
        assert_match(/#{tk.todo}/, result)
      end
    end

    test "CMD 'task --all -cate=cdl' permet de voir toutes les tâches d'une catégorie définie" do
      # * préparation *
      reset_taches
      tks = create_taches(5)
      cate_name = "Ma catégorie pour -cate="
      tks_cate = create_taches(10, cate: cate_name)

      # * check préliminaire *
      assert_equal(15, MyTaches::Tache.count)
      assert_equal(10, MyTaches::Tache.all(cate: cate_name, all:true).count)

      # * opération *
      CLI.main_command = nil
      set_argv(['--all', '-cate=Ma\ catégorie\ pour\ \-cate\='])
      tableau = MyTaches.run

      tks.each do |tk|
        assert_no_match(/#{tk.todo}/, tableau)
      end
      tks_cate.each do |tk|
        assert_match(/#{tk.todo}/, tableau)
      end

    end

    test "CMD 'task' avec options multiples (p.e. '--proche' et '--current' affiche toutes les tâches correspondantes" do
      require_relative 'xtests/task_utils'
      tsk = create_tasks_for_task_command

      CLI.main_command = nil
      set_argv(['--proche','--current'])
      assert_nothing_raised{check_affichage_de([:proche, :current])}

      set_argv(['--proche', '--current'])
      assert_nothing_raised{check_affichage_de([:current, :proche])}

      set_argv(['--current', '--out'])
      assert_nothing_raised{check_affichage_de([:current, :out])}      
    end

    test "CMD 'task' avec options (comme --proche) n'affiche que les tâches concernées" do
      require_relative 'xtests/task_utils'
      
      # * préparation *
      redefine_now(Time.now)
      tsk = create_tasks_for_task_command

      # --- Voir les courantes ---

      CLI.main_command = nil
      set_argv(['--current'])

      # --- Les tâches du jour ---
      set_argv('--today')
      l = [8,10]
      l << 7 if _NOW_.hour < 22
      assert_nothing_raised{check_affichage_de(l)}

      # --- Voir les proches ---
      set_argv(['--near'])
      assert_nothing_raised{check_affichage_de([:proche])}

      # --- Voir les très proches ---
      set_argv(['-near=4d'])
      assert_nothing_raised{check_affichage_de([4,7,10])}

      # --- Voir les dépassées ---
      set_argv(['--out'])
      assert_nothing_raised{check_affichage_de([:out])}

      set_argv('--today')
      lst = [8,10]
      lst << 7 if _NOW_.hour < 20
      assert_nothing_raised{check_affichage_de(lst)}

      # --- Voir les futures ---
      set_argv('--futur')
      assert_nothing_raised{check_affichage_de([:futur])}

      # --- Voir les lointaines ---
      set_argv(['--far'])
      assert_nothing_raised{check_affichage_de([0,3])}

      # --- Voir les tâches sans temps défini ---
      set_argv('--no_time')
      assert_nothing_raised{check_affichage_de([9,11,12,13,14])}

      # --- Tous les tâches ---
      set_argv('--all')
      assert_nothing_raised{check_affichage_de(:all)}

    end

    # TODO : Test des différents affichages 
    test "ONLY CMD 'task --linked' permet d'afficher les tâches liées" do
      # 'task --linked' permet d'afficher les tâches courantes
      # et en plus les tâches qui leur sont liées.
      
      # * préparation *
      reset_taches
      tks = create_taches(10, index:true)
      ecrit "Première tâche : #{tks.first.inspect}".jaune
      # tks.inject(:save)

      # * opération *
      CLI.main_command = nil
      set_argv('--linked')
      tableau = MyTaches.run
      ecrit "Tableau : #{tableau}".bleu

      # * check final *
      # On doit trouver les tâches courantes
      # TODO
      # On doit trouver les tâches liées aux tâches courantes,
      # avec un préfixe qui les lie.
      # TODO

    end

    test "CMD 'task --notify' permet de notifier les tâches qui doivent l'être (début et fin)" do
      # Note : c'est la même chose que '--cron'
    end


    # === CRÉATION DES TÂCHES ====

    test "TASK On peut instancier une tâche sans aucune donnée" do
      inst = tache({})
      assert_equal(inst.class, MyTaches::Tache)
    end

    #
    # Une tâche sans :todo ne peut pas être instanciée
    # 
    test "TASK On ne peut pas instancier une tâche sans :todo (chose à faire)" do
      assert_raise(RuntimeError){tache(todo: nil)}
    end

    #
    # Deux tâches ne peuvent pas avoir le même identifiant
    # 
    test "TASK On ne peut pas enregistrer deux tâches avec le même identifiant" do
      inst = tache(id:'pour_faute')
      tk2  = tache(id:'pour_faute')
      assert_equal('pour_faute-1', tk2.id)
    end

    test "TASK On peut allonger ou raccourcir la durée d'une tâche définie par une durée" do
      
      tkid = "TK#{get_new_id_tache}"
      tk = tache(id:tkid, duree:'2d').save

      # * check préliminaire *
      assert_equal('2d', tk.duree)
      assert_equal(2.jours, tk.duree_secondes)

      # = Opération =
      # = On allonge la durée de la tâche
      CLI.main_command = "mod"
      Q.answers = [
        {_name_: 'Une tâche'},
        {_name_: /liste/},
        {_name_: /#{tk.todo}/},
        {_name_: /durée/},
        {_name_: /ajout/},
        '2',
        {_name_: /Finir/}
      ]
      MyTaches.run
      
      # * check final *
      tk = MyTaches::Tache.get(tkid)
      assert_equal('4d', tk.duree)
      assert_equal(4.jours, tk.duree_secondes)

      CLI.main_command = 'mod'
      Q.answers = [
        {_name_: 'Une tâche'},
        {_name_: /liste/},
        {_name_: /#{tk.todo}/},
        {_name_: /durée/},
        {_name_: /retrait/},
        '3',
        {_name_: /Finir/}
      ]
      MyTaches.run

      # * check final *
      tk = MyTaches::Tache.get(tkid)
      assert_equal('1d', tk.duree)
      assert_equal(JOUR, tk.duree_secondes)

    end


    test "CHECK les chevauchements de temps sont impossibles avec des temps estimés" do
      
      # * préparation *
      reset_taches
      tka, tkb = create_taches(2)
      tka.link_to(tkb)

      # * check préliminaire *
      assert_instance_of(MyTaches::Tache, tka)      
      assert_instance_of(MyTaches::Tache, tkb)      
      assert_respond_to(tka, :data_valid?)
      assert_equal(tkb.id, tka.data[:suiv])
      assert_true(tka.data_valid?)

      # * opération *
      # On modifie les temps de telle sorte que les temps 
      # se chevauchent
      tka.start = _NOW_.plus(1).jour
      tka.send(:duree=, '4d').save
      tkb.send(:start=, _NOW_.moins(1).jour).save

      # * check *
      MyTaches::Tache.init
      assert(not(tka.data_valid?))

    end

    test "CHECK les chevauchements de temps sont impossibles même avec des temps stipulés explicitement" do
      
      # * préparation *
      reset_taches
      tka, tkb = create_taches(2)
      tka.link_to(tkb)

      # * check préliminaire *
      assert_instance_of(MyTaches::Tache, tka)      
      assert_instance_of(MyTaches::Tache, tkb)      
      assert_respond_to(tka, :data_valid?)
      assert_equal(tkb.id, tka.data[:suiv])
      assert(tka.data_valid?)

      # * opération *
      # On modifie les temps de telle sorte que les temps 
      # se chevauchent
      tka.send(:start=, _NOW_.moins(4).jour)
      tka.send(:duree=, '5d').save
      tkb.send(:start=, _NOW_.moins(1).jour)
      tkb.send(:duree=, '3d').save

      # * check *
      MyTaches::Tache.init
      refute(tka.data_valid?)

    end

    # ====== TACHES PARALLÈLES ======== #



    test "PARAL On peut créer des tâches parallèles" do
      reset_taches
      tk1 = tache(todo: "Première tâche").save
      tk2 = tache(todo: "Seconde tâche, parallèle à la troisième").save
      tk3 = tache(todo: "Troisième tâche, parallèle à la deuxième").save
      tk4 = tache(todo: "Quatrième tâche pour finir").save

      # * check préliminaires *
      assert_true(tk2.respond_to?(:parallelize_with))
      assert_true(tk2.private_methods.include?(:add_parallel))
      assert_true(tk2.respond_to?(:set_parallels))
      assert_true(tk2.respond_to?(:parallel?))
      assert_true(tk2.respond_to?(:parallelized_tasks))
      assert_false(tk2.parallel?)
      assert_true(tk2.respond_to?(:parallels))
      assert_nil(tk2.parallels)
      assert_nil(tk3.parallels)

      # * opération *
      tk2.parallelize_with(tk3, sauver = true)

      # * check final *
      assert_true(tk2.parallel?)
      assert_equal([tk2.id, tk3.id], tk2.parallels)
      assert_equal([tk2.id, tk3.id], tk3.parallels)
      assert_nil(tk1.parallels)
      assert_nil(tk4.parallels)
    end

    test "PARAL On peut déparalléliser une tâche" do
      reset_taches
      tk1 = tache(id:'tk1', todo: "Première tâche").save
      tk2 = tache(
        id:'tk2',
        todo: "Seconde tâche, parallèle à la troisième",
        parallels: ['tk2','tk3']
      )
      tk3 = tache(
        id:'tk3',
        todo: "Troisième tâche, parallèle à la deuxième",
        parallels: ['tk2','tk3'])
      tk4 = tache(id:'tk4', todo: "Quatrième tâche pour finir").save
      tk2.save
      tk3.save
      # * check preliminaire *  
      assert_true(tk2.respond_to?(:deparallelize))
      assert_false(tk1.parallel?)
      assert_true(tk2.parallel?)
      assert_true(tk3.parallel?)
      assert_false(tk4.parallel?)

      # * opération *
      tk2.deparallelize(sauver = true)

      # * check final *
      MyTaches::Tache.init
      otk1 = MyTaches::Tache.get('tk1')
      otk2 = MyTaches::Tache.get('tk2')
      otk3 = MyTaches::Tache.get('tk3')
      otk4 = MyTaches::Tache.get('tk4')
      assert_equal(nil, otk1.parallels)
      assert_false(otk1.parallel?)
      assert_equal(nil, otk2.parallels)
      assert_false(otk2.parallel?)
      assert_equal(nil, otk3.parallels)
      assert_false(otk3.parallel?)
      assert_equal(nil, otk4.parallels)
      assert_false(otk4.parallel?)

    end

    test "PARAL On peut paralléliser trois tâches" do
      reset_taches
      tk1 = tache(id:'tk1', todo: "Première tâche").save
      tk2 = tache(
        id:'tk2',
        todo: "Seconde tâche, parallèle à la troisième").save
      tk3 = tache(
        id:'tk3',
        todo: "Troisième tâche, parallèle à la deuxième").save
      tk4 = tache(
        id:'tk4', 
        todo: "Quatrième tâche pour finir").save
      tk5 = tache(
        id:'tk5', todo: 'Cinquième tâche à paralléliser aussi').save

      # * check preliminaire *
      assert_false(tk1.parallel?)
      assert_nil(tk1.parallels)
      assert_false(tk2.parallel?)
      assert_nil(tk2.parallels)
      assert_false(tk3.parallel?)
      assert_nil(tk3.parallels)
      assert_false(tk4.parallel?)
      assert_nil(tk4.parallels)
      assert_false(tk5.parallel?)
      assert_nil(tk5.parallels)

      # * Première opération *
      tk2.parallelize_with(tk5)

      # * check intermédiaire
      assert_false(tk1.parallel?)
      assert_nil(tk1.parallels)
      assert_true(tk2.parallel?)
      assert_false(tk3.parallel?)
      assert_nil(tk3.parallels)
      assert_false(tk4.parallel?)
      assert_nil(tk4.parallels)
      assert_true(tk5.parallel?)

      # * Deuxième opération *
      tk5.parallelize_with(tk3, sauver = true)

      # * check final *
      ary = ['tk2','tk5','tk3']
      MyTaches::Tache.init
      otk1 = MyTaches::Tache.get('tk1')
      otk2 = MyTaches::Tache.get('tk2')
      otk3 = MyTaches::Tache.get('tk3')
      otk4 = MyTaches::Tache.get('tk4')
      otk5 = MyTaches::Tache.get('tk5')
      assert_false(otk1.parallel?)
      assert_true(otk2.parallel?)
      assert_true(otk3.parallel?)
      assert_false(otk4.parallel?)
      assert_true(otk5.parallel?)
      assert_equal(ary, otk2.parallels)
      assert_equal(ary, otk3.parallels)
      assert_equal(ary, otk5.parallels)
      assert_nil(otk1.parallels)
      assert_nil(otk4.parallels)
    end

    test "PARAL On peut déparalléliser trois tâches parallèles" do
      reset_taches
      tk1 = tache(id:'tk1', todo: "Première tâche")
      tk2 = tache(
        id:'tk2',
        parallels: ['tk2','tk5','tk3'],
        todo: "Seconde tâche, parallèle à la troisième")
      tk3 = tache(
        id:'tk3',
        parallels: ['tk2','tk5','tk3'],
        todo: "Troisième tâche, parallèle à la deuxième")
      tk4 = tache(
        id:'tk4', 
        todo: "Quatrième tâche pour finir")
      tk5 = tache(
        id:'tk5', 
        parallels: ['tk2','tk5','tk3'],
        todo: 'Cinquième tâche à paralléliser aussi')
      [tk1,tk2,tk3,tk4,tk5].each{|tk|tk.save}

      # * check preliminaire *
      assert_false(tk1.parallel?)
      assert_nil(tk1.parallels)
      assert_true(tk2.parallel?)
      assert_not_nil(tk2.parallels)
      assert_true(tk3.parallel?)
      assert_not_nil(tk3.parallels)
      assert_false(tk4.parallel?)
      assert_nil(tk4.parallels)
      assert_true(tk5.parallel?)
      assert_not_nil(tk5.parallels)

      # * Première opération *
      tk2.deparallelize(sauver = true)

      # * check intermédiaire *
      assert_false(tk2.parallel?)
      assert_nil(tk2.parallels)
      assert_true(tk3.parallel?)
      assert_equal(['tk5','tk3'], tk3.parallels)
      assert_true(tk5.parallel?)
      assert_equal(['tk5','tk3'], tk5.parallels)

      # * Deuxième opération *
      tk5.deparallelize(sauver = true)

      # * check final *
      MyTaches::Tache.init
      otk1 = MyTaches::Tache.get('tk1')
      otk2 = MyTaches::Tache.get('tk2')
      otk3 = MyTaches::Tache.get('tk3')
      otk4 = MyTaches::Tache.get('tk4')
      otk5 = MyTaches::Tache.get('tk5')
      assert_false(otk1.parallel?)
      assert_nil(otk1.parallels)
      assert_false(otk2.parallel?)
      assert_nil(otk2.parallels)
      assert_false(otk3.parallel?)
      assert_nil(otk3.parallels)
      assert_false(otk4.parallel?)
      assert_nil(otk4.parallels)
      assert_false(otk5.parallel?)
      assert_nil(otk5.parallels)

    end

    test "PARAL On peut définir la parallélité d'une tâche (intégration)" do
      # -intégration-
      reset_taches
      tk1 = tache(todo:"Ma première tâche").save
      tk2 = tache(todo:'Ma deuxième tâche').save

      # * check prémilinaire *
      assert_false(tk1.parallel?)
      assert_false(tk2.parallel?)

      # * opération *
      CLI.main_command = 'mod'
      ARGV << tk1.id
      Q.answers = [
        {_name_:/Parallèle à/},   # régler la propriété :parallels
        {_name_:/liste/},         # pour choisir l'autre tâche par liste
        {_name_: /#{tk2.todo}/},  # choisir la tâche
        {_name_:/Finir/},         # Enregistrer la tâche
      ]
      result = MyTaches.run

      # * check final *
      MyTaches::Tache.init
      tk1 = MyTaches::Tache.get(tk1.id)
      tk2 = MyTaches::Tache.get(tk2.id)
      assert_true(tk1.parallel?)
      ary = [tk1.id, tk2.id]
      assert_equal(ary, tk1.parallels)
      assert_true(tk2.parallel?)
      assert_equal(ary, tk2.parallels)
    end

    test "PARAL Finir une tâche parallèle la déparallélise avec ses parallèles" do
      # Checké avec le test suivant
    end

    test "PARAL La fin d'une tâche parallèle ne règle pas le :start d'une suivante s'il reste des tâches parallèles" do
      # * préparation *
      tkpar_a, tkpar_b, tksuiv = deux_paralleles_et_une_suivante

      # * opération *
      tkpar_a.on_mark_done

      # * check final *
      tksuiv = get_tache(tksuiv.id)
      assert_false(tkpar_a.parallel?)
      assert_false(tkpar_b.parallel?)
      assert_equal(tksuiv.id, tkpar_b.data[:suiv])
      assert_nil(tksuiv.start)
      refute_equal(tkpar_a.id, tksuiv.prev_id)
      assert_equal(tkpar_b.id, tksuiv.prev_id)
    end

    test "PARAL La destruction d'une tâche parallèle déparallélise ce qu'il faut" do
      # Checké avec le test précédent
    end

    test "PARAL Le déclenchement d'une tâche dépend des tâches parallèles qui la précèdent" do
      # Soit :
      #   - un tâche tk1 qui ne pourra être déclenchée que si 
      #     les tâches parallèle tk2 et tk3 sont achevées toutes les
      #     deux
      # 
      # * préparation *
      tkpar_a, tkpar_b, tksuiv = deux_paralleles_et_une_suivante
      tksuiv.
        send(:start=, _NOW_.moins(1).jour).
        send(:duree=, '4d').
        save

      # * test *
      assert_false(tksuiv.notify?)

    end

    test "PARAL On ne peut pas paralléliser avec une tâche elle-même" do
      # "Parallèle" avec la tâche dont il est question, évidemment, 
      # sinon, on peut évidemment paralléliser une tâche avec une
      # tâche parallèle à une autre (puisqu'on peut paralléliser 
      # autant de tâche qu'on le veut).

      # * préparation *
      tkid = get_new_id_tache
      tache(id:tkid, todo:"La tâche à paralléliser").save
      MyTaches::Tache.init
      tk = get_tache(tkid)

      # * check préliminaire *
      assert_false(tk.parallel?)

      # * opération *
      tk.parallelize_with(tk)
      # * check final *
      assert_match(/On ne peut pas paralléliser une tâche avec elle\-même/, texte_console(true))
      assert_false(tk.parallel?)

    end

    test "PARAL On ne peut pas choisir comme tâche suivante une tâche parallèle" do
      # * préparation *
      reset_taches
      tka, tkb, tksuiv = deux_paralleles_et_une_suivante

      # * opération (en choisissant la suivante) *
      tka.edit_data = {}
      tka.edit_suiv(tkb)

      # * check intermédiare *
      assert_match("On ne peut pas la choisir comme tâche suivante", texte_console(true))
      assert_nil(tka.edit_data[:suiv])

      # * opération (en choisissant la précédente) *
      tka.edit_prev(tkb)

      # * check final *
      assert_match("On ne peut pas la choisir comme tâche précédente", texte_console(true))
      assert_nil(tka.edit_data[:prev])

    end

    test "PARAL Deux tâches parallèles ne peuvent pas se suivre" do
      # Sens : on a 2 tâches parallèles, on essaie de les faire se suivre
      # Mais : une alerte permet de déparalléliser les tâches
      # Noter que c'est ici juste une mesure de protection car l'incident
      # doit être relevé dès qu'on choisit une tâche qui ne peut pas
      # suivre (cf. test précédent)
      reset_taches
      tka, tkb, tksuiv = deux_paralleles_et_une_suivante
      # * check *
      assert_raise(RuntimeError) { tka.link_to(tkb) }
    end

    test "PARAL 2 tâches qui se suivent ne peuvent pas se paralléliser" do
      # Sens : 2 tâches se suivent, on essaie de les paralléliser
      # Mais : une alerte permet de supprimer le :suiv
      reset_taches
      tka, tkb = create_taches(2)
      tka.link_to(tkb)
      [tka,tkb].each {|t|t.save}

      # * check préliminaire *
      MyTaches::Tache.set_taches_prev
      assert_instance_of(MyTaches::Tache, tka)
      assert_instance_of(MyTaches::Tache, tkb)
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.data[:suiv])
      
      tka.parallelize_with(tkb)
      # ecrit "rs: #{texte_console}".bleu
      assert_match(/Impossible de paralléliser avec la tâche suivante/, texte_console(true))
    end

    test "PARAL On ne peut pas choisir comme parallèle la tâche précédente" do
      # * préparation *
      reset_taches
      tka, tkb = create_x_taches_linked(2)

      # * check préliminaire *
      refute(tka.parallel?)
      refute(tkb.parallel?)

      # * opération *
      tkb.edit_data = {}
      tkb.edit_parallels(tka)

      # * check fiinal *
      refute(tka.parallel?)
      refute(tkb.parallel?)
      assert_match("On ne peut pas choisir comme parallèle la tâche précédente.", MyTaches.output)
    end

    test "PARAL On ne peut pas choisir comme parallèle la tâche suivante" do
      # * préparation *
      reset_taches
      tka, tkb = create_x_taches_linked(2)

      # * check préliminaire *
      refute(tka.parallel?)
      refute(tkb.parallel?)

      # * opération *
      tka.edit_data = {}
      tka.edit_parallels(tkb)

      # * check fiinal *
      refute(tka.parallel?)
      refute(tkb.parallel?)
      assert_match("On ne peut pas choisir comme parallèle la tâche suivante.", MyTaches.output)
    end

    test "PARAL Le déclenchement d'une tâche déclenche aussi les tâches parallèles" do
      # * préparation *
      tks = x_paralleles_et_une_suivante(4)

      # * opération *
      tks[0].change_start(_NOW_)

      # * check final *
      tks[0...-1].each do |tk|
        assert_equal(_NOW_.jj_mm_aaaa_hh_mm, tk.data[:start])
        assert_equal(_NOW_, tk.start_time)
      end
    end

    # ======= AFFICHAGE DES TÂCHES ======= #

    test "SHOW 'task show' permet de choisir une tâche à afficher" do
      # * préparation *
      reset_taches
      tks = create_taches(10)
      tka = tks[3]

      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      Q.answers = [
        {_name_:'Une tâche'},
        {_name_:/liste/},
        {_name_:/#{tka.todo}/}
      ]
      retour = MyTaches.run
      # ecrit("retour:\n#{retour}")

      # * check *
      assert_instance_of(MyTaches::Tache, MyTaches.current_objet)
      assert_equal(tka.id, MyTaches.current_objet.id)
      assert_match(/ID +\[#{tka.id}\]/, retour)

    end


    # ====== Tests de l'AFFICHAGE des tâches ====


    test "SHOW 'task show' permet de choisir un modèle à afficher" do
      # * préparation *
      mdl = create_modele
      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      Q.answers = [
        {_name_: 'Un modèle'},
        {_name_: mdl.name}
      ]
      retour = MyTaches.run
      # ecrit("retour:\n#{retour}")

      # * check *
      assert_instance_of(MyTaches::Model, MyTaches.current_objet)
      assert_equal(mdl.id, MyTaches.current_objet.id)
      assert_match(/\[#{mdl.id}\]/, retour)
    end

    test "SHOW 'task show' permet de choisir une tâche archivée à afficher" do
      # * préparation *
      reset_taches
      tk = create_taches(4)[2]
      MyTaches::Tache.acheve_tache(tk)

      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      Q.answers = [
        {_name_:/archivée/},
        {_name_:/liste/},
        {_name_:/#{tk.todo}/}
      ]
      retour = MyTaches.run

      # * check *
      assert_instance_of(MyTaches::ArchivedTache, MyTaches.current_objet)
      assert_equal(tk.id, MyTaches.current_objet.id)
      assert_match(/ID +\[#{tk.id}\]/, retour)
    end

    test "SHOW On peut afficher une tâche simple" do
      # -intégration-

      # * préparation *
      tk_id     = get_new_id_tache
      tk_todo   = "La tâche #{tk_id[0...-1]}"
      tk_cate   = "Tâche à afficher"
      tk_file   = '/Users/mon/fichier/a/ouvrir'
      tk_app    = 'com.skype.skype'
      tk_code   = 'ls -la'
      tk = tache(
        id:     tk_id,
        todo:   tk_todo,
        cate:   tk_cate, 
        start:  _NOW_.at('6:45'),
        duree:  '4d',
        rappel: '1d::14:22',
        app:    tk_app,
        exec:   tk_code,
        open:   tk_file
      ).save

      assert_true(tk.respond_to?(:display))

      # * opération *
      CLI.main_command = "show"
      ARGV << "id=#{tk_id}"
      tableau = MyTaches.run

      # ecrit("Tableau retourné :\n")
      # ecrit(tableau.bleu)

      assert_not_nil(tableau)
      assert_equal(String, tableau.class)
      assert_match(/#{tk_id}/, tableau)
      assert_match(/#{tk_todo}/, tableau)
      assert_match(/#{tk_cate}/, tableau)
      assert_match(/#{tk_file}/, tableau)
      assert_match(/4 jours/, tableau)
      assert_match(/Tous les jours à 14:22/, tableau)
      assert_match(tk_app, tableau)
      assert_match(tk_code, tableau)
    end

    test "SHOW On peut afficher une tâche liée" do
      # * préparation *
      reset_taches
      tks = create_x_taches_linked(3)
      tka, tkb, tkc = tks

      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      ARGV << tkb.id
      tableau = MyTaches.run

      # * check *
      assert_match(/#{tkb.id}/, tableau)
      assert_match(/Tâche précédente +#{tka.todo} \[#{tka.id}\]/, tableau)
      assert_match(/Tâche suivante +#{tkc.todo} \[#{tkc.id}\]/, tableau)
    end

    test "SHOW Les tâches parallèles s'affichent bien" do
      # * préparation *
      tks = x_paralleles_et_une_suivante(3)
      tka, tkb, tkc, tksuiv = tks

      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      ARGV << tkc.id
      tableau = MyTaches.run

      # * check *
      assert_match(/#{tkc.todo}/, tableau)
      assert_match(/ID +\[#{tkc.id}\]/, tableau)
      assert_match(/Tâches parallèles/, tableau)
      assert_match(/    \[#{tka.id}\] +#{tka.todo}/, tableau)
      assert_match(/    \[#{tkb.id}\] +#{tkb.todo}/, tableau)

      # On en profite pour vérifier que l'affichage de la
      # tâche suivante, qui n'est pas parallélisé, n'affiche
      # pas cette information
      CLI.main_command = 'show'
      ARGV.clear
      ARGV << tksuiv.id
      tableau = MyTaches.run

      # * check *
      assert_no_match(/Tâches parallèles/, tableau)

    end

    test "SHOW On peut afficher une tâche archivée" do
      # * opération *
      tkid = get_new_id_tache
      tache(id:tkid, todo:"La tâche archivée #{tkid}").save
      tk = get_tache(tkid)

      # * opération préparatoire *
      CLI.main_command = 'done'
      ARGV.clear
      ARGV << tkid
      Q.answers = ["\n"] # pour confirmation
      MyTaches.run

      # * opération *
      MyTaches::Tache.init

      # * check intermédiaire *
      assert_nil(MyTaches::Tache.get(tkid))

      # * opération *
      CLI.main_command = 'show'
      ARGV.clear
      ARGV << tkid
      tableau = MyTaches.run

      assert_match(/#{tk.todo}/, tableau)
      assert_match(/ID +\[#{tkid}\]/, tableau)
      assert_match(/Archivée/, tableau)

    end

    test "SHOW On peut afficher un modèle de suite de tâche" do
      # -semi-intégration-
      # *préparation*
      mdl = create_modele

      # *opération*
      CLI.main_command = 'show'
      ARGV.clear
      ARGV << mdl.id
      tableau = MyTaches.run

      assert_not_nil(tableau)
      assert_instance_of(String, tableau)
      assert_match(/MODÈLE DE SUITE DE TÂCHES « #{mdl.name.upcase} »/, tableau)
      # Toutes les tâches doivent être bien affichées
      mdltasks = mdl.taches.dup.reverse
      while tk = mdltasks.pop
        assert_match(/#{tk.todo}/, tableau)
        assert_match(/#{tk.f_duree}/, tableau)
        assert_match(/#{tk.id}/, tableau)
      end
    end

    test "SHOW On ne peut pas afficher une tâche détruite" do
      reset_taches
      tk = create_taches(4)[2]
      tk_path = tk.path.freeze
      assert_true(File.exist?(tk_path))
      Q.answers = ["\n"] # confirmation
      MyTaches::Tache.destroy(tk)
      # * check préliminaire *
      MyTaches::Tache.init
      assert_false(File.exist?(tk_path))
      assert_nil(get_tache(tk.id))
      # * opération *
      CLI.main_command = 'show'
      set_argv(tk.id)
      retour = MyTaches.run
      # * check final *
      assert_no_match(/\[#{tk.id}\]/, retour)
    end


    # ======= /FIN tests AFFICHAGE DES TÂCHES ======= #


    # ===== MODIFICATION DES TÂCHES ===== #


    test "MOD On peut modifier une tâche avec 'task mod id=<...>'" do

      reset_taches
      taches = all_taches
      if taches.count == 0
        create_taches_with_time_et_duree
        taches = all_taches
      end
      tk = taches.first
      new_tache_todo = "Nouveau nom de tâche pour #{tk.id}"

      # * check préliminaire *
      assert_true(taches.count > 0)

      # * opération *
      CLI.main_command = 'mod'
      ARGV << "id=#{tk.id}"
      Q.answers = [
        {_name_:/à faire/},
        new_tache_todo,
        {_name_:/Finir/}
      ]
      result = MyTaches.run
      # ecrit "result: #{result.inspect}".bleu


      # * check final *
      assert_equal(tk.id, MyTaches.current_objet.id)
      assert_match(/modifiée avec succès/, result)
      tk = MyTaches::Tache.get(tk.id)
      assert_equal(new_tache_todo, tk.todo)

    end

    test "MOD On peut modifier une tâche en fournissant seulement son identifiant" do
      reset_taches
      taches = all_taches
      if taches.count == 0
        create_taches_with_time_et_duree
        taches = all_taches
      end
      tk = taches.first

      # * check préliminaire *
      assert_true(taches.count > 0)

      # * opération *
      CLI.main_command = 'mod'
      ARGV << tk.id
      Q.answers = [
        {_name_: /à faire/},
        'Le nouveau todo de la tâche à faire',
        {_name_:/Finir/}
      ]
      result = MyTaches.run
      # ecrit "result: #{result.inspect}".bleu

      # * check final *
      assert_equal(tk.id, MyTaches.current_objet.id)
      assert_match(/Tâche '#{tk.id}' modifiée avec succès/, result)

    end

    test "MOD On peut supprimer le lien avec la tâche suivante" do
      # * préparation *
      reset_taches
      tka, tkb = create_taches(2)
      tka.link_to(tkb).save
      tkb.save

      # * check préliminaire *
      MyTaches::Tache.init
      tka, tkb = get_taches([tka.id, tkb.id])
      assert_true(tka.suiv?)
      assert_false(tka.prev?)
      assert_true(tkb.prev?)
      assert_false(tkb.suiv?)
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.suiv.id)

      # * opération *
      CLI.main_command = 'mod'
      set_argv(tka.id)
      Q.answers = [
        {_name_:/Tâche suivante/},
        "\n",  # Quand une tâche suivante est déjà
               # définie, une question permet la supprimer
        {_name_:/Finir/} # enregistrer
      ]
      result = MyTaches.run

      tka,tkb = get_taches([tka.id, tkb.id])
      assert_false(tka.suiv?)
      assert_false(tka.prev?)
      assert_false(tkb.prev?)
      assert_false(tkb.suiv?)
      assert_equal(nil, tkb.prev_id)
      assert_equal(nil, tka.data[:suiv])
    end

    test "MOD On peut supprimer le lien avec la tâche précédente" do
      # * préparation *
      reset_taches
      tka, tkb = create_taches(2)
      tka.link_to(tkb).save
      tkb.save

      # * check préliminaire *
      MyTaches::Tache.init
      tka, tkb = get_taches([tka.id, tkb.id])
      assert_true(tka.suiv?)
      assert_false(tka.prev?)
      assert_true(tkb.prev?)
      assert_false(tkb.suiv?)
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.suiv.id)

      # * opération *
      CLI.main_command = 'mod'
      set_argv(tkb.id)
      Q.answers = [
        {_name_:/Tâche précédente/},
        "\n",  # Quand une tâche précédente est déjà
               # définie, une question permet la supprimer
        {_name_:/Finir/} # enregistrer
      ]
      result = MyTaches.run

      tka,tkb = get_taches([tka.id, tkb.id])
      assert_false(tka.suiv?)
      assert_false(tka.prev?)
      assert_false(tkb.prev?)
      assert_false(tkb.suiv?)
      assert_equal(nil, tkb.prev_id)
      assert_equal(nil, tka.data[:suiv])
    end

    # ===== /Fin de la modification des tâches =====


    # === MARQUAGE D'UNE TÂCHE FAITE ===

    test "DONE Une tâche marquée accomplie mémorise sa date de fin" do
      # * préparation *
      reset_taches
      tk = create_taches(1).first

      # * check préliminaire *
      assert_nil(tk.data[:done_at])
      assert_instance_of(MyTaches::Tache, tk)

      # * opération *
      CLI.main_command = 'done'
      ARGV.clear
      ARGV << tk.id
      Q.answers = ["\n"] # confirmation
      MyTaches.run

      # * check final *
      CLI.main_command = 'noop'
      ARGV.clear
      ARGV << tk.id
      MyTaches.run
      curobjet = MyTaches.current_objet
      assert_equal(tk.id, curobjet.id)
      assert_instance_of(MyTaches::ArchivedTache, curobjet)
      assert_not_nil(curobjet.data[:done_at])
      assert_equal(_NOW_.jj_mm_aaaa_hh_mm, curobjet.data[:done_at])
    end

    test "DONE Une tâche accomplie se délie de sa précédente" do
      # * préparation *
      reset_taches
      tks = create_x_taches_linked(3)
      tka, tkb, tkc = tks

      # * opération *
      CLI.main_command = 'done'
      ARGV << tkb.id
      Q.answers = ["\n"] # confirmer
      MyTaches.run

      # * check final *
      tka, tkb, tkc = get_taches([tka.id, tkb.id, tkc.id])
      assert_nil(tkb.data[:suiv])
      assert_false(tkb.suiv?)
      assert_false(tkb.prev?)
      # Mais la précédente et la suivante sont reliées
      assert_true(tka.suiv?)
      assert_equal(tkc.id, tka.suiv.id)
      assert_true(tkc.prev?)
      assert_equal(tka.id, tkc.prev.id)
    end

    # === DURÉE ===

    test "DUREE Sans fin ni durée, on ne trouve pas le menu 'ajout'" do
      tk = tache
      tk.edit_data = {}
      # * opération et test *
      assert_raise do
        Q.answers = [{_name_:/un ajout/}]
        tk.edit_duree
      end
    end

    test "DUREE Sans fin ni durée, on ne trouve pas le menu 'retrait'" do
      tk = tache
      tk.edit_data = {}
      # * opération et test *
      assert_raise do
        Q.answers = [{_name_:/un retrait/}]
        tk.edit_duree
      end
    end

    test "DUREE Avec une durée définie, on trouve le menu 'ajout'" do
      tk = tache
      tk.data[:duree] = '4d'
      tk.save
      tk.edit_data = {}
      # * opération et test *
      assert_nothing_raised do
        Q.answers = [{_name_:/un ajout/}]
        tk.edit_duree
      end
    end

    test "DUREE Avec une durée définie, on trouve le menu 'retrait'" do
      tk = tache
      tk.data[:duree] = '4d'
      tk.save
      tk.edit_data = {}
      # * opération et test *
      assert_nothing_raised do
        Q.answers = [{_name_:/un retrait/}]
        tk.edit_duree
      end
    end

    test "DUREE Hors modèle, on ne trouve pas le menu 'Durée variable'" do
      tk = tache
      tk.edit_data = {}
      # * opération et test *
      assert_raise do
        Q.answers = [{_name_:/Durée variable/}]
        tk.edit_duree
      end
    end

    test "DUREE Pour un modèle on trouve le menu 'durée variable'" do
      mdl = create_model
      tk  = mdl.taches.first
      assert_instance_of(MyTaches::Model::Tache, tk)
      tk.edit_data = {}
      assert_nothing_raised do
        Q.answers = [{_name_:/Durée variable/}]
        tk.edit_duree
      end
    end

    test "DUREE La durée par défaut d'une tâche est de 1 jour" do
      inst = tache
      assert_equal(inst.duree, nil)
      assert_equal(inst.duree_seconds, JOUR)
    end

    test "DUREE Une tâche avec un temps de départ seulement possède une durée d'un jour" do
      ta = tache(start:hdate(_NOW_ - 10 * 3600))
      assert_equal(ta.duree, nil)
      assert_equal(ta.duree_secondes, JOUR)
    end

    test "DUREE Calcul de la durée en secondes d'une tâche" do

      # - Durée définie par :duree et une valeur hors mois et année -
      [
        ['4m' , 4.minutes],
        ['5h' , 5.heures],
        ['6d' , 6.jours],
        ['7w' , 7.semaines],
      ].each do |duree_str, duree_sec|
        tk = tache(duree: duree_str)
        assert_equal(duree_sec, tk.duree_seconds)
      end

      # - Durée définie par :duree avec unité mois et sans temps -
      tk = tache(duree: '3s')
      assert_equal(nil, tk.duree_seconds)

      # - Durée définie par :duree avec unité année sans temps -
      tk = tache(duree: '4y')
      assert_equal(nil, tk.duree_seconds)
    
      # - Durée définie par :duree avec unité mois avec :start -
      start_tache = _NOW_.at('10:23')
      tk = tache(duree: '3s', start: start_tache)
      end_tache = _NOW_.plus(3).mois.at('10:23')
      expected = end_tache.to_i - start_tache.to_i
      assert_equal(expected, tk.duree_seconds)

      # - Durée définie par :duree avec unité année et :start -
      start_tk = _NOW_.at('10:54')
      tk = tache(duree:'7y', start: start_tk)
      end_tk = start_tk.plus(7).annees
      expected = (end_tk - start_tk).to_i
      assert_equal(expected, tk.duree_seconds)

    end

    test "DUREE On peut modifier la durée d'une tache (ajout/retrait)" do
      # * semi intégration *
      # 

      # - Ajout avec des jours -

      # * préparation *
      tk = tache(duree: '2d')
      Q.answers = [{_name_: /ajout/},"4"]
      # = Opération =
      tk.edit_data = {}
      tk.edit_duree
      # * check *
      assert_equal('6d', tk.edit_data[:duree])

      # - Ajout avec des semaines -

      # * préparation
      tk = tache(duree: '3w')
      Q.answers = [{_name_: /ajout/}, "4"]
      # = opération =
      tk.edit_data = {}
      tk.edit_duree
      # * check *
      assert_equal('7w', tk.edit_data[:duree])

      # - Retrait avec des semaines -

      # * préparation *
      tk = tache(duree:'4w')
      Q.answers = [{_name_:/retrait/}, '3']
      # * opération *
      tk.edit_data = {}
      tk.edit_duree
      # * check *
      assert_equal('1w', tk.edit_data[:duree])

      # - Retrait avec des heures -

      # * préparation *
      tk = tache(duree:'6h')
      Q.answers = [{_name_:/retrait/}, '2']
      # * opération *
      tk.edit_data = {}
      tk.edit_duree
      # * check *
      assert_equal('4h', tk.edit_data[:duree])

    end

    test "DUREE Ajout ou retrait de durée à des temps" do
      # * semi intégration *
      # 
      # Contrairement à la méthode précédente, ici, ce
      # sont les temps qui sont définis (:start et/ou :stop)
      # et l'utilisateur modifie la durée par la durée
      # 

      # - Ajout de jours avec le :start défini -
      # Impossible
      # * préparation *
      tk = tache(start: _NOW_.moins(5).jours.at('10:00'))
      tk.edit_data = {}
      assert_raise do
        Q.answers = [{_name_:/ajout/},'d',"4"]
        # * opération *
        tk.edit_duree
      end
      # * check *
      assert_nil(tk.edit_data[:start])
      assert_nil(tk.edit_data[:duree])

      # - Retrait de semaines avec le :start défini -
      # C'est impossible, normalement

      # - Ajout d'heure avec le :end défini -

      # * préparation *
      tk = tache(end: _NOW_.at('10:02'))
      tk.edit_data = {}
      Q.answers = [{_name_:/ajout/},'h',"4"]
      # * opération *
      tk.edit_duree
      # * check *
      assert_equal(_NOW_.at('14:02').jj_mm_aaaa_hh_mm, tk.edit_data[:end])

      # - Retrait de jours avec le :end défini -

      # * préparation *
      tk = tache(end: _NOW_.at('10:04'))
      tk.edit_data = {}
      Q.answers = [{_name_:/retrait/},'d',"3"]
      # * opération *
      tk.edit_duree
      # * check *
      assert_equal(_NOW_.moins(3).jours.at('10:04').jj_mm_aaaa_hh_mm, tk.edit_data[:end])

      # - Ajout d'heure avec le :start et le :end définis -

      # * préparation *
      tk = tache(start: _NOW_.moins(4).jours, end: _NOW_.at('10:02'))
      tk.edit_data = {}
      Q.answers = [{_name_:/ajout/},'h',"4"]
      # * opération *
      tk.edit_duree
      # * check *
      assert_equal(_NOW_.at('14:02').jj_mm_aaaa_hh_mm, tk.edit_data[:end])

      # - Retrait de jours avec le :start et le :end définis -

      # * préparation *
      tk = tache(start: _NOW_.moins(4).jours, end: _NOW_.at('10:04'))
      tk.edit_data = {}
      Q.answers = [{_name_:/retrait/},'d',"3"]
      # * opération *
      tk.edit_duree
      # * check *
      assert_equal(_NOW_.moins(3).jours.at('10:04').jj_mm_aaaa_hh_mm, tk.edit_data[:end])

    end

    test "DUREE Définition de la durée quand :start et :end sont déjà définis" do
      # Dans ce cas, il faut rectifier le :end

      # * préparation *
      tk = tache(start: _NOW_.moins(1).jour.at('10:00'), end:_NOW_.plus(1).jour.at('10:00'))
      tk.edit_data = {}
      Q.answers = ['d', '3']
      # * opération *
      tk.edit_duree
      # * check *
      assert_equal('3d', tk.edit_data[:duree])
      assert_equal(nil, tk.edit_data[:end])

    end

    test "DUREE #hunite_duree retourne la bonne valeur" do
      tk = tache(todo: "Pour essayer la méthode hunite_duree")

      [
        ['y', :court, false, 'an'],
        ['y', :court, true, 'ans'],
        ['y', :normal, false, 'année'],
        ['y', :normal, true, 'années'],
        ['s', :court, false, 'mois'],
        ['s', :court, true, 'mois'],
        ['s', :normal, false, 'mois'],
        ['s', :normal, true, 'mois'],
        ['w', :court, false, 'sem.'],
        ['w', :court, true, 'sem.'],
        ['w', :normal, false, 'semaine'],
        ['w', :normal, true, 'semaines'],
        ['d', :court, false, 'jour'],
        ['d', :court, true, 'jrs'],
        ['d', :normal, false, 'jour'],
        ['d', :normal, true, 'jours'],
        ['h', :court, false, 'heure'],
        ['h', :court, true, 'hrs'],
        ['h', :normal, false, 'heure'],
        ['h', :normal, true, 'heures'],
        ['m', :court, false, 'min.'],
        ['m', :court, true, 'mns'],
        ['m', :normal, false, 'minute'],
        ['m', :normal, true, 'minutes'],
      ].each do |u,f,p, expected|
        assert_equal(expected, tk.hunite_duree(u,f,p))
      end
    end

    test "DUREE #hunite_duree lève une erreur en cas de mauvaise unité" do
      tk = tache(todo: "Pour faire plante #hunite_duree")
      assert_raise(RuntimeError) { tk.hunite_duree('z',:court,false) }
    end

    test "DUREE #f_duree retourne la bonne valeur" do
      tk = tache(todo:"Pour tester #f_duree")
      [
        ['1m', nil, '1 minute'],
        ['1m', :normal, '1 minute'],
        ['1m', :court, '1 min.'],
        ['2m', nil, '2 minutes'],
        ['2m', :normal, '2 minutes'],
        ['2m', :court, '2 mns'],

        ['1h', nil, '1 heure'],
        ['1h', :normal, '1 heure'],
        ['1h', :court, '1 heure'],
        ['3h', nil, '3 heures'],
        ['3h', :normal, '3 heures'],
        ['3h', :court, '3 hrs'],

        ['1d', nil, '1 jour'],
        ['1d', :normal, '1 jour'],
        ['1d', :court, '1 jour'],
        ['3d', nil, '3 jours'],
        ['3d', :normal, '3 jours'],
        ['3d', :court, '3 jrs'],

        ['1w', nil, '1 semaine'],
        ['1w', :normal, '1 semaine'],
        ['1w', :court, '1 sem.'],
        ['3w', nil, '3 semaines'],
        ['3w', :normal, '3 semaines'],
        ['3w', :court, '3 sem.'],

        ['1s', nil, '1 mois'],
        ['1s', :normal, '1 mois'],
        ['1s', :court, '1 mois'],
        ['3s', nil, '3 mois'],
        ['3s', :normal, '3 mois'],
        ['3s', :court, '3 mois'],

        ['1y', nil, '1 année'],
        ['1y', :normal, '1 année'],
        ['1y', :court, '1 an'],
        ['3y', nil, '3 années'],
        ['3y', :normal, '3 années'],
        ['3y', :court, '3 ans'],

        ['%', nil, 'Durée variable'],
        ['%', :normal, 'Durée variable'],
        ['%', :court, 'Durée variable'],
        ['%', nil, 'Durée variable'],
        ['%', :normal, 'Durée variable'],
        ['%', :court, 'Durée variable'],
      ].each do |str, fmt, expected|
        if fmt.nil?
          assert_equal(expected, tk.f_duree(str))
        else
          assert_equal(expected, tk.f_duree(str, fmt))
          if fmt == :court
            assert_equal(expected, tk.f_duree_courte(str))
          end
        end
      end
    end


    # ======= TEMPS ======= #

    test "TEMPS Quand on change le :start d'une tâche, ça change le :start de ses parallèles" do
      tka, tkb = create_taches(2)
      tka.parallelize_with(tkb)
      # * check préliminaire *
      assert_true(tka.parallel?)
      assert_true(tkb.parallel?)
      assert_nil(tka.start_time)
      assert_nil(tkb.start_time)
      # * opération *
      tka.edit_data = {start: _NOW_.plus(10).jours}
      tka.check.save
      # * check final *
      tkb = get_tache(tkb.id)
      MyTaches::Tache.init
      tkb = MyTaches::Tache.get(tkb.id)
      assert_not_nil(tkb.start_time)

    end

    # TODO : il faut faire tous les tests de changement de temps
    # avec le nouveau principe : un temps qui change change tous les
    # autres

    # --- Ci-dessous les anciennes méthodes de temps ---

    #
    # Une instance suivant une autre prend en temps de
    # début le temps de fin de l'échéance
    # 
    test "TEMPS Une tâche suivante a le départ de la fin de sa tâche précédente" do
      tka = tache(id:'taskun', start:_NOW_, suiv:'taskdeux')
      tkb = tache(id:'taskdeux')
      MyTaches::Tache::set_taches_prev
      refute(tka.no_time?)
      assert(tkb.no_time?)
      assert(tka.suiv?)
      refute(tkb.suiv?)
      refute(tkb.start_time.nil?)
      assert_equal(_NOW_.plus(1).jour, tkb.start_time)
    end

    test "TEMPS On peut définir le :start avec des valeurs symboliques (sam, dim, etc.)" do
      tk = tache()
      tk.edit_data = {}

      # * opération *
      Q.answers = [
        'sam 8:45'
      ]
      tk.edit_start

      # * check intermédiaire *
      assert_equal(6, date_from(tk.edit_data[:start]).wday)
      assert_equal(samedi.at('8:45').jj_mm_aaaa_hh_mm, tk.edit_data[:start])

      # * opération *
      Q.answers = [
        'vendredi 7:59'
      ]
      tk.edit_start

      # * check *
      assert_equal(vendredi.at('7:59').jj_mm_aaaa_hh_mm, tk.edit_data[:start])
      assert_equal(5, date_from(tk.edit_data[:start]).wday)
    
    end



    # === TEMPS ESTIMÉS (ESTIMATED) ===


    test "ESTIM Estimation des temps avec rien de défini produit nil" do
      tk = tache(id:'esti-a')
      assert_nil(tk.start_time)
      assert_nil(tk.end_time)
    end
    
    test "ESTIM Estimation des temps avec tâches liées sans rien" do
      tkpre = tache(id:'esti-b', suiv:'esti-c').save
      tkcur = tache(id:'esti-c', suiv:'esti-d').save
      tksui = tache(id:'esti-d').save
      MyTaches::Tache.set_taches_prev
      assert_equal(tkpre.id, tkcur.prev_id)
      assert_equal(tkcur.id, tksui.prev_id)

      # = test =
      assert_nil(tkpre.start_time)
      assert_nil(tkpre.end_time)
      assert_nil(tkcur.start_time)
      assert_nil(tkcur.end_time)
      assert_nil(tksui.start_time)
      assert_nil(tksui.end_time)
    end

    test "ESTIM Estimation des temps avec tâches liées et start" do
      tkpre = tache(id:'esti-e', suiv:'esti-f', start:DEMAIN).save
      tkcur = tache(id:'esti-f', suiv:'esti-g', start:DEMAIN.plus(1).jour).save
      tksui = tache(id:'esti-g', start:DEMAIN.plus(2).jours).save
      MyTaches::Tache.set_taches_prev
      assert_equal(tkpre.id, tkcur.prev_id)
      assert_equal(tkcur.id, tksui.prev_id)

      # = test =
      assert_not_nil(tkpre.start_time)
      assert_not_nil(tkpre.end_time)
      assert_equal(DEMAIN.plus(1).jour, tkpre.end_time)
      assert_not_nil(tkcur.start_time)
      assert_equal(DEMAIN.plus(1).jours, tkcur.start_time)
      assert_not_nil(tkcur.end_time)
      assert_equal(DEMAIN.plus(2).jours, tkcur.end_time)
      assert_not_nil(tksui.start_time)
      assert_equal(DEMAIN.plus(2).jours, tksui.start_time)
      assert_not_nil(tksui.end_time)
      assert_equal(DEMAIN.plus(3).jours, tksui.end_time)
    end


    test "ESTIM Tache#start_time retourne la bonne valeur quand le temps de départ est défini" do
      tk = tache(id:"testi-a", start: DEMAIN, duree:'2d')
      assert_equal(DEMAIN, tk.start_time)
    end

    test "ESTIM Tache#end_time retourne la bonne valeur quand le temps de début et la durée sont définis" do
      tk = tache(id:"testf-b", start: DEMAIN, duree:'2d')
      assert_equal(DEMAIN.plus(2).jours, tk.end_time)
    end

    test "ESTIM Tache#end_time retourne la bonne valeur quand le temps de début de la tâche suivante et la durée de la tâche sont définis" do
      tk      = tache(id:"testf-d", duree:'2d')
      tksuiv  = tache(id:'testf-c', start: DEMAIN)
      tk.link_to(tksuiv).save
      tksuiv.save
      MyTaches::Tache.set_taches_prev
      assert_equal(DEMAIN.moins(2).jour, tk.start_time)
      assert_equal(DEMAIN, tk.end_time)
    end

    test "ESTIM #start_time est bon quand on peut définir le temps de fin de la tâche précédente" do
      tkprev = tache(id:'testi-e', end: nil, start:DEMAIN, duree:'2d')
      tk = tache(id:'testi-f', start:nil, end: nil, duree: nil)
      tkprev.link_to(tk).save
      tk.save
      MyTaches::Tache.set_taches_prev
      assert_equal(tkprev.id, tk.prev_id)
      assert_equal(DEMAIN.plus(2).jours, tkprev.end_time)
      assert_equal(DEMAIN.plus(2).jours, tk.start_time)
    end

    test "ESTIM Une tâche sans :start ni :end ne peut pas estimer ses temps" do
      tk = tache(id: 'tk-estim-1', duree: '2d')
      assert_nil(tk.start_time)
      assert_nil(tk.end_time)
    end

    test "ESTIM Une tâche avec :start seulement peut estimer son temps de fin" do
      tk = tache(id: 'tk-estim-2', start: _NOW_)
      assert_not_nil(tk.start_time)
      assert_not_nil(tk.end_time)
      assert_equal(_NOW_ + 1.jour, tk.end_time)
    end

    test "ESTIM Une tâche avec un start: et une durée estime bien son temps de fin" do
      tk = tache(id: 'tk-estim-4', start: hdate(_NOW_), duree:'3d')
      assert_not_nil(tk.start_time)
      assert_not_nil(tk.end_time)
      assert_equal(_NOW_ + 3.jours, tk.end_time)
    end


    # === LISTING DES TÂCHES ===


    test "LIST La propriété méthode Tache::all renvoie toutes les tâches au format MyTaches::Tache" do
      reset_taches
      tache({todo:"Première", id:'t1'}, saveit = true)
      assert_equal(1, all_taches.count)
      tache({todo:"Deuxième", id:'t2'}, saveit = true)
      assert_equal(2, all_taches.count)
      tache({todo:"Troisième", id:'t3'}, saveit = true)
      assert_equal(3, all_taches.count)
      all_taches.each do |tache|
        assert_equal(MyTaches::Tache, tache.class)
      end
    end

    test "LIST Tache::all renvoie les bonnes tâches avec test sur :todo et :cate" do
      taches = create_taches(10, reset: true, index:true)
      assert_equal(10, all_taches.count)
      assert_equal(MyTaches::Tache, taches.first.class)
      cate_name   = "Mon Groupe"
      cate2_name  = "Mon autre catégorie"
      tk1_gr = taches[1]
      tk4_gr = taches[4]
      tk6_gr = taches[6]
      tk8_gr = taches[8]
      [tk1_gr, tk4_gr, tk6_gr, tk8_gr].each do |tk|
        tk.data.merge!(cate: cate_name)
        tk.save
      end
      [2,5,7].each do |i|
        tk = taches[i]
        tk.data.merge!(cate: cate2_name)
        tk.save
      end
      assert_equal(4,   all_taches(categorie: cate_name).count)
      assert_equal(10,  all_taches(todo: /Tâche/).count)
      assert_equal(1,   all_taches(todo:'0').count)
      assert_equal(0,   all_taches(categorie: 'Mon').count)
      assert_equal(7,   all_taches(categorie:/Mon/).count)
    end

    test "LIST Tache::all retourne les bonnes tâches par le temps" do
      taches = create_taches_with_time_et_duree(10, reset: true)
      allt = all_taches(start_after: _NOW_.moins(5).jours)
      if allt.count != 3
        puts "Trouvées : #{allt.map{|tk| tk.id}.join(", ")}".rouge
      end
      assert_equal(3, allt.count)
      allt = all_taches(start_before: _NOW_.moins(1).jour)
      if allt.count != 3
        puts "Trouvées : #{allt.map{|tk| tk.id}.join(", ")}".rouge
      end
      assert_equal(3, allt.count)
      assert_equal(2, all_taches(end_before: _NOW_ + 4.jours).count)
      assert_equal(3, all_taches(end_after: _NOW_ + 5.jours).count)
    end

    test "LIST Tache:all retourne les bonnes tâches par la durée" do
      taches = create_taches_with_time_et_duree(10, reset: true)
      assert_equal(2, all_taches(duree_min: '12d').count)
      assert_equal(1, all_taches(duree_max: '4d').count)
    end

    test "LIST Tache::all retourne les bonnes tâches par la liaison" do
      taches = create_taches(10, reset:true)
      assert_equal(10, all_taches.count)
      assert_equal(MyTaches::Tache, taches.first.class)
      taches[0].link_to(taches[1])
      taches[1].link_to(taches[3])
      taches[3].link_to(taches[8])
      taches[2].link_to(taches[9])
      taches[9].link_to(taches[6])
      MyTaches::Tache.set_taches_prev

      assert_equal(7, all_taches(linked:true).count)
      assert_equal(3, all_taches(linked:false).count)

    end

    test "LIST MyTaches::Tache#display_as_linked retourne le listing bien formaté" do

      # = Préparation =
      
      require_relative 'Tache_list'
      # Notamment pour les constantes d'affichage
      
      taches = create_taches(10, categorie: 'Tâches liées en essai', reset: true, index:true)
      tk1 = taches[1]; tk1.data.merge!(start: DEMAIN.jj_mm_aaaa, duree:'1d')
      tk4 = taches[4]; tk4.data.merge!(duree:'1d')
      tk6 = taches[6]; tk6.data.merge!(start: DEMAIN.plus(4).jours.jj_mm_aaaa, duree:'1d')
      tk8 = taches[8]; tk8.data.merge!(duree:'2d')
      tk9 = taches[9]; tk9.data.merge!(duree:'4d')
      tk1.link_to(tk4).save
      tk4.link_to(tk6).save
      tk6.link_to(tk9).save
      tk9.link_to(tk8).save
      tk8.save
      MyTaches::Tache.set_taches_prev

      # * check préliminaire *
      assert_equal(tk1.id, tk4.prev_id)
      assert_equal(tk6.id, tk9.prev_id)
      assert_equal(tk8, tk9.suiv)
      assert_equal(tk9.id, tk8.prev_id)
      assert_equal(DEMAIN_MATIN, tk1.start_time)
      assert_equal(DEMAIN_MATIN.plus(1).jour, tk1.end_time)
      assert_equal(DEMAIN_MATIN.plus(1).jour, tk4.start_time)
      assert_equal(DEMAIN_MATIN.plus(9).jours, tk8.start_time)

      # = Opération =

      lines = tk1.lines_linked_task.split("\n")
      # puts "\n"
      # lines.each_with_index do |line, idx|
      #   puts "LINE #{idx}: #{line}"
      # end

      assert_equal("  TÂCHES LIÉES EN ESSAI", lines[1])
      assert_equal("#{MyTaches::INDENT_FIRST_LINKED_TASK}#{MyTaches::PICTO_START_TASK}#{DEMAIN.jj_mm} * Tâche n°1 * 1 jour #{MyTaches::PICTO_END_TASK}#{DEMAIN.plus(1).jour.jj_mm}", lines[3])
      expline = "#{MyTaches::INDENT_OTHER_LINKED_TASK}#{MyTaches::PICTO_START_TASK}~#{DEMAIN.plus(9).jours.jj_mm} * Tâche n°8 * 2 jrs #{MyTaches::PICTO_END_TASK}~#{DEMAIN.plus(11).jour.jj_mm}"
      assert_equal(expline, lines[11])
    end


    # --- CLASSEMENT/SORT (all(:sort) ---


    test "LIST SORT On peut lister par date de début" do
      create_taches_with_time_et_duree(10, reset:true, index:true)
      
      # * test *
      taches = MyTaches::Tache.all.sorted(key: :start, dir: :asc)
      
      # puts "\n"
      # taches.each_with_index do |tk, idx|
      #   puts "Index #{idx} : #{tk.id}".jaune
      # end
      
      # = check =
      assert_equal('t2', taches[0].id)
      assert_equal('t3', taches[1].id)
      assert_equal('t0', taches[2].id)
      assert_equal('t4', taches[3].id)
      assert_equal('t1', taches[4].id)
      assert_equal(5, taches.count)

      # * test *
      taches = MyTaches::Tache.all.sorted(key: :start, dir: :desc)

      # = check =
      assert_equal(5, taches.count)
      assert_equal('t1', taches[0].id)
      assert_equal('t4', taches[1].id)
      assert_equal('t0', taches[2].id)
      assert_equal('t3', taches[3].id)
      assert_equal('t2', taches[4].id)

    end

    test "LIST Classement par date de début en forçant toutes" do
      create_taches_with_time_et_duree(10, reset:true, index:true)

      # * test *
      taches = MyTaches::Tache.all.sorted(key: :start, dir: :asc, force_all:true)

      # = check =
      assert_equal(10, taches.count)
      assert_equal('t2', taches[0].id)
      assert_equal('t3', taches[1].id)
      assert_equal('t0', taches[2].id)
      assert_equal('t4', taches[3].id)

    end


    test "LIST Classement par date de fin" do

      create_taches_with_time_et_duree(10, reset:true, index:true)

      # * test *
      taches = MyTaches::Tache.all.sorted(key: :end)

      # = check =
      assert_equal(5, taches.count)
      assert_equal('t2', taches[0].id)
      assert_equal('t1', taches[1].id)
      assert_equal('t0', taches[2].id)
      assert_equal('t4', taches[3].id)
      assert_equal('t3', taches[4].id)
      
    end

    test "LIST Classement par intitulé (:todo)" do

      create_taches_with_time_et_duree(10, reset:true, index:true)

      # * test *
      taches = MyTaches::Tache.all.sorted(key: :todo)

      # = check =
      assert_equal(10, taches.count)
      assert_equal('t0', taches[0].id)
      assert_equal('t1', taches[1].id)
      assert_equal('t2', taches[2].id)
      assert_equal('t3', taches[3].id)
      assert_equal('t4', taches[4].id)
      assert_equal('t5', taches[5].id)
      assert_equal('t6', taches[6].id)
      assert_equal('t7', taches[7].id)
      assert_equal('t8', taches[8].id)
      assert_equal('t9', taches[9].id)
    end

    test "LIST Classement par intitulé (:todo) inversé" do

      create_taches_with_time_et_duree(10, reset:true, index:true)

      # * test *
      taches = MyTaches::Tache.all.sorted(key: :todo, dir: :desc)

      # = check =
      assert_equal(10, taches.count)
      assert_equal('t0', taches[9].id)
      assert_equal('t1', taches[8].id)
      assert_equal('t2', taches[7].id)
      assert_equal('t3', taches[6].id)
      assert_equal('t4', taches[5].id)
      assert_equal('t5', taches[4].id)
      assert_equal('t6', taches[3].id)
      assert_equal('t7', taches[2].id)
      assert_equal('t8', taches[1].id)
      assert_equal('t9', taches[0].id)
    end

    test "LIST Pas de classement par la catégorie" do

      # * test *
      assert_raise(RuntimeError) { MyTaches::Tache.all.sorted(key: :cate, alt_key: :start, alt_dir: :desc) }
    
    end

    test "LIST all.per_categorie permet un classement par catégorie" do

      create_taches_with_time_et_duree(10, reset:true)

      # * test *
      htaches = MyTaches::Tache.all.per_categorie

      if false
        htaches.each do |cate, tks|
          puts "CATÉGORIE : #{cate}"
          tks.each do |tk|
            puts "#{tk.todo} : #{tk.f_start_time}"
          end
        end
      end

      # puts htaches.to_h

      assert_equal(3, htaches.count)
      assert_equal('aaa', htaches.keys[0])
      assert_equal(Array, htaches['aaa'].class)
      assert_equal(6, htaches['aaa'].count)
      assert_equal(2, htaches['bbb'].count)
      assert_equal(2, htaches['ccc'].count)
      assert_equal(MyTaches::Tache, htaches['aaa'].first.class)
      assert_equal('bbb', htaches.keys[1])
      assert_equal('ccc', htaches.keys[2])

    end

    test "LIST all.per_categorie avec :all à faux permet de ne remonter que les tâches avec temps" do

      create_taches_with_time_et_duree(10, reset:true)

      # * test *
      htaches = MyTaches::Tache.all.per_categorie(all: false)

      # htaches.each do |cate, tks|
      #   puts "CATÉGORIE : #{cate}"
      #   tks.each do |tk|
      #     puts "#{tk.todo} : #{tk.f_start_time}"
      #   end
      # end

      # puts htaches.to_h

      assert_equal(2, htaches.count)
      assert_equal('aaa', htaches.keys[0])
      assert_equal(Array, htaches['aaa'].class)
      assert_equal(4, htaches['aaa'].count)
      assert_equal(1, htaches['bbb'].count)
      assert_equal(MyTaches::Tache, htaches['aaa'].first.class)
      assert_equal('bbb', htaches.keys[1])

    end



    # === STATUTS DES TÂCHES ===



    #
    # Une instance qui ne définit ni :start ni :end
    # renvoie false pour :no_time?
    #
    test "STATUS #no_time? renvoie true s'il n'y a ni échéance de début ni échéance de fin" do
      inst = tache(duree: 1000)
      assert_true(inst.no_time?)
    end

    #
    # Pour une instance qui commence demain :
    #   :no_time? est false
    #   :futur?   est true
    #   :end_time est défini par défaut au même temps
    #   auquel est ajouté un jour
    # 
    test "STATUS Les propriété no_time? futur? et :end_time sont bonnes pour une instance commençant demain" do
      inst = tache(start:hdate(DEMAIN))
      assert_equal(inst.start_time, date_from(hdate(DEMAIN)))
      refute(inst.no_time?)
      assert(inst.times?)
      assert_true(inst.futur?)
      assert_not_nil(inst.end_time)
      assert_equal(DEMAIN.plus(1).jour, inst.end_time)
    end

    #
    # Pour une instance qui a commencé une demi-heure
    # plus tôt (et dure donc 1 jour)
    #   :no_time?     est false
    #   :futur?       est false
    #   :current      est true
    test "STATUS Une tâche commencée il y a un quart d'heure, sans durée, est current? et pas futur?" do
      inst = tache(start:hdate(_NOW_ - 30*60))
      refute(inst.futur?)
      refute(inst.no_time?)
      assert(inst.current?)
    end

    #
    # Pour une instance dont l'échéance est dépassée
    #   :no_time?       est false
    #   :current?       est false
    #   :out_of_date?   est true
    test "STATUS Une tâche à plus de 10 jours de durée 1 jour est dépassée (out-of-date), n'est pas futur" do
      inst = tache(start:_NOW_.moins(10).jours, duree: '1d')
      refute(inst.no_time?)
      refute(inst.futur?)
      assert(inst.current?)
      assert(inst.out_of_date?)
      refute(inst.suivante?)
    end

    test "STATUS before? retourne la bonne valeur" do
      reset_taches
      tka, tkb = create_taches(2)
      tka.start = _NOW_.plus(2).jours
      tkb.start = _NOW_.moins(3).jours
      tka.save
      tkb.save

      assert_nothing_raised { tka.before?(tkb) }
      assert_true(tkb.before?(tka))
      assert_false(tka.before?(tkb))
      
    end
    test "STATUS after? retourne la bonne valeur" do
      reset_taches
      tka, tkb = create_taches(2)
      tka.start = _NOW_.plus(2).jours
      tkb.start = _NOW_.moins(3).jours
      tka.save
      tkb.save

      assert_nothing_raised { tka.after?(tkb) }
      assert_true(tka.after?(tkb))
      assert_false(tkb.after?(tka))
    end

    # === Tests sur les liaisons de tâche ===

    test "LINK Une tâche peut être liée à une tâche suivante" do
      # -avant-
      #         TKAP
      #         NT
      # -après-
      #         NT -> TKAP
      # 
      # -par- 
      #         suiv:
      # 
      reset_taches
      taskapres = tache(todo:"Une deuxième tâche après", id:'tache_apres').save
      newtask   = tache(todo:"Tâche insérée", id:'tache_inserted')
      # Check préliminaire
      assert_nil(taskapres.prev_id)
      assert_nil(newtask.data[:suiv])
      # = Opération =
      newtask.init_edition
      newtask.edit_suiv(taskapres)
      newtask.check.save
      # Check final
      assert_equal(taskapres.id, newtask.data[:suiv])
      assert_equal(newtask.id, taskapres.prev_id)
    end

    test "LINK Une tâche peut être liée à une tâche précédente" do
      # -avant-
      #         TKAV
      #           NT
      # -après-
      #         TKAV -> NT
      # -par-
      #         prev:
      # 
      reset_taches
      taskavant = tache(todo:"Une première tâche avant", id:'tache_avant').save
      newtask   = tache(todo:"Tâche insérée", id:'tache_inserted')
      # Check préliminaire
      assert_nil(taskavant.data[:suiv])
      assert_nil(newtask.prev_id)
      # = Opération =
      newtask.init_edition
      newtask.edit_prev(taskavant)
      newtask.check.save
      # Check
      assert_equal(newtask.id, taskavant.data[:suiv])
      assert_equal(taskavant.id, newtask.prev_id)
    end


    test "LINK Une tâche peut être insérée entre deux tâchées non liées" do
      # -avant-
      #         TKAV
      #         TKAP
      #         NT
      # -après-
      #         TKAV -> NT -> TKAP
      # -par-
      #         :prev, :suiv
      # 
      reset_taches
      taskavant = tache(todo:"Une première tâche avant", id:'tache_avant').save
      taskapres = tache(todo:"Une deuxième tâche après", id:'tache_apres').save
      newtask   = tache(todo:"Tâche insérée", id:'tache_inserted')

      # Check préliminaire
      assert_nil(taskavant.data[:suiv])
      assert_nil(taskapres.prev_id)

      # = Opération =
      newtask.init_edition
      newtask.edit_prev(taskavant)
      newtask.edit_suiv(taskapres)
      newtask.check.save

      # - Check -
      assert_equal(newtask.id, taskavant.data[:suiv])
      assert_equal(newtask.id, taskapres.prev_id)
      assert_equal(taskavant.id, newtask.prev_id)
      assert_equal(taskapres.id, newtask.data[:suiv])

    end

    test "LINK Une tâche insérée par :prev entre deux tâches liées règle bien les liaisons" do
      # -avant-
      #         TKAV -> TKAP
      #         NT
      # -après-
      #         TKAV -> NT -> TKAP
      # -par-
      #         :prev
      # 
      reset_taches
      taskavant = tache(todo:"Une première tâche avant", id:'tache_avant', suiv:'tache_apres')
      taskapres = tache(todo:"Une deuxième tâche après", id:'tache_apres')
      newtask   = tache(todo:"Tâche insérée", id:'tache_inserted')
      MyTaches::Tache.set_taches_prev

      # Check préliminaire
      assert_nil(newtask.prev_id)
      assert_nil(newtask.data[:suiv])
      assert_equal(taskapres.id, taskavant.data[:suiv])
      assert_equal(taskavant.id, taskapres.prev_id)

      # = Opération =
      newtask.init_edition
      newtask.edit_prev(taskavant)
      newtask.check.save

      # - Check final -
      assert_equal(taskavant.id, newtask.prev_id)
      assert_equal(taskapres.id, newtask.data[:suiv])
      assert_equal(newtask.id, taskavant.data[:suiv])
      assert_equal(newtask.id, taskapres.prev_id)

    end

    test "LINK Une tâche insérée par :suiv entre 2 tâches liées règle bien les liaisons" do
      # -avant-
      #         TKAV -> TKAP
      #         NT
      # -après-
      #         TKAV -> NT -> TKAP
      # -par-
      #         :suiv
      # 
      reset_taches
      taskavant = tache(todo:"Une première tâche avant", id:'tache_avant', suiv:'tache_apres').save
      taskapres = tache(todo:"Une deuxième tâche après", id:'tache_apres').save
      newtask   = tache(todo:"Tâche insérée", id:'tache_inserted')
      MyTaches::Tache.set_taches_prev

      # Check préliminaire
      assert_nil(newtask.prev_id)
      assert_nil(newtask.data[:suiv])
      assert_equal(taskapres.id, taskavant.data[:suiv])
      assert_equal(taskavant.id, taskapres.prev_id)

      # = Opération =
      newtask.init_edition
      newtask.edit_suiv(taskapres)
      newtask.check.save

      # - Check final -
      assert_equal(taskavant.id, newtask.prev_id)
      assert_equal(taskapres.id, newtask.data[:suiv])
      assert_equal(newtask.id, taskavant.data[:suiv])
      assert_equal(newtask.id, taskapres.prev_id)

    end

    test "LINK Une tâche insérée entre deux tâches non liées les règlent bien" do

      reset_taches
      taskavant = tache(todo:"Une première tâche avant", id:'tache_avant').save
      taskapres = tache(todo:"Une deuxième tâche après", id:'tache_apres').save
      newtask = tache(todo:"Tâche insérée", id:'tache_inserted')

      # Check préliminaire
      assert_nil(newtask.prev_id)
      assert_nil(newtask.data[:suiv])
      assert_nil(taskavant.data[:suiv])
      assert_nil(taskapres.prev_id)

      # = Opération =
      newtask.init_edition
      newtask.edit_suiv(taskapres)
      newtask.edit_prev(taskavant)
      newtask.check.save

      # - Check final -
      assert_equal(newtask.id, taskapres.prev_id)
      assert_equal(newtask.id, taskavant.data[:suiv])
      assert_equal(taskapres.id, newtask.data[:suiv])
      assert_equal(taskavant.id, newtask.prev_id)

    end

     test "LINK Une tâche insérée déplacée relie ses deux tâches liées" do
      # -avant-
      #         TKAV -> CT -> TKAP
      #         T3 -> T4
      # -après-
      #         TKAV -> TKAP
      #         T3 -> T4
      #         CT
      # -par-
      #         :prev et :suiv (mis à nil)
      # 

      ct, tkav, tkap, t3, t4 = make_4_taches_et_currente

      # Check préliminaire
      assert_equal(ct.id, tkav.suiv.id)
      assert_equal(tkav.id, ct.prev_id)
      assert_equal(tkap.id, ct.suiv.id)
      assert_equal(ct.id, tkap.prev_id)

      # = Opération =
      ct.init_edition
      ct.edit_prev(nil)
      ct.edit_suiv(nil)
      ct.check.save

      # Check #
      assert_equal(tkap.id, tkav.data[:suiv])
      assert_equal(tkav.id, tkap.prev_id)

    end

    test "LINK Une tâche déplacée vers deux autres tâches non liées" do
      # SOIT ct, placée entre tkav et tkap
      # SI on déplace ct entre t3 et T4
      # ALORS :
      #   ct est bien déplacée
      #   tkav et tkap se trouvent reliées

      ct, tkav, tkap, t3, t4 = make_4_taches_et_currente

      # Checks préliminaires
      assert_nil(t3.data[:suiv])
      assert_nil(t4.data[:prev])
      assert_equal(ct.id, tkav.data[:suiv])
      assert_equal(ct.id, tkap.prev_id)

      # = Opération =
      ct.init_edition
      ct.edit_prev(t3)
      ct.edit_suiv(t4)
      ct.check.save

      # Check final #
      assert_equal(tkap.id, tkav.data[:suiv])
      assert_equal(tkav.id, tkap.prev_id)
      assert_equal(t4.id, ct.data[:suiv])
      assert_equal(ct.id, t3.data[:suiv])

    end

    test "LINK Une tâche déplacée vers deux autres tâches liées" do
      # SOIT ct, placée entre tkav et tkap
      # SOIT t3 et t4 reliées entre elles
      # SI on déplace ct entre t3 et T4
      # ALORS :
      #   ct est bien insérée entre t3 et t4
      #   tkav et tkap se trouvent reliées
      # 
      # -avant-
      #         TKAV -> CT -> TKAP 
      #         T3 -> T4
      # -après-
      #         TKAV -> TKAP
      #         T3 -> CT -> T4
      # -par-
      # 

      ct, tkav, tkap, t3, t4 = make_4_taches_et_currente
      t3.link_to(t4).save

      # Checks préliminaires
      assert_equal(tkav.id, ct.prev_id)
      assert_equal(tkap.id, ct.data[:suiv])
      assert_equal(ct.id,   tkav.data[:suiv])
      assert_equal(ct.id,   tkap.prev_id)
      assert_equal(t4.id,   t3.data[:suiv])

      # = Opération =
      ct.init_edition
      ct.edit_prev(t3)
      ct.edit_suiv(t4)
      ct.check.save

      # Check final #
      assert_equal(t3.id, ct.prev_id)
      assert_equal(t4.id, ct.data[:suiv])
      assert_equal(tkav.id, tkap.prev_id)
      assert_equal(tkap.id, tkav.data[:suiv])
      assert_equal(ct.id, t4.prev_id)
      assert_equal(ct.id, t3.data[:suiv])


    end

    test "LINK Déplacement d'une tâche liée vers une même tâche" do

      # Déplacement :
      #   TKAV
      #   CT ---·
      #   TKAP  |
      #   CT <--·
      #   T3
      #
      # -avant-
      #         TKAV -> CT -> TKAP -> T3
      # -après-
      #         TKAV -> TKAP -> CT -> T3
      # -par-
      #         :prev
      # 
      # Pour le moment, c'est faux…

      ct, tkav, tkap, t3, t4 = make_4_taches_et_currente
      tkap.link_to(t3).save
      MyTaches::Tache.set_taches_prev

      # Check préliminaire
      assert_equal(tkav.id, ct.prev_id)
      assert_equal(tkap.id, ct.data[:suiv])
      assert_nil(tkav.prev_id)
      assert_equal(ct.id,   tkav.data[:suiv])
      assert_equal(ct.id,   tkap.prev_id)
      assert_equal(t3.id,   tkap.data[:suiv])
      assert_equal(tkap.id, t3.prev_id)
      assert_nil(t3.data[:suiv])

      # = Opération =
      ct.init_edition
      ct.edit_prev(tkap)
      ct.check.save

      # Check final #
      assert_nil(tkav.prev_id)
      assert_equal(tkap.id, tkav.data[:suiv])
      assert_equal(tkav.id, tkap.prev_id)
      assert_equal(ct.id,   tkap.data[:suiv])
      assert_equal(tkap.id, ct.prev_id)
      assert_equal(t3.id,   ct.data[:suiv])
      assert_equal(ct.id,   t3.prev_id)
      assert_nil(t3.data[:suiv])

    end

    test "LINK Déplacements et tâches liées dans un parcours" do
      # Ce dernier test permet de tester des liaisons et
      # des déplacements/insertions comme si c'était en 
      # temps réel

      reset_taches

      # On crée deux premières tâches non liées
      t1 = tache(todo:'T1', id:'t1')
      t2 = tache(todo:'T2', id:'t2')
      # =>
      #   T1
      #   T2

      # On crée une troisième liée à la première (avant)
      # t3 -> t1
      # t2
      t3 = tache(todo:'T3', id:'t3')
      t1.link_to(t3).save 
      MyTaches::Tache.set_taches_prev
      assert_equal(t1.id, t3.prev_id)
      assert_equal(t3.id, t1.data[:suiv])
      # =>
      #   T1 -> T3
      #   T2

      # On lie la 3 à la 2e
      t3.init_edition
      t3.edit_suiv(t2)
      t3.check.save
      assert_equal(t1.id, t3.prev_id)
      assert_equal(t2.id, t3.data[:suiv])
      assert_equal(t3.id, t1.data[:suiv])
      assert_equal(t3.id, t2.prev_id)
      # =>
      #   T1 -> T3 -> T2

      # On ajoute une tâche après T2
      t4 = tache(todo:'T4', id:'t4')
      t2.link_to(t4).save
      MyTaches::Tache.set_taches_prev
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(t3.id, t1.data[:suiv])
      assert_equal(t3.id, t2.prev_id)
      assert_equal(t4.id, t2.data[:suiv])
      assert_equal(t1.id, t3.prev_id)
      assert_equal(t2.id, t3.data[:suiv])
      assert_equal(t2.id, t4.prev_id)
      assert_equal(nil,   t4.data[:suiv])
      # =>
      #   T1 -> T3 -> T2 -> T4

      # On déplace T3 pour la mettre entre T2 et T4
      # =>
      #   T1 -> T2 -> T3 -> T4
      # Cette opération devrait être faite comme ça :
      #   t3.edit_data = {prev: "t2"}
      #   * on doit regarder où se trouve t2
      #   * puisqu'elle a un :prev, il faut la
      #     détacher (de t3)
      #   * puisqu'elle a un :suiv, il faut la
      #     détacher (de t4)
      #   * puisqu'elle a les deux => recoller
      #   * => recoller T3 et T4
      #   * il faut que suiv de T2 soit mis à 
      #     T3
      #   * mais comme T3 a déjà un prev_id (T1)
      #     il faut mettre le prev_id de T2 à T1
      #   
      t3.init_edition
      t3.edit_prev(t2)
      t3.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(t2.id, t1.data[:suiv])
      assert_equal(t1.id, t2.prev_id)
      assert_equal(t3.id, t2.data[:suiv])
      assert_equal(t2.id, t3.prev_id)
      assert_equal(t4.id, t3.data[:suiv])
      assert_equal(t3.id, t4.prev_id)
      assert_equal(nil,   t4.data[:suiv])
      # =>
      #   T1 -> T2 -> T3 -> T4

      # On crée deux autres branches avec une tâche T5 et T6
      t5 = tache(todo:'T5', id:'t5')
      t6 = tache(todo:'T6', id:'t6')
      # Check final #
      assert_nil(t5.prev_id)
      assert_nil(t5.data[:suiv])
      assert_nil(t6.prev_id)
      assert_nil(t6.data[:suiv])
      # =>
      #   T1 -> T2 -> T3 -> T4
      #   T5
      #   T6

      # On déplace T2 pour la mettre entre T6 et T5
      # =>
      #   T1 -> T3 -> T4
      #   T6 -> T2 -> T5
      #   
      t2.init_edition
      t2.edit_suiv(t5)
      t2.edit_prev(t6)
      t2.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(t3.id, t1.data[:suiv])
      assert_equal(t6.id, t2.prev_id)
      assert_equal(t5.id, t2.data[:suiv])
      assert_equal(t1.id, t3.prev_id)
      assert_equal(t4.id, t3.data[:suiv])
      assert_equal(t3.id, t4.prev_id)
      assert_equal(nil,   t4.data[:suiv])
      assert_equal(t2.id, t5.prev_id)
      assert_equal(nil,   t5.data[:suiv])
      assert_equal(nil,   t6.prev_id)
      assert_equal(t2.id, t6.data[:suiv])
      # =>
      #   T1 -> T3 -> T4
      #   T6 -> T2 -> T5
      #/


      # On sort T3 de sa suite
      # =>
      #   T1 -> T4
      #   T6 -> T2 -> T5
      #   T3
      # CONFIG.debug = true
      t3.init_edition
      t3.edit_suiv(nil)
      t3.edit_prev(nil)
      t3.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(t4.id, t1.data[:suiv])
      assert_equal(t6.id, t2.prev_id)
      assert_equal(t5.id, t2.data[:suiv])
      assert_equal(nil,   t3.prev_id)
      assert_equal(nil,   t3.data[:suiv])
      assert_equal(t1.id, t4.prev_id)
      assert_equal(nil,   t4.data[:suiv])
      assert_equal(t2.id, t5.prev_id)
      assert_equal(nil,   t5.data[:suiv])
      assert_equal(nil,   t6.prev_id)
      assert_equal(t2.id, t6.data[:suiv])

      # On relie les deux premières branches en indiquant
      # le suiv de T4
      # =>
      #   T1 -> T4 -> T6 -> T2 -> T5
      #   T3
      t4.init_edition
      t4.edit_suiv(t6)
      t4.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(t4.id, t1.data[:suiv])
      assert_equal(t6.id, t2.prev_id)
      assert_equal(t5.id, t2.data[:suiv])
      assert_equal(nil,   t3.prev_id)
      assert_equal(nil,   t3.data[:suiv])
      assert_equal(t1.id, t4.prev_id)
      assert_equal(t6.id, t4.data[:suiv])
      assert_equal(t2.id, t5.prev_id)
      assert_equal(nil,   t5.data[:suiv])
      assert_equal(t4.id, t6.prev_id)
      assert_equal(t2.id, t6.data[:suiv])

      # Je retire T1 de la suite
      # =>
      #   T4 -> T6 -> T2 -> T5
      #   T3
      #   T1
      t1.init_edition
      t1.edit_suiv(nil)
      t1.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(nil,   t1.data[:suiv])
      assert_equal(t6.id, t2.prev_id)
      assert_equal(t5.id, t2.data[:suiv])
      assert_equal(nil,   t3.prev_id)
      assert_equal(nil,   t3.data[:suiv])
      assert_equal(nil,   t4.prev_id)
      assert_equal(t6.id, t4.data[:suiv])
      assert_equal(t2.id, t5.prev_id)
      assert_equal(nil,   t5.data[:suiv])
      assert_equal(t4.id, t6.prev_id)
      assert_equal(t2.id, t6.data[:suiv])

      # Je mets T5 au début de la suite
      # =>
      #   T5 -> T4 -> T6 -> T2
      #   T3
      #   T1
      t5.init_edition
      t5.edit_suiv(t4)
      t5.check.save
      # Check final #
      assert_equal(nil,   t1.prev_id)
      assert_equal(nil,   t1.data[:suiv])
      assert_equal(t6.id, t2.prev_id)
      assert_equal(nil,   t2.data[:suiv])
      assert_equal(nil,   t3.prev_id)
      assert_equal(nil,   t3.data[:suiv])
      assert_equal(t5.id, t4.prev_id)
      assert_equal(t6.id, t4.data[:suiv])
      assert_equal(nil,   t5.prev_id)
      assert_equal(t4.id, t5.data[:suiv])
      assert_equal(t4.id, t6.prev_id)
      assert_equal(t2.id, t6.data[:suiv])


    end

    test "LINK Une tâche ne peut pas régler son :start avant la tâche qui la précède" do
      # Note : il y a deux cas :
      #   1. :start est avant la fin de la tâche précédente
      #   2. :start est avant le début de la tâche précédente
      # edit_start
      tka, tkb = create_taches(2)
      tka.start = _NOW_.moins(4).jours
      tka.data[:duree] = '4d'
      tka.link_to(tkb).save
      MyTaches::Tache.set_taches_prev

      # * check préliminaire *
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.data[:suiv])

      # * opération *
      tkb.edit_data = {}
      Q.answers = [
        _NOW_.moins(6).jours.at('8:06').jj_mm_aaaa_hh_mm
      ]
      tkb.edit_start

      # * check *
      assert_match(/ne peut pas commencer avant la tâche précédente/, texte_console(true))
      assert_nil(tkb.edit_data[:start])

      # * opération *
      Q.answers = [
        _NOW_.moins(3).jours.at('8:30').jj_mm_aaaa_hh_mm
      ]
      tkb.edit_start
      
      # * check *
      assert_match(/ne peut pas commencer avant la tâche précédente/, texte_console(true))
      assert_nil(tkb.edit_data[:start])

    end

    test "LINK Une tâche ne peut pas régler son :end avant la tâche qui la précède" do
      # edit_end
      reset_taches
      tka, tkb = create_taches(2)
      tka.start = _NOW_.moins(4).jours
      tka.data[:duree] = '4d'
      tka.link_to(tkb).save
      MyTaches::Tache.set_taches_prev

      # * check préliminaire *
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.data[:suiv])

      # * opération *
      tkb.edit_data = {}
      Q.answers = [
        _NOW_.moins(5).jours.jj_mm_aaaa_hh_mm
      ]
      tkb.edit_end

      # * check *
      assert_nil(tkb.edit_data[:end])
      assert_match(/ne peut pas terminer avant la tâche précédente/, texte_console(true))

      # * opération *
      Q.answers = [
        _NOW_.moins(2).jours.jj_mm_aaaa_hh_mm
      ]
      tkb.edit_end

      # * check *
      assert_nil(tkb.edit_data[:end])
      assert_match(/ne peut pas terminer avant la tâche précédente/, texte_console(true))

    end

    test "LINK Une tâche ne peut pas régler son :start après la tâche qui la suit" do
      # edit_start
      reset_taches
      tka, tkb = create_taches(2)
      # tka.start = _NOW_.moins(4).jours
      # tka.data[:duree] = '4d'
      tkb.start = _NOW_.plus(1).jours
      tkb.data[:duree] = '4d'
      tkb.save
      tka.link_to(tkb).save
      MyTaches::Tache.set_taches_prev

      # * check préliminaire *
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.data[:suiv])

      # * opération *
      tka.edit_data = {}
      Q.answers = [
        _NOW_.plus(2).jours.jj_mm_aaaa_hh_mm # après le :start
      ]
      tka.edit_start

      # * check *
      assert_nil(tka.edit_data[:start])
      assert_match(/ne peut pas commencer après la tâche suivante/, texte_console(true))

      # * opération *
      Q.answers = [
        _NOW_.plus(7).jours.jj_mm_aaaa_hh_mm # après le :end
      ]
      tka.edit_start

      # * check *
      assert_nil(tka.edit_data[:start])
      assert_match(/ne peut pas commencer après la tâche suivante/, texte_console(true))

    end

    test "LINK Une tâche ne peut pas régler son :end après la tâche qui la suit" do
      # edit_end
      reset_taches
      tka, tkb = create_taches(2)
      # tka.start = _NOW_.moins(4).jours
      # tka.data[:duree] = '4d'
      tkb.start = _NOW_.plus(1).jours
      tkb.data[:duree] = '4d'
      tkb.save
      tka.link_to(tkb).save
      MyTaches::Tache.set_taches_prev

      # * check préliminaire *
      assert_equal(tka.id, tkb.prev_id)
      assert_equal(tkb.id, tka.data[:suiv])

      # * opération *
      tka.edit_data = {}
      Q.answers = [
        _NOW_.plus(2).jours.jj_mm_aaaa_hh_mm # après le :start
      ]
      tka.edit_end

      # * check *
      assert_nil(tka.edit_data[:end])
      assert_match(/ne peut pas terminer après la tâche suivante/, texte_console(true))

      # * opération *
      Q.answers = [
        _NOW_.plus(7).jours.jj_mm_aaaa_hh_mm # après le :end
      ]
      tka.edit_end

      # * check *
      assert_nil(tka.edit_data[:end])
      assert_match(/ne peut pas terminer après la tâche suivante/, texte_console(true))

    end


    test "LINK On ne peut pas choisir en tâche suivante un tâche dont le :start est avant" do
      # edit_suiv

      # * préparation *
      reset_taches
      tka, tkb = create_taches(2)
      tka.start = _NOW_.plus(2).jours
      tkb.start = _NOW_.moins(3).jours
      tka.save
      tkb.save

      # * check préliminaire *
      assert_true(tka.after?(tkb))
      assert_true(tkb.before?(tka))

      # * opération *
      tka.edit_data = {}
      tka.edit_suiv(tkb)

      # * check *
      assert_nil(tka.edit_data[:suiv])
      assert_match(/la tâche suivante ne peut pas commencer avant/, texte_console(true))

    end

    test "LINK La fin d'une tâche liée règle le :start de la tâche suivante" do
      # * préparation *
      tk1_id = get_new_id_tache
      tk2_id = get_new_id_tache
      tk1 = tache(
        id: tk1_id,
        todo: "La première tâche #{tk1_id}",
        suiv: tk2_id
      ).save
      tk2 = tache(id:tk2_id, todo:"Deuxième tâche", duree:'5d').save
      MyTaches::Tache.init
      tk1 = get_tache(tk1_id)
      tk2 = get_tache(tk2_id)

      # * check préliminaire *
      assert_equal(tk1_id, tk2.prev_id)
      assert_nil(tk2.start)
      assert_nil(tk2.start_time)

      # * opération *
      tk1.on_mark_done

      # * check final *
      assert_equal(tk2.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk2.start_time)

    end

    test "LINK La fin d'une tâche liée règle le :start de la tâche suivante (intégration)" do
      # -intégration-

      # * préparation *
      tk1_id = get_new_id_tache
      tk2_id = get_new_id_tache
      tk1 = tache(
        id: tk1_id,
        todo: "La première tâche #{tk1_id}",
        suiv: tk2_id
      ).save
      tk2 = tache(id:tk2_id, todo:"Deuxième tâche", duree:'5d').save
      MyTaches::Tache.init
      tk1 = get_tache(tk1_id)
      tk2 = get_tache(tk2_id)

      # * check préliminaire *
      assert_equal(tk1_id, tk2.prev_id)
      assert_nil(tk2.start)
      assert_nil(tk2.start_time)

      # * opération *
      CLI.main_command = 'done'
      ARGV << tk1_id
      Q.answers = [
        "\n", # confirmation
      ]
      MyTaches.run

      # * check final *
      tk2 = get_tache(tk2_id)
      assert_equal(tk2.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk2.start_time)

    end



    test "LINK La fin d'une tâche liée règle le :start des tâches parallèles suivantes" do
      # * préparation *
      tk1_id = get_new_id_tache
      tk2_id = get_new_id_tache
      tk3_id = get_new_id_tache
      tache(
        id: tk1_id,
        todo: "La première tâche #{tk1_id}",
        suiv: tk2_id
      ).save
      tk2 = tache(id:tk2_id, todo:"Deuxième tâche", duree:'5d', parallels:[tk2_id,tk3_id])
      tk3 = tache(id:tk3_id, todo:"Troisième tâche parallèle à tk2", duree:'10d', parallels:[tk2_id,tk3_id])
      [tk2,tk3].each{|t|t.save}
      MyTaches::Tache.init
      tk1 = get_tache(tk1_id)
      tk2 = get_tache(tk2_id)
      tk3 = get_tache(tk3_id)

      # * check préliminaire *
      assert_equal(tk1_id, tk2.prev_id)
      assert_nil(tk2.start)
      assert_nil(tk3.start)
      assert_nil(tk2.start_time)
      assert_nil(tk3.start_time)
      assert_true(tk2.parallel?)
      assert_true(tk3.parallel?)

      # * opération *
      tk1.on_mark_done

      # * check final *
      assert_equal(tk2.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk2.start_time)
      assert_equal(tk3.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk3.start_time)

    end

    test "LINK La fin d'une tâche liée règle le :start des tâches parallèles suivantes (intégration)" do
      # -intégration-

      # * préparation *
      tk1_id = get_new_id_tache
      tk2_id = get_new_id_tache
      tk3_id = get_new_id_tache
      tache(
        id: tk1_id,
        todo: "La première tâche #{tk1_id}",
        suiv: tk2_id
      ).save
      tk2 = tache(id:tk2_id, todo:"Deuxième tâche", duree:'5d', parallels:[tk2_id,tk3_id])
      tk3 = tache(id:tk3_id, todo:"Troisième tâche parallèle à tk2", duree:'10d', parallels:[tk2_id,tk3_id])
      [tk2,tk3].each{|t|t.save}
      MyTaches::Tache.init
      tk1 = get_tache(tk1_id)
      tk2 = get_tache(tk2_id)
      tk3 = get_tache(tk3_id)

      # * check préliminaire *
      assert_equal(tk1_id, tk2.prev_id)
      assert_nil(tk2.start)
      assert_nil(tk3.start)
      assert_nil(tk2.start_time)
      assert_nil(tk3.start_time)
      assert_true(tk2.parallel?)
      assert_true(tk3.parallel?)

      # * opération *
      CLI.main_command = 'done'
      ARGV << tk1_id
      Q.answers = [
        "\n", # confirmation
      ]
      MyTaches.run

      # * check final *
      tk2 = get_tache(tk2_id)
      tk3 = get_tache(tk3_id)
      assert_equal(tk2.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk2.start_time)
      assert_equal(tk3.start, _NOW_.jj_mm_aaaa_hh_mm)
      assert_equal(_NOW_, tk3.start_time)

    end



    # === / fin des tests de déplacement/liaisons ===


    # = test de la PÉREMPTION =

    test "OUT Une tâche est out-of-date seulement si elle est périmée" do

      tk = tache(
        id: 'tk-out',
        start: hdate(_NOW_ - 10.jours),
        duree: '9d'
      )
      tkin = tache(
        id:     'tk-in',
        start:  hdate(_NOW_ - 10.jours),
        duree:  '2w'
      )

      assert(tk.out_of_date?)
      refute(tkin.out_of_date?)

    end

    test "OUT Une tâche périmée répond correctement à #peremption" do

      tk = tache(
        id: 'tk-out-2',
        start: _NOW_.moins(10).jours,
        duree: '9d'
      )

      assert(tk.respond_to?(:peremption))
      assert(tk.respond_to?(:f_peremption))
      assert(tk.respond_to?(:calc_peremption))
      assert_equal({jours:1, semaines:0, heures:0}, tk.calc_peremption)
      assert_equal('1d', tk.peremption)
      assert_equal('1 jour', tk.f_peremption)
    end

    # === Valeurs d'une tâche courante ===

    test "IN On peut obtenir la durée restante avec :reste" do
      tk = tache(
        id: 'tk-in-2',
        start: hdate(_NOW_ - 1.semaine),
        duree: '8d'
      )

      assert(tk.respond_to?(:reste))
      assert(tk.respond_to?(:f_reste))
      assert(tk.respond_to?(:calc_reste))
      assert(tk.respond_to?(:reste_secondes))

      assert_equal(1.jour, tk.reste_secondes)
      assert_equal('1d', tk.reste)
      assert_equal('1 jour', tk.f_reste)
      assert_equal({semaines:0, jours:1, heures:0}, tk.calc_reste)
    end



    # === DESTRUCTION ===

    test "REM La destruction d'une tâche insérée doit recoller les deux tâches liées" do
      # * préparation *
      reset_taches
      taches = create_x_taches_linked(3, index: true)
      tk0, tk1, tk2 = taches

      # = Opération =
      tk1.destroy

      # * check final *
      assert_equal('t2', tk0.data[:suiv])
      assert_equal('t0', tk2.prev_id)
    end




    # ====== MODÈLE DE SUITE DE TÂCHES ======== #



    test "MODEL On peut créer un modèle" do

      # * Préparation *
      
      reset_taches
      ids_list = ['MTK001-0001','MTK001-0002','MTK001-0003','MTK001-0004']
      
      mdl = create_modele(
        id:         'MTK001',
        name:       'Premier modèle de tâches',
        categorie:  'Première catégorie',
        taches_ids: ids_list
      )

      # * vérification *
      # 
      # Note : ici, c'est autant pour vérifier la création du modèle
      # de suite de tâche que pour vérifier que la méthode de test
      # 'create_modele' fonctionne bien.
      # 
      assert_equal(MyTaches::Model, mdl.class)
      assert_true(mdl.respond_to?(:taches))
      assert_true(File.exist?(mdl.path))
      data_mdl = YAML.load_file(mdl.path)
      assert_equal('MTK001', data_mdl[:id])
      assert_equal('Premier modèle de tâches', data_mdl[:name])
      assert_equal('Première catégorie', data_mdl[:categorie])
      assert_equal(ids_list, data_mdl[:taches_ids])
      # Les tâches doivent avoir été créée
      ids_list.each do |tache_id|
        p = File.join(MyTaches::Model.taches_folder,"#{tache_id}.yaml")
        assert_true(File.exist?(p))
        data_tk = YAML.load_file(p)
        assert_equal(tache_id, data_tk[:id])
        assert_equal('MTK001', data_tk[:model_id])
      end
    end


    test "MODEL On peut insérer un modèle de tâche" do
      
      # * Préparation *
      reset_taches
      mdl = create_modele(
        id: 'MTK002',
        name: 'Deuxième modèle de tâches',
        categorie: 'Deuxième catégorie',
        taches_ids:  ['MTK002-0001','MTK002-0002','MTK002-0003','MTK002-0004'],
        data_taches: {
          'MTK002-0001' => {
              todo:"La tâche de %{somebody}",
              duree:'2d'
            },
          'MTK002-0002' => {
              todo:"La tâche de %{someone_else}",
              duree:'3d'
            },
          'MTK002-0003' => {
              todo:"%{someone_else} parle à %{somebody}",
              duree:'4d'
            },
        },
        dynamic_values: {
          somebody:       {what:'Qui est ce quelqu’un ?'},
          someone_else:   {what:'Qui est ce quelqu’un d’autre ?'}
        }
      )

      # On insert le modèle
      date_start_str = "#{_NOW_.plus(5).jours.jj_mm_aaaa} 11:23"
      suffix = _NOW_.strftime('%Y%m%d%H%M')
      MyTaches::Tache.insert_from_model(
        # Les données directes pour court-circuiter les demandes
        # interactives.
        mdl,
        suffix,
        date_start_str,
        {somebody: 'Tom Cruise', someone_else: "Anne Hathaway"},
        false   # pas de confirmation
      )

      # * Check final *

      # Toutes les tâches doivent avoir été créées
      tk1m_path = File.join(MyTaches::Model.taches_folder,"MTK002-0001.yaml")
      tk1_path  = File.join(MyTaches::Tache.taches_folder,"MTK002-0001-#{suffix}.yaml")
      assert_true(File.exist?(tk1m_path))
      assert_true(File.exist?(tk1_path))
      tk2m_path = File.join(MyTaches::Model.taches_folder,"MTK002-0002.yaml")
      tk2_path = File.join(MyTaches::Tache.taches_folder,"MTK002-0002-#{suffix}.yaml")
      assert_true(File.exist?(tk2_path))
      tk3m_path = File.join(MyTaches::Model.taches_folder,"MTK002-0003.yaml")
      tk3_path = File.join(MyTaches::Tache.taches_folder,"MTK002-0003-#{suffix}.yaml")
      assert_true(File.exist?(tk3_path))
      tk4m_path = File.join(MyTaches::Model.taches_folder,"MTK002-0004.yaml")
      tk4_path = File.join(MyTaches::Tache.taches_folder,"MTK002-0004-#{suffix}.yaml")
      assert_true(File.exist?(tk4_path))

      # Toutes les tâches doivent posséder les bonnes valeurs
      # temporelles et dynamique
      tk1_data = YAML.load_file(tk1_path)
      assert_equal(date_start_str, tk1_data[:start])
      assert_equal("MTK002-0002-#{suffix}", tk1_data[:suiv])

      # On va vérifier que les nouvelles tâches sont bien 
      # datées
      tk1 = MyTaches::Tache.get("MTK002-0001-#{suffix}")
      tk2 = MyTaches::Tache.get("MTK002-0002-#{suffix}")
      tk3 = MyTaches::Tache.get("MTK002-0003-#{suffix}")
      tk4 = MyTaches::Tache.get("MTK002-0004-#{suffix}")
      assert_equal(MyTaches::Tache, tk1.class)
      assert_equal(date_start_str, tk1.start)
      assert_equal(_NOW_.plus(5).jours.at('11:23'), tk1.start_time)
      assert_equal(_NOW_.plus(5 + 2).jours.at('11:23'), tk1.end_time)
      assert_equal(_NOW_.plus(5 + 2).jours.at('11:23'), tk2.start_time)
      assert_equal(_NOW_.plus(5 + 2 + 3).jours.at('11:23'), tk2.end_time)
      assert_equal(_NOW_.plus(5 + 2 + 3).jours.at('11:23'), tk3.start_time)
      assert_equal(_NOW_.plus(5 + 2 + 3 + 4).jours.at('11:23'), tk3.end_time)
      assert_equal(_NOW_.plus(5 + 2 + 3 + 4).jours.at('11:23'), tk4.start_time)
      assert_equal(_NOW_.plus(5 + 2 + 3 + 4 + 1).jours.at('11:23'), tk4.end_time)

    end

    test "MODEL Un nom de modèle doit être unique" do
      # Noter qu'il s'agit bien du NOM (:name), pas de l'identifiant
      # qui lui sera toujours unique
      nom_model = "Le nom du modèle qui sera dupliqué"
      id_model1 = "MTK#{100 + rand(100000)}"
      data_premier_model = {
        id:   id_model1,
        name: nom_model,
        categorie: "Duplication de nom",
        taches_ids: ["#{id_model1}-001", "#{id_model1}-002"]
      }
      id_model2 = "#{id_model1}1"
      data_second_model = {
        id:   id_model2,
        name: nom_model,
        categorie: "Duplication de nom",
        taches_ids: ["#{id_model2}-001", "#{id_model2}-002"]
      }

      mdl1 = create_modele(data_premier_model)
      assert_equal(nom_model, mdl1.name)

      # = Opération et test =

      assert_raise(RuntimeError) { create_modele(data_second_model) }
    
    end

    test "MODEL On ne peut pas modifier le nom d'un modèle en lui donnant un nom existant" do

      nom_model = "Le nom du modèle qui sera doublé après"
      id_model1 = "MTK#{100 + rand(100000)}"
      data_premier_model = {
        id:   id_model1,
        name: nom_model,
        categorie: "Duplication de nom",
        taches_ids: ["#{id_model1}-001", "#{id_model1}-002"]
      }
      id_model2 = "#{id_model1}1"
      data_second_model = {
        id:   id_model2,
        name: "Un bon nom de modèle #{id_model2}",
        categorie: "Duplication de nom",
        taches_ids: ["#{id_model2}-001", "#{id_model2}-002"]
      }

      mdl1 = create_modele(data_premier_model)
      assert_equal(nom_model, mdl1.name)
      mdl2 = create_modele(data_second_model) 

      # = opération et check =
      assert_raise(RuntimeError) { 
        mdl2.data[:name] = nom_model
        mdl2.save
      }
    end


    # --- Tests d'intégration sur les MODÈLES ---


    test "MODEL On peut créer des tâches" do
      # -intégration-

      # * préparation *
      reset_taches

      # * opération *
      todo_tache_a = "Première de tâche à #{_NOW_.sec}"
      CLI.main_command = 'create'
      Q.answers = [
        {_name_:/nouveau modèle/},
        "Modèle de #{_NOW_.hour}:#{_NOW_.min} avec des tâches parallèles",
        {_name_:/\- Aucune \-/},    # aucune catégorie
        # = Création de la première tâche =
        {_name_:/nouvelle tâche/},   # Pour créer une nouvelle tâche
        {_name_:/À faire/},
        todo_tache_a,
        {_name_:/Durée/},
        {_name_:/jour/},
        '4',
        {_name_:/Finir/},     # Enregistrement de la première tâche
        # = Création de la deuxième tâche =
        {_name_:/nouvelle tâche/},
        {_name_:/À faire/},
        "Deuxième tâche à #{_NOW_.sec}",
        {_name_:/Durée/},
        {_name_:/jour/},
        '7',
        {_name_:/Finir/},     # Enregistrement de la seconde tâche
        {_name_:/Enregistrer le modèle/}
      ]
      retour = MyTaches.run

      # * check final *
      assert_equal(1, MyTaches::Model.count)
      mdl = MyTaches::Model.all.first
      assert_instance_of(MyTaches::Model, mdl)
      assert_equal(2, mdl.taches.count)

    end

    test "MODEL On peut paralléliser deux tâches dans un modèle en leur mettant un start identique" do
      # - semi-intégration -
      # Normalement, de base, une tâche doit déjà être enregistrée
      # avant de pouvoir être parallélisée. Ici, il s'agit de créer
      # une tâche dans le modèle, d'en créer une seconde tout de 
      # suite en choisissant la première comme tâche parallèle.
      # Il faut faire le test sans identifiant.
      reset_taches

      # * check préliminaire *
      assert_equal(0, MyTaches::Model.count)
      assert_equal(0, MyTaches::Tache.count)

      
      # * préparation *
      now_str = Time.now.jj_mm_aaaa_hh_mm_ss
      model_name          = "Mon modèle le #{now_str}"
      categorie_name      = "Création de modèle"
      todo_premiere_tache = "Ma première tâche du #{now_str}"
      todo_deuxieme_tache = "Ma seconde tâche du #{now_str}"
      CLI.main_command = 'create'
      set_argv('model')
      Q.answers = [
        model_name,                         # Nom du modèle
        {_name_:/Nouvelle catégorie/},      # Nouveau modèle
        categorie_name,                     # Nom du modèle
        {_name_:/nouvelle tâche/},          # Pour créer une tâche
        {_name_:/À faire/},                 # => définir le todo
        todo_premiere_tache,
        {_name_:/Finir/},                   # Enregistrer la tâche
        {_name_:/nouvelle tâche/},          # Créer la deuxième tâche
        {_name_:/À faire/},                 # Définir le todo de la 2e tâche
        todo_deuxieme_tache,
        {_name_:/Finir/},                   # Enregistrer la tâche
        # --- ICI ---
        {_name_:/Paralléliser/},
        '1',                                # choisir la première tâche
        '2',                                # choisir la deuxième tâche
        # --- /ICI ---
        {_name_:/Enregistrer le modèle/},   # Enregistrer le modèle
      ]
      
      # * opération *
      result = nil
      assert_nothing_raised do
        result = MyTaches.run
      end
      
      # * check final *
      assert_equal(1, MyTaches::Model.count)
      mdl = MyTaches::Model.all.first
      model_path = File.join(MyTaches::Model.models_folder,"#{mdl.id}.yaml")
      assert(File.exist?(model_path))
      mod = MyTaches::Model.new(YAML.load_file(model_path))
      tka, tkb = mod.taches
      assert(tka.parallel?)
      assert(tkb.parallel?)
      assert(tka.parallel_to?(tkb))
      assert(tkb.parallel_to?(tka))

    end


    test "MODEL On peut renoncer à l'insertion d'un modèle" do

      # * préparation *
      reset_taches
      alea = 100 + rand(100000)
      current_name = "Le nom initial du modèle #{alea}"
      mdl = create_modele(name: current_name)

      # * opération *
      CLI.main_command = 'add'
      Q.answers = [
        {_name_:/Créer des tâches d’après un modèle/},
        {_name_:/Renoncer/}
      ]

      has_raised = false
      begin
        MyTaches.run
      rescue Exception => e
        puts e.message.rouge
        has_raised = true
      end

      # * check final *
      assert_false(has_raised)
    end

    test "MODEL On peut insérer un modèle (integration)" do
      
      # -intégration-

      reset_taches

      # * check préliminaire *
      assert_equal(0, all_taches.count)

      # * préparation *
      alea = 100 + rand(100000)
      mdl_id = "MTK#{alea}"
      current_name = "Un modèle à insérer #{alea}"
      mdl = create_modele(
        id:         mdl_id,
        name:       current_name,
        categorie:  'Deuxième catégorie',
        taches_ids:  ["#{mdl_id}-0001","#{mdl_id}-0002","#{mdl_id}-0003","#{mdl_id}-0004"],
        data_taches: {
          "#{mdl_id}-0001" => {
              todo:"Une tâche de %{somebody}",
              duree:'2d'
            },
          "#{mdl_id}-0002" => {
              todo:"Une tâche de %{someone_else}",
              duree:'3d'
            },
          "#{mdl_id}-0003" => {
              todo:"%{someone_else} parle à %{somebody}",
              duree:'4d'
            },
          "#{mdl_id}-0004" => {
              todo:"%{someone_else} parle à personne",
              duree:'5w'
            },
        },
        dynamic_values: {
          somebody:       {what: 'Qui est ce quelqu’un ?'},
          someone_else:   {what: 'Qui est ce quelqu’un d’autre ?'}
        }
      )

      # * opération *
      CLI.main_command = 'add'
      start = _NOW_.plus(1).semaine.at('19:55')
      Q.answers = [
        {_name_:/Créer des tâches d’après un modèle/},
        {_item_: 1}, # choisir le modèle (un seul)
        'Mickey',           # pour somebody
        'Rourke',           # pour someone_else
        hdate(start), # la date de départ
        # = Affichage de l'exemple avec les temps =
        "\n"                # Confirmation 
      ]
      MyTaches.run

      # * check final *
      assert_equal(4, all_taches.count)
      four_taches = Array.new(4)
      all_taches.each do |tache|
        if tache.id.start_with?("#{mdl_id}-000")
          ind = tache.id.split('-')[1][3].to_i - 1
          four_taches[ind] = tache
        end
      end
      # puts "four_taches: #{four_taches.inspect}"
      assert_equal(4, four_taches.count)
      tk1, tk2, tk3, tk4 = four_taches
      assert_equal("Une tâche de Mickey"      ,tk1.todo)
      assert_equal("Une tâche de Rourke"      ,tk2.todo)
      assert_equal(start.plus(2).jours        ,tk2.start_time)
      assert_equal("Rourke parle à Mickey"    ,tk3.todo)
      assert_equal(start.plus(2 + 3).jours    ,tk3.start_time)
      assert_equal("Rourke parle à personne"  ,tk4.todo)
      assert_equal(start.plus(2+3+4).jours    ,tk4.start_time)
      fin = start.plus(9).jours.plus(5).semaines
      assert_equal(fin, tk4.end_time)

    end

    test "MODEL On peut modifier le nom d'un modèle de tâches" do
      reset_taches

      alea = 100 + rand(100000)
      current_name = "Le nom initial du modèle #{alea}"
      nouveau_name = "Le nouveau nom du modèle #{alea}"
      mdl1 = create_modele
      mdl2 = create_modele(name: current_name)

      # * check préliminaire *
      assert_equal(current_name, mdl2.name)

      # = Opération =

      CLI.main_command = "mod"
      Q.answers = [
        {_name_: "Un modèle"},  # modifier un modèle
        {_name_: mdl2.name },   # modifier le second modèle
        nouveau_name,           # le nouveau nom à lui donner
        'Y',                    # pour garder la même catégorie
        {_name_: 'Enregistrer le modèle'} # enregistrement
      ]
      MyTaches.run

      # * check *
      # MyTaches::Model.reset
      mdl = MyTaches::Model.get(mdl2.id)
      assert_equal(nouveau_name, mdl.name)

    end

    test "MODEL On peut ajouter une tâche à un modèle" do
      reset_taches

      mdl = create_modele

      # * check préliminaire *
      assert_equal(3, mdl.taches.count)

      # = Opération =
      CLI.main_command = 'modify'
      Q.answers = [
        {_name_: 'Un modèle'},  # modifier un modèle
        {_name_: mdl.name},     # le modèle créé
        "\n",                   # garder le nom
        'Y',                    # garder la catégorie
        {_name_: 'Créer une nouvelle tâche'},
        {_name_: 'À faire'},
        "La nouvelle tâche de #{mdl.id}",
        {_regname_: /Finir/},
        {_name_: 'Enregistrer le modèle'}, # enregistrement
      ]
      MyTaches.run

      # * check final *
      MyTaches::Model.reset
      mdl = MyTaches::Model.get(mdl.id)
      new_data = YAML.load_file(mdl.path)
      assert_equal(4, new_data[:taches_ids].count)
      assert_equal(4, mdl.taches.count)

    end

    test "MODEL On peut déplacer les tâches du modèle" do
      reset_taches
      mdl = create_modele

      # * check préliminaire *
      assert_equal(3, mdl.taches.count)
      assert_equal("#{mdl.id}-001", mdl.taches[0].id)
      assert_equal("#{mdl.id}-002", mdl.taches[1].id)
      assert_equal("#{mdl.id}-003", mdl.taches[2].id)

      # = Opération =
      # = On déplace deux tâches
      CLI.main_command = 'modify'
      Q.answers = [
        {_name_: 'Un modèle'},  # modifier un modèle
        {_name_: mdl.name},     # le modèle créé
        "\n",                   # garder le nom
        'Y',                    # garder la catégorie
        {_regname_: /Déplacer/},
        '2',                    # indice de la tâche à déplacer
        '0',                    # nouvelle position (pour première)
        {_regname_: /Déplacer/},
        '2',                    # indice de la tâche à déplacer
        '2',                    # positionner à la fin
        {_regname_: /Enregistrer/}, # enregistrement
      ]
      MyTaches.run


      # * check final *
      MyTaches::Model.reset
      mdl = MyTaches::Model.get(mdl.id)
      assert_equal(3, mdl.taches.count)
      assert_equal("#{mdl.id}-002", mdl.taches[0].id)
      assert_equal("#{mdl.id}-003", mdl.taches[1].id)
      assert_equal("#{mdl.id}-001", mdl.taches[2].id)


    end

    test "MODEL On peut supprimer des tâches dans le modèle" do
      reset_taches
      mdl = create_modele

      # * check préliminaire *
      assert_equal(3, mdl.taches.count)
      assert_equal("#{mdl.id}-001", mdl.taches[0].id)
      assert_equal("#{mdl.id}-002", mdl.taches[1].id)
      assert_equal("#{mdl.id}-003", mdl.taches[2].id)

      # = Opération =
      # = On déplace deux tâches
      CLI.main_command = 'modify'
      Q.answers = [
        {_name_: 'Un modèle'},      # modifier un modèle
        {_name_: mdl.name},         # le modèle créé
        "\n",                       # garder le nom
        'Y',                        # garder la catégorie
        {_regname_: /Supprimer/},
        '2',                        # indice de la tâche à supprimer
        {_regname_: /Enregistrer/}, # enregistrement
      ]
      MyTaches.run


      # * check final *
      MyTaches::Model.reset
      mdl = MyTaches::Model.get(mdl.id)
      assert_equal(2, mdl.taches.count)
      assert_equal("#{mdl.id}-001", mdl.taches[0].id)
      assert_equal("#{mdl.id}-003", mdl.taches[1].id)


    end

    test "MODEL On peut définir une date dynamique" do
      # - intégration -

      # * préparatif *
      # On construit un modèle avec un tâche à durée 
      # dynamique
      reset_taches
      alea = (100 + rand(1000000)).to_s
      nom_modele = "Mon modèle de suite #{alea}"
      CLI.main_command = 'add'
      Q.answers = [
        {_name_:/nouveau modèle/}, # créer un nouveau modèle
        nom_modele,                       # Nom du modèle
        {_name_:/Nouvelle catégorie/},
        "Modèles avec durées variables",  # Catégorie
        # Ici la "table" du modèle, avec sa liste de tâches (aucune
        # pour le moment) et les menus d'opération est affiché
        {_name_:/nouvelle tâche/},
        {_name_:/À faire/},         # Pour définir le :todo
        "La première tâche avec une durée variable",
        {_name_:/Durée/},           # Pour définir la durée
        {_name_:/variable/},        # <--- seulement pour les modèles
        {_name_:/Finir/},
        {_name_:/Enregistrer le modèle/}
      ]
      # * Opération *
      MyTaches.run
      # * Check *
      assert_equal(1, MyTaches::Model.count)
      assert_equal(0, MyTaches::Tache.count)
      assert_equal(1, MyTaches::Model::Tache.count)

    end

    test "MODEL Insertion d'un modèle avec tâche à durée variable" do
      # -intégration-

      # * préparation *
      mdl_id = get_uniq_model_id
      mdl_name = "Modèle de suite de tâche #{mdl_id}"
      mdl = create_modele(
        id:         mdl_id,
        name:       mdl_name,
        taches_ids: ["#{mdl_id}-001", "#{mdl_id}-002", "#{mdl_id}-003"],
        data_taches: {
          "#{mdl_id}-001" => {
            todo: "Première tâche du modèle #{mdl_id}",
            duree: '4d'
          },
          "#{mdl_id}-002" => {
            todo: "Deuxième tâche du modèle #{mdl_id}",
            duree: '%'
          },
          "#{mdl_id}-003" => {
            todo: "Troisième tâche du modèle #{mdl_id}",
            duree: '%'
          }
        }
      )

      CLI.main_command = 'add'
      Q.answers = [
        {_name_:/Créer des tâches/},
        {_name_: mdl_name},  # selectionner le modèle
        # Pas de variables dynamiques
        'dem',      # Date de démarrage (demain)
        # C'est ici qu'on demande les durées propres
        'd', '3',
        'w', '2',
        "\n" # Confirmation

      ]
      MyTaches.run

      # * check final *




    end

    # ======= FIN TEST MODELS ==========



    # ======= FONCTIONS PARTICULIÈRES DE DATE =====


    test "DATE On peut utiliser des diminutifs pour obtenir la date" do
      njour = _NOW_.day
      nmois = _NOW_.month
      nan   = _NOW_.year
      demain = _NOW_.plus(1).jour
      hier   = _NOW_.moins(1).jour
      [
        ['auj', "#{_NOW_.jj_mm_aaaa}"],
        ['dem', "#{demain.jj_mm_aaaa}"],
        ['demain', "#{demain.jj_mm_aaaa}"],
        ['tom', "#{demain.jj_mm_aaaa}"],
        ['tomorrow', "#{demain.jj_mm_aaaa}"],
        ['hier', hier.jj_mm_aaaa],
        ['yesterday', hier.jj_mm_aaaa],
        ['lundi', lundi.jj_mm_aaaa],
        ['lun', lundi.jj_mm_aaaa],
        ['monday', lundi.jj_mm_aaaa],
        ['mon', lundi.jj_mm_aaaa],
        ['mardi', mardi.jj_mm_aaaa],
        ['mar', mardi.jj_mm_aaaa],
        ['tues', mardi.jj_mm_aaaa],
        ['tuesday', mardi.jj_mm_aaaa],
        ['mer', mercredi.jj_mm_aaaa],
        ['mercredi', mercredi.jj_mm_aaaa],
        ['wed', mercredi.jj_mm_aaaa],
        ['wednesday', mercredi.jj_mm_aaaa],
        ['jeu', jeudi.jj_mm_aaaa],
        ['jeudi', jeudi.jj_mm_aaaa],
        ['thur', jeudi.jj_mm_aaaa],
        ['thursday', jeudi.jj_mm_aaaa],
        ['ven', vendredi.jj_mm_aaaa],
        ['vendredi', vendredi.jj_mm_aaaa],
        ['fri', vendredi.jj_mm_aaaa],
        ['friday', vendredi.jj_mm_aaaa],
        ['sam', samedi.jj_mm_aaaa],
        ['samedi', samedi.jj_mm_aaaa],
        ['sat', samedi.jj_mm_aaaa],
        ['saturday', samedi.jj_mm_aaaa],
        ['dim', dimanche.jj_mm_aaaa],
        ['dimanche', dimanche.jj_mm_aaaa],
        ['sun', dimanche.jj_mm_aaaa],
        ['sunday', dimanche.jj_mm_aaaa],

      ].each do |str_date, expected_time|
        res = MyTaches::Tache.replace_dim_in_date(str_date)
        assert_equal(expected_time, res)
        heures  = rand(24)
        minutes = rand(60)
        str_date = "#{str_date} #{heures}:#{minutes}"
        res = MyTaches::Tache.replace_dim_in_date(str_date)
        assert_equal("#{expected_time} #{heures}:#{minutes}", res)
      end
    end

    # ======= /FIN TESTS DATE =====


    # ======= RAPPELS =========


    test "RAPPEL On peut instancier un nouveau rappel avec les bonnes données" do
      i = MyTaches::Rappel.new('1h::30')
      assert_equal(MyTaches::Rappel, i.class)
    end


    test "RAPPEL On ne peut pas instancier un rappel avec de mauvaises données" do
      # Unité non valide
      assert_raise(RuntimeError) { rappel('1a::30') }
      # Pas de quantité d'unité
      assert_raise(RuntimeError) { rappel('h::30') }
      # Pas de temps défini ou d'indice jour
      assert_raise(RuntimeError) { rappel('3h') }
      assert_raise(RuntimeError) { rappel('3h::') }
      # Mauvaise heure définie en fonction de l'unit
      assert_raise(RuntimeError) { rappel('3h::61') } 
      assert_raise(RuntimeError) { rappel('3d::24:10') } 
      assert_raise(RuntimeError) { rappel('3d::12:62') } 
      assert_raise(RuntimeError) { rappel('3s::32 10:30') } 
      assert_raise(RuntimeError) { rappel('3s::0 10:30') } 
      assert_raise(RuntimeError) { rappel('3s::30 10:30') } 
      assert_raise(RuntimeError) { rappel('3s::30 25:30') } 
      # Jour mal défini
      assert_raise(RuntimeError) { rappel('3d::30 21:30') } 
      assert_raise(RuntimeError) { rappel('3d::25:30') } 
      assert_raise(RuntimeError) { rappel('3d::12:72') }
      # Mois mal défini pour une fréquence année
      assert_raise(RuntimeError) { rappel('1y::1/13 20:00') }
      assert_raise(RuntimeError) { rappel('1y::12/0 20:00') }
      assert_raise(RuntimeError) { rappel('1y::12/03 25:00') }
      assert_raise(RuntimeError) { rappel('1w::0 10:00') }
    end


    test "RAPPEL Rappel#next_time retourne la bonne valeur pour toutes les unités" do
      # Quand c'est la première notification (pas de last rappel)
      redefine_now Time.now
      wday = _NOW_.wday
      wday = 7 if wday == 0
      heure_passee = "#{_NOW_.hour - 1}:#{_NOW_.min}"
      lestests = [
        ['1d::10:00'                        ,now_at('10:00')],
        ['2d::10:01'                        ,now_at('10:01')],
        ['3d::11:00'                        ,now_at('11:00')],
        ["1w::#{wday} #{heure_passee}"      ,_NOW_.at(heure_passee)]
      ]
      if _NOW_.day < 29
        lestests += [
          ["1s::#{_NOW_.day} 9:31"              ,now_at('9:31')],
          ["1y::#{_NOW_.day}/#{_NOW_.month} #{heure_passee}" ,now_at(heure_passee)]
        ]
      end
      lestests.each do |str,time|
        # puts "str: #{str.inspect} / time: #{time.inspect}".jaune
        rap = rappel(str)
        assert_equal(time, rap.next_time(nil))
      end
    end

    test "RAPPEL Rappel#next_time sans rappel précédent avec des quantités multiples retourne la bonne valeur" do
      heure_apres  = "#{_NOW_.hour + 1}:#{_NOW_.min}"
      wday = _NOW_.wday
      wday = 7 if wday == 0
      lesrappels = [
        ['2d::23:00', now_at('23:00')],
        ['3d::23:00', now_at('23:00')],
        ["2w::#{wday} #{heure_apres}", now_at(heure_apres)]
      ]
      i = 0
      lesrappels.each do |rappel_str, expected_time|
        # ecrit "rappel_str: #{rappel_str} / expected_time: #{expected_time}".jaune
        irappel = MyTaches::Rappel.new(rappel_str)
        assert_equal(expected_time, irappel.next_time(nil))
      end
    end

    test "RAPPEL Rappel#next_time avec un rappel précédent  et unité unique retourne la bonne valeur" do
      lesrappels = [
        # ['rappel tâche', dernier rappel, next_time_rappel attendu]
        [
          '1d::23:00', 
          _NOW_.at('23:00'),              # dernier rappel
          _NOW_.plus(1).jour.at('23:00')  # next time attendu
        ],
        [
          '1w::1 23:01',
          _NOW_.moins(3).jour.at('23:04'), 
          _NOW_.plus(4).jour.at('23:01')
        ]
      ]
      if _NOW_.moins(1).jour.day < 29
        lesrappels << [
          "1s::#{_NOW_.moins(1).jour.day} 23:02", 
          now_at('23:41').moins(1).jours, 
          _NOW_.moins(1).jours.plus(1).mois.at('23:02')
        ]

        lesrappels << [
          "1y::#{_NOW_.moins(1).jour.day}/#{_NOW_.month} 23:03",
          _NOW_.moins(1).jour.at('23:09'),
          _NOW_.moins(1).jour.plus(1).an.at('23:03')
        ]
      end
      lesrappels.each do |rappel_str,last_rappel, expected_time|
        # puts "str: #{rappel_str.inspect} / last: #{last_rappel} / next: #{expected_time}"
        irappel = MyTaches::Rappel.new(rappel_str)
        assert_equal(expected_time, irappel.next_time(last_rappel))
      end

    end


    test "RAPPEL Rappel#next_time avec rappel précédent et unité multiple retourne la bonne valeur" do
      redefine_now(Time.now)
      now10min  = _NOW_.moins(10).minutes.min
      rappel50h = _NOW_.at("#{_NOW_.hour}:#{now10min}")
      exptim50h = rappel50h.plus(50).heures.adjust(min:now10min)

      moins5jour = _NOW_.moins(5).jours
      moins4jour = _NOW_.moins(4).jours

      lesrappels = [
        [
          '2h::10',
          _NOW_.at('10:10'),
          _NOW_.at('12:10')
        ],
        [
          "50h::#{_NOW_.moins(10).minutes.min}",
          rappel50h,
          exptim50h
        ],
        [
          '2d::11:10',
          _NOW_.at('11:13'),
          _NOW_.plus(2).jours.at('11:10')
        ],
        [
          '60d::11:11',
          _NOW_.at('11:29'),
          _NOW_.plus(60).jours.at('11:11')
        ],
        [
          "3y::#{moins5jour.day}/#{moins5jour.month} 11:16",
          _NOW_.at('11:29'),
          _NOW_.plus(3).ans.adjust(day:moins5jour.day,month:moins5jour.month).at('11:16')
        ],
        [
          "20y::#{moins4jour.day}/#{moins4jour.month} 11:17",
          _NOW_.at('11:29'),
          _NOW_.plus(20).ans.adjust(month:moins4jour,day:moins4jour).at('11:17')
        ]
      ]

      wday = _NOW_.moins(2).jours.wday
      wday = 7 if wday == 0
      lesrappels << [
        "3w::#{wday} 11:12",
        _NOW_.at('11:29'),
        _NOW_.plus(3).semaines.at('11:12')
      ]

      wday = _NOW_.moins(3).jours.wday
      wday = 7 if wday == 0
      lesrappels << [
        "23w::#{wday} 11:13",
        _NOW_.at('11:29'),
        _NOW_.plus(23).semaines.at('11:13')
      ]

      if (leday = _NOW_.moins(3).jours.plus(24).mois.day) < 29
        lesrappels << [
          "24s::#{leday} 11:15",
          _NOW_.at('11:29'),
          _NOW_.moins(3).jours.plus(24).mois.at('11:15')
        ]
      end
      if (leday = _NOW_.moins(2).jours.plus(2).mois.day) < 29
        lesrappels << [
          "2s::#{leday} 11:14",
          _NOW_.at('11:29'),
          _NOW_.moins(2).jours.plus(2).mois.at('11:14')
        ]
      end

      lesrappels.each do |rappel_str, last_rappel, expected_time|
        # ecrit "Rappel: #{rappel_str.inspect} / last: #{last_rappel} / next: #{expected_time}".bleu
        irappel = MyTaches::Rappel.new(rappel_str)
        assert_equal(expected_time, irappel.next_time(last_rappel))
      end
    end


    # --- rappel.is_time? true ---

    test "RAPPEL Rappel#is_time? retourne true quand c'est un premier rappel et le bon moment" do
      rap = rappel("2d::#{_NOW_.hour}:#{_NOW_.min}")
      assert_true(rap.is_time?(nil))
    end

    test "RAPPEL Rappel#is_time? retourne true quand c'est un autre rappel et le bon moment" do
      rap = rappel("2d::#{_NOW_.hour}:#{_NOW_.min}")
      last = _NOW_ - 2.jours
      assert_true(rap.is_time?(last))
    end

    test "RAPPEL is_time? avec un jour de la semaine retourne la valeur correcte" do
      wday = _NOW_.wday
      wday = 7 if wday == 0
      rap = rappel("1w::#{wday} #{_NOW_.hour}:#{_NOW_.min}")
      assert_true(rap.is_time?(nil))
    end

    test "RAPPEL is_time? est juste avec un rappel de plusieurs semaines et last_rappel" do
      ilya1jour = _NOW_.moins(1).jour
      irappel = MyTaches::Rappel.new("4w::#{ilya1jour.wday + 1} 11:32")
      last_rappel = ilya1jour.moins(4).semaines.at('11:34')
      assert_true(irappel.is_time?(last_rappel))

      last_rappel = ilya1jour.moins(3).semaines.at('11:34')
      assert_false(irappel.is_time?(last_rappel))
    end

    # --- rappel.is_time? false ---

    test "RAPPEL Rappel#is_time? retourne false quand c'est un premier rappel et le mauvais moment" do
      rap = rappel("3d::#{_NOW_.hour + 1}:12")
      assert_false(rap.is_time?(nil))
    end

    test "RAPPEL Rappel#as_human retourne la bonne valeur" do
      [
        ['1h::24'         ,'Toutes les heures à 0:24'],
        ['4h::24'         ,'Toutes les 4 heures à 0:24'],
        ['1d::10:00'      ,'Tous les jours à 10:00'],
        ['3d::10:00'      ,'Tous les 3 jours à 10:00'],
        ['1w::1 7:11'     ,'Toutes les semaines le lundi à 7:11'],
        ['5w::3 7:11'     ,'Toutes les 5 semaines le mercredi à 7:11'],
        ['1s::12 12:12'   ,'Tous les mois le 12 à 12:12'],
        ['3s::24 11:10'   ,'Tous les 3 mois le 24 à 11:10'],
        ['1y::01/01 8:00' ,'Tous les ans le 1er janvier à 8:00'],
        ['3y::1/02 8:12'  ,'Tous les 3 ans le 1er février à 8:12']
      ].each do |str, hum|
        rap = rappel(str)
        assert_equal(hum, rap.as_human)
      end
    end
  
  test "RAPPEL Le temps du rappel doit être un Time ou Nil" do
    rap = rappel('2d::12:00')
    assert_raise(RuntimeError) { rap.is_time?('14:00') }
    assert_raise(RuntimeError) { rap.is_time?('n’importe/quoi') }
  end

  # --- rappel.next_time ---


    test "RAPPEL Une tâche sans rappel n'a pas d'instance irappel" do
      tk = tache(todo:"Tâche sans rappel")
      assert_nil(tk.irappel)
      assert_false(tk.rappel?)
    end

    test "RAPPEL On peut ajouter un rappel à une tâche" do
      tk = tache(rappel: '1d::21:30')
      assert_not_nil(tk.irappel)
      assert_equal(MyTaches::Rappel, tk.irappel.class)
    end

    test "RAPPEL Une tâche avec un rappel toutes les heures doit être notifiée" do
      tun = tache(rappel:"1h::#{_NOW_.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)
    end

    test "RAPPEL Une tâche avec un rappel toutes les heures mais hors temps ne doit pas être notifiée" do
      if _NOW_.min < 58
        if _NOW_.sec > 55
          # Si le temps courant est 59 minutes, on ne peut
          # pas faire le test, car rappel? serait toujours vrai
          # puisque le temps courant serait supérieur au temps du
          # rappel (et on ne peut pas attendre une minute…)
          # On attend juste un peu si on est dans les dernières
          # secondes
          sleep 5
          tafter = _NOW_.adjust(min: 59)
          tun = tache(rappel:"1h::59")
          assert_false(tun.rappel?)
          assert_false(tun.notify?)
        end
      end
    end

    test "RAPPEL Une tâche avec un rappel quotidien doit être notifiée à l'heure requise" do
      tun = tache(rappel:"1d::#{_NOW_.hour}:#{_NOW_.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel quotidien doit être notifiée si l'heure est passée" do
      redefine_now(Time.now)
      tbefore = _NOW_.moins(6).minutes
      tun = tache(rappel:"1d::#{tbefore.hour}:#{tbefore.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel quotidien ne doit pas être notifié si hors heure" do
      tafter = _NOW_.plus(15).minutes
      tun = tache(rappel:"1d::#{tafter.hour}:#{tafter.min}")
      assert_false(tun.rappel?)
      assert_false(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel hebdomadaire doit être notifiée à l'heure requise" do
      wday = _NOW_.wday
      wday = 7 if wday == 0
      tun = tache(rappel:"1w::#{wday} #{_NOW_.hour}:#{_NOW_.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel hebdomadaire doit être notifiée à l'approche de l'heure" do
      tbefore = _NOW_.moins(6).minutes
      wday = tbefore.wday
      wday = 7 if wday == 0
      tun = tache(rappel:"1w::#{wday} #{tbefore.hour}:#{tbefore.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel hebdomadaire n'est pas notifiée en dehors de l'heure" do
      tafter = _NOW_.plus(3).minutes
      wday = tafter.wday > 0 ? tafter.wday + 1 : 7
      tun = tache(rappel:"1w::#{wday} #{tafter.hour}:#{tafter.min}")
      assert_false(tun.rappel?)
      assert_false(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel hebdomadaire n'est pas notifiée en dehors du jour" do
      unless _NOW_.wday == 0
        # On ne peut pas faire ce test si l'on est un dimanche, car
        # il serait toujours faux puisque 
        demain = _NOW_.plus(1).jour
        index_jour = demain.wday > 0 ? demain.wday + 1 : 7
        rappel_str = "1w::#{index_jour} #{_NOW_.hour}:#{_NOW_.min}"
        tun = tache(rappel:rappel_str)
        assert_false(tun.rappel?)
        assert_false(tun.notify?)      
      end
    end

    test "RAPPEL Une tâche avec un rappel mensuel doit être notifiée à l'heure" do
      # Test qui ne peut pas être fait en toute fin du mois
      if _NOW_.day < 29
        tun = tache(rappel:"1s::#{_NOW_.day} #{_NOW_.hour}:#{_NOW_.min}")
        assert_true(tun.rappel?)
        assert_true(tun.notify?)      
      end
    end

    test "RAPPEL Une tâche avec un rappel mensuel doit être notifiée au dépassement de l'heure" do
      tbefore = _NOW_.moins(6).minutes
      if tbefore.day < 29
        tun = tache(rappel:"1s::#{tbefore.day} #{tbefore.hour}:#{tbefore.min}")
        assert_true(tun.rappel?)
        assert_true(tun.notify?)      
      end
    end

    test "RAPPEL Une tâche avec un rappel mensuel n'est pas notifiée en dehors de l'heure" do
      tafter = _NOW_.plus(14).minutes
      if tafter.day < 29
        tun = tache(rappel:"1s::#{tafter.day} #{tafter.hour}:#{tafter.min}")
        assert_false(tun.rappel?)
        assert_false(tun.notify?)      
      end
    end

    test "RAPPEL Une tâche avec un rappel mensuel n'est pas notifiée en dehors du jour" do
      if _NOW_.day < 28
        # Le test ne peut pas être fait après le 28 car c'est le
        # nombre maximum pour un rappel
        tun = tache(rappel:"1s::#{_NOW_.day + 1} #{_NOW_.hour}:#{_NOW_.min}")
        assert_false(tun.rappel?)
        assert_false(tun.notify?)      
      end
    end

    test "RAPPEL Une tâche avec un rappel annuel doit être notifiée à l'heure" do
      tun = tache(rappel:"1y::#{_NOW_.day}/#{_NOW_.month} #{_NOW_.hour}:#{_NOW_.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel annuel doit être notifiée au dépassement de l'heure" do
      tbefore = _NOW_.moins(6).minutes
      tun = tache(rappel:"1y::#{tbefore.day}/#{tbefore.month} #{tbefore.hour}:#{tbefore.min}")
      assert_true(tun.rappel?)
      assert_true(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel annuel n'est pas notifiée en dehors de l'heure" do
      tafter = _NOW_.plus(6).minutes
      tun = tache(rappel:"1y::#{tafter.day}/#{tafter.month} #{tafter.hour}:#{tafter.min}")
      assert_false(tun.rappel?)
      assert_false(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel annuel n'est pas notifiée en dehors du jour" do
      tun = tache(rappel:"1y::#{DEMAIN.day}/#{DEMAIN.month} #{_NOW_.hour}:#{_NOW_.min}")
      assert_false(tun.rappel?)
      assert_false(tun.notify?)      
    end

    test "RAPPEL Une tâche avec un rappel annuel n'est pas notifiée en dehors du mois" do
      tun = tache(rappel:"1y::#{_NOW_.day}/#{_NOW_.month + 1} #{_NOW_.hour}:#{_NOW_.min}")
      assert_false(tun.rappel?)
      assert_false(tun.notify?)      
    end

    # --- Rappels avec précédent rappel ---

    test "RAPPEL Une tâche déjà notifiée n'est pas renotifiée" do
      tbefore = _NOW_.moins(3).minutes
      trappel = _NOW_.moins(2).minutes
      tun = tache(
        rappel:"1w::#{tbefore.wday + 1} #{tbefore.hour}:#{tbefore.min}",
        last_rappel: trappel.to_i
      )
      assert_false(tun.rappel?)
      assert_false(tun.notify?)
    end

    # === / FIN DES TESTS SUR LES RAPPELS ===



    # === Tests sur les codes à jouer (:run) ===


    test "RUN La commande 'task run' permet de jouer une tâche" do
      # * prépartion *
      pth = "./mon_fichier_#{_NOW_.to_i}.txt"
      msg = "J’ai exécuté le code avec succès à #{_NOW_}".strip
      tk = tache(
        todo: "Tâche dont il faut runner le code à #{_NOW_.to_i}",
        exec: "echo 'Salut le monde !' > #{pth}"
        ).save
      retour = nil
      assert_nothing_raised do
        CLI.main_command = 'run'
        Q.answers = [
          {_name_:/liste/},
          {_name_:/#{tk.todo}/}
        ]
        retour = MyTaches.run
      end
      # ecrit retour.bleu
      assert(File.exist?(pth))
      content = File.read(pth)
      File.delete(pth) if File.exist?(pth)
      assert_match(/Salut le monde/, content)
    end

    test "RUN Un code qui foire produit le bon message d'erreur" do
      # * préparation *
      tk = tache(
        exec: 'boumboumboum'
      ).save

      # * opération *
      CLI.main_command = 'run'
      set_argv(tk.id)
      retour = MyTaches.run

      # * vérification *
      assert_match(/Une erreur est survenue en exécutant le code "boumboumboum"/, retour)
    end

    test "RUN On peut exécuter du code shell" do
      tk = tache(exec:'ls -la').save
      CLI.main_command = 'run'
      set_argv(tk.id)
      retour = MyTaches.run
      assert_match(/Tache_run\.rb/, retour)
      assert_match(/xtests/, retour)
      assert_match(/TaskArray\.rb/, retour)
    end

    test "RUN On peut utiliser du code ruby avec 'ruby -e <code>'" do
      pth = './logrun.txt'
      tk = tache(
        # exec: "echo 'Bonjour everybody' > #{pth}" # OK
        exec: "ruby -e 'puts \"Bonjour everybody\"' > #{pth}"
      ).save
      CLI.main_command = 'run'
      set_argv(tk.id)
      MyTaches.run
      # * Vérification *
      assert(File.exist?(pth))
      assert_match(/Bonjour everybody/, File.read(pth))
      File.delete(pth)
    end

    test "RUN On peut utiliser du code ruby avec 'ruby << CODE <code>'" do
      pth = './logrun2.txt'
      tk = tache(
        # exec: "echo 'Bonjour everybody' > #{pth}" # OK
        exec: "ruby > #{pth} << CODER\nputs 'Bonjour every body'\nCODER"
      ).save
      CLI.main_command = 'run'
      set_argv(tk.id)
      MyTaches.run
      # * Vérification *
      assert(File.exist?(pth))
      assert_match(/Bonjour every body/, File.read(pth))
      File.delete(pth)
    end

    test "RUN Quand une tâche est notifiée, il faut jouer son code si elle en a un" do
      # Non, ça serait un test d'intégration où il faudrait
      # pouvoir cliquer sur la notification.
    end

  end #Test::Unit
end
