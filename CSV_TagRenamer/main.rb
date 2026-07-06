# CSV_TagRenamer/main.rb
# Logique principale de l'extension "CSV Tag Renamer".
#
# - Export de l'arborescence des balises (Tags) et dossiers (Tag Folders) en CSV.
# - Import du CSV modifié et application des nouveaux noms dans une seule
#   opération annulable (Edit > Undo).

require 'sketchup.rb'
require 'csv'

module Tenrev
  module CSVTagRenamer

    PLUGIN_NAME = 'CSV Tag Renamer'.freeze
    PLUGIN_DIR  = File.dirname(__FILE__).freeze

    CSV_SEPARATOR = ';'.freeze
    CSV_HEADER    = ['Type', 'Nom Actuel', 'Nouveau Nom'].freeze

    # La prise en charge des dossiers de balises (Sketchup::LayerFolder)
    # est apparue avec SketchUp 2021.
    MINIMUM_SU_VERSION = 21

    class << self

      # ----------------------------------------------------------------------
      # Parcours du modèle
      # ----------------------------------------------------------------------

      # Balise par défaut ("Untagged" / "Layer0") : exclue de l'export et de
      # tout renommage (comportement natif restrictif de SketchUp).
      def default_tag(model)
        model.layers[0]
      end

      # Tous les dossiers de balises du modèle, récursivement
      # (dossiers racine puis sous-dossiers, en profondeur).
      def all_folders(model)
        result = []
        walker = lambda do |parent|
          parent.folders.each do |folder|
            result << folder
            walker.call(folder)
          end
        end
        walker.call(model.layers)
        result
      end

      # Toutes les balises du modèle, sauf la balise par défaut.
      def exportable_tags(model)
        default = default_tag(model)
        model.layers.to_a.reject { |layer| layer == default }
      end

      # ----------------------------------------------------------------------
      # Export CSV
      # ----------------------------------------------------------------------

      def export_csv(dialog)
        model = Sketchup.active_model
        path = UI.savepanel('Exporter la structure des balises',
                            '', 'balises_export.csv')
        return if path.nil? # Annulation utilisateur : sortie silencieuse.

        path += '.csv' unless path.downcase.end_with?('.csv')

        folders = all_folders(model)
        tags    = exportable_tags(model)

        File.open(path, 'w:UTF-8') do |file|
          # BOM UTF-8 écrit explicitement pour qu'Excel (versions
          # européennes) détecte l'encodage — le mode 'bom|utf-8' de Ruby
          # ne l'écrit pas en sortie.
          file.write("\uFEFF")
          csv = CSV.new(file, col_sep: CSV_SEPARATOR)
          csv << CSV_HEADER
          # nil (et non '') pour laisser la colonne vraiment vide dans le
          # fichier, sans guillemets parasites pour le tableur.
          folders.each { |folder| csv << ['Folder', folder.name, nil] }
          tags.each    { |tag|    csv << ['Tag',    tag.name,    nil] }
        end

        log(dialog,
            "Export réussi : #{folders.length} dossiers et " \
            "#{tags.length} balises exportés.",
            :success)
      rescue StandardError => e
        log(dialog, "Erreur lors de l'export : #{e.message}", :error)
      end

      # ----------------------------------------------------------------------
      # Import CSV
      # ----------------------------------------------------------------------

      def import_csv(dialog)
        model = Sketchup.active_model
        path = UI.openpanel('Importer les modifications',
                            '', 'Fichiers CSV|*.csv||')
        return if path.nil? # Annulation utilisateur : sortie silencieuse.

        rows = read_csv_rows(path)
        rows.shift if header_row?(rows.first)

        folders = all_folders(model)
        tags    = exportable_tags(model)

        # Sécurité des quantités : le CSV doit décrire exactement la
        # structure actuelle du modèle (aucune ligne ajoutée ou supprimée).
        expected = folders.length + tags.length
        if rows.length != expected
          log(dialog,
              "Le nombre d'éléments dans le CSV (#{rows.length}) ne " \
              "correspond pas à la structure actuelle du modèle " \
              "(#{expected}).",
              :error)
          return
        end

        mapping = build_mapping(rows)

        renamed = 0
        errors  = []

        model.start_operation('Import Tags from CSV', true)
        begin
          renamed += rename_entities(folders, mapping[:folder], 'Dossier', errors)
          renamed += rename_entities(tags,    mapping[:tag],    'Balise',  errors)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end

        log(dialog, "Import réussi : #{renamed} balises/dossiers renommés.",
            :success)
        errors.each { |message| log(dialog, message, :error) }
      rescue StandardError => e
        log(dialog, "Erreur lors de l'import : #{e.message}", :error)
      end

      # Lit le CSV en UTF-8 (avec ou sans BOM) et ignore les lignes vides.
      # liberal_parsing tolère les guillemets irréguliers produits par
      # certains tableurs lors de l'édition manuelle.
      def read_csv_rows(path)
        rows = CSV.read(path, col_sep: CSV_SEPARATOR, encoding: 'bom|utf-8',
                              liberal_parsing: true)
        rows.reject { |row| row.nil? || row.compact.map(&:to_s).all?(&:empty?) }
      end

      def header_row?(row)
        return false if row.nil?
        first = row[0].to_s.strip.downcase
        first == 'type'
      end

      # Tableau de hachage { Nom Actuel => Nouveau Nom }, séparé par type
      # pour éviter toute collision entre un dossier et une balise homonymes.
      def build_mapping(rows)
        mapping = { folder: {}, tag: {} }
        rows.each do |row|
          type     = row[0].to_s.strip.downcase
          old_name = row[1].to_s
          # Nettoyage automatique des espaces en début/fin de chaîne.
          new_name = row[2].to_s.strip
          next if new_name.empty?

          key = (type == 'folder') ? :folder : :tag
          mapping[key][old_name] = new_name
        end
        mapping
      end

      # Applique les nouveaux noms. Les doublons refusés par SketchUp sont
      # capturés, ignorés et ajoutés au rapport d'erreurs.
      def rename_entities(entities, name_map, label, errors)
        renamed = 0
        entities.each do |entity|
          current  = entity.name
          new_name = name_map[current]
          next if new_name.nil? || new_name.empty? || new_name == current

          begin
            entity.name = new_name
            renamed += 1
          rescue StandardError => e
            errors << "#{label} « #{current} » → « #{new_name} » ignoré " \
                      "(doublon ou nom invalide) : #{e.message}"
          end
        end
        renamed
      end

      # ----------------------------------------------------------------------
      # Interface (HtmlDialog)
      # ----------------------------------------------------------------------

      def show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title:    PLUGIN_NAME,
          preferences_key: 'Tenrev_CSVTagRenamer',
          resizable:       true,
          width:           440,
          height:          380,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(File.join(PLUGIN_DIR, 'html', 'dialog.html'))

        @dialog.add_action_callback('export_csv') { |_ctx| export_csv(@dialog) }
        @dialog.add_action_callback('import_csv') { |_ctx| import_csv(@dialog) }

        @dialog.center
        @dialog.show
      end

      # Pousse un message vers la <div id="console"> de la HtmlDialog.
      def log(dialog, message, kind = :info)
        return unless dialog && dialog.visible?
        # String#inspect produit une chaîne entre guillemets doubles avec les
        # échappements nécessaires, valide comme littéral JavaScript.
        dialog.execute_script("appendConsole(#{message.to_s.inspect}, '#{kind}');")
      end

      def supported_version?
        Sketchup.version.to_i >= MINIMUM_SU_VERSION
      end

      # ----------------------------------------------------------------------
      # Menu et barre d'outils
      # ----------------------------------------------------------------------

      def create_ui
        command = UI::Command.new(PLUGIN_NAME) { launch }
        command.tooltip = PLUGIN_NAME
        command.status_bar_text =
          'Exporter/Importer les balises et dossiers de balises via CSV.'
        command.small_icon = File.join(PLUGIN_DIR, 'icons', 'tag_renamer_24.png')
        command.large_icon = File.join(PLUGIN_DIR, 'icons', 'tag_renamer_32.png')

        UI.menu('Extensions').add_item(command)

        toolbar = UI::Toolbar.new('Tag Renamer')
        toolbar.add_item(command)
        toolbar.restore
      end

      def launch
        unless supported_version?
          UI.messagebox(
            "#{PLUGIN_NAME} nécessite SketchUp 2021 ou plus récent " \
            '(prise en charge des dossiers de balises).'
          )
          return
        end
        show_dialog
      end

    end # class << self

    unless file_loaded?(__FILE__)
      create_ui
      file_loaded(__FILE__)
    end

  end # module CSVTagRenamer
end # module Tenrev
