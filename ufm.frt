\ 
\ Universal Turing Machine 
\ programed in Forth
\ 

256 Constant tape-length
8 Constant line-length

\ u3: neuer state, u4: pointer offset für tape
\ { cur-state tape-sym tape-ptr }
: transition ( u1 u2 u5 -- u3 u4 ) 
	 over 0 = if
	 	dup 1 = if
	 		2drop \ clean up stack - we write new {cur-state,type-sym} now
	 		1 write-tape \ => write 1 to tape
	 		0 \ next-state to go to
	 		tape-ptr ptr-move-right
	 		1 \ => loop once again!
	 		endif
	 	dup 2 = if
	 		2drop 
	 		1 write-tape
	 		\ ptr-move-stay
	 		1
	 		endif
	 	endif
	 over 1 = if \ => terminal state
	 	0 \ do not loop again
	 	endif
	;
	 
\ u1: tape offset, u2: neuer tape offset (incementiert)
: ptr-move-right ( u1 -- u2 )	
	1 +
	;

\ u1: tape offset, u2: neuer tape offset (dekrementiert)
: ptr-move-left ( u1 -- u2 )
	1 -
	;

\ u1: aktueller tape offset, u2: geholter wert auf dem tape
: tape-fetch ( u1 -- u2 )
	tape-addr swap cells + @
	;
	 
	 
: ufm ( program-path-str input-path-str -- [output-stack] )

	\ TODO: tape lesen und in den speicher schreiben, constant global variable defined
	s" input1.tape" init-tape 

	\ TODO: transition dynamisch hardcoden
	\ TODO: prepare stack for execution loop
	\ words, die wir brauchen könnten: edit-line

	1 begin	 
		0> while 
			tape-fetch \ => read tape-sym at curr-state position
			transition \ => do the transition dance
		repeat
	tape-to-stack
	;
	

\ liest die Anzahl der Zeilen indem der input 
\ Zeile für Zeile eingelesen wird und ein counter mitläuft
\ darauf folgt: die größte des benötigten Initialspeichers
\ weiters reserviert es den Speicher und schreibt dem Inhalt
\ des tape-files in den Speicher
\ erzeugt Platzhalter Variable "tape-ptr"
\ Übergabeparameter: str - Pfad zum tape-file .tape
\ TODO: Überprüfüng wegen büffer överflöw
: init-tape ( c-addr u -- ) { tape-input-path path-char-count }
	create tape-addr tape-length cells allot
	create line-buffer line-length allot
	tape-input-path path-char-count r/w open-file throw Value fd-in
	2 tape-addr !
	try
	1 1 begin
		line-buffer line-length fd-in read-line throw
	  	while
			line-buffer s>number? 2drop
			tape-addr rot cells + !
			1 + dup
			\ iferror
			\ 	leave 
			\ then
	  	repeat
	  	iferror then
	 endtry
	 drop 2 swap tape-addr swap cells + ! \ counter wird durch drop zu beginn verworfen
	;
