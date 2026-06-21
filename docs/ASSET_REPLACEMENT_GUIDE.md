# Eigene Grafiken und Sounds einsetzen

Das Spiel benutzt derzeit einfache, selbst erstellte Platzhalter. Du kannst sie später ersetzen, ohne den Programmcode zu verändern.

## 1. Eine passende Datei finden

Gute kostenlose Quellen sind:

- [Kenney](https://kenney.nl/assets) – sehr viele CC0-Grafiken und Sounds
- [OpenGameArt](https://opengameart.org/) – Lizenz bei jedem Download einzeln prüfen
- [itch.io Game Assets](https://itch.io/game-assets/free) – nach „free“ und erlaubter kommerzieller Nutzung filtern
- [Freesound](https://freesound.org/) – Lizenz des einzelnen Sounds prüfen

Suchbeispiele: `survivor portrait CC0`, `abandoned city background`, `rifle inventory icon`, `dark ambient loop`.

## 2. Richtige Größe und Format

- Szenenhintergrund: 1920 × 1080, PNG oder JPG
- Weltkarte: 2400 × 1350, PNG oder JPG
- Charakter: 512 × 512, transparentes PNG
- Portrait: 400 × 400, transparentes PNG
- Inventar-Icon: 128 × 128, transparentes PNG
- Status-Icon: 64 × 64, transparentes PNG
- Musik: loopfähige OGG-Datei
- Soundeffekt: WAV oder OGG, möglichst unter drei Sekunden

## 3. Datei austauschen

1. Öffne den gewünschten Unterordner unter `assets`.
2. Lies dort die `README.txt`.
3. Benenne die neue Datei exakt wie den vorhandenen Platzhalter.
4. Überschreibe die alte Datei.
5. Öffne Godot. Der Import geschieht automatisch.

Wenn Pfad und Dateiname gleich bleiben, ist keine Codeänderung nötig.

## 4. Einen neuen Gegenstand ergänzen

Beispiel: eine neue Waffe.

1. Lege ihr Icon unter `assets/items/weapons/ranged/` ab.
2. Öffne `data/items/weapons_ranged.tres`.
3. Kopiere einen vorhandenen Eintrag wie `old_revolver`.
4. Vergib eine eindeutige ID in Kleinbuchstaben, zum Beispiel `rifle_old_hunting`.
5. Ändere Name, Gewicht, Schaden und Munition.

Die übrigen Balancing-Dateien unter `data` funktionieren nach demselben Muster.

## Lizenzhinweis

Keine Dateien aus Darkest Dungeon, DayZ, 7 Days to Die, Supernatural oder anderen geschützten Werken übernehmen. Diese Titel sind nur Stimmungsvorbilder.

