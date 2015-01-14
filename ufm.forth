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

: read-next-machine-line ( -- str-len flag )
	machine-line-buffer machine-line-length machine-fd-in read-line throw
	;


: open-machine-input ( addr u -- str-len flag )  
	r/o open-file throw to machine-fd-in \ create the file decriptor for the file
	read-next-machine-line \ read the first line of machine file (= start state)
	0= if
		cr ." ERROR: malformed machine file" cr
		bye
	else
		machine-line-buffer swap s>number? 2drop to start-state \ TODO: ist hier das swap auch ok oder im noch ein copy-paste fehler? ; set the start state 
	endif
	;


\ read machine-file path argument
next-arg 2dup 0 0 d<> if 
	cr ." no path to machine input file provided"
	bye
else
	open-machine-input
endif

\ read tape-file path argument
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
		tape-line-buffer tape-line-length tape-fd-in read-line ( string-len flag errcode )  throw
	while
	    ( buff-len )
	    tape-line-buffer ( buff-len buff-addr ) swap s>number? ( num-read 0 -1 ) 2drop
	    ( counter counter num-read ) tape-addr rot cells + ! \ consumes one counter, keeps the other
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
	
\ str-addr str-len: str address to split and its length
\ sep-addr sep-len: separator string that separates the tokens
\ token-addr token-len: adress of the tokens array and the length of the array
: str-split ( str-addr str-len sep-addr sep-len -- token-addr token-len )
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
: get-next-edge-token ( addr -- n )
	2@ \ fetch next token-str at addr
   ( str-addr str-len )
	s>number? 
    ( num flag errcode )
	2drop
	;
	
: machine-get-sym-read ( token-addr -- )
	get-next-edge-token to token-sym-read
	;

: machine-get-sym-write ( token-addr -- )
	get-next-edge-token to token-sym-write
	;

: machine-get-next-state ( token-addr -- )
	get-next-edge-token to token-next-state
	;

: machine-get-ptr-move ( C: token-addr -- ; I: -- )
	get-next-edge-token 
    ( n )
	CASE
		-1 OF POSTPONE tape-ptr-move-left  ENDOF
		 0 OF POSTPONE tape-ptr-move-right ENDOF
		 1 OF POSTPONE tape-ptr-move-stay  ENDOF
	ENDCASE
	;

\ checks if a new state is defined in the machine file. sets the token variable in this case, returns a flag
: machine-has-next-state ( token-addr token-len flag -- str-addr str-len flag )
	\ ließt eine Zeile des files in den buffer
	\ prüft ob zeile einen state beinhaltet oder __EOF__
	\ returns boolean flag ( -1  = true, 0 = false )
	0 to is-terminal-state \ reset the flag, we don't know if the new one will be one or not
    
    ( str-addr str-len flag )
    0 = if \ nächte zeile wurde bereits von has-next-edge für den vorherigen state geschrieben
        ( token-addr token-len ) 2drop \ in diesem fall besteht token-addr und token-len aus 0 0
    	read-next-machine-line \ writes the line to the buffer ( string-len flag )
    	
    	0 = if \ __EOF__ reached --> no next state obviously
			0 \ return false flag
		else 
		    ( str-len )
			machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens ( token-addr token-len )
    	endif
    endif
		
    ( token-addr token-len )
	dup 1 = if ( token-addr len ) \ when it is one, there is a next state
		drop ( token-addr ) 2@ ( str-addr str-len ) s>number? 2drop ( n ) to token-cur-state (  )
		0 0 \ no label for this state (not a terminal state)
		-1 \ return flag: has next state = true
	dup 2 = if \ check if we process a terminal state
		drop dup ( tok-addr tok-addr ) 2@ s>number? 2drop to token-cur-state \ read the state token
		cell+ cell+ ( tok-addr )
		2@ s>number? 2drop 
		( str-addr str-len )			
		-1 to is-terminal-state \ mark this state as a terminal state
		-1 \ has next state: true 
		( str-addr str-len flag )
	else
		cr ." malformed sytnax in machine file in state: " machine-line-buffer swap type cr
		0 \ error in machine file syntax --> terminate
	endif
		

	;
	

: machine-has-next-edge ( -- token-addr token-len flag )
	\ ließt nächste zeile des files in den buffer
	\ prüft ob buffer ein new-line beinhaltet (= ende der edges des states)
	\ retuniert true (= -1) wenn noch eine edge-line, false (=0) wenn state zu ende
	read-next-machine-line \ writes the line to the buffer
    ( str-len flag ) 
	0 = if \ __EOF__ --> no next edge obviously 
		0 \ return false flag ( buffer-len f )
	else
		machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens ( str len sep len -- token-addr token-len )
		dup 4 = if
			drop \ we dont need token-len any more
			dup machine-get-sym-read
			dup cell+ cell+ machine-get-sym-write
			dup cell+ cell+ machine-get-next-state
			cell+ cell+ machine-get-ptr-move
			0 0 \ no return string needed --> already parsed and values set
			-1 \ return true flag, next edge found and tokens set
		else \ we did not detect a line containing 4 tokens. this means we have reached another state definition
		    ( token-addr token-len )
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
	 	    ( u1 u2 )
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

: compile-transition ( C: addr len flag -- ) \ TODO: ist der stack effect sicher gestellt?!
	0 0 0 ( C: token-addr token-len flag )
	  begin 
	    ( addr len flag ) \ 
	 	machine-has-next-state
	    ( str-addr str-len flag ) \ TODO: ist hier sicher gestellt, das der stack auch so ausschaut? oder werden hier auch noch irgendwelche addressen geliefert?
	  while
	 	POSTPONE over token-cur-state POSTPONE literal POSTPONE = POSTPONE if
	 		is-terminal-state if
	 		    ( u1 u2 str-addr str-len ) 
	 		    swap
	 		    ( u1 u2 str-len str-addr )
	 		    POSTPONE literal POSTPONE literal 
	 		    ( u1 u2 str-addr str-len ) 
	 		    POSTPONE cr POSTPONE type POSTPONE cr \ print the state label
		 		POSTPONE 2drop \ drops u1 & u2	 		 
		 		loop-flag-stop POSTPONE literal
		 		0 0 0 ( C: token-addr token-len flag )
	 		else
	 		    ( C: str-addr str-len )
	 		    2drop \ those should be 0 0 --> no label for non-terminal states
	 			begin 
	 				machine-has-next-edge
	 			    ( C: token-addr token-len flag )
	 			while
	 			    ( C: token-addr token-len )
	 			    2drop
					POSTPONE dup machine-get-read-symbol POSTPONE literal POSTPONE = POSTPONE if
					    ( u1 u2 )
						POSTPONE 2drop \ drop u1 u2
						machine-get-write-symbol POSTPONE literal POSTPONE tape-write 
						machine-get-next-state POSTPONE literal \ next-state to go to
						machine-get-ptr-move \ TODO: BRAUCHEN WIR HIER EIN POSTPONE?! --> das word soll sofort aufgerufen werden, aber den code des tape-ptr-move words erst in der transition ausgeführt, also schon, oder? oder müssen die calls im machine-get-ptr-move postponed werden? (was sie derzeit sind) \ left, right or stay
						loop-flag-continue POSTPONE literal \ = 1
						POSTPONE endif
				repeat
				-1 ( C: token-addr token-len flag )
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
