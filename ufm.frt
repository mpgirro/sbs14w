\ 
\ Universal Turing Machine 
\ programed in Forth
\ 


256 Constant tape-length 
8 Constant line-length 
Create tape-addr tape-length cells allot
Create line-buffer line-length allot
0 Value fd-in
0 Value tape-ptr

: open-input ( addr u -- )  r/o open-file throw to fd-in ;

\ liest die Anzahl der Zeilen indem der input 
\ Zeile für Zeile eingelesen wird und ein counter mitläuft
\ darauf folgt: die größte des benötigten Initialspeichers
\ weiters reserviert es den Speicher und schreibt dem Inhalt
\ des tape-files in den Speicher
\ erzeugt Platzhalter Variable "tape-ptr"
\ Übergabeparameter: str - Pfad zum tape-file .tape
\ TODO: Überprüfüng wegen büffer överflöw
: init-tape ( addr u -- u ) \ { tape-input-path path-char-count } \ rückgabe: counter
	\ tape-input-path path-char-count r/w open-file throw Value fd-in
	\ Create tape-addr tape-length cells allot
	open-input
	2 tape-addr !
	
	1 1 begin
		line-buffer line-length fd-in read-line throw
	  	while
	  		line-buffer swap s>number? cr .s cr 2drop
			tape-addr rot cells + !
			1 + dup
	  	repeat
		drop
	 2 swap tape-addr swap cells + ! 
	 1 - .s cr \ counter wird durch drop zu beginn verworfen
	;
	
\ u1: tape offset, u2: neuer tape offset (incementiert)
: ptr-move-right ( -- )	
	tape-ptr 1 + to tape-ptr
	;

\ u1: tape offset, u2: neuer tape offset (dekrementiert)
: ptr-move-left (  --  )
	tape-ptr 1 - to tape-ptr
	;

\ u1: aktueller tape offset, u2: geholter wert auf dem tape
: tape-fetch ( u1 -- u2 )
	tape-addr swap cells + @
	;
 
: write-tape ( u -- )
	tape-addr tape-ptr cells + ! ;

\ u3: neuer state, u4: pointer offset für tape
\ { cur-state tape-sym tape-ptr }
: transition ( u1 u2 u5 -- u3 u4 ) 
	 over 0 = if
	 	dup 1 = if
	 		2drop \ clean up stack - we write new {cur-state,type-sym} now
	 		1 write-tape \ => write 1 to tape
	 		0 \ next-state to go to
	 		 ptr-move-right 
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
	\ tape-to-stack ------ zurzeit auskommentiert
	;
	
