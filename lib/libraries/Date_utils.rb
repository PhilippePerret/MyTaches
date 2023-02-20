# encoding: UTF-8
# frozen_string_literal: true
=begin

  Date Utilitaires
  -----------------
  version 1.4

  Méthodes utilitaires pour les dates/times
=end
require 'date'

JOUR = (3600 * 24)

REG_DATE_WITH_TIME = /^((?<jour>[0-9]{1,2})?((?:\/(?<mois>[0-9]{1,2}))?(?:\/(?<annee>[0-9]{4}))?)?(?: (?<heure>[0-9]{1,2})\:(?<minute>[0-9]{2}))?|(?<heure>[0-9]{1,2})\:(?<minute>[0-9]{2}))$/

def formate_date(time = nil, options = nil)
  options ||= {}
  options.key?(:mois) || options.merge!(mois: :long)
  time ||= Time.now
  time =  case time
          when Date then time.to_time
          when Time then time
          else Time.at(time.to_i)
          end
  # Le mois
  mois = MOIS[time.month][options[:mois]]
  options[:template] ||= begin
    temp =  if time.day == 1
              ["1er #{mois} %Y"]
            else
              ["%-d #{mois} %Y"]
            end
    temp << "à %H:%M" if options[:time] || options[:hour]
    temp.join(' ')
  end
  d = "#{options[:jour] || options[:day] ? DAYNAMES[time.wday]+' ' : ''}#{time.strftime(options[:template])}"
  if options[:duree]
    tnow = Time.now
    jours = ((tnow - time).abs.to_f / JOUR).round
    laps =  if jours == 0
              'aujourd’hui'
            else
              s = jours > 1 ? 's' : '' ;
              mot = tnow > time ? 'il y a' : 'dans' ;
              "#{mot} #{jours} jour#{s}"
            end
    d = "#{d} <span class=\"small\">(#{laps})</span>"
  end
  return d
end #/ formate_date

##
# @entrée : une date complète ou partielle avec la date et l'heure
# @sortie : une table contenant :
#   :jour, :mois, :annee, :heure, :minute,
#   :time (nil si aucun temps)
#   :date_str (J/MM/AAAA[ H:MM], 
#   :with_time (toujours le temps))
# 
def date_from_with_time(datestr)
  return false unless REG_DATE_WITH_TIME.match(datestr)
  rg = REG_DATE_WITH_TIME.match(datestr)
  r  = {} 
  [:jour, :mois, :annee, :heure, :minute].each do |prop|
    r.merge!(prop => rg[prop] && rg[prop].to_i)
  end
  # puts "r : #{r.inspect}"
  tnow = Time.now
  r[:jour] ||= tnow.day
  return false if r[:jour] > 31
  r[:mois]  ||= tnow.month
  return false if r[:mois] > 12
  r[:annee] ||= tnow.year
  date_str = "#{r[:jour]}/#{rdig(r[:mois])}/#{rdig(r[:annee],4)}"
  if r[:heure]
    return false if r[:heure] > 24
    return false if r[:minute] > 60
    r.merge!(time: "#{rdig(r[:heure])}:#{rdig(r[:minute])}")
    with_time = date_str = "#{date_str} #{r[:time]}"
  else
    with_time = "#{date_str} 0:00"
  end

  return r.merge!(date_str:date_str, with_time:with_time)
end
def rdig(value, len = 2)
  value.to_s.rjust(len,'0')
end

# 
# Retourne la date (instance Date ou Time) de la valeur +foo+ qui
# peut être :
#   - une date ou un temps (rien à faire)
#   - un string 'JJ/MM/AAAA' ou 'JJ/MM/AAAA HH:SS'
#   - un string 'AAAA/MM/JJ'
#   - un timestamp (nombre de secondes)
# 
def date_from(foo)
  return nil if foo.nil?
  case foo
  when Time       then foo
  when Date       then foo.to_time
  when Integer    then Time.at(foo)
  when String
    if foo.match?('/')
      if foo.match?(' ')
        sdate, sheure = foo.split(' ')
        h, m = sheure.split(':').map(&:to_i)
      else
        sdate = foo
        h, m, s = [0,0,0]
      end
      a, b, c = sdate.split('/')
      a.numeric? || raise("Le jour ou l'année devrait être un chiffre.")
      b.numeric? || raise("Le mois devrait être un chiffre.")
      unless c.nil?
        c.numeric? || raise("Le jour ou l'année devrait être un chiffre.")
      end
      if c.nil?
        Time.new(Time.now.year, b.to_i, a.to_i, h, m, 0)
      elsif c.length == 4
        Time.new(c.to_i, b.to_i, a.to_i, h, m, 0)
      else
        Time.new(a.to_i, b.to_i, c.to_i, h, m, 0)
      end
    elsif foo.match?(/^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]/)
      return Time.new(foo)
    else
      raise "#{foo.inspect} est une date mal formatée. Impossible d'en tirer la date voulue."
    end
  else
    raise "Impossible de trouver la date qui se cache dans #{foo.inspect}"
  end
end

# ---------------------------------------------------------------------
#
#   Class DateString
#   ----------------
#   v. 0.1.0
#
#   Permet de gérer les dates sous forme JJ MM AAAA HH:MM:SS
#   - Les espaces peuvent être remplacées par des "/" : JJ/MM/AAAA
#   - Seuls les jours et les mois sont absolument requis. Toutes les
#     autres valeurs sont optionnelles.
#   - L'année peut être mise sur 2 chiffres. Dès qu'elle est inférieure
#     à 100, on lui ajoute 2000.
#
#   @usage
#     dstring = DateString.new(valeur)
#     dstring.valid?  -> true si ok, false otherwise
#                     dstring.error contient l'erreur de formatage
#     dstring.to_time -> La {Date} ({Time}) correspondant
# ---------------------------------------------------------------------

class DateString
# ---------------------------------------------------------------------
#
#   INSTANCE
#
# ---------------------------------------------------------------------
attr_reader :init_value
attr_reader :jour, :mois, :annee, :heure, :minutes, :seconds
attr_reader :error
def initialize(init_value)
  @init_value ||= init_value
end #/ initialize

##
# @return la date en JJ/MM/AAAA (avec possibilité de changer le
# délimiteur)
#
def jj_mm_aaaa(delimiteur = '/')
  to_time.strftime("%d#{delimiteur}%m#{delimiteur}%Y")
end

# OUT   La date au format {Time}
def to_time
  valid? || raise(@error)
  @to_time ||= Time.new(annee||tnow.year, mois||tnow.month, jour, heure||0, minutes||0, seconds||0)
end #/ to_time

def tnow
  @tnow ||= Time.now
end
# OUT   True si la date string fournie est valide.
def valid?
  check_formatage
  error.nil?
end #/ valid?
# ---------------------------------------------------------------------
#   Méthodes de check
# ---------------------------------------------------------------------
def check_formatage
  check_value_init
  @jour, @mois, @annee, @heure, @minutes, @seconds = init_value.split(/[ \/\-:]/).collect{|m| m.to_i}
  # puts "@jour:#{@jour.inspect}, @mois:#{@mois.inspect}, @annee:#{@annee.inspect}"
  check_jour
  check_mois    if not(@mois.nil?)
  check_annee   if not(@annee.nil?)
  check_heure   if not(@heure.nil?)
  check_minutes if not(@minutes.nil?)
  check_seconds if not(@seconds.nil?)
  return true
rescue Exception => e
  @error = e.message
  return false
end #/ check_formatage

def check_value_init
  c   = '[0-9]'
  c2  = "#{c}?#{c}"
  c4  = "#{c}#{c}(#{c}#{c})?"
  sep = '[ \/]'
  format_ok = init_value.match?(/^#{c2}(#{sep}#{c2}(#{sep}#{c4})?)?(([\-\/]#{c2}:#{c2}(:#{c2})?)?)?$/) 
  format_ok || raise("La date doit être fournie au format 'JJ[ MM[ YY[ HH:MM]]]' (les espaces peuvent être remplacées par des '/').")
end #/ check_value_init
def check_jour
  raise "Le jour doit être un nombre entre 1 et 31" if jour < 1 || jour > 31
end #/ check_jour
def check_mois
  raise "Le mois doit être un nombre entre 1 et 12" if mois < 1 || mois > 12
end #/ check_mois
def check_annee
  raise "L'année doit être un nombre positif" if annee < 0
  @annee += 2000 if @annee < 100
end #/ check_annee
def check_heure
  raise "L'heure doit être un nombre entre 0 et 24" if heure < 0 || heure > 24
end #/ check_heure
def check_minutes
  raise "Les minutes doivent être un nombre entre 0 et 59" if minutes < 0 || minutes > 59
end #/ check_minutes
def check_seconds
  raise "Les secondds doivent être un nombre entre 0 et 59" if seconds < 0 || seconds > 59
end #/ check_seconds
end #/DateString


if $0 == __FILE__
  require 'test/unit'
  class TestDeDateString < Test::Unit::TestCase

    test "DateString.new('5/7') doit renvoyer la date du 5 juillet de l'année courante" do
      d = DateString.new('5/7')
      n = Time.now
      assert_equal("05/07/#{n.year}", d.jj_mm_aaaa)
    end
    test "DateString.new('5') doit renvoyer la date du 5 du mois courant" do
      d = DateString.new('5')
      n = Time.now
      assert_equal("05/#{n.month.to_s.rjust(2,'0')}/#{n.year}", d.jj_mm_aaaa)
    end
    test "DateString.new(...).jj_mm_aaaa('-') retourne la bonne valeur" do
      d = DateString.new('5/8/20')
      assert_equal('05-08-2020', d.jj_mm_aaaa('-'))
    end

    test "date_from_with_time/REG_DATE_WITH_TIME permet de checker et vérifier une date avec heure" do
      tnow = Time.now
      # 
      # Bonnes dates
      # 
      [
        ['08/05/2022 06:33', true, [8, 5, 2022, 6, 33, '8/05/2022 6:33']],
        ['8/5/2022 6:33', true, [8, 5, 2022, 6, 33, '8/05/2022 6:33']],
        ['8/05 6:33', true, [8, 5, tnow.year, 6, 33, '8/05/2022 6:33']],
        ['8/05', true, [8, 5, tnow.year, nil, nil, "8/05/#{tnow.year} 0:00"]],
        ['8', true, [8, tnow.month, tnow.year, nil, nil, "8/#{tnow.month.to_s.rjust(2,'0')}/#{tnow.year} 0:00"]],
        ['8 17:29', true, [8, tnow.month, tnow.year, 17, 29, "8/#{tnow.month.to_s.rjust(2,'0')}/#{tnow.year} 17:29"]],
        ['16:26', true, [tnow.day, tnow.month, tnow.year, 16, 26, "#{tnow.day}/#{tnow.month.to_s.rjust(2,'0')}/#{tnow.year} 16:26"]],
      ].each do |exdate, isdate, chiffres|
        hd = date_from_with_time(exdate)
        assert_false(!hd)
        comp = [hd[:jour],hd[:mois],hd[:annee],hd[:heure],hd[:minute], hd[:with_time]]
        assert_equal(chiffres, comp)
      end
      # 
      # Mauvaises dates
      # 
      [
        '32/05/2022',
        '-1/05/2022',
        '31/13/2022',
        '25/05/2022 25:10',
        '25/05/2022 12',
        '25/05/2022 12:61',
        'a/b/c d:e',
        'aa/bb/cc dd:ee'
      ].each do |exdate, isdate, chiffres|
        assert_false(date_from_with_time(exdate))
      end
    end
  end
end

=begin

  VERSIONS
  --------
  1.4
    Test plus rigoureux de la valeur envoyée à date_from
    
  1.3
    Implémentation de #date_from_with_time qui retourne
    false ou un {Hash} contenant toutes les informations
    sur la date et l'heure, en compensant les valeurs
    manquantes.

  1.2
    Première version "officielle"
    Ajout du traitement des heures dans la méthode date_from
=end
