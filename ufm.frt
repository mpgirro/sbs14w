\ 
\ Universal Turing Machine 
\ programed in Forth
\ 


256 Constant tape-length 
8 Constant line-length 
1 Constant loop-flag-continue
0 Constant loop-flag-stop
Create tape-addr tape-length cells allot
Create line-buffer line-length allot
0 Value fd-in
0 Value fd-out
1 Value tape-ptr

: open-input ( addr u -- )  r/o open-file throw to fd-in ;
: open-output ( addr u -- )  w/o create-file throw to fd-out ;

\ .s word will dump up to the 20 top most elements
20 maxdepth-.s ! 

: debug-dump-stack ( -- u1 u2 u3 ... ) cr .s cr ;

\ reads input-file for the tape and initializes tape memory space
: init-tape ( addr u -- u ) 
	open-input
	tape-length 0 u+do
		2 tape-addr i cells + !
	loop
	
	1 1 begin
		line-buffer line-length fd-in read-line throw
	  	while
	  		line-buffer swap s>number? 2drop
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
			s" 1" fd-out write-line throw
		endif
		2 = if
			cr ." blank"
			s" blank" fd-out write-line throw
		endif
	loop
	
	fd-out close-file throw
	;

\ performs the state transition of the turing machine
\ u1: current state
\ u2: current symbol on the tape position
\ u3: resulting state
\ u4: new symbol on the current tape position 
: transition ( u1 u2 -- u3 u4 ) 
	 over 0 = if
	 	dup 1 = if
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

: ufm ( program-path-str input-path-str -- [output-stack] )

	s" input1.tape" init-tape 

	0 \ => init state q0
	loop-flag-continue begin	  
		0> while 
			tape-read \ => read tape-sym at curr-state position
			transition \ => do the transition dance
		repeat
	
	s" result.tape" tape-to-file
	\ tape-to-stack 
	;
	
