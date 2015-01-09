A project for the course [Stackbasierte Sprachen/2014W](http://www.complang.tuwien.ac.at/anton/lvas/stack.html) ("*stackbased languages*") at TU Wien. 

## Notizen

- transition-word definieren
	+ zu beginn hardgecoded - palindrom erkennen
	+ später dynamisch hardcoden (stackfeature!), sodass das word zur laufzeit definiert wird
	+ terminate state operation definieren
	
- blanksymbol definieren, soll das im program-file stehen?

- Format für input file(s) 
	- program file
		+ 1.Zeile: startzustand
		+ 2.Zeile: liste der endzustände
		+ 3.-n.Zeile: transitions der zustände (curr-state, tape-sym, write-sym, next-state, ptr-move)
	- tape input file
	
- tape-ptr in der mitte beginnen lassen


Vortschritt:

- Möglichkeiten die funktionieren könnten: Schreibe das "normale" Transition word wie wir es momentan haben, aber anstatt die States hard zu coden schreiben wir das word hol-mir-den-nächsten-state-aus-dem-file word. Problem: Jedes mal wenn wir das transition word aufrufen wird das Programm file gelesen --> kein Stack feature!
- Problem: Wie bekommen wir die Werte des Programm files ins transition word ohne das wir das program file beim aufruf von transition lesen? Wir müssen dafür sorgen, das transition "erstellt" wird, und am Ende seiner Definition compiled wird.
- Wörter/Methoden die eventuell das richtige sein können: 
	- `compile,`
	- `[` und `]`
	- `CREATE` und `DOES>` zb unter [https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/Macros.html#index-compile_002c-_0040var_007b-xt-_002d_002d---_007d--core_002dext-1427](https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/Macros.html#index-compile_002c-_0040var_007b-xt-_002d_002d---_007d--core_002dext-1427):
		+ Create ist der Header indem der Name des neuen Words definiert wird. Weiters kann man hier auch gleich weiteren Speicher allocieren, sollte man dieses benötigen. Dieser Code wird nur einmal ausgeführt, bei der erstellung des neuen words. Allerdings wird er jedens Mal ausgeführt wenn man das umfassende word ausführt (um damit eine neues word zu erstellen). Der DOES-Teil beinhaltet den Code für das neue Word, dieser wird erst ausgeführt, wenn dieses neue Word ausgeführt wird. Dabei wird zu beginn die adresse des neuen Words-Name auf den Stack gepushed. Mit dieser kann man den allocierten Speicher ansprechen. Für unsere Forth-Machine könnte das folgendermaßen funktionieren: Wird benennen im Create-Teil unsere neues Word, dass wir natürlich dann "Transition" nennen und lesen dort auch gleich das progam file und speichern es Symbol für Symbol in den Speicher des neuen Word. Im Does-Teil schreiben wir dann den Code des Transition-Words und holen und dabei die einzelnen Symbole des Programs mit einer einfachen @ Anweisung. (Den Speicher schrittweise hinaufzuzählen dürfen wir natürlich auch nicht vergessen.) 
		+ vll nützlich ist `>body`: Get the address of the body of the word represented by xt (the address of the word's data field).
	- `'` und `[']`
	- `COMP'` und `[COMP']` und `postpone,`
	- [User defined defining words](https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/User_002ddefined-Defining-Words.html#User_002ddefined-Defining-Words)
	- `latestxt`
	- [http://stackoverflow.com/questions/19363904/compile-an-anonymous-word-in-a-compiled-word-in-forth](http://stackoverflow.com/questions/19363904/compile-an-anonymous-word-in-a-compiled-word-in-forth)
