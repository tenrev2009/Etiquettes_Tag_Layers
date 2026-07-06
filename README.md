# CSV Tag Renamer

Extension SketchUp pour le renommage en masse des **balises** (Tags) et des
**dossiers de balises** (Tag Folders) via un fichier CSV.

**Compatibilité :** SketchUp 2021 → SketchUp 2026 (nécessite la prise en
charge des `LayerFolder`).

## Fonctionnement

1. **Exporter** — Le plugin écrit l'arborescence complète des dossiers et
   balises dans un fichier CSV (séparateur `;`, UTF-8 avec BOM, compatible
   Excel européen) :

   | Type   | Nom Actuel     | Nouveau Nom |
   |--------|----------------|-------------|
   | Folder | Dossier Racine |             |
   | Tag    | Murs           |             |

2. **Modifier** — Ouvrez le CSV dans un tableur et remplissez **uniquement
   la colonne *Nouveau Nom*** pour les éléments à renommer (laissez vide
   pour conserver le nom actuel), puis sauvegardez.

   > ⚠️ Ne modifiez jamais la colonne *Nom Actuel* : c'est elle qui permet
   > au plugin de retrouver chaque élément dans le modèle. Ne supprimez et
   > n'ajoutez aucune ligne.

   L'import accepte les fichiers réenregistrés par Excel aussi bien en
   UTF-8 qu'en ANSI (Windows-1252), le format par défaut d'Excel pour
   « CSV (séparateur : point-virgule) ».

3. **Importer** — Le plugin relit le fichier et applique les nouveaux noms.
   La structure des dossiers et les assignations géométriques sont
   intégralement préservées : seul le nom change.

## Installation

1. Copiez `CSV_TagRenamer.rb` et le dossier `CSV_TagRenamer/` dans le
   répertoire `Plugins` de SketchUp :
   - **Windows :** `C:\Users\<vous>\AppData\Roaming\SketchUp\SketchUp 20xx\SketchUp\Plugins`
   - **macOS :** `~/Library/Application Support/SketchUp 20xx/SketchUp/Plugins`
2. Redémarrez SketchUp.
3. Lancez via **Extensions > CSV Tag Renamer** ou l'icône de la barre
   d'outils *Tag Renamer*.

## Sécurités intégrées

- **Annulation propre** : l'import complet est encapsulé dans une seule
  opération (`model.start_operation`) — un seul *Ctrl+Z* annule tout.
- **Contrôle de quantité** : si des lignes ont été ajoutées ou supprimées
  dans le tableur, l'import est refusé.
- **Doublons** : les noms refusés par SketchUp (doublon au même niveau)
  sont ignorés et listés dans le rapport d'erreurs.
- **Balise par défaut** : « Untagged » (*Layer0*) est exclue de l'export
  et jamais renommée.
- **Nettoyage** : les espaces en début/fin des nouveaux noms sont
  supprimés automatiquement.
- **Annulation utilisateur** : fermer une boîte de dialogue de fichier
  interrompt l'action silencieusement.
- **Encodage** : détection automatique UTF-8 (avec ou sans BOM) ou ANSI
  (Windows-1252) à l'import — compatible avec un fichier réenregistré
  par Excel sans option particulière.

## Structure du dépôt

```
CSV_TagRenamer.rb          # Loader (enregistrement de l'extension)
CSV_TagRenamer/
  main.rb                  # Logique export/import + UI
  html/dialog.html         # Fenêtre HtmlDialog (HTML/CSS/JS)
  icons/                   # Icônes de la barre d'outils (24 px / 32 px)
```
