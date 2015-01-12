#! /usr/bin/env gforth

\
\ Universal Turing Machine
\ programed in Forth
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

: open-tape-input ( addr u -- )  r/o open-file throw to tape-fd-in ;
: open-output ( addr u -- )  w/o create-file throw to tape-fd-out ;

: open-machine-input ( addr u -- )  r/o open-file throw to machine-fd-in ;

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

	1 1 begin
		tape-line-buffer tape-line-length tape-fd-in read-line throw
	  	while
	  		tape-line-buffer swap s>number? 2drop
			tape-addr rot cells + !
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

\ reads next element of line in program file
: get-next-elem
;

: prog-has-next-state ( ... - n )
	
;

: prog-get-cur-state ( ... - n )
	
;

: is-terminal-state ( ... - n )
	
;

: prog-has-next-edge (  )
	
;

: prog-get-read-symbol
	get-next-elem
;

: prog-get-write-symbol
	get-next-elem
;

: prog-get-next-state
	get-next-elem
;

: prog-get-ptr-move
	get-next-elem
;

\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol on the tape position
\ u3: resulting state
\ u4: loop flag
: transition ( u1 u2 -- u3 u4 )
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

: trans-test
	 [ [BEGIN] prog-has-next-state [WHILE] ]
	 	over [ prog-get-cur-state ] literal = if
	 		[ is-terminal-state [IF] ] 
		 		2drop
		 		loop-flag-stop \ = 0
	 		[ [ELSE] ]
	 			[ [BEGIN] prog-has-next-edge [WHILE] ]
					dup [ prog-get-read-symbol ] literal = if
						2drop 
						[ prog-get-write-symbol ] literal tape-write
						[ prog-get-next-state ] literal \ next-state to go to
						[ prog-get-ptr-move ] \ left, right or stay
						loop-flag-continue \ = 1
						endif
				[ [REPEAT] ]
			[ [ENDIF] ]
		 	endif
	 [ [REPEAT] ]
	 ; 


: ufm ( program-path-str input-path-str -- [output-stack] )

	s" input1.tape" init-tape

	0 \ => init state q0
	
	\ read states and edges, stuff
	
	
	
	loop-flag-continue begin
		0> while
			tape-read \ => read tape-sym at curr-state position
			transition \ => do the transition dance
		repeat

	s" result.tape" tape-to-file
	\ tape-to-stack
	;
