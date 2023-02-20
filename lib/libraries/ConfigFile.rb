# encoding: UTF-8
# frozen_string_literal: true
=begin
  Produit MyTaches::CONFIGURATION qui contient la configuration
  de l'application, définie dans le fichier config.yaml à la 
  racine.
=end
require 'yaml'

module MyTaches
class ConfigFile

  ##
  # @return la préférence de clé +key+ ou la valeur
  # par défaut +default+
  def get(key, default = nil)
    data[key] || default
  end
  def save
    File.open(path,'wb') { |f| f.write data.to_yaml }
  end
  def data
    @data ||= begin
      if File.exist?(path)
        YAML.load_file(path) || {}
      else
        {}
      end
    end
  end
  def path
    @path ||= File.join(APP_FOLDER,'config.yaml')
  end
end #/class ConfigFile

CONFIGURATION = ConfigFile.new
end #/module MyTaches
