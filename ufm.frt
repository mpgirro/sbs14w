\ 
\ Universal Turing Machine 
\ programed in Forth
\ 

: transition { cur-state tape-sym } ( u1 u2 -- u ) 
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
	 		ptr-move-stay
	 		1
	 		endif
	 	endif
	 over 1 = if \ => terminal state
	 	0 \ do not loop again
	 	endif
	;
	 
	
	 
	 
: ufm ( program-path-str input-path-str -- [output-stack] )

	\ TODO: tape lesen und in den speicher schreiben, constant global variable defined
	\ TODO: transition dynamisch hardcoden
	\ TODO: prepare stack for execution loop

	1 begin	 
		0> while 
			tape-fetch \ => read tape-sym at curr-state position
			transition \ => do the transition dance
		repeat
	tape-to-stack
	;
	 