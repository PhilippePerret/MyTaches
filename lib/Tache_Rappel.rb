# encoding: UTF-8
# frozen_string_literal: true
=begin
  Class MyTaches::Rappel
  ----------------------
  Classe auto-testée pour gérer les rappels

  NOTES
  -----

    Toute la difficulté du calcul réside dans le fait qu'on peut 
    mettre une quantité à l'unité. Par exemple '4 jours' pour 'tous
    les 4 jours'. Si le traitement consistait juste à faire 'tous les
    jours' ou 'toutes les semaines le jeudi à 13 heures' on pourrait
    calculer la date de prochain rappel facilement. Mais ici, on peut
    dire "toutes les 2 semaines le jeudi à 13 heures".
    Donc, pour connaitre ces 2 semaines, il faut connaitre le dernier
    temps de rappel.
    Ce temps est enregistré avec la tâche sous la propriété :
      :time_next_rappel
    Si elle n'est pas définie, on considère que c'est le premier
    rappel.


=end
module MyTaches
class Rappel

  #
  # La version String du rappel, c'est-à-dire par exemple
  #   2d::11:30
  # … qui signifie : tous les deux jours à 11 heures 30
  # 
  attr_reader :vstring
  
  def initialize(vstring)
    @vstring = vstring
    parse
  end

  ##
  # Ultime méthode publique de la classe, elle renvoie TRUE si 
  # le rappel doit être donné. False dans le cas contraire.
  # 
  def is_time?(last_rappel)
    unless last_rappel.nil?
      last_rappel = date_from(last_rappel) unless last_rappel.is_a?(Time)
      last_rappel.is_a?(Time) || raise("Le temps du dernier rappel doit être un {Time}.")
    end
    next_time(last_rappel) <= _NOW_
  end

  def next_time(last_rappel = nil)
    next_time_from(last_rappel)
  end

  ##
  # @return {String} Le rappel au format humain
  # 
  def as_human
    heure = "#{heures_rappel}:#{minutes_rappel.to_s.rjust(2,'0')}"
    nfreq = quant_unite
    case freq_unite
    when 'd' 
      "Tous les #{nfreq > 1 ? "#{nfreq} " : ''}jours à #{heure}"
    when 'w'
      ijour = [nil,'Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'][indice_jour]
      "Toutes les #{nfreq > 1 ? "#{nfreq} " : ''}semaines le #{ijour.downcase} à #{heure}"
    when 's'
      ijour = indice_jour.dup
      ijour = '1er' if ijour == '1'
      "Tous les #{nfreq > 1 ? "#{nfreq} " : ''}mois le #{ijour} à #{heure}"
    when 'm'
      "Toutes les #{nfreq > 1 ? "#{nfreq} " : ''}minutes"
    when 'h'
      "Toutes les #{nfreq > 1 ? "#{nfreq} " : ''}heures à 0:#{minutes_rappel.to_s.rjust(2,'0')}"
    when 'y'
      ijour = indice_jour
      ijour = '1er' if ijour.to_i == 1
      mois = MOIS[indice_mois.to_i][:long]
      "Tous les #{nfreq > 1 ? "#{nfreq} " : ''}ans le #{ijour} #{mois} à #{heure}"
    end    
  end

  # @return {String} La fréquence de l'unité, en lettre
  # d = day/jour, s = mois, y = année/year, w = semaine/week,
  # h = heure, m = minute
  # 
  def freq_unite
    @freq_unite
  end

  # @return le nombre d'unité fréquence. Par exemple 4 pour
  # 4 heures
  def quant_unite
    @quant_unite
  end

  def minutes_rappel
    @minutes_rappel
  end

  def heures_rappel
    @heures_rappel
  end

  def indice_jour
    @indice_jour
  end

  def indice_mois
    @indice_mois
  end

  def tolerance
    @tolerance ||= begin
      case freq_unite
      when 'y','s'  then 15
      when 'w','d'  then 7.5
      when 'h','m'  then 3
      end
    end
  end

private  

    def parse
      freq, dd = vstring.split('::')
      @freq_unite     = freq[-1]
      if dd.nil?
        dd = 
          case @freq_unite
          when 'h','m'  then nil # ne rien faire
          when 'y'      then '1/01 10:00'
          when 's', 'w' then '1 10:00'
          when 'd'      then '10:00'
          else '10:00'
          end
      end
      unite_valid? || raise("L'unité #{@freq_unite.inspect} n'est pas valide par un rappel.")
      @quant_unite   = freq[0...-1].to_i
      @quant_unite > 0 || raise("Il devrait y avoir une quantité d'unité…")
      parse_heure(dd)
    end

    def parse_heure(dd)
      (dd && dd.length > 0) || raise("Un temps devrait être défini.")
      @heures_rappel, @minutes_rappel =
        if dd.match?(' ')
          ijour, heure = dd.split(' ')
          case freq_unite 
          when 'h','d'
            raise "Le format du rappel est mauvais…"
          when 'y'
            ijour, mois = ijour.split('/')
            mois.numeric? || raise("Le mois doit être un nombre.")
            mois = mois.to_i 
            mois.between?(1,12) || raise("Le mois doit être un nombre entre 1 et 12.")
            @indice_mois = mois
          end
          ijour = ijour.to_i if ijour.numeric?
          case freq_unite
          when 'w' # semaine
            ijour.between?(1,7) || raise("L'indice du jour doit être entre 1 (lundi) et 7 (dimanche) (il vaut #{ijour}).")
          when 's' # mois
            ijour.between?(1,28) || raise("L'indice du jour doit être entre 1 et 28 (il vaut #{ijour}).")
          when 'y' # année
          end
          @indice_jour = ijour
          heure.split(':').map{|n|n.to_i}
        elsif freq_unite == 'h'
          [_NOW_.hour, dd.to_i]
        elsif freq_unite == 'd'
          dd.split(':').map{|n|n.to_i}
        end
      @heures_rappel.between?(0, 23)  || raise("#{@heures_rappel.inspect} n'est pas un nombre d'heures valide.")
      @minutes_rappel.between?(0, 60) || raise("#{@minutes_rappel.inspect} n'est pas un nombre de minutes valide.")
    end

    def unite_valid?
      ['m','h','d','w','s','y'].include?(freq_unite)
    end

    #
    # @return le prochain temps de rappel par rapport à maintenant
    # et au dernier temps de rappel +last_rappel+
    # 
    # Il se calcule en deux temps :
    #   1. d'abord, il faut trouver le jour et l'heure approximatifs
    #      en fonction de la fréquence
    #   2. ensuite il faut donner le temps exact.
    # 
    # @param  last_rappel {Nil|Time} Soit nil (si premier check soit
    #         le temps du dernier rappel)
    # 
    def next_time_from(last_rappel)

      if last_rappel.nil?
        
        # 
        # Quand c'est la première fois
        # 
        
        case freq_unite
        when 'h' # heure
          return _NOW_.adjust(min: minutes_rappel)
        when 'd' # jour
          return _NOW_.at("#{heures_rappel}:#{minutes_rappel}")
        when 'w' # semaine
          wday = _NOW_.wday
          wday = 7 if wday == 0
          ntime = 
            if indice_jour != wday
              if wday > indice_jour
                diff_indice = wday - indice_jour
                _NOW_.moins(diff_indice).jours
              else
                diff_indice = indice_jour - wday
                _NOW_.plus(diff_indice).jours
              end
            else
              _NOW_
            end
          return adjust_time_since('w', ntime)
        when 's' # mois
          ntime = Time.new(_NOW_.year,_NOW_.month,indice_jour,heures_rappel,minutes_rappel)
          return adjust_time_since('s', ntime)
        when 'y' # année
          ntime = Time.new(_NOW_.year,indice_mois,indice_jour,heures_rappel,minutes_rappel)
          return adjust_time_since('y', ntime)
        end

      else

        # 
        # Quand ce n'est pas la première fois (cf. manuel dév.)
        # 

        adjust_time_since(freq_unite, case freq_unite
          when 'y' # tous les x années
            last_rappel.plus(quant_unite).ans
          when 's'
            last_rappel.plus(quant_unite).mois
          else
            # puts "last_rappel(#{last_rappel}) + quant_unite (#{quant_unite}) * frequence_secondes #{frequence_secondes} — #{7 * 24 * 3600}"
            last_rappel + quant_unite * frequence_secondes
          end
        ).tap do |ti|
          # puts "Temps ajusté: #{ti}"
        end
      end
    end

    def adjust_time_since(freq, time)
      nb_for_freq = {y: 4, s: 3, w: 2, wdh: 2, d: 2, h: 1}[freq.to_sym]
      args = {}
      args.merge!(min:    minutes_rappel) if nb_for_freq > 0
      args.merge!(hour:   heures_rappel)  if nb_for_freq > 1
      args.merge!(day:    indice_jour)    if nb_for_freq > 2
      args.merge!(month:  indice_mois)    if nb_for_freq > 3
      return time.adjust(args)
    end

    # @return {Integer} la fréquence en secondes
    # en fonction de l'unité de fréquence (jour, année, …) et
    # la quantité de fréquence
    def frequence_secondes
      case freq_unite
      when 'h' then 3600
      when 'd' then 1.jour
      when 'w' then 1.semaine
      end
    end

end #/Class
end #/module MyTaches

