#! /usr/bin/env gforth

\
\ Universal Turing Machine in Forth
\
\ (c) 2014-2015
\ by Maximilian Irro and Theresa Fröschl
\

1000 Constant tape-length
8 Constant tape-line-length         \ maximum line length in tape file
32 Constant machine-line-length     \ maximum line length in machine file
20 Constant termlabel-table-space   \ size (= # rows) auf termlabel table
32 Constant termlabel-length        \ maximum line length of termlabel table
0 Value termlabel-table-cursor      \ next free row in termlable table
Create tape-addr tape-length cells allot
Create tape-line-buffer tape-line-length allot
Create machine-line-buffer machine-line-length chars allot
Create termlabel-tmp termlabel-length chars allot \ tmp buffer to convert cell pair strings to counted strings
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
: open-tape-output ( addr u -- )  w/o create-file throw to tape-fd-out ;

\ move tape-ptr to the cell representing the left neighbor
: tape-ptr-move-left ( -- )
    tape-ptr 1 - to tape-ptr
    tape-ptr tape-left-rim < if
        tape-ptr to tape-left-rim
    endif
    ;

\ move tape-ptr to the cell representing the right neighbor
: tape-ptr-move-right ( -- )
    tape-ptr 1 + to tape-ptr
    tape-ptr tape-right-rim > if
        tape-ptr to tape-right-rim
    endif
    ;

\ this word indicates that the tape-ptr will not be moved by this transition --> basically a documentary place holder
: tape-ptr-move-stay ( -- ) ;

\ reads the tape value at tape-ptr and returns it
: tape-read ( -- u ) tape-addr tape-ptr cells + @ ;

\ writes top of the stack to the tape at tape-ptr
: tape-write ( u -- ) tape-addr tape-ptr cells + ! ;

\ sets the tape-ptr to the inital position
\ this operation is needed if we want to run the turing machine multiple times on the same tape
: reset-tape-ptr ( -- )
    tape-length 2 / to tape-ptr
    tape-ptr-move-right
    ;

\ reads input-file for the tape and initializes tape memory space
: init-tape ( addr u --  )
    open-tape-input ( )

    \ init whole tape-memory with 0's
    tape-length 0
    u+do
        0 tape-addr i cells + !
    loop

    \ write the tape input file to the tape-memory
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
        ( c c buff-addr buff-len num-read 0 flag )  \ --> on error: 0 0 0
        0= if \ conversion failed
            ( c c buff-addr buff-len 0 0 )
            2drop \ drop the 0's return on failed conversion
            ." [ERROR] malformed input tape. invalid symbol: " type cr
            ( c c )
            2drop
            bye
        else \ drop debug information
            ( c c buff-addr buff-len num-read 0 )
            drop \ useless 0
            rot rot
            ( c c num-read buff-addr buff-len )
            2drop \ drop error msg string
        endif

        ( counter counter num-read ) tape-addr tape-ptr
        cells + rot ( counter num t-addr counter ) cells + ! ( counter ) \ consumes one counter, keeps the other
        1 + dup ( counter counter )
    repeat
    ( counter counter buff-len )
    2drop drop \ drop length of line-buffer and counter

    reset-tape-ptr
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
    r/o open-file throw to machine-fd-in (  ) 	\ create the file decriptor for the file
    read-next-machine-line ( str-len flag ) 	\ read the first line of machine file (= start state)
    0= if
        ." [ERROR] malformed machine file. start state missing" cr
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
    ." [ERROR] no path to machine input file provided" cr
    ." usage: ufm.forth machine-file tape-file" cr
    bye
[ENDIF]

\ read tape-file path argument
next-arg 2dup 0 0 d<> [IF]
    init-tape
[ELSE]
    ." [ERROR] no path to tape input file provided" cr
    ." usage: ufm.forth machine-file tape-file" cr
    bye
[ENDIF]

next-arg 2dup 0 0 d<> [IF]
    ." [WARNING] to many arguments provided. the argument: >>" type ." << and any following will be ignored" cr
    ." usage: ufm.forth machine-file tape-file" cr
[ELSE]
    ( 0 0 )
    2drop
[ENDIF]

\ .s word will dump up to the 20 top most elements
20 maxdepth-.s !

: debug-dump-stack ( -- u1 u2 u3 ... ) cr .s cr ;


\ convert a cell pair string to a counted string
: s>cstr ( str-addr str-len cstr-addr -- )
    over over >r >r
    char+ swap chars
    cmove
    r> r>
    c!
    ;

\ converts a number to a string
\ n: number to convert
\ str-addr str-len: string of the converted number
: num>string ( n — str-addr str-len )
    here 16 chars allot \ allocate 16 chars space
    ( n addr )
    >r dup >r abs s>d <# #s r> sign #>
      r@ char+ swap dup >r cmove r> r> tuck ( str-addr str-len str-addr )
      c! ( str-addr )
      count ( str-addr str-len )
      ;

\ lets us create 2D arrays for long term string storage
: 2d-array
    create  ( n1 n2 ) 					\ create an entry
        dup  ( n1 n2 n2 ) 				\ = rows columns columns
        ,  ( n1 n2 )  					\ compile the number of cells in a row
         * chars  ( n1*n2 )  			\ calculate size
        allot  ( -- )  					\ allocate the number of cells
    does>  ( n1 n2 a )  				\ what to do at runtime
        rot over @  ( n2 a n1 n3 ) 		\ get number of cells in a row
        * rot + 1+  ( a n1*n3+n2+1 ) 	\ calculate offset
        chars +  ( a+n1*n3+n2+1 ) 		\ calculate address
    ;

\ define a lookup table for the terminal state labels (long term storage)
termlabel-table-space termlabel-length 2d-array termlabel-table


\ dumps the tape to a file
\ only writes the part of the tape that was written to
\ path-addr path-len: takes the path to the output file
: dump-tape ( path-addr path-len -- )

    open-tape-output

    cr ." result tape: " cr

    \ run this loop from the leftmost symbol on the tape to the rightmost symbol
    tape-right-rim tape-left-rim
    u+do
        tape-addr tape-left-rim cells + \ calculate left part of the written tape
        1 cells + \ don't know why there has to be this offset
        i tape-left-rim - cells + \ i does not start at 0, but at tape-left-rim! drop the first line of this loop and calculate via this one only
        ( addr ) @ ( n ) num>string ( str-addr str-len )
        2dup
        cr ." [ " i tape-left-rim - . ." ] : " type \ print number-str to command line ( we could also only dup and dot the number before cast to string )
        tape-fd-out write-line throw \ write number to output file
    loop

    cr \ this is only for a pretty output

    tape-fd-out close-file throw
    ;

\ str-addr str-len: str address to split and its length
\ sep-addr sep-len: separator string that separates the tokens
\ token-addr token-len: adress of the tokens array and the length of the array
: str-split ( str-addr str-len separator-addr separator-len -- token-addr token-len )
    here >r 2swap ( sep-addr sep-len str-addr str-len )
    begin
        2dup 2,      ( sep-addr sep-len str-addr str-len )                         \ save this token
        2over search ( sep-addr sep-len str-without-next-word-addr str-len flag )  \ find next separator
    while
        dup negate          ( sep-addr sep-len str-addr str-len -str-len )
        here 2 cells -  +!  ( sep-addr sep-len str-addr str-len )  \ store length of word
        2over nip /string   ( sep-addr sep-len str-addr str-len )  \ start next search past separator
      repeat
  ( sep-addr sep-len str-without-next-word-addr str-len )
      2drop 2drop ( counter )
      r>  here over -   ( tokens length )
      dup negate allot    \ reclaim dictionary
      2 cells /           \ turn byte length into token count
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

: machine-get-sym-read ( token-addr -- ) get-next-edge-token to token-sym-read ;

: machine-get-sym-write ( token-addr -- ) get-next-edge-token to token-sym-write ;

: machine-get-next-state ( token-addr -- ) get-next-edge-token to token-next-state ;

: machine-get-ptr-move ( token-addr -- ) get-next-edge-token to token-ptr-move ;

\ checks if a new state is defined in the machine file.
\ sets the token variable in this case, returns a flag
\ token-addr: address of token array
\ token-len: count of elements in token array
\ str-addr str-len: label-str for the label of a terminal state. 0 0 in case of a regular state
\ returns boolean flag ( -1  = true, 0 = false )
: machine-has-next-state ( token-addr token-len flag -- str-addr str-len flag )
    0 to is-terminal-state \ reset the flag, we don't know if the new one will be one or not

    0 = if          \ true when next line has not been read by has-next-edge
        2drop       \ drop token-addr and token-len --> they are 0 0 anyway
        read-next-machine-line  \ writes the line to the buffer
        ( string-len flag )
        0 = if \ __EOF__ reached --> no next state obviously
            drop
            0 \ return false flag ( 0 0 )
        else
            ( str-len )
            machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens ( token-addr token-len )
        endif
    endif

    case \ check which kind of line we process
        1 of \ = regular state (only one token) -  when it is one, there is a next state
            ( token-addr )
            2@ ( str-addr str-len ) s>number? 2drop ( n ) to token-cur-state (  )
            0 0     \ no label-str for this state (not a terminal state)
            -1      \ return flag: has next state = true
        endof
        2 of \ = terminal state (two tokens in line)
            dup ( token-addr token-addr )
            2@ s>number? 2drop to token-cur-state \ read the state token
            cell+ cell+ ( token-addr )
            2@    \ read the terminal state label (= what is printed when machine terminates)
            ( str-addr str-len )

            \ the string here is in heap memory dictionary space.
            \ it "does not last forever. If you wait too long it will be overwritten."
            \ "It depends on your system how long the string will last."
            \  --> great. we'll have to copy it to our label table then...

            termlabel-tmp
            s>cstr  \ make cell pair string to counted string (= table storage format)
            0 termlabel-table-cursor termlabel-table \ fetch the next free table addr
            ( table-addr )
            termlabel-tmp swap
            ( tmp-addr table-addr )
            termlabel-tmp count nip
            1+ \ account for the count byte (damn those unstandardised strings in forth...)
            ( tmp-addr table-addr cstr-len )
            cmove \ copy counted string to table row
            (  )
             0 termlabel-table-cursor termlabel-table
            ( table-str-addr )
            0 termlabel-table-cursor termlabel-table
            count nip
            ( table-str-addr table-str-len )
            1+         	\ compiled count byte accounted string size into transition!
            dup >r  	\ memorize length at the return stack

            termlabel-table-cursor r> + to termlabel-table-cursor \ ajust table cursor to next free position

            -1 to is-terminal-state 	\ mark this state as a terminal state
            -1                         	\ return true (has next state)
            ( str-addr str-len flag )
        endof
        0 of \ = __EOF__ (no token in line)
            ( token-addr ) drop
            0 0 0     \ return false --> __EOF__ reached
        endof
        \ ELSE: undefined amount of tokens in line --> nothing that we expect
        ( n )
        >r \ write n to return stack (we need it at the end for the endcase)
        ." [ERROR] malformed sytnax in machine file for state: " machine-line-buffer swap type cr
        0 0 0 \ return false --> error in machine file syntax, terminate
        r> \ get this tedious n back...
        ( str-addr str-len flag n )
    endcase
    ;


\ read next line of machine file into the buffer
\ if it matches the specification of an edge line, it will return true
: machine-has-next-edge ( -- token-addr token-len flag )

    read-next-machine-line ( str-len flag ) \ writes the line to the buffer

    0 = if         	\ __EOF__ --> no next edge obviously
        drop
        0 0 0     	\ return false
    else
        ( str-len ) machine-line-buffer swap ( line-addr line-len ) s"  " str-split \ parse the tokens
        ( token-addr token-len )
        dup 4 = if  	\ true when there is a new edge
            drop     	\ we dont need token-len any more ( token-addr )
            dup machine-get-sym-read                ( token-addr )
            cell+ cell+ dup machine-get-sym-write   ( token-addr )
            cell+ cell+ dup machine-get-next-state  ( token-addr )
            cell+ cell+ machine-get-ptr-move        ( )
            0 0 	\ no return string needed --> already parsed and values set
            -1  	\ return true flag, next edge found and tokens set
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
     over 1 = \ => terminal state
     if
         cr s" terminal state: " type s" finished" type cr
         2drop
         0 \ return false, stop machine loop
         exit
     endif

     over 0 = \ current state
     if
         dup 1 = \ symbol read on tape
         if
             ( u1 u2 )
             2drop 			\ clean up stack - we set new cur-state and type-sym now
             1 tape-write 	\ => write 1 to tape
             0 				\ next-state to go to
             tape-ptr-move-right
             -1 			\ = 1
             exit
         endif
         dup 2 =
         if
             2drop
             1 tape-write
            1 \ next-state to go to
             tape-ptr-move-stay
             -1 \ return true, keep machine loop working
             exit
         endif
     endif
    ;

: [compile-transition] ( C: -- ; I: undefined )
    0 0 0 ( C: token-addr token-len flag )
	begin
    ( token-addr token-len flag )
	machine-has-next-state
    ( str-addr str-len flag )
	while
    ( str-addr str-len )
	>r >r \ send str to return-stack
	POSTPONE over token-cur-state POSTPONE literal POSTPONE = POSTPONE if
		is-terminal-state if
			POSTPONE cr
			s" terminal state: "
			swap
			POSTPONE literal POSTPONE literal
			POSTPONE type

			r> r> \ fetch label-str for this terminal state from return-stack
		    ( C: str-addr str-len )
			swap
		    ( u1 u2 str-len str-addr )
			POSTPONE literal POSTPONE literal
		    ( I: u1 u2 str-addr str-len )
			POSTPONE type POSTPONE cr 	\ print the term-state label
		    ( I: u1 u2 )
			POSTPONE 2drop
			0 POSTPONE literal 			\ return false, stop machine loop
			POSTPONE exit 				\ exit the transition word here
		    ( C:  )
			0 0 0 ( C: token-addr token-len flag )
			>r >r >r \ push compile-time stack effect to return-stack, so that the postponed endif will find its origin
		 else
			r> r> \ fetch str from return-stack
		    ( C: str-addr str-len )
			2drop \ those are 0 0 at this point --> no labels for non-terminal states
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
						 0 of POSTPONE tape-ptr-move-stay  endof
						 1 of POSTPONE tape-ptr-move-right endof
					endcase

					-1 POSTPONE literal 	\ return true, keep machine loop working
					POSTPONE exit 			\ exit the transition word here
				POSTPONE endif
			repeat
			-1 ( C: token-addr token-len flag ) \ line read flag
			>r >r >r 	\ push compile-time stack effect to return-stack
		endif
	POSTPONE endif
	r> r> r> \ fetch compile-time stack effect from return-stack
	repeat
    ( str-addr str-len ) 	 \ = 0 0 at this point
	2drop \ cleanup stack
	; compile-only immediate \ make it compile-only for the interpretation semantics is undefined (and useless) anyway

\ this is the magic word. but the magic does not happen here
\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol read at tape position
\ u3: resulting state
\ f: loop flag
: transition ( C: -- ; I: u1 u2 -- u3 f )
    [compile-transition]
    ;

: run-turing-machine ( -- )

    start-state
    1 \ initial loop flag
    begin
        ( cur-state flag )
    while
        ( cur-state )
        tape-read 	\ => read tape-sym at curr-state position
        ( cur-state cur-sym )
        transition 	\ => do the transition dance
        ( next-state flag )
    repeat

    s" result.tape" dump-tape
    cr
    ;

\ execute machine immediatly when calling the script
run-turing-machine
