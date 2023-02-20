# encoding: UTF-8
=begin
  
  Requis
  ------
    APP_FOLDER      Constante du chemin d'accès à l'application
    Time.rb         librairie pratique de la gestion du temps

=end
class Cron
class << self
  
  ##
  # = main =
  # 
  # Pour écrire dans le log du cron
  def log(str)
    # ecrit("Écrire dans le cron : #{str.inspect}")
    @fref ||= begin
      File.delete(path) if File.exist?(path)
      File.open(path,'a')
    end
    @fref.puts "#{Time.now.jj_mm_aaaa_hh_mm_ss} #{str}"
    close if test?
  end

  def close
    @fref.close
    @fref = nil
  end
  
  def path
    @path ||= File.join(APP_FOLDER,'cron.log')
  end
end #/<< self
end #/class Cron
