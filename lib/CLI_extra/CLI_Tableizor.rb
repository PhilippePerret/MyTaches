# encoding: UTF-8
=begin

  Tableizor
  ----------
  Version 2.1

  Pour simplifier l'affichage de table à la console.
  Attention, contrairement à CLITable, Tableizor n'affiche
  toujours que deux colonnes, en libellé/valeur.

  @usage pour l'affichage
  =======================

    t = Tableizor.new(<params>)

    t.w "<label>", "<valeur>", <options>
    ...

    t.display # puts 

  @usage pour l'édition
  =====================

      <params> doit définir 
      * :object     L'objet (instance) concerné (pour les
                    méthodes d'édition). L'édition se servira de
                    sa propriété :data qui doit contenir les 
                    valeurs (et doit donc être exposée)
      * :properties Liste {Array} de {:name, :prop} où :name 
                    est le libellé à afficher et :prop les 
                    propriétés dans :values
      # :data_method  La méthode/propriété à appeler pour obtenir
                      les données (éditée) de l'objet. C'est :data
                      par défaut mais ça pourrait être par exemple
                      :mod_data si objet@mod_data est la table dans
                      laquelle sont conservées les valeurs éditées en
                      attente de confirmation et d'enregistrement.
                      Note sur le fonctionnement : en premier, le
                      tableizor essaie d'obtenir dans cette table 
                      spécifiée. Si la valeur est nil, il cherche dans
                      :data
      # :flex       Si true (default = true), on adapte le contenu
                    de la valeur à la largeur de la console (en ajoutant
                    des retours chariot).
      * L'objet (:object) doit répondre aux méthodes :edit_<:prop>
        pour modifier les valeurs. Par exemple, si :edit contient :
          {name:"Modifier le pion", prop: :pion}
        … alors l'instance :object doit obligatoirement répondre à :
          object#edit_pion
        … qui doit retourner la valeur modifiée
      * L'objet peut répondre aux méthodes #f_<prop>(value) qui re-
        tournera une valeur formatée à afficher. Noter que ces métho-
        des doivent impérativement recevoir la valeur en argument 
        pour quand on ne travaille pas directement avec les données
        de l'objet. Car Tableizor transmet la données en édition.


      t.edit # pour mettre la table en édition

  NOTES
  =====
    Il y a des options très pratiques comme la propriété :if qui
    permet de n'écrire la ligne que si la condition est vraie. Ça
    permet de ne pas avoir d'identation dans la définition de la
    table.
    Au lieu de :
    
      t.w "Mon label", "Ma valeur"
      if cest_vrai
        t.w "Autre label", "Autre valeur"
      end

    … on utilisera :

      t.w "Mon label", "Ma valeur"
      t.w "Autre label", "Autre valeur", if:cest_vrai

=end
UNDEFINED = 'NON DÉFINI'

class Tableizor

  class TTYForceFinEdition < StandardError; end

  attr_reader :lines
  attr_reader :config
  #
  # @param  params {Hash|Nil}
  #   :titre        Le titre à donné au tableau
  #   :titre_color  Couleur à appliquer (bleu par défaut)
  #   :separator    le sépateur, en général une espace mais peut être
  #                 aussi un point
  #   :delimitor_size   {Integer} La longueur par défaut d'une
  #                 ligne délimitant les données.
  #                 On peut définir la longueur d'une ligne à la
  #                 volée avec le 2e paramètres : t.w(:delimitor, 20)
  #   :delimitor_char  {String} Caractère utilisé pour le délimiteur
  #                 Par défaut, un signe '='
  #   :gutter       {Integer} La largeur de la gouttière (4 par défaut)
  #   :indentation  {Integer} Nombre d'espace en indentation (2 par
  #                 defaut)
  #   :selectable   {Boolean} Si true, l'instance rajoute des numéros
  #                 à chaque item et permet à la fin d'en choisir
  #                 un :  value = Tableizor#display
  #   :align        Alignement du label et de la valeur
  #                 {label: :left/:right, value: :left/:right}
  #   :flex         Si true (default = true), on adapte le contenu
  #                 de la valeur à la largeur de la console en ajoutant
  #                 des retours chariot
  #   :keep         {Boolean} Si true, on conserve les lignes définies
  #                 même après l'écriture du tableau avec #display
  #                 Sinon (défaut) un #display réinitialise tout.
  # = Pour l'édition =
  #   :object       Instance éditée (doit répondre à #data/@data
  #   :properties   {Array de {:name, :prop}} — cf. ci-dessus
  # 
  def initialize(params = nil)
    defaultize_config(params)
    reset
  end
  def defaultize_config(config)
    @config = config || {}
    @config.key?(:gutter)           || @config.merge!(gutter: 4)
    @config.key?(:indentation)      || @config.merge!(indentation: 2)
    @config.key?(:separator)        || @config.merge!(separator: ' ')
    @config.key?(:delimitor_size)   || @config.merge!(delimitor_size: nil)
    @config.key?(:delimitor_char)   || @config.merge!(delimitor_char: '=')
    @config.key?(:delimitor_color)  || @config.merge!(delimitor_color: nil)
    @config.key?(:titre_color)      || @config.merge!(titre_color: :bleu)
    @config.key?(:align)            || @config.merge!(align:{label: :left, value: :left})
    @config[:align].key?(:label)    || @config[:align].merge!(label: :left)
    @config[:align].key?(:value)    || @config[:align].merge!(value: :left)
    @config.key?(:flex)             || @config.merge!(flex: true)
  end
  
  #
  # Pour écrire dans la table
  # 
  # @param  label {String}
  #     Le label. Certaines valeurs spéciales peuvent être utilisées
  #     comme :delimitor (la longueur sera celle définie en second
  #     argument ou celle définie par défaut)
  # @param  value {Any}
  #     La valeur à afficher à droite du label.
  # @param  params {Hash}
  #     Les paramètres à appliquer. C'est là que la méthode prend
  #     tout son sens.
  #     Les valeurs définies peuvent être :
  #       :color    {Symbol} La méthode de couleur (p.e. :vert)
  #       :if       On n'affiche la ligne que si la valeur est true
  # 
  def w(label, value = nil, params = nil)
    params ||= {}
    return if params.key?(:if) && !params[:if]
    # 
    # Traitement de valeur de +label+ spéciales
    # 
    case label
    when :titre, :title
      value = "\n#{value}\n#{'-'*value.length}"
      add_line [:titre, value, params]
    when :delimitor
      params.merge!(color: delimitor_color) unless params.key?(:color)
      add_line([:delimitor, value, params])
    else
      add_line([label || '', value || '', params])
    end
  end
  alias :<< :w

  def reset
    @label_width = nil
    @lines = [] # pour se servir encore de l'instance
    @indent = nil
    @values = [] # pour selectable
  end

  def add_line(dline)
    #
    # Si c'est une table "sélectionnable", il faut ajouter des
    # index pour choisir la valeur
    # 
    if selectable?
      @values << dline[1].freeze
      dline[0] = "#{@values.count.to_s.rjust(3)}. #{dline[0]}"
    end
    # 
    # Ajout de la ligne
    # 
    @lines << dline
  end

  ##
  # = main =
  # 
  # Méthode pour afficher la table
  # 
  # @param  lines {Array's String} EN mode test, on met dans cette
  #         table Array les lignes à écrire.
  # 
  def display(output_lines = nil)
    if test?
      @output = output_lines || []
    end
    output("\n")
    #
    # Si la table est flexible, il faut calculer la largeur
    # maximale de la colonne des valeurs
    # 
    if config[:flex]
      calc_max_largeur_valeur
    end
    # 
    # Écriture du titre (if any)
    #
    if config[:titre]
      sep = "*" * (config[:titre].length + 2)
      output("#{indent + sep}", config[:titre_color])
      output("#{indent + ' ' + config[:titre]}\n#{indent + sep}", @config[:titre_color])
    end
    output("\n")
    #
    # Écriture des lignes
    # 
    lines.each do |lab, val, params|
      case lab
      when :titre 
        # 
        # Un titre
        # 
        lab, val = [val,'']
      when :delimitor
        # 
        # Une délimitation
        # 
        lab = delimitor_char * delimitor_size(val)
        val = nil
      else
        # 
        # Un label normal
        # 
        meth_align = config[:align][:label] == :left ? :ljust : :rjust
        lab = "#{lab} ".send(meth_align, label_width - 2, config[:separator])
      end
      str = lab + ' ' + formate_value(val, params)
      str = str.send(params[:color]) if params[:color]
      idt = indent(params)
      str = idt + str.split("\n").join("\n#{idt}")
      output(str)
    end
    output("\n\n")
    if selectable?
      wait_for_item_chosen
    end
    reset unless keep_lines?
  
    return @output.join("\n") if test?
  end #/display
  alias :flush :display

  def output(str, couleur = nil)
    if test?
      @output ||= []
      @output << str
    else
      str = str.send(couleur) if couleur
      puts str
    end    
  end

  ##
  # = main =
  #
  # Méthode pour éditer les valeurs
  # 
  def edit
    objet = @config[:object] || begin
      raise "Pour l'édition, l'objet doit être impérativement défini."
    end
    # 
    # Pour capter les CTRL-S pour terminer
    # 
    Q.on(:keypress) do |event|
      # Pour le voir dans le fichier daily.log
      # log("Évènement : #{event.inspect}")
      if event.key.name == :ctrl_s
        raise TTYForceFinEdition.new
      else
        # log("Combinaison jouée : #{event.inspect}")
      end
    end
    
    #
    # Définition des propriétés modifiables
    # 
    properties = config[:properties]
    
    # 
    # le NOM de la table des données 
    # (par exemple :mod_data ou :data)
    # 
    data_method = config[:data_method] || :data

    # 
    # La table des données actuelles
    # 
    table_data = objet.respond_to?(:data) ? objet.send(:data) : {}

    # 
    # Table des données alternative (la première dans laquelle)
    # chercher.
    # 
    table_data_alt = config[:data_method] ? objet.send(@config[:data_method]) : {}


    #
    # === Début de boucle ici ===
    #
    while true
      #
      # La propriété sélectionnée par défaut (indice)
      # 
      default_choice = nil
      # 
      # Liste affichant les propriétés et leur valeur actuelle
      # 
      tty_props = []
      @label_width = 0
      properties.each_with_index do |dprop, idx|
        len = dprop[:name].length + 3
        @label_width = len if len > @label_width
      end.each_with_index do |dprop, idx|
        prop = dprop[:prop]
        format_method = "f_#{prop}".to_sym
        r_value = table_data_alt[prop] || table_data[prop]
        f_value = 
          if objet.respond_to?(format_method)
            objet.send(format_method, r_value)
          elsif r_value.nil?
            nil            
          else
            r_value
          end
        if r_value.nil?
          default_choice = idx + 1 if default_choice.nil?
          f_value = '- à définir -'
          mcolor = :blanc
        else
          mcolor = :vert
        end
        tty_props << {name: "#{dprop[:name].ljust(label_width)} : #{f_value}".send(mcolor), value: dprop[:prop]}  
      end
      tty_props << {name:"Finir (enregistrer)".bleu, value: nil}
      clear
      puts "Création/édition d'une tâche".jaune
      puts "----------------------------".jaune
      begin
        per_page = tty_props.count
        options = {
          default:default_choice, 
          per_page:per_page, show_help:false, filter:true}
        prop = Q.select("(Ctrl-S: Finir & Save, Ctrl-C: Interrupt)".gris, tty_props, **options) || break
      rescue TTYForceFinEdition => e
        break
      rescue TTY::Reader::InputInterrupt => e
        clear
        puts "Opération interropue.\n\n".orange
        return false
      # rescue Exception => e
      #   puts e.message.rouge
      #   (debug? || test?) && puts(e.backtrace.join("\n").rouge)
      end

      begin
        objet.respond_to?("edit_#{prop}".to_sym) || raise("Méthode inconnue : <Tache>#edit_#{prop}")
        objet.send("edit_#{prop}".to_sym)
      rescue TTY::Reader::InputInterrupt => e
        clear
        puts "Opération interrompue.\n\n".orange
        return
      end
      # table_data[prop] = UNDEFINED if table_data[prop].nil?

    end #/while (tant qu'on doit définir les valeurs)
    
    # 
    # On remet à nil les propriétés qui doivent l'être
    #
    table_data.each do |prop, value|
      table_data.merge!(prop => nil) if table_data[prop] == UNDEFINED
    end

    return true
  end
  # /edit

  def keep_lines?
    :TRUE == @mustkeeplines ||= true_or_false(@config[:keep])
  end

  def wait_for_item_chosen
    choix = nil
    nombre_choix = @values.count
    puts "\n"
    while choix.nil?
      STDOUT.write("\rMémoriser : ")
      choix = STDIN.getch.to_i
      if choix > 0 && choix <= nombre_choix
        break
      else
        STDOUT.write "\r                   #{choix} n'est pas compris entre 1 et #{nombre_choix}.".rouge
        choix = nil
      end
    end
    STDOUT.write("\r"+' '*80)
    clip @values[choix.to_i - 1]
    puts "\n\n"    
  end

  def delimitor_color
    @delimitor_color ||= config[:delimitor_color]
  end
  def delimitor_size(value = nil)
    return value unless value.nil?
    @delimitor_size ||= config[:delimitor_size] || (label_width - 1)
  end
  def delimitor_char
    @delimitor_char || config[:delimitor_char]
  end

  def indent(params = {})
    @indent ||= ' ' * config[:indentation]
    case params[:indent]
    when 0        then ''
    when nil      then @indent
    when Integer  then @indent + ' ' * params[:indent]
    when String   then @indent + params[:indent]
    end
  end
  #
  # Formater la valeur en fonction des paramètres (et de la 
  # flexibilité de la colonne des valeurs)
  # 
  def formate_value(val, params)
    return '' if val.nil?
    val = €(val)            if params[:euros]
    val = formate_date(val) if params[:date]
    val = val.to_s
    if val.include?("\n")
      # 
      # Une valeur contenant des retours chariots
      # 
      ind = ' ' * (label_width - 1)
      val = val.split("\n").map do |line|
        split_line_for_flex(line)
      end.join("\n#{ind}")
    elsif flex? && val.length > max_value_width
      # Version simple avec texte raccourci
      # val = val.tomax(max_value_width)
      # Version plus complexe avec l'ajout de retours chariots
      val = split_line_for_flex(val)
    end
    return val
  end

  ##
  # Méthode qui reçoit la valeur [String] +str+ et qui la découpe
  # pour qu'elle ne dépasse pas de la fenêtre.
  # 
  # @return [String] La valeur correcte à afficher
  # 
  def split_line_for_flex(str)
    return str unless (flex? && str.length > max_value_width)
    mots = str.split(' ', -1).reverse # reverse pour poper
    slines  = []
    sline   = mots.pop
    while mot = mots.pop
      if (sline.length + mot.length + 1) < max_value_width
        sline = sline + ' ' + mot
      else
        slines << sline.strip
        sline = mot
      end
    end
    slines << sline unless sline.empty?
    return slines.join("\n" + ' ' * (label_width - 1))
  end

  # 
  # @return true si le contenu de la colonne des valeurs est flexible
  # Il l'est si :
  #   1. la configuration :flex a été choisi
  #   2. Une valeur est supérieure à la largeur max possible
  # 
  def flex?
    :TRUE == @isflexible ||= true_or_false(config[:flex] && has_too_large_value?)
  end

  def has_too_large_value?
    largeur_ligne = label_width + @value_max_width + indent.length
    return largeur_ligne > console_width
  end

  def max_value_width
    @max_value_width ||= begin
      mvw = console_width - (label_width + indent.length)
      mvw += 4 if selectable?
      mvw
    end
  end

  #
  # Calcul de la longueur du label
  # 
  def label_width
    @label_width ||= begin
      maxw = 0; @lines.each do |dline|
        labl = dline[0].length
        maxw = labl if labl > maxw
      end;
      maxw + config[:gutter]
    end
  end

  def selectable?
    :TRUE == @isselectable ||= true_or_false(@config[:selectable] == true)
  end

  def calc_max_largeur_valeur
    maxlen = 0
    lines.each do |lab, val, pms|
      vallen = val.length
      maxlen = vallen if vallen > maxlen
    end  
    @value_max_width = maxlen
  end

end

=begin
  2.1
    Possibilité de définir l'alignement du libellé et de
    la valeur (à droite ou à gauche)
  2.0
    Ajout de l'édition. La table sert à gérer les valeurs
    d'une table à deux dimensions (Tableizor#edit.
  1.0
    Première version officielle
=end
