# MiniReminders

WoW Forever (Interface 16001), Version 0.3.0.

Erinnert Schamanen an eine fehlende Waffenverzauberung und ein fehlendes Schild.
Eine beliebige aktive Waffenverzauberung auf einer der beiden Waffen genügt.
Schamanen-Waffenbuffs werden auch als aktive Spieler-Auren erkannt.
Dabei zählen alle Ränge; beispielsweise wird „Rockbiter 2“ als Rockbiter erkannt.
Zusätzlich werden beide Waffentooltips auf Waffenbuffs geprüft, auch direkt nach
dem Einloggen oder einem Reload mit bereits aktivem Buff.
Blitzschlagschild, Wasserschild und Erdschild auf dem Spieler gelten als Alternativen.
Nur erlernte Zauber werden vorgeschlagen; andere Klassen erhalten noch keine Hinweise.
Ohne ausgerüstete Waffe entfällt der Waffenhinweis, im Tod entfallen alle Hinweise.

Die Symbole sind 36 × 36 Pixel groß, leuchten golden und stehen mit 8 Pixel Abstand
zentriert um die gespeicherte Position. Ein Linksklick wirkt den angezeigten Buff
auf den Spieler. Im Kampf bleiben Anzeige und Zauberzuordnung bestehen; die
Hinweise werden nach Kampfende aktualisiert. Verschieben ist außerhalb des Kampfes möglich.

- `/minireminders unlock`: Ein Beispiel-Symbol ersetzt die Hinweise. Mit gedrückter
  linker Maustaste ziehen, um die Position zu ändern.
- `/minireminders lock`: Fixiert die Position und ersetzt das Beispiel durch die
  tatsächlich fehlenden Buffs.
- `/minireminders except "Lightning Shield"`: Deaktiviert den Hinweis für diesen
  Buff. Alle Ränge zählen zusammen; Groß-/Kleinschreibung wird ignoriert.
- `/minireminders allow "Lightning Shield"`: Aktiviert den Hinweis wieder.

Ausnahmen gelten für den jeweils vorgeschlagenen Buff und werden pro Charakter
gespeichert. Im Kampf wird die Anzeige nach Kampfende angepasst. Das Beispiel-Symbol
im Verschiebemodus bleibt unabhängig von Ausnahmen sichtbar.

Die Position wird pro Charakter gespeichert. Nach dem Anlegen des AddOns das Spiel
neu starten, falls es in der AddOn-Liste noch nicht erscheint.
