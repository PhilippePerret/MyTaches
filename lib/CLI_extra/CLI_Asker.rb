# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class Asker
  -----------
  version 1.0
  
  "Interrogateur" qui permet de faciliter l'utilisation de TTY-prompt
  pour demander des informations quelconques à l'utilisateur.


=end

class Asker
class << self

  def ask_for_string(dproperty, default_value = nil)
    while true
      value = Q.ask((dproperty[:question]||dproperty[:hname]).bleu, default:default_value)
      ok, value, errors = check_value_against(dproperty, value)
      return value if ok
      log_error(errors)
    end
  end

  def ask_with_helper(dproperty, default_value = nil)
    while true
      value = dproperty[:helper][:class].send(dproperty[:helper][:method], default_value)
      ok, value, errors = check_value_against(dproperty, value)
      return value if ok
      log_error(errors)
    end
  end

  # = Demande une date =
  # 
  # @param params {Hash}
  #   :separator      Séparateur de date ('/' par défaut)
  #   :heures         Mettre à true si on doit donner l'heure
  #   :require_annee  True si l'année est requise absolument
  #   :reformate      True si la méthode doit retourner la date
  #                   complète, avec tous les chiffres.
  # 
  def ask_for_date(question, params = {separator:'/', heures:true, require_annee:false, reformate:true})
    # 
    # Format exemple
    # 
    sep = params[:separator]
    fmt = ['JJ', 'MM'].join(params[:separator])
    fmtannee = "#{sep}AAAA"
    fmtannee = "[#{fmtannee}]" unless params[:require_annee]
    fmtheure = params[:heures] ? " HH:MM" : ""
    fmt = fmt + fmtannee + fmtheure
    # 
    # Expression régulière pour contrôle
    #
    regseparator = Regexp.escape(params[:separator])
    dbl = '[0-9]?[0-9]'
    regdate = [dbl, dbl].join(regseparator)
    regannee = "#{regseparator}[0-9][0-9][0-9][0-9]"
    regannee = "(#{regannee})?" unless params[:require_annee]
    regheure = params[:heures] ? " #{dbl}:#{dbl}" : ""
    regdate = regdate + regannee + regheure
    while true
      # 
      # On fait la demande
      # 
      value = Q.ask("#{question} (#{fmt})", default:params[:default])
      params.merge!({ok_if: regdate, transform:{class:Asker, method: :reformat_date}})
      ok, value, errors = check_value_against(params, value)
      return value if ok
      log_error(errors)
    end 
  end

  # --- Méthodes de vérification ---

  def check_value_against(dproperty, value)
    errors = []
    ok = true # pour marquer un problème fatal
    #
    # --- Méthodes de check et de transformation ---
    #
    if ok && dproperty[:required]
      ok = !value.nil? && !value.empty?
      ok || errors << "Une valeur est absolument requise."
    end
    if ok && dproperty[:ok_if]
      ok = value.to_s.match?(dproperty[:ok_if])
      ok || errors << "La valeur doit matcher '#{dproperty[:ok_if]}'."
    end
    if ok && dproperty[:check_with]
      ok = dproperty[:check_with][:class].send(dproperty[:check_with][:method].to_sym, value)
      ok || errors << "La méthode #{dproperty[:check_with][:class]}::#{dproperty[:check_with][:method]} a renvoyé false."
    end
    # 
    # Transformation de la valeur
    #
    # La méthode de transformation doit recevoir deux arguments :
    #   (value, dproperty)
    #
    if ok && dproperty[:transform]
      value = 
        if dproperty[:transform].is_a?(Symbol)
          value.send(dproperty[:transform])
        else
          dproperty[:transform][:class].send(dproperty[:transform][:method].to_sym, value, dproperty)
        end
    end
    if ok
      return [true, value, nil]
    else
      return [false, nil, errors.join("\n")]
    end
  end


  # --- Méthodes d'helper ---

  ##
  # = Pour reformater une date raccourcie =
  # 
  # @value {String}
  #   La valeur à formater. Par exemple "1/2 3:4" pour
  #   le 1er février de cette année, à 3 heures 4 minutes
  #
  # @param dproperty
  #   :separator    Le séparateur
  #   :heures       True si la date contient des heures
  # 
  def reformat_date(value, dproperty = nil)
    dproperty ||= {separator: '/', heures: true}
    dproperty.key?(:separator)  || dproperty.merge!(separator: '/')
    dproperty.key?(:heures)     || dproperty.merge!(heures: true)
    sep = Regexp.escape(dproperty[:separator])
    mdbl = '([0-9]?[0-9])'
    masqannee = '(?:'+sep+'([0-9]?[0-9]?[0-9][0-9]))?'
    masq = mdbl+sep+mdbl+masqannee
    if dproperty[:heures]
      masq = masq + ' ' + mdbl + ':' + mdbl
    end
    res = value.match(masq).to_a.collect{|n|n.to_i}
    tout, jour, mois, annee, heure, minute = res

    s = dproperty[:separator]
    jour  = jour.to_s.rjust(2,"0")
    mois  = mois.to_s.rjust(2,"0")
    annee = Time.now.year if annee == 0
    annee = "2" + annee.to_s.rjust(3,'0') if annee < 100
    
    d = "#{jour}#{s}#{mois}#{s}#{annee}"
    if dproperty[:heures]
      minute = minute.to_s.rjust(2,"0")
      d = d + ' ' + heure.to_s + ':' + minute
    end
    return d
  end

end #/<< self
end #/class Asker

#
# --- Méthodes raccourcies ---
#

##
# Transmet une définition de propriétés (+properties+) et retourne
# les valeurs transmises pour chaque propriété par l'utilisateur.
#
# @param properties
#         Liste (Array) de définition de propriétés, contenant
#         au moins :
#           name:       Le nom de la propriété (clé pour data)
#           hname:      Ce qui servira de question (sauf si :question
#                       est défini)
#           question:   Question alternative, à la place de :hname
#           type:       Le type de la donnée, pour savoir quelle
#                       commande tty-prompt utiliser. Par exemple, si
#                       la donnée est de type 'string', on utilise
#                       Q.ask
#                       En fonction du type, d'autres propriété peu-
#                       vent être définies. Cf. ci-dessous.
#           ok_if:      Expression régulière permettant de tester 
#                       la réponse.
#           check_with: Ou la méthode à appeler avec la donnée
#                       {:class, :method}
#           transform:  Méthode pour transformer la valeur. Si c'est
#                       un symbole (p.e. :to_i), utilise cette méthode
#                       sur la valeur, sinon, si c'est un 
#                       {:class, :method} on envoie la valeur à cette
#                       méthode et on récupère la valeur.
# 
#   ADDED-PROPERTIES PER TYPE
#         'number'      :max      Valeur maximale
#                       :min      Valeur minimale
# 
#
def ask_for_properties(properties, init_data, params = {})
  data = {}
  properties.each do |dproperty|
    prop = dproperty[:name].to_sym
    # 
    # Dans tous les cas, quand il y a un helper, on l'utilise
    # 
    if dproperty[:helper]
      data.merge! prop => Asker.ask_with_helper(dproperty, init_data[prop])
    else
      case dproperty[:type]
      when 'string'
        value = Asker.ask_for_string(dproperty, init_data[prop])
        data.merge! prop => value
      end
    end
  end 

  return data
end
