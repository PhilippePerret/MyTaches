# encoding: UTF-8
# frozen_string_literal: true
require_relative 'Tache_list'
module MyTaches

INDENT_FIRST_LINKED_TASK = '    -> '
INDENT_OTHER_LINKED_TASK = '    |– '
INDENT_ALINK_LINKED_TASK = '    |  '
PICTO_START_TASK = '🚀 '
PICTO_END_TASK   = '🎯 '

class Tache


  # Ligne de la tâche pour le terminal
  # en fonction des données qu'elle possède
  # 
  # @param  params {Hash|Nil}
  #         :max    Définit la longueur maximale de la ligne pour un
  #                 affichage correct.
  #         :indent {Integer} Si c'est un nombre, c'est le nombre
  #                 d'espaces qu'il faut laisser avant.
  #                 {String} Si c'est un string, c'est le texte de
  #                 l'indentation de départ, qui servira à formater
  #                 les autres lignes.
  # 
  def infos(params = nil)
    params ||= {}
    params.merge!(no_id: true) unless params.key?(:no_id)
    li = ["#{PICTO_START_TASK}#{f_start_simple||'---'}"]
    li << todo
    li << "#{"#{f_duree_courte} " if duree}#{PICTO_END_TASK}#{f_end_simple}"
    li << "[#{id}]" unless params[:no_id]

    li = li.join(' * ')
    
    if params[:max]
      # 
      # <= La ligne est trop longue
      # => Il faut la découper
      # 
      maxlen = params[:max]
      if params[:indent].is_a?(Integer)
        indent = params[:indent]
        indent_str = ' ' * indent
      else
        indent = params[:indent].length
        indent_str = params[:indent]
      end

      if li.length > params[:max]
        mots  = li.split(' ').reverse
        lines = [] 
        line  = ""
        while mot = mots.pop
          if indent + line.length + mot.length > maxlen
            lines << line
            line = ""
          end
          line = "#{line} #{mot}".strip
        end
        lines << line unless line.empty?
        li = (params[:first_indent]||indent_str) + lines.join("\n#{indent_str}")
      else
        li = (params[:first_indent]||indent_str) + li
      end
    end

    return li
  end

  # @return {String} l'affichage de la tâche dans un
  # affichage présentant verticalement la suite des
  # tâches liées.
  # 
  # Normalement, c'est la première tâche qui appelle
  # cette méthode (mais il est tout à fait possible 
  # d'imaginer de partir à partir d'une autre tâche —
  # par exemple pour afficher des tâches restantes)
  # 
  # @param  params {Hash|Nil}
  #         Les paramètres d'affichage
  #         :no_id  Mettre à false pour afficher l'identifiant
  #                 de la liste (true par défaut)
  #         :max    {Integer} Longueur maximale de la ligne (70 par
  #                 défaut)
  #         :first_indent   {String} Indentation initiale pour la
  #                         toute première tâche seulement
  #                         Si ≠ de valeur par défaut
  #         :first_indent_other {String} Identation pour les autres
  #                         première ligne de tâches
  #                         Si ≠ de valeur par défaut
  #         :indent         {String} l'identation pour du texte de 
  #                         suite de la tâche ou rien
  #                         Si ≠ de valeur par défaut
  # 
  def lines_linked_task(params = nil)
    params ||= {}
    params.key?(:no_id) || params.merge!(no_id: true)
    params.key?(:max)   || params.merge!(max: 70)
    params.key?(:first_indent) || params.merge!(first_indent:INDENT_FIRST_LINKED_TASK)
    params.key?(:indend) || params.merge!(indent:INDENT_ALINK_LINKED_TASK)
    params_other = params.dup
    params_other.merge!(first_indent: params.delete(:first_indent_other) || INDENT_OTHER_LINKED_TASK)
    lines = []
    lines << "\n  #{categorie||'divers'}".upcase
    lines << ""
    lines << infos(params)
    curta = self # pour la boucle
    while curta.suiv
      curta = curta.suiv
      lines << "    |\n#{curta.infos(params_other)}"
    end
    lines << "\n\n"
    
    return lines.join("\n")
  end

  def f_prev(value = nil)
    return if value.nil?
    "[#{prev_id}] #{prev.todo}" if prev?
  end


  def f_start_simple
    return '' if start_time.nil?
    meme_annee = start_time.year == _NOW_.year
    fmt_date = meme_annee ? '%d/%m' : '%d/%m/%y'
    if start_time
      (start ? '' : '~') + start_time.strftime(fmt_date)
    end
  end
  alias :f_start_court :f_start_simple

  def f_end_simple
    return '---' if end_time.nil?
    meme_annee = end_time.year == _NOW_.year
    fmt_date = meme_annee ? '%d/%m' : '%d/%m/%y'
    if end_time
      (start ? '' : '~') + end_time.strftime(fmt_date)
    end    
  end

  def f_start_time
    if start_time
      (start ? '' : '~') + formate_date(start_time)
    else
      '---'
    end
  end

  def f_start(value)
    if value
      f_start_time
    end
  end

  def f_end_time
    if end_time
      (start ? '' : '~') + formate_date(end_time)
    else
      '---'
    end
  end

  ##
  # @return la durée formatée de +value+ (pour l'édition) ou 
  # de la durée dans les données
  # 
  # @param  fmt {Symbol} :normal, :court
  # 
  def f_duree(value = nil, fmt = :normal)
    value ||= duree
    return nil if value.nil?
    @f_duree = begin
      if value == '%' # durée variable d'une tâche de modèle
        "Durée variable"
      elsif value.nil?
        '- non définie -'
      else
        hduree = Tache.decompose_duree(value)
        unite = hduree[:unite]
        value = hduree[:quant]
        "#{value} #{hunite_duree(unite, fmt, value > 1)}"
      end
    end
  end

  def f_duree_courte(value = nil)
    value ||= duree
    return nil if value.nil?
    f_duree(value, :court)
  end

  def hunite_duree(unite, fmt, pluriel)
    sing, plur, court, court_sing = case unite
    when 'y' then ['année','années','ans','an']
    when 's' then ['mois','mois','mois','mois']
    when 'w' then ['semaine', 'semaines', 'sem.', 'sem.']
    when 'd' then ['jour','jours', 'jrs', 'jour']
    when 'h' then ['heure','heures','hrs', 'heure']
    when 'm' then ['minute','minutes','mns', 'min.']
    else raise "Unité inconnue : #{unite}"
    end
    case fmt
    when :court   then pluriel ? court : court_sing
    when :normal  then pluriel ? plur : sing
    end
  end

  def f_rappel(value = nil)
    value ||= data[:rappel]
    if value
      Rappel.new(value).as_human
    else
      "- non défini -"
    end
  end

  def f_reste
    Tache.human_delai(calc_reste)    
  end

  # @return Un string de type "3w 4d 5h"
  # @params per {:semaines, :jours, :heures}
  def formate_delai(per)
    rac = []
    rac << "#{per[:semaines]}w" if per[:semaines] > 0
    rac << "#{per[:jours]}d"    if per[:jours] > 0
    rac << "#{per[:heures]}h"   if per[:heures] > 0

    return rac.join(' ')
  end

  # @return Un string de type "3 semaines et 4 jours"
  # @params sjd {:semaines, :jours, :heures}
  def self.human_delai(sjd)
    str = []
    sjdsem = sjd[:semaines]
    str << "#{sjdsem} semaine#{'s' if sjdsem > 1}" if sjdsem > 0
    sjdday = sjd[:jours]
    str << "#{sjdday} jour#{'s' if sjdday > 1}" if sjdday > 0
    sjdhour = sjd[:heures]
    str << "#{sjdhour} heure#{'s' if sjdhour > 1}" if sjdsem == 0 && sjdhour > 0
    str.pretty_join    
  end

  def f_parallels(value)
    return if value.nil?
    value.join(', ')
  end

  def f_detail(value = nil)
    value ||= detail
    return if value.nil?
    "\n\t" + value.split("\n").join("\n\t")
  end

end #/Tache
end #/module MyTaches
