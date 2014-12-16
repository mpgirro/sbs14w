A project for the course [Stackbasierte Sprachen/2014W](http://www.complang.tuwien.ac.at/anton/lvas/stack.html) ("*stackbased languages*") at TU Wien. 

## Notizen

**Vorarbeit**:

- tape einlesen
  + file lesen
  + fileinhalt in speicher schreiben
  + globale variable `tape-ptr` für speicheradresse benutzen

- transition-word definieren
	+ zu beginn hardgecoded - palindrom erkennen
	+ später dynamisch hardcoden (stackfeature!), sodass das word zur laufzeit definiert wird
	+ terminate state operation definieren

- stackeffekt für schleife für das tape/den ablauf überlegen
	+ pro schleifendurchgang wird benötigt: curr-state (aktueller Zustand) und tape-sym (aktuelles Zeichen im tape)
	+ rückgabe: neuen zustand
	+ falls move-left durchgeführt wird, dann noch innerhalb der schleife

- Format für input file(s) 
	- program file
	- tape input file
	
**Hauptarbeit**:

- Schleife laufen lassen (schleifenbedingung überlegen)
	
