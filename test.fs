: split ( str len separator len -- tokens count )
  here cr .s cr >r cr .s cr 2swap cr .s cr
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
  2 cells / ;                \ turn byte length into token count
 
: .tokens ( tokens count -- )
  1 ?do dup 2@ type ." ." cell+ cell+ loop 2@ type ;


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
	  		tape-line-buffer cr .s cr swap s>number? 2drop
			tape-addr rot cells + !
			1 + dup
	  	repeat
		drop
	 2 swap tape-addr swap cells + !
	 1 -
	 drop \ TODO: counter wird hiermit derzeit verworfen
	;



