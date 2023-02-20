# encoding: UTF-8
# frozen_string_literal: true
module MyTaches
class ArchivedTache < Tache

  def self.folder
    @folder ||= Tache.folder_archives
  end

  def self.get(id)
    @@table ||= {}
    @@table[id] ||= begin
      pth = File.join(folder,"#{id}.yaml")
      new(YAML.load_file(pth)) if File.exist?(pth)
    end
  end

  def self.all(params = nil)
    @@all ||= begin
      Dir["#{folder}/*.yaml"].map do |pth|
        new(YAML.load_file(pth))
      end
    end
  end


  def done_at
    @done_at ||= data[:done_at]
  end
  
  def path
    @path ||= File.join(self.class.folder,"#{id}.yaml")
  end

end #/class ArchivedTache
end #/module MyTaches
