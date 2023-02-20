# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
class Tache

class << self

  ##
  # État des lieux
  # 
  # Méthode qui permet d'afficher les tâches de toutes sortes
  # de façon, avec différents filtre. À la base, elle est faite
  # pour afficher les tâches courantes, utiles pour le travail
  # du jour.
  # 
  def etat_des_lieux
    # ecrit("-> etat_des_lieux le #{_NOW_}".bleu)
    if test?
      @output_lines = []
    end

    show_today    = cli?(['--today','--auj'])
    show_futures  = cli?(['--futur','--future'])
    show_proches  = cli?(['--near','--proche'])
    show_current  = cli?(['--current'])
    delai_proche  = cli?(/^\-proche\=(.+)$/)
    delai_proche  = delai_proche || cli?(/^\-near\=(.+)$/)
    show_perimees = cli?(['--out_of_date', '--périmée'])
    show_lointain = cli?(['--far','--loin'])
    show_lost     = cli?(['--lost','--perdu','--perdue'])
    show_no_time  = cli?(['--out','--no_time'])
    show_all      = cli?('--all')
    show_ids      = cli?(['--id'])
    show_linkeds  = cli?(['--linked','--liée','--liee'])
    notify_them   = cli?(['--cron', '--notify'])

    if not(show_today||show_futures||show_proches||show_current||delai_proche||
      show_perimees||show_lointain||show_lost||show_no_time||show_all)
      show_current = true
    end

    # 
    # Paramètre (filtre) pour Tache::all
    # 
    params = {}

    if show_all
      
      params.merge!(all: true)

    else

      if delai_proche
        delai_proche = Tache.calc_duree_seconds(delai_proche)
        params.merge!(near: delai_proche) 
      end
      params.merge!(near:   true) if show_proches
      params.merge!(today:  true) if show_today
      params.merge!(futur:  true) if show_futures
      params.merge!(far:    true) if show_lointain
      params.merge!(no_time:true) if show_no_time
      params.merge!(lost:   true) if show_lost
      params.merge!(current:true) if show_current

      # 
      # Si aucun choix (pas d'option) c'est qu'on veut
      # voir les tâches courantes
      # 
      params.merge!(current: true) if params.empty?

      # 
      # Options supplémentaires
      # 
      params.merge!(linked: true) if show_linkeds
      params.merge!(ids:    true) if show_ids
      params.merge!(notify: true) if notify_them

    end
  

    # Faut-il ne voir que les tâches d'une catégorie ?
    by_categorie = cli?('--cate')
    cate = nil
    if by_categorie
      cate = choose_categorie
      params.merge!(categorie: cate) unless cate.nil?
    elsif cli?(/^\-\-?cate=(.+)$/)
      # Catégorie définie en ligne de commande
      params.merge!(categorie: /#{CLI.values[:cate]}/i)
    end


    # ecrit("Params all: #{params.inspect}".bleu) if test?

    # 
    # Récupération des tâches passant les tests
    # 
    founds = all(params)

    clear

    # 
    # Pour savoir si on doit afficher le message indiquant comment
    # marquer une tâche comme faite.
    # 
    some_out_of_date_tasks = false

    if founds.count == 0

      msg = "Aucune tâche n'a été trouvée avec ces options."

      if test?
        @output_lines << msg
      else
        puts msg.orange
      end

    else

      titre = "TÂCHES À FAIRE #{" (« #{cate} »)" unless cate.nil?}"
      tb = Tableizor.new(
        titre:    titre,
        indent:   4,
        align:    {label: :right},
        flex:     true
      )

      # 
      # ***********************
      # * Création du tableau *
      # ***********************
      # 
      founds.sorted(force_all:show_all||show_no_time||show_futures).each do |tache|
        
        # DEBUG
        # ecrit "-Tâche : #{tache.inspect}"
        # /DEBUG

        # Si une tâche en suit une autre, elle est mise un peu
        # en retrait
        retrait = tache.prev? ? '|- ' : ''

        ftodo   = "#{retrait}#{"#{tache.categorie} : " unless by_categorie}#{tache.todo}#{" [#{tache.id}]" if show_ids}"
        fstart  = tache.f_start_court


        if tache.out_of_date?
          # 
          # Les tâches périmées
          # -------------------
          # On doit les traiter avant les tâches courantes car elles
          # sont aussi des tâches courantes à terminer.
          # 
          tb.w fstart, ftodo
          tb.w '', " ⏰ #{"[#{tache.id}] " unless show_ids}périmée depuis #{tache.f_peremption}.", color: :rouge
          # 
          # Pour afficher le message d'aide final
          # 
          some_out_of_date_tasks = true
        elsif tache.current?
          # 
          # Les tâches courantes
          # 
          # Noter que dans les courantes, il y a aussi les
          # périmées, qui restent à faire donc qui sont courantes
          tb.w "#{fstart}", ftodo
          n = tache.reste_secondes
          color_reste = 
            case 
            when n < 3.jours  then :orange
            when n < 6.jours  then :jaune
            when n < 10.jours then :bleu
            else :vert
            end
          tb.w '', " #{PICTO_END_TASK}Doit être achevée dans #{tache.f_reste}", color: color_reste

        elsif tache.futur?
          tb.w fstart, ftodo

        else
          # Une tâche qui n'est rien de tout ça mais qui doit
          # être affichée
          tb.w fstart, ftodo
        end
      end

      @output_lines = tb.display(@output_lines) # @output_lines -> quand tests

    end #/ s'il y a ou non des tâches

    if test?
      @output_lines = [@output_lines] if @output_lines.is_a?(String)
    end

    msg_fin = []
    if some_out_of_date_tasks
      msg_fin << "(jouer 'task done <id tâche>' pour archiver une tâche)"
    end

    msg_fin << "(jouer 'task aide' pour voir les options possibles)\n\n"

    # Pour la rejouer si on 'add' ou 'sup', etc.
    MyTaches.memorise_commande_liste

    if test?
      @output_lines += msg_fin
    else
      puts msg_fin.join("\n").gris
    end

    if test?
      @output_lines = @output_lines.join("\n")
      return @output_lines
    end
  end
  # /etat_des_lieux

end #/<< self

# = main =
# 
# Méthode d'instance pour afficher la tâche
# 
def show(params = nil)
  clear
  tb = Tableizor.new(
    titre: "Tâche « #{todo} »"
  )
  tb.w 'Tâche'              ,todo
  tb.w( 'Détail'            ,detail) if detail
  tb.w 'ID'                 ,"[#{id}]"
  if archived?
    tb.w 'Archivée le', formate_date(done_at)
  end
  tb.w 'Catégorie'          ,categorie
  tb.w 'Fichier à ouvrir'   ,(self.open||'- aucun -')
  tb.w 'Durée'              ,f_duree
  tb.w 'Rappel'             ,f_rappel
  tb.w 'Code à exécuter'    ,(self.exec||'- aucun -')
  tb.w 'Application/icône'  ,(app||'- aucune -')
  # ------ les tâches liés, parallèles -------
  tb.w('Tâche précédente'   ,"#{prev.todo} [#{prev.id}]") if prev?
  tb.w('Tâche suivante'     ,"#{suiv.todo} [#{suiv.id}]") if suiv?
  if parallel?
    tb.w('Tâches parallèles', "(#{parallels.count})")
    parallelized_tasks.each do |tk|
      tb.w "    [#{tk.id}]", tk.todo
    end
  end

  tableau = tb.display
  return tableau if test?  
end


end #/class Tache
end #/module MyTaches
