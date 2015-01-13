#! /usr/bin/env gforth

\ 
\ Universal Turing Machine in Forth 
\ 

10 Constant tape-length
8 Constant tape-line-length
1 Constant loop-flag-continue
0 Constant loop-flag-stop
Create tape-addr tape-length cells allot
Create tape-line-buffer tape-line-length allot
0 Value tape-fd-in
0 Value tape-fd-out
0 Value machine-fd-in
1 Value tape-ptr
0 Value start-state
0 Value machine-line-cursor \ hold current line for the machine file parsing 
0 Value token-cur-state 
0 Value token-sym-read
0 Value token-sym-write
0 Value token-next-state
0 Value token-tape-ptr-move
0 Value is-terminal-state

32 Constant machine-line-length
Create machine-line-buffer machine-line-length chars allot


: open-tape-input ( addr u -- )  r/o open-file throw to tape-fd-in ;
: open-output ( addr u -- )  w/o create-file throw to tape-fd-out ;

: read-next-machine-line ( -- string-len flag )
	machine-line-buffer machine-line-length machine-fd-in read-line throw
;


: open-machine-input ( addr u -- )  
	r/o open-file throw to machine-fd-in \ create the file decriptor for the file
	read-next-machine-line \ read the first line of machine file (= start state)
	machine-line-buffer swap s>number? 2drop to start-state \ set the start state 
	read-next-machine-line
	;


\ read machine-file path
next-arg 2dup 0 0 d<> if 
	cr ." no path to machine input file provided"
	bye
else
	open-machine-input
endif

\ read tape-file path
next-arg 2dup 0 0 d<> if 
	cr ." no path to tape input file provided"
	bye
else
	open-tape-input
endif

 

\ .s word will dump up to the 20 top most elements
20 maxdepth-.s !

: debug-dump-stack ( -- u1 u2 u3 ... ) cr .s cr ;

\ reads input-file for the tape and initializes tape memory space
: init-tape ( addr u -- u )
	open-tape-input
	
	tape-length 0 u+do
		2 tape-addr i cells + !
	loop

	1 1 \ counter
	begin
		tape-line-buffer tape-line-length tape-fd-in read-line ( -- string-len flag errcode )  throw
	while
	    tape-line-buffer ( -- buff-addr ) swap s>number? ( str-addr str-len -- num-read 0 -1 ) 2drop
	    ( counter counter num-read -- ) tape-addr rot cells + ! \ consumes one counter, keeps the other
		1 + dup
	repeat
	drop
	2 swap tape-addr swap cells + !
	1 -
	drop \ TODO: counter wird hiermit derzeit verworfen
	;

\ moves the tape-ptr to the cell containing the field representing the right neighbor
: tape-ptr-move-right ( -- ) tape-ptr 1 + to tape-ptr ;

\ moves the tape-ptr to the cell containing the field representing the left neighbor
: tape-ptr-move-left ( -- ) tape-ptr 1 - to tape-ptr ;

\ this word indicates that the tape-ptr will not be moved by this transition --> basically a documentary place holder
: tape-ptr-move-stay ( -- ) ;

\ reads the tape value at tape-ptr and returns it
: tape-read ( -- u ) tape-addr tape-ptr cells + @ ;

\ writes top of the stack to the tape at tape-ptr
: tape-write ( u -- ) tape-addr tape-ptr cells + ! ;

: tape-to-file ( addr u -- )
	open-output

	cr cr ." tape: " cr

	tape-length 0 u+do
		tape-addr i cells + @
		dup
		1 = if
			cr ." 1"
			s" 1" tape-fd-out write-line throw
		endif
		2 = if
			cr ." blank"
			s" blank" tape-fd-out write-line throw
		endif
	loop

	tape-fd-out close-file throw
	;
	
\ str str-len: str address to split and its length
\ separator sep-len: separator string that separates the tokens
: str-split ( str str-len separator sep-len -- tokens count )
  here >r 2swap
  begin
    2dup 2,             \ save this token ( addr len )
    2over search        \ find next separator
  while
    dup negate  here 2 cells -  +!  \ adjust last token length
    2over nip /string               \ start next search past separator
  repeat
  2drop 2drop
  r>  here over -   ( tokens length )
  dup negate allot           \ reclaim dictionary
  2 cells / 				\ turn byte length into token count
  ;                

\ fetches the next token from the current edge line processed
\ addr: tokens addr
\ u: symbol read
: get-next-edge-token ( addr -- u )
	2@ s>number? 2drop
	;
	
: machine-get-sym-read
	get-next-edge-token to token-sym-read
;

: machine-get-sym-write
	get-next-edge-token to token-sym-write
;

: machine-get-next-state
	get-next-edge-token to token-next-state
;

: machine-get-ptr-move
	get-next-edge-token
	CASE
		-1 OF POSTPONE tape-ptr-move-left  ENDOF
		 0 OF POSTPONE tape-ptr-move-right ENDOF
		 1 OF POSTPONE tape-ptr-move-stay  ENDOF
	ENDCASE
	;

\ checks if a new state is defined in the machine file. sets the token variable in this case, returns a flag
: machine-has-next-state ( - n )
	\ ließt eine Zeile des files in den buffer
	\ prüft ob zeile einen state beinhaltet oder __EOF__
	\ returns boolean flag ( -1  = true, 0 = false )
	0 to is-terminal-state \ reset the flag, we don't know if the new one will be one or not
	read-next-machine-line \ writes the line to the buffer \ TODO: wenn es ein neuer state war wo darüber die letzte edge steht, dann wurde die zeile bereits von has-next-edge gelesen
	\ zuerst überprüfen, aus wie vielen wörtern die bereits gelesene Zeile besteht
	\ ist diese 4 wörter lang, wurde sie noch nicht gelesen, ist die 1 oder 2 wörter lang, dann schon
	( -- str-len flag )
	0 = if \ __EOF__ reached --> no next state obviously
		0 \ return false flag
	else 
		machine-line-buffer s"  " str-split \ parse the tokens
		dup 1 = if
			\ TODO ist hier das swap richtig?!
			swap 2@ 2dup newline str= if 
				0 \ has no next state, finish parsing
			else \ this opens the new state to process
				( token-str token-len )
				s>number? 2drop to token-cur-state \ set token for new state to process
				-1 \ return flag: has next state = true
			endif
		dup 2 = if \ check if we process a terminal state
			\ TODO: die swaps hier müssen ggf auch noch überarbeitet werden
			swap 2@ s>number? 2drop to token-cur-state \ read the state token
			swap 2@ s>number? 2drop s" t" str<> if \ check the state mark for a 't'
				cr token-cur-state type ." state has an additional mark, but is not marked as a terminal!"
			endif
			
			is-terminal-state to -1 \ mark this state as a terminal state
			-1 \ has next state: true
		else
			cr ." malformed sytnax in machine file in state: " machine-line-buffer swap type cr
			0 \ error in machine file syntax --> terminate
		endif
	endif
	;
	

: machine-has-next-edge ( token-addr token-len )
	\ ließt nächste zeile des files in den buffer
	\ prüft ob buffer ein new-line beinhaltet (= ende der edges des states)
	\ retuniert true (= -1) wenn noch eine edge-line, false (=0) wenn state zu ende
	read-next-machine-line ( -- string-len flag ) \ writes the line to the buffer
	0 = if \ __EOF__ --> no next edge obviously
		drop \ drop the str-length 
		0 \ return false flag
	else
		machine-line-buffer swap s"  " str-split \ parse the tokens ( str len sep len -- tokens count )
		4 = if
			dup machine-get-sym-read
			dup machine-get-sym-write
			dup machine-get-next-state
			machine-get-ptr-move
			-1 \ return true flag, next edge found and tokens set
		else \ we did not detect a line containing 4 tokens. this means we have reached another state definition
			drop \ drop token-addr
			0 \ no next edge, return false
		endif	
	endif
;



\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol on the tape position
\ u3: resulting state
\ f: loop flag
: transition ( u1 u2 -- u3 f )
	 over 0 = if \ current state
	 	dup 1 = if \ symbol read on tape
	 		2drop \ clean up stack - we set new cur-state and type-sym now
	 		1 tape-write \ => write 1 to tape
	 		0 \ next-state to go to
	 		tape-ptr-move-right
	 		loop-flag-continue \ = 1
	 		endif
	 	dup 2 = if
	 		2drop
	 		1 tape-write
			1 \ next-state to go to
	 		tape-ptr-move-stay
	 		loop-flag-continue \ = 1
	 		endif
	 	endif
	 over 1 = if \ => terminal state
	 	2drop
	 	loop-flag-stop \ = 0
	 	endif
	;

\ : trans-test
\ 	 [ [BEGIN] machine-has-next-state [WHILE] ]
\ 	 	over [ token-cur-state ] literal = if
\ 	 		[ is-terminal-state [IF] ] 
\ 		 		2drop
\ 		 		loop-flag-stop \ = 0
\ 	 		[ [ELSE] ]
\ 	 			[ [BEGIN] machine-has-next-edge [WHILE] ]
\ 					dup [ machine-get-read-symbol ] literal = if
\ 						2drop 
\ 						[ machine-get-write-symbol ] literal tape-write
\ 						[ machine-get-next-state ] literal \ next-state to go to
\ 						[ machine-get-ptr-move ] \ left, right or stay
\ 						loop-flag-continue \ = 1
\ 						endif
\ 				[ [REPEAT] ]
\ 			[ [ENDIF] ]
\ 		 	endif
\ 	 [ [REPEAT] ]
\ 	 ; 



\ #### this is all very testy here! #####



: compile-transition ( -- )
	  begin 
	 	machine-has-next-state
	  while
	 	POSTPONE over token-cur-state POSTPONE literal POSTPONE = POSTPONE if
	 		is-terminal-state if
		 		POSTPONE 2drop
		 		loop-flag-stop POSTPONE literal
	 		else
	 			begin 
	 				machine-has-next-edge
	 			while
					POSTPONE dup machine-get-read-symbol POSTPONE literal POSTPONE = POSTPONE if
						POSTPONE 2drop 
						machine-get-write-symbol POSTPONE literal POSTPONE tape-write 
						machine-get-next-state POSTPONE literal \ next-state to go to
						machine-get-ptr-move \ TODO: BRAUCHEN WIR HIER EIN POSTPONE?! \ left, right or stay
						loop-flag-continue POSTPONE literal \ = 1
						POSTPONE endif
				repeat
				endif
		 	POSTPONE endif
	 repeat
	 ; immediate
	 
: transition-v2 
	compile-transition \ use [ compile-transition ]  in case it does not work
	;

\ ###########


: ufm ( program-path-str input-path-str -- [output-stack] )

	s" input1.tape" init-tape

	start-state \ => init state q0
	
	\ read states and edges, stuff
	
	
	
	loop-flag-continue begin
		0> while
			tape-read \ => read tape-sym at curr-state position
			transition \ => do the transition dance
		repeat

	s" result.tape" tape-to-file
	\ tape-to-stack
	;
