#!/usr/bin/env ruby
# encoding: UTF-8


begin
  require_relative 'lib/required'
  MyTaches.run
rescue ExitWithoutError => e
  # Sortie forcée normale
  puts "\n\n"
rescue Exception => e
  # On essaie de notifier l'erreur
  # Sauf si on est en mode test
  if test?
    raise e
  else
    begin
      notify("Une erreur est survenue dans MyTaches. Consulter les journaux de bord. Jouer 'task open -dev' pour ouvrir le dossier.", sender: 'phil.app.MyTaches')
    rescue Exception => e
    end
  end
  if self.respond_to?(:log_error)
    log_error(e)
  else
    puts e.message
  end
  puts e.backtrace.join("\n")
  exit 1
end

exit 0 # OK
