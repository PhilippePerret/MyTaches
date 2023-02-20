# encoding: UTF-8
module MyTaches
class Tache
class << self

  ##
  # Pour jouer le code 'run' d'une tâche
  # 
  def run_code(tache)
    tache ||= choose('Tâche dont il faut jouer le code') || return
    tache.run_code
  end

end #/<< self


##
# = main =
# 
# Pour jouer le code :run de la tâche
def run_code
  if exec.nil?
    puts "Aucun code n'est à exécuter pour cette tâche.".rouge
  else
    begin
      File.delete('./log_run.txt') if File.exist?('./log_run.txt')
      cmd = exec.dup
      unless exec.match?(' > ')
        cmd = "#{exec} 2>&1"
        cmd = "#{cmd} > ./log_run.txt"
      end
      # ecrit "cmd = #{cmd.inspect}".rouge
      res = `#{cmd}`
      raise if $?.exitstatus != 0
      if File.exist?('./log_run.txt')
        puts File.read('./log_run.txt') 
        File.delete('./log_run.txt')
      end
    rescue Exception => e
      puts "Une erreur est survenue en exécutant le code #{exec.inspect} : #{e.message}".rouge
      debug? && puts(e.backtrace.join("\n").rouge)
    end
  end
end


end #/class Tache
end #/module MyTaches
