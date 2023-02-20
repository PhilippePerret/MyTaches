# encoding: UTF-8
# frozen_string_literal: true
require 'clir'
require 'yaml'
require 'fileutils'

class ExitWithoutError < StandardError; end

#
# Surclassement de la méthode puts pour récupération par les tests
# du texte écrit
# 
def puts(str, forcer_puts = false)
  if test? && not(forcer_puts)
    MyTaches.add_out_lines(str)
  else
    super(str)
  end
end


require_relative 'MyTaches'
require_relative 'libraries/ConfigFile'
require_relative 'libraries/utils'
Dir["#{__dir__}/MiniClasses/**/*.rb"].each{|m|require(m)}
require_relative 'constants'
Dir["#{__dir__}/CLI_extra/*.rb"].each { |m| require m }
Dir["#{__dir__}/libraries/*.rb"].each { |m| require m }
require_relative 'Tache_class'
require_relative 'ArchivedTache'
