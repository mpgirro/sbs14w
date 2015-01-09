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
	- `CREATE` und `DOES>` zb unter [https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/Macros.html#index-compile_002c-_0040var_007b-xt-_002d_002d---_007d--core_002dext-1427](https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/Macros.html#index-compile_002c-_0040var_007b-xt-_002d_002d---_007d--core_002dext-1427)
	- `'` und `[']`
	- `COMP'` und `[COMP']` und `postpone,`
	- [User defined defining words](https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/User_002ddefined-Defining-Words.html#User_002ddefined-Defining-Words)
	- `latestxt`
	- [http://stackoverflow.com/questions/19363904/compile-an-anonymous-word-in-a-compiled-word-in-forth](http://stackoverflow.com/questions/19363904/compile-an-anonymous-word-in-a-compiled-word-in-forth)
