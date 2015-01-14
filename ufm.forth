#! /usr/bin/env gforth

\ 
\ Universal Turing Machine in Forth 
\ 

1000 Constant tape-length 
8 Constant tape-line-length
32 Constant machine-line-length
Create tape-addr tape-length cells allot
Create tape-line-buffer tape-line-length allot
Create machine-line-buffer machine-line-length chars allot
0 Value tape-fd-in
0 Value tape-fd-out
0 Value machine-fd-in
tape-length 2 / Value tape-ptr		
tape-ptr Value tape-left-rim  
tape-ptr Value tape-right-rim	
0 Value start-state
0 Value token-cur-state 
0 Value token-sym-read
0 Value token-sym-write
0 Value token-next-state
0 Value token-ptr-move
0 Value token-tape-ptr-move
0 Value is-terminal-state


: open-tape-input ( addr u -- )  r/o open-file throw to tape-fd-in ;
: open-output ( addr u -- )  w/o create-file throw to tape-fd-out ;

\ reads input-file for the tape and initializes tape memory space
: init-tape ( addr u --  )
	open-tape-input ( )
	
	1 1 \ counter
	begin
		tape-line-buffer tape-line-length tape-fd-in read-line ( counter counter buff-len flag errcode ) throw
	while
	    ( c c  buff-len )
	    tape-line-buffer 
	    ( c c buff-len buff-addr ) 
	    swap 2dup 
	    ( c c buff-addr buff-len buff-addr buff-len ) 
	    s>number? 
	    ( c c buff-addr buff-len num-read 0 flag )  \ on error: 0 0 0 
	    0= if \ conversion failed
	        ( c c buff-addr buff-len 0 0 )
	        2drop
	    	cr ." malformed input tape. invalid symbol: " type cr
	        ( c c )
	    	2drop 
	    	bye
	    else \ drop debug information
	        ( c c buff-addr buff-len num-read 0 ) 
	        drop \ useless 0
	        rot rot
	        ( c c num-read buff-addr buff-len )
	    	2drop \ drop debug string
	    endif
	    
	    ( counter counter num-read ) tape-addr tape-ptr cells + rot ( counter num t-addr counter ) cells + ! ( counter ) \ consumes one counter, keeps the other
		1 + dup ( counter counter )
	repeat
    ( counter counter buff-len )
	2drop drop \ drop length of line-buffer and counter
	
;

\ load next line of file into the line-buffer
\ str-len: length of read line
\ flag: true if next line exists, false otherwise
: read-next-machine-line ( -- str-len flag )
	machine-line-buffer machine-line-length machine-fd-in read-line throw
	;

\ opens the file specified by the path string on the stack 
\ path-addr path-len: string of path to input file
: open-machine-input ( path-addr path-len -- ) 
	r/o open-file throw to machine-fd-in (  ) \ create the file decriptor for the file
	read-next-machine-line ( str-len flag ) \ read the first line of machine file (= start state)
	0= if
		cr ." ERROR: malformed machine file. start state missing" cr
		drop (  )
		bye
	else
		machine-line-buffer swap s>number? 2drop to start-state 
	endif
    (  )
	;


\ read machine-file path argument
next-arg 2dup 0 0 d<> [IF]
	open-machine-input
[ELSE]
	cr ." no path to machine input file provided"
	bye
[ENDIF]

\ read tape-file path argument
next-arg 2dup 0 0 d<> [IF]
	init-tape
[ELSE]
	cr ." no path to tape input file provided"
	bye
[ENDIF]

\ .s word will dump up to the 20 top most elements
20 maxdepth-.s !

: debug-dump-stack ( -- u1 u2 u3 ... ) cr .s cr ;

\ moves the tape-ptr to the cell containing the field representing the right neighbor
: tape-ptr-move-right ( -- ) 
	tape-ptr 1 + to tape-ptr 
	
	tape-ptr tape-left-rim > if
		tape-ptr to tape-left-rim
	endif
	;

\ moves the tape-ptr to the cell containing the field representing the left neighbor
: tape-ptr-move-left ( -- ) 
	tape-ptr 1 - to tape-ptr 
	
	tape-ptr tape-right-rim < if
		tape-ptr to tape-right-rim
	endif
	;

\ this word indicates that the tape-ptr will not be moved by this transition --> basically a documentary place holder
: tape-ptr-move-stay ( -- ) ;

\ reads the tape value at tape-ptr and returns it
: tape-read ( -- u ) tape-addr tape-ptr cells + @ ;

\ writes top of the stack to the tape at tape-ptr
: tape-write ( u -- ) tape-addr tape-ptr cells + ! ;

\ converts a number to a string
\ n: number to convert
\ str-addr str-len: string of the converted number
: num>string ( n — str-addr str-len )
	here 16 chars allot \ allocate 16 chars space
    ( n addr )
	>r dup >r abs s>d <# #s r> sign #>
  	r@ char+ swap dup >r cmove r> r> tuck ( str-addr str-len str-addr ) c! 
    ( str-addr ) count ( str-addr str-len )
  	;
  

\ dumps the tape to a file
\ only writes the part of the tape that was written to
\ path-addr path-len: takes the path to the output file 
: tape-to-file ( path-addr path-len -- )
	
	open-output

	cr cr ." tape: " cr

	\ run this loop from the leftmost symbol on the tape to the rightmost symbol
	tape-right-rim tape-left-rim u+do
		tape-addr tape-left-rim + i + cells + \ calculate some addr on the tape
	    ( addr ) @ ( n ) num>string ( str-addr str-len )
		2dup
		cr type \ print number-str to command line ( we could also only dup and dot the number before cast to string )
		tape-fd-out write-line throw \ write number to output file
	loop
	
	tape-fd-out close-file throw
	;
	
\ str-addr str-len: str address to split and its length
\ sep-addr sep-len: separator string that separates the tokens
\ token-addr token-len: adress of the tokens array and the length of the array
: str-split ( str-addr str-len separator-addr separator-len -- token-addr token-len )
  here >r 2swap ( sep-addr sep-len str-addr str-len )
  begin
    2dup ( sep-addr sep-len str-addr str-len str-addr str-len ) 2, ( sep-addr sep-len str-addr str-len )  \ save this token
    2over ( sep-addr sep-len str-addr str-len sep-addr sep-len ) search ( sep-addr sep-len str-without-next-word-addr str-len flag )  \ find next separator
  while
    dup negate ( sep-addr sep-len str-addr str-len -str-len ) here 2 cells -  +! ( sep-addr sep-len str-addr str-len ) \ store length of word
    2over ( sep-addr sep-len str-addr str-len sep-addr sep-len ) nip ( sep-addr sep-len str-addr str-len sep-len ) /string \ start next search past separator
    ( sep-addr sep-len str-addr str-len )
  repeat
  ( sep-addr sep-len str-without-next-word-addr str-len )
  2drop 2drop ( counter )
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
	get-next-edge-token to token-ptr-move
	;

\ see machine-get-ptr-move

\ checks if a new state is defined in the machine file. 
\ sets the token variable in this case, returns a flag
\ token-addr: address of token array
\ token-len: count of elements in token array
\ str-addr str-len: label-str for the label of a terminal state. 0 0 in case of a regular state
: machine-has-next-state ( token-addr token-len flag -- str-addr str-len flag )
	\ ließt eine Zeile des files in den buffer
	\ prüft ob zeile einen state beinhaltet oder __EOF__
	\ returns boolean flag ( -1  = true, 0 = false )
	0 to is-terminal-state \ reset the flag, we don't know if the new one will be one or not
    
    ( str-addr str-len flag )
    0 = if \ trifft zu wenn nächste zeile bereits von has-next-edge gelesen wurde
        2drop \ in diesem fall besteht token-addr und token-len aus 0 0
    	read-next-machine-line \ writes the line to the buffer ( string-len flag )
    	
    	0 = if \ __EOF__ reached --> no next state obviously
    		drop
			0 \ return false flag ( 0 0 )
		else 
		    ( str-len )
			machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens ( token-addr token-len )
    	endif
    endif
    
    case
    	1 of 
    		\ when it is one, there is a next state
			 ( token-addr ) cr ." 2@ Nr 1:" cr .s cr 2@ ( str-addr str-len ) s>number? 2drop ( n ) to token-cur-state (  )
			0 0 \ no label-str for this state (not a terminal state)
			-1 \ return flag: has next state = true
		endof
		2 of
			dup ( tok-addr tok-addr ) 
			cr ." 2@ Nr 2:" cr .s cr 
			2@ s>number? 2drop to token-cur-state \ read the state token
			cell+ cell+ ( tok-addr )
			\ read the terminal state label (= what is printed when machine terminates)
			cr ." 2@ Nr 3: " cr .s cr 
			2@ \ s>number? 2drop \ SO EIN BLÖDSINN!
			cr ." after 2@ Nr 3: " cr .s cr 2dup type cr
			
		    ( str-addr str-len )			
			-1 to is-terminal-state \ mark this state as a terminal state
			-1 \ has next state: true 
			 ( str-addr str-len flag )
		endof
		0 of 
			 ( token-addr ) drop
			0 0 0 \ return false -> end of file
		endof
	    \ ELSE:
	    ( ... n )
	    >r \ write n to return stack (we need it at the end for the endcase)
		cr ." malformed sytnax in machine file for state: " machine-line-buffer swap type cr 
		0 0 0 \ return false --> error in machine file syntax, terminate
		r> \ get this tedious n back...
	    ( ... n )
    endcase
		
\    ( token-addr token-len )
\ 	dup 1 = if ( token-addr token-len ) \ when it is one, there is a next state
\ 		drop ( token-addr ) cr ." 2@ Nr 1:" cr .s cr 2@ ( str-addr str-len ) s>number? 2drop ( n ) to token-cur-state (  )
\ 		0 0 \ no label-str for this state (not a terminal state)
\ 		-1 \ return flag: has next state = true
\ 	endif
\ 	dup 2 = if \ check if we process a terminal state
\ 		swap dup ( token-len tok-addr tok-addr ) cr ." 2@ Nr 2:" cr .s cr 2@ s>number? 2drop to token-cur-state \ read the state token
\ 		cell+ cell+ ( token-len tok-addr )
\ 		cr ." 2@ Nr 3: " cr .s cr 2@ s>number? 2drop ( token-len str-addr str-len )			
\  		-1 to is-terminal-state \ mark this state as a terminal state
\ 		-1 \ has next state: true 
\ 	    ( token-len str-addr str-len flag )
\ 	endif
\ 	0 = if
\ 		0 0 0 \ return false -> end of file
\ 	else
\ 		cr ." malformed sytnax in machine file for state: " machine-line-buffer swap type cr 
\ 		0 0 0 \ return false --> error in machine file syntax, terminate
\ 	endif
	;
	
: machine-has-next-edge ( -- token-addr token-len flag )
	\ ließt nächste zeile des files in den buffer
	\ prüft ob buffer ein new-line beinhaltet (= ende der edges des states)
	\ retourniert true (= -1) wenn noch eine edge-line, false (=0) wenn state zu ende

	read-next-machine-line ( str-len flag ) \ writes the line to the buffer
 
	0 = if \ __EOF__ --> no next edge obviously
		drop 
		0 0 0 \ return false
	    ( 0 0 flag )
	else
        ( str-len ) machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens 
        ( token-addr token-len )
		dup 4 = if \ true when there is a new edge
			drop \ we dont need token-len any more ( tok-addr )
			dup machine-get-sym-read ( tok-addr )
			cell+ cell+ dup machine-get-sym-write ( tok-addr )
			cell+ cell+ dup machine-get-next-state ( tok-addr )
			cell+ cell+ machine-get-ptr-move ( )
			0 0 \ no return string needed --> already parsed and values set
			-1 \ return true flag, next edge found and tokens set
            ( 0 0 -1 )
		else \ we did not detect a line containing 4 tokens. this means we have reached another state definition
			0 \ no next edge, return false
            ( token-addr token-len 0 )
		endif	
	endif
	;



\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol on the tape position
\ u3: resulting state
\ f: loop flag
: transition-increment-example ( u1 u2 -- u3 f )
	 over 0 = if \ current state
	 	dup 1 = if \ symbol read on tape
	 	    ( u1 u2 )
	 		2drop \ clean up stack - we set new cur-state and type-sym now
	 		1 tape-write \ => write 1 to tape
	 		0 \ next-state to go to
	 		tape-ptr-move-right
	 		-1 \ = 1
	 	endif
	 	dup 2 = if
	 		2drop
	 		1 tape-write
			1 \ next-state to go to
	 		tape-ptr-move-stay
	 		-1 \ return true, keep machine loop working
	 	endif
	 endif
	 over 1 = if \ => terminal state
	 	2drop
	 	0 \ return false, stop machine loop
	 endif
	;

: compile-transition ( C: -- ; I: ??? )
	0 0 0 ( C: token-addr token-len flag )
	  begin 
	    ( token-addr token-len flag ) 
	 	machine-has-next-state
	    ( str-addr str-len flag ) 
	  while
	  	>r >r
	 	POSTPONE over token-cur-state POSTPONE literal POSTPONE =  POSTPONE if 
	 		is-terminal-state if
	 			r> r>
	 			( u1 u2 str-addr str-len ) 
	 		    swap
	 		    ( u1 u2 str-len str-addr )
	 		    POSTPONE literal POSTPONE literal 
	 		    ( I: u1 u2 str-addr str-len ) 
	 		    POSTPONE cr POSTPONE type POSTPONE cr \ print the term-state label
	 		    ( I: u1 u2 ) 
		 		POSTPONE 2drop	 		 
		 		0 POSTPONE literal \ return false, stop machine loop
		 	    (  )
		 		0 0 0 ( C: token-addr token-len flag )
		 		>r >r >r \ push compile-time stack effect to return stack, so that the postponed endif will find his origin
	 		else
	 			r> r> \ get back from return stack
	 		    ( C: str-addr str-len )
	 		    2drop \ those should be 0 0 --> no label for non-terminal states
	 			begin 
	 				machine-has-next-edge
	 			    ( C: token-addr token-len flag )
	 			while
	 			    ( C: token-addr token-len )
	 			    2drop \ edge token line is read an token-vals are set, drop the token array adress
					POSTPONE dup token-sym-read POSTPONE literal POSTPONE = POSTPONE if
					    ( I: u1 u2 )
						POSTPONE 2drop \ drop u1 u2  
						token-sym-write POSTPONE literal POSTPONE tape-write 
						token-next-state POSTPONE literal \ next-state to go to
						token-ptr-move 
						( C: n )
						case
							-1 of POSTPONE tape-ptr-move-left  endof
		 					 0 of POSTPONE tape-ptr-move-right endof
		 					 1 of POSTPONE tape-ptr-move-stay  endof
						endcase
						
						-1 POSTPONE literal \ return true, keep machine loop working
					POSTPONE endif
				repeat
				
				-1 ( C: token-addr token-len flag ) \ line read flag
				>r >r >r \ TODO: push compile time stack effekt to return stack
			endif
			
		 POSTPONE endif
		 r> r> r> \ fetch compile-time stack effect from return stack
		 
	 repeat
	 ( str-addr str-len ) \ should be 0 0 at this point 
	 2drop \ cleanup stack
	 ; immediate
	 
	 
\ see compile-transition
	 
\ this is the magic word. but the magic does not happen here 
\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol read at tape position
\ u3: resulting state
\ f: loop flag
: transition ( C: -- ; I: u1 u2 -- u3 f )
	compile-transition  \ TODO: use [ compile-transition ] in case it does not work
	;


: run-turing-machine ( -- )

	start-state
	1 begin
	    ( cur-state flag )
		0> 
	while
	    ( cur-state )
		tape-read \ => read tape-sym at curr-state position
	    ( cur-state cur-sym )
		transition \ => do the transition dance
	    ( next-state flag )
	repeat

	s" result.tape" tape-to-file
	\ tape-to-stack
	;
	
\ run turing machine
\ run-turing-machine 
