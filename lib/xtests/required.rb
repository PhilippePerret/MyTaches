# encoding: UTF-8
require 'test/unit'

# Qui définit :ecrit
require_relative '../CLI/CLI_utilities'

# Pour écrit à la console pendant les tests (car la méthode puts
# est surclassée pour récupérer le texte écrit par le programme)
def ecrit(str)
  STDOUT.puts(str)
end

require_relative 'utils'
require_relative 'utils_parallels'

module MyTaches
  def self.output
    if out_lines
      return out_lines.join("\n")
    else
      ''
    end
  end
end

def texte_console(reset = false)
  str = MyTaches.output
  reset && reset_console
  return str
end
# Efface le texte en console (pour les tests 
# successive)
def reset_console
  MyTaches.reset_out_lines
end

# Les librairies de l'application
# 
# Cet appel doit être placé, après les appels à utils des
# tests qui redéfinirait des méthodes utiles, sinon.
require_relative '../required'
require_relative '../Tache_Model' # charge les autres

MyTaches::Tache.reset
DEMAIN = Time.now.plus(1).jour.adjust(sec:0).freeze
# ecrit "DEMAIN = #{DEMAIN}".bleu
DEMAIN_MATIN = DEMAIN.at('0:00').freeze

APP_FOLDER = MyTaches::APP_FOLDER
