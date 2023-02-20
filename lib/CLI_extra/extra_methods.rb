require 'terminal-notifier'

#
# @param  params {Hash}
#         :title      Le titre
#         :subtitle   Le sous-titre
#         :open       Le fichier/url/dossier à ouvrir
#         :execute    Le code à exécuter
#         :activate   Pour activer une application par son identifiant (p.e. com.apple.safari)
#         :appIcon    L'icone (ça ne fonctionne pas)
#
def notify(msg, params = nil)
  params ||= {}
  begin
    Cron.log("Notification de #{msg.inspect} avec les params: #{params.inspect}")
  rescue
  end
  TerminalNotifier.notify(msg, params)
end

##
# Retourne true si la ligne de commande contient exactement +str+
#
def cli?(str)
  case str
  when Regexp
    ARGV.each do |arg|
      if arg.match?(str)
        return arg.match(str).to_a[1]
      end
    end
    return false
  when String
    ARGV.include?(str)
  when Array
    str.each do |opt|
      return true if ARGV.include?(opt)
    end
    return false
  end
end

def cron?
  CONFIG.cron?
end


def ask_or_null(question, params = nil)
  params ||= {}
  response = Q.ask(question.jaune, params)
  response = nil if response && response.upcase == 'NULL'
  return response
end
