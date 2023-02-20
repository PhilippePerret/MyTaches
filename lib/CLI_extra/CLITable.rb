# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class CLITable
  --------------
  version 1.2

  Construction d'une table en console

  Contrairement à Tableizor qui ne construit des tables qu'à 
  deux colonnes, avec <<< libelle, valeur >>>, cette classe permet
  de construire des affichages à plusieurs colonnes.


  @usage

    # Pour définir la table
    tb = CLITable.new(
      colonnes_totaux: {3 => :euros},
          # On comptera le total de la 3e colonnes et l'on transformera
          # toutes les valeurs en euros (avec la méthode :€)
      header: ["TITRE", "NOMBRE", "REDEVANCE"],
          # Les titres des colonnes
      gutter: 3,
          # Gouttière entre les colonnes
      align:  {right: [3]}
          # La 3e colonne sera alignée à droite (sur le '€' ici)
      flex_column: [2]
          # La colonne à « strecher » en cas de console trop 
          # étroite
    )

    # Pour ajouter une ligne
    tb << [titre, nombre, redevance]

    # Pour l'afficher
    tb.display if tb.any?

=end
class CLITable
  attr_reader :params

  attr_reader :nombre_colonnes

  ##
  # Instanciation
  # 
  # @param  params {Hash}
  # 
  #         Définition générale de la table.
  # 
  #   :colonnes_totaux  {Hash} Table des indices (1-start) des
  #                     colonnes dont il faut faire la somme.
  #                     Avec en clé l'indice réel de la colonne et
  #                     en valeur soit nil pour un nombre normal, 
  #                     soit :euros pour une somme financière.
  #                     Si cette donnée est définie, une nouvelle
  #                     ligne sera ajoutée au bout du tableau avec
  #                     la somme de cette colonne.
  # 
  #   :max_lengths      {Hash} définit les longueurs maximales des
  #                     colonnes voulues. En clé, l'indice 1-start de
  #                     la colonne et en valeur la longueur.
  #                     Par exemple, max_lengths: {2 => 35} indique
  #                     que la 2e colonne ne peut pas faire plus de
  #                     35 caractères de longueur. Toute valeur supé-
  #                     rieure sera tronquée par le milieu.
  #               
  #   :header   {Array} Entête, nom de chaque colonne. On peut 
  #             utiliser les retours de chariot pour faire deux
  #             lignes.
  #   :header_color     {Symbol} Méthode couleur à appliquer à 
  #                     l'entête (:gris par défaut)
  #                     Note : s'appliquera aussi aux délimitations
  # 
  #   :gutter   {Integer} Goutière entre chaque colonne. 2 par défaut
  #   :indent   {Integer} Indentation initiale, en nombre d'espaces
  # 
  #   :align    {Hash}  Définition de l'alignement des colonnes.
  #                     :right => [<index colonnes 1-start>]
  #                     :left  => [<index colonnes 1-start>]
  # 
  #   :separation_char  {String} La caractère pour faire les lignes
  #                     horizontales de séparation. Une étoile par
  #                     défaut.
  # 
  #   :flex_column      {Array||Integer} Indice(s) 1-start de ou des
  #                     colonnes à largeur flexible qui permettent de
  #                     faire tenir le texte dans la console en le
  #                     réduisant si nécessaire.
  # 
  def initialize(params = nil)
    @params = params
    @lines = []
    add_header_lines
  end

  def display
    #
    # On définit l'alignement de chaque colonne
    # 
    define_colonnes_align

    #
    # On fait les totaux des colonnes désignées
    # 
    formate_cells_totaux unless colonnes_totaux.nil?

    # 
    # On mesure les largeurs des colonnes
    # 
    calc_column_widths

    #
    # On ajoute une séparation à la toute fin
    # 
    add(separation)

    # 
    # Boucle sur chaque ligne d'entête
    # 
    @header_lines.each do |cols|
      traite_colonnes(cols, header_color)
    end
    # 
    # Boucle sur chaque ligne de données
    # 
    @lines.each do |cols|
      traite_colonnes cols
    end
    puts "\n\n"
  end

  def traite_colonnes(cols, color = nil)
    line = 
      case cols
      when Array
        cols.collect.with_index do |col, idx|
          # 
          # Traitement de chaque valeur de chaque colone d'une
          # ligne pour la mettre au format de la colonne (au niveau
          # de la largeur et de l'alignement)
          # 
          cell_content = traite_content(col.to_s, idx)
          send(colonne_aligns[idx], cell_content, @column_widths[idx])
        end.join(gutter)
      when :separation  then separation
      when String       then cols
      end
    line = line.send(color) unless color.nil?
    #
    # Écriture de la ligne
    # 
    puts indent + line    
  end

  ##
  # Traitement du contenu de la colonne en fonction de sa flexibilité
  # Si la console est trop petite et que la colonne +col_idx+ est
  # flexible, alors il faut adapter la longueur de +str+ (qui peut
  # être trop long, mais pas obligatoirement)
  # 
  def traite_content(str, col_idx)
    if is_flex_column?(col_idx)
      if str.length > @column_widths[col_idx]
        # 
        # Il faut réduire
        # 
        str.tomax(@column_widths[col_idx])
      else
        str
      end
    else
      str
    end
  end

  def ljust(str, len)
    str.ljust_max(len)
  end
  def rjust(str, len)
    str.rjust_max(len)
  end

  def add(ary)
    @lines << ary
  end
  alias :<< :add

  def any?
    count > 0
  end

  def count
    @lines.count
  end

  # Construction de l'entête.
  # On part toujours du principe qu'il y a deux lignes, et si
  # l'une est vide, on n'en met qu'une seule.
  def add_header_lines
    @header_lines = []
    deux_lignes = false
    line1 = []
    line2 = []
    params[:header].each do |lib|
      lib1, lib2 = 
        if lib.match?("\n")
          deux_lignes = true
          lib.split("\n")
        else
          ['', lib]
      end
      line1 << lib1
      line2 << lib2
    end
    @nombre_colonnes = line2.count
    @header_lines << line1 if deux_lignes
    @header_lines << line2
    @header_lines << :separation
  end

  def table_width
    @table_width ||= @column_widths.sum + (gutter_width * (nombre_colonnes - 1))
  end

  def separation
    @separation ||= begin
      len = (table_width + indent_width) > console_width ? (console_width - indent_width) : table_width
      (separation_char * len).send(header_color)
    end
  end

  def separation_char
    @separation_char ||= params[:separation_char] || '*'
  end

  def gutter
    @gutter ||= ' ' * gutter_width
  end

  def gutter_width
    @gutter_width ||= params[:gutter] || 2
  end

  def indent
    @indent ||= ' ' * (params[:indent] || 2)
  end

  def indent_width
    @indent_width ||= indent.length
  end

  def align
    @align ||= params[:align]
  end

  def colonnes_totaux
    @colonnes_totaux ||= params[:colonnes_totaux]
  end

  # Alignement des colonnes
  def colonne_aligns
    @colonne_aligns
  end

  def header_color
    @header_color ||= params[:header_color] || :gris
  end

  def max_lengths
    @max_lengths ||= params[:max_lengths] || {}
  end

  def flex_column
    @flex_column ||= params[:flex_column]
  end

  private

    def define_colonnes_align
      @colonne_aligns = Array.new(nombre_colonnes, :ljust)
      return if align.nil?
      if align.key?(:right)
        align[:right].each do |idx|
          real_idx = idx - 1
          @colonne_aligns[real_idx] = :rjust
        end
      end
    end

    #
    # Note : requis avant de compter la largeur des colonnes, car
    # les totaux peuvent changer la donne
    # 
    def formate_cells_totaux
      #
      # On fait la ligne de total
      # 
      make_totaux_line
      # 
      # On formate toutes les valeurs. Car elles ont été données
      # en nombre (x) et non pas en euros (€(x)) pour pouvoir calcu-
      # ler les totaux.
      # 
      @lines.each do |cols|
        next unless cols.is_a?(Array)
        colonnes_totaux.each do |idx, type|
          real_idx = idx - 1
          case type
          when :euros then cols[real_idx] = €(cols[real_idx])
          end
        end
      end

    end

    def calc_column_widths
      #
      # Pour collecter les largeurs de colonnes
      # 
      @column_widths = []
      #
      # Les valeurs maximales définies
      # 
      max_lengths.each do |col_id, len|
        @column_widths[col_id - 1] = len
      end
      # 
      # Boucles sur chaque ligne
      # 
      (@header_lines + @lines).each do |cols|
        next unless cols.is_a?(Array) # les lignes spéciales
        cols.each_with_index do |col, idx|
          next if max_lengths.key?(idx + 1)
          len = col.to_s.length
          @column_widths[idx] = len if @column_widths[idx].nil? || len > @column_widths[idx]
        end
      end

      # 
      # Si la table définit des colonnes flexibles, on regarde la
      # largeur.
      # 
      if flex_column
        # 
        # Pour mémoriser les colonnes flexibles
        # En clé : l'index (0-start)
        # En valeur : true 
        # (pour la méthode :is_flex_column?)
        @flex_columns = {}

        if (table_width + indent_width) > console_width
          # 
          # Quand le total des colonnes est plus large que la console
          # et qu'il y a une colonne flexible, on va modifier la
          # largeur de la colonne.
          # 
          diff = (table_width + indent_width) - console_width
          if flex_column.is_a?(Integer)
            @flex_columns.merge!((flex_column - 1) => true)
            @column_widths[flex_column - 1] = @column_widths[flex_column - 1] - diff
          elsif flex_column.is_a?(Array)
            nombre_flex_colonnes = flex_column.count
            sup_per_colonne = diff / nombre_flex_colonnes
            flex_column.each do |indice|
              idx = indice - 1
              @flex_columns.merge!( idx => true )
              @column_widths[idx] = @column_widths[idx] - sup_per_colonne
            end
          else
            raise ":flex_column doit être un indice de colonne (1-start) ou un array."
          end
        end
      end
    end

    def is_flex_column?(idx)
      flex? && @flex_columns[idx] === true
    end

    # @return true s'il y a une colonne flexible. Si c'est le
    # cas, il faut vérifier la taille de la valeur de la colonne
    # traitée 
    def flex?
      :TRUE == @largisflex ||= true_or_false(not(flex_column.nil?))
    end

    def make_totaux_line
      totaux_line = Array.new(nombre_colonnes, '')
      max_index = colonnes_totaux.keys.min
      totaux_line[max_index - 2] = 'TOTAUX' unless max_index == 1
      colonnes_totaux.each do |idx, type|
        totaux_line[idx - 1] = 0
      end
      @lines.each do |cols|
        colonnes_totaux.each do |idx, type|
          real_idx = idx - 1
          totaux_line[real_idx] += cols[real_idx]
        end
      end
      add(:separation)
      add(totaux_line)
    end
end #/class CLITable

=begin
  
  HISTORIQUE DES VERSIONS
  -----------------------

* 1.2
  Possibilité de choisir une colonne à "strecher" en cas de console
  trop étroite.

* 1.1 (non précisée)
  Première version de la classe

=end
