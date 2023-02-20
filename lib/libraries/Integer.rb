# encoding: UTF-8
# frozen_string_literal: true

class Integer

  JOUR = 3600 * 24

  # Pour faire 6.semaines
  def semaines
    return self * 7 * JOUR
  end
  alias :semaine :semaines
  
  # Pour faire 3.jours
  def jours
    return self * JOUR
  end
  alias :jour :jours

  # Pour faire 4.heures
  def heures
    return self * 3600
  end
  alias :heure :heures

  # Pour faire 5.minutes
  def minutes
    return self * 60
  end
  alias :minute :minutes

end
