# encoding: UTF-8
# frozen_string_literal: true
=begin

  Extension de la classe Time
  Auto-testée

  v 1.0.0

=end
require_relative 'Integer' # extension

class TheNow
  class << self
    def now
      @now ||= Time.now
    end
    def now=(time)
      @now = time
    end
    def reset
      @now = nil
    end
  end #/<< self
end
def thenow
  TheNow.maintenant
end

def now
  TheNow.now
end
alias :maintenant :now

def _NOW_
  TheNow.now
end

class Time

  # Pour utiliser Time#plus(x).<chose> où <chose> peut
  # être 'jours', 'mois', 'semaines', etc.
  # 
  # Par exemple :
  # 
  #   _NOW_.plus(3).jours
  #   # => retourne le temps {Time} à 3 jours d'ici
  # 
  def plus(value)
    Additionneur.new(self, value)
  end

  # Pour utiliser Time#moins(x).<chose> où <chose> peut
  # être 'jours', 'mois', 'semaines', etc.
  # 
  def moins(value)
    plus(- value)
  end

  ##
  # Ajuste le temps courant avec les valeurs fournies dans la table
  # +hash+
  # 
  # @param hash {Hash}
  #   Table contenant :year, :month, :day, :min, :sec
  #   Les valeurs peuvent être des nombres ou d'autres dates. Par 
  #   exemple, si :
  #       day: untemps
  #   … alors c'est le jour de untemps (untemps.day) qui sera utilisé
  #   comme valeur.
  # 
  def adjust(hash)
    args = {year: self.year, month:self.month, day: self.day, hour:self.hour, min:self.min, sec:self.sec}
    hash.each do |k,v|
      hash[k] = v.send(k) unless v.is_a?(Integer)
    end
    args.merge!(hash)
    return Time.new(*args.values)
  end

  # Pour caler le temps sur une heure.
  # Par exemple, pour avoir le temps exact du petit matin :
  #   untemps.at('0:00') (ou même untemps.at(0))
  def at(heure)
    hrs, mns, scs = heure.to_s.split(':').map{|n|n.to_i}
    adjust(hour:hrs, min:mns.to_i, sec:scs.to_i)
  end

  # @return {String} Le time au format JJ/MM/AAAA HH:MM
  def jj_mm_aaaa_hh_mm(del = '/')
    return self.strftime("%d#{del}%m#{del}%Y %H:%M")
  end

  # @return {String} Le time au format JJ/MM/AAAA HH:MM
  def jj_mm_aaaa_hh_mm_ss(del = '/')
    return self.strftime("%d#{del}%m#{del}%Y %H:%M:%S")
  end

  # @return {String} Le time au format JJ/MM/AAAA ou avec un
  # autre délimiteur +del+
  def jj_mm_aaaa(del = '/')
    return self.strftime("%d#{del}%m#{del}%Y")
  end

  # @return {String} Le time au format JJ/MM ou avec un
  # autre délimiteur +del+
  def jj_mm(del = '/')
    return self.strftime("%d#{del}%m")
  end
end

class Time
  class Additionneur

    attr_reader :time
    attr_reader :nombre
    def initialize(time, value)
      @time   = time
      @nombre = value
    end

    #
    # @usage    Time#plus(x).secondes
    # 
    def secondes
      return time + nombre
    end
    alias :seconde :secondes
    alias :second  :secondes
    alias :seconds :secondes

    # 
    # @usage    Time#plus(x).minutes
    # 
    def minutes
      return time + nombre.minutes
    end
    alias :minute :minutes

    #
    # @usage  Time#plus(x).heures
    #
    def heures
      return time + nombre.heures
    end
    alias :hours :heures
    alias :heure :heures

    # 
    # @usage    Time#plus(x).jours
    # 
    def jours
      return time + nombre.jours
    end
    alias :jour :jours
    alias :days :jours

    #
    # @usage Time#plus(x).semaines
    # 
    def semaines
      return time + nombre.semaines
    end
    alias :weeks :semaines
    alias :week :semaines
    alias :semaine :semaines

    # @usage : Time#plus(x).mois
    # 
    def mois
      annee, mois = [time.year, time.month]
      mois += nombre
      if mois > 12 || mois < 0
        annee = annee + mois / 12
        mois  = mois % 12
      end
      return Time.new(annee,mois,time.day,time.hour,time.min,time.sec)
    end

    # @usage : Time#plus(x).mois
    #
    def annees
      Time.new(time.year + nombre,time.month,time.day,time.hour,time.min,time.sec)
    end
    alias :ans :annees
    alias :an  :annees
    alias :annee :annees
    alias :years :annees
    
  end
end

class Time
  class WDay
    def after_now?
      diff_with_now < 0
    end
    def diff_with_now
      @diff_with_now ||= _NOW_.wday - self.index
      # 6 (samedi) - 0 (dimanche)
      # 5 (vendredi) - 6 (samedi) = -1
    end
    def diff_abs
      @diff_abs ||= diff_with_now.abs
    end
    def next
      if after_now?
        _NOW_.plus(diff_abs).jours
      else
        _NOW_.plus(7 - diff_abs).jours
      end
    end
    def prev
      self.next.moins(7).jours
    end
    def out(params = nil)
      params ||= {}
      send(params[:previous] ? :prev : :next)
    end
  end
end
class Time
  class Lundi < WDay
    def index; 1 end
  end
  class Mardi < WDay
    def index; 2 end
  end
  class Mercredi < WDay
    def index; 3 end
  end
  class Jeudi < WDay
    def index; 4 end
  end
  class Vendredi < WDay
    def index; 5 end
  end
  class Samedi < WDay
    def index; 6 end
  end
  class Dimanche < WDay
    def index; 0 end
  end
end

# @return {Time} Le prochain lundi
# @param params {Hash}
def lundi(params = nil)
  Time::Lundi.new().out(params)
end
def mardi(params = nil)
  Time::Mardi.new().out(params)
end
def mercredi(params = nil)
  Time::Mercredi.new().out(params)
end
def jeudi(params = nil)
  Time::Jeudi.new().out(params)
end
def vendredi(params = nil)
  Time::Vendredi.new().out(params)
end
def samedi(params = nil)
  Time::Samedi.new().out(params)
end
def dimanche(params = nil)
  Time::Dimanche.new().out(params)
end

def lundi?;     _NOW_.wday == 1 end
def mardi?;     _NOW_.wday == 2 end
def mercredi?;  _NOW_.wday == 3 end
def jeudi?;     _NOW_.wday == 4 end
def vendredi?;  _NOW_.wday == 5 end
def samedi?;    _NOW_.wday == 6 end
def dimanche?;  _NOW_.wday == 0 end


if $0 == __FILE__

  require 'test/unit'
  class TestExtensionTime < Test::Unit::TestCase

    test "On peut ajouter ou soustraire des minutes" do
      assert_equal(_NOW_ + 30*60, _NOW_.plus(30).minutes)
      assert_equal(_NOW_ - 30*60, _NOW_.moins(30).minutes)
    end

    test "On peut ajouter ou soustraire des heures" do
      assert_equal(_NOW_ + 2*3600, _NOW_.plus(2).heures)
      assert_equal(_NOW_ - 2*3600, _NOW_.moins(2).heures)
      assert_equal(_NOW_ + 3*3600, _NOW_.plus(3).hours)
      assert_equal(_NOW_ - 3*3600, _NOW_.moins(3).hours)
    end

    test "On peut ajouter ou soustraire des jours" do
      assert_equal(_NOW_ + 4*3600*24, _NOW_.plus(4).jours)
      assert_equal(_NOW_ + 4*3600*24, _NOW_.plus(4).days)
      assert_equal(_NOW_ - 4*3600*24, _NOW_.moins(4).jours)
      assert_equal(_NOW_ - 4*3600*24, _NOW_.moins(4).days)
    end

    test "On peut ajouter ou soustraire des semaines" do
      assert_equal(_NOW_ + 5*7*3600*24, _NOW_.plus(5).semaines)
      assert_equal(_NOW_ + 5*7*3600*24, _NOW_.plus(5).weeks)
      assert_equal(_NOW_ - 5*7*3600*24, _NOW_.moins(5).semaines)
      assert_equal(_NOW_ - 5*7*3600*24, _NOW_.moins(5).weeks)
    end

    test "On peut ajouter ou soustraire des mois" do
      # La formule est forcément plus compliqué à cause
      # du nombre variable de jours dans le mois
      ti = Time.new(2022,5,16)
      
      # Dans la même année
      tcapres = Time.new(2022,9,16)
      tcavant = Time.new(2022,1,16)
      assert_equal(tcapres, ti.plus(4).mois)
      assert_equal(tcavant, ti.moins(4).mois)

      # En arrivant à 12
      tcapres = Time.new(2022,12,16)
      assert_equal(tcapres, ti.plus(7).mois)

      # En passant une année
      tcapres = Time.new(2023,2,16)
      tcavant = Time.new(2021,10,16)
      assert_equal(tcapres, ti.plus(9).mois)
      assert_equal(tcavant, ti.moins(7).mois)

      # Avec un grand nombre de mois
      tc = Time.new(2022,5,18)
      tc1apres = Time.new(2024,5,18)
      tc2apres = Time.new(2025,7,18)
      assert_equal(tc1apres, tc.plus(24).mois)
      assert_equal(tc2apres, tc.plus(38).mois)
      tc1avant = Time.new(2000,5,18)
      assert_equal(tc1avant, tc.moins(264).mois)
    end

    test "On peut ajouter ou soustraire des années" do
      ti = Time.new(2022,5,16)

      tcapres = Time.new(2025,5,16)
      tcavant = Time.new(2019,5,16)

      assert_equal(tcapres, ti.plus(3).ans)
      assert_equal(tcapres, ti.plus(3).years)
      assert_equal(tcapres, ti.plus(3).annees)

      assert_equal(tcavant, ti.moins(3).ans)
      assert_equal(tcavant, ti.moins(3).years)
      assert_equal(tcavant, ti.moins(3).annees)

    end

    test "On peut ajuster les temps avec un nombre" do
      ti = Time.new(2022,5,17,0,0,0)
      assert_equal(0, ti.min)
      ti = ti.adjust(min:12)
      assert_equal(12, ti.min)

      assert_equal(2022, ti.year)
      ti = ti.adjust(year: 2030)
      assert_equal(2030, ti.year)
    end

    test "On peut ajuster un temps avec une autre date" do
      tc = Time.new(1964,8,31)
      tr = Time.new(2022,5,18)
      assert_equal(31, tc.day)
      tc = tc.adjust(day:tr)
      assert_equal(18, tc.day)
      assert_equal(8, tc.month)
      tc = tc.adjust(month:tr)
      assert_equal(5, tc.month)
      assert_equal(1964, tc.year)
      tc = tc.adjust(year:tr)
      assert_equal(2022, tc.year)
    end

    test "Les méthodes lundi?, mardi? etc. existent et retournent la bonne valeur" do
      [:lundi?, :mardi?, :mercredi?, :jeudi?, :vendredi?,
        :samedi?, :dimanche?
      ].each do |method|
        assert_nothing_raised(NameError) { send(method) }
      end
    end

    test "Les méthodes lundi, mardi, mercredi, etc. retourne les bonnes valeurs" do
      [
        :lundi, :mardi, :mercredi, :jeudi, :vendredi, :samedi, :dimanche
      ].each do |method|
        assert_nothing_raised(NameError) { send(method) }
        assert_instance_of(Time, send(method))
      end

      assert_equal(0, dimanche.wday)
      assert_true(dimanche > _NOW_)
      assert_equal(1, lundi.wday)
      assert_true(lundi > _NOW_)
      assert_equal(2, mardi.wday)
      assert_true(mardi > _NOW_)
      assert_equal(3, mercredi.wday)
      assert_true(mercredi > _NOW_)
      assert_equal(4, jeudi.wday)
      assert_true(jeudi > _NOW_)
      assert_equal(5, vendredi.wday)
      assert_true(vendredi > _NOW_)
      assert_equal(6, samedi.wday)
      assert_true(samedi > _NOW_)

      assert_equal(0, dimanche(previous:true).wday)
      assert_true(dimanche(previous:true) < _NOW_) unless dimanche?
      assert_equal(1, lundi(previous:true).wday)
      assert_true(lundi(previous:true) < _NOW_) unless lundi?
      assert_equal(2, mardi(previous:true).wday)
      assert_true(mardi(previous:true) < _NOW_) unless mardi?
      assert_equal(3, mercredi(previous:true).wday)
      assert_true(mercredi(previous:true) < _NOW_) unless mercredi?
      assert_equal(4, jeudi(previous:true).wday)
      assert_true(jeudi(previous:true) < _NOW_) unless jeudi?
      assert_equal(5, vendredi(previous:true).wday)
      assert_true(vendredi(previous:true) < _NOW_) unless vendredi?
      assert_equal(6, samedi(previous:true).wday)
      assert_true(samedi(previous:true) < _NOW_) unless samedi?

    end

  end#/TestCase

end
