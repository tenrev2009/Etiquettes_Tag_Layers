# CSV_TagRenamer.rb
# Loader de l'extension "CSV Tag Renamer".
#
# Exporte l'arborescence des balises (Tags) et dossiers de balises (Tag Folders)
# vers un fichier CSV, permet le renommage en masse dans un tableur externe,
# puis réimporte les nouveaux noms dans SketchUp.
#
# Compatibilité : SketchUp 2021 -> SketchUp 2026 (nécessite les LayerFolder).

require 'sketchup.rb'
require 'extensions.rb'

module Tenrev
  module CSVTagRenamer

    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'CSV Tag Renamer',
        File.join('CSV_TagRenamer', 'main')
      )
      extension.description = 'Exporte les balises et dossiers de balises vers un ' \
                              'fichier CSV, puis réimporte les noms modifiés pour ' \
                              'un renommage en masse.'
      extension.version   = '1.0.0'
      extension.creator   = 'Tenrev'
      extension.copyright = '© 2026 Tenrev'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end

  end # module CSVTagRenamer
end # module Tenrev
