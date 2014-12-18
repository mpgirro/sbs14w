256 Constant tape-length
25 Constant line-length
create tape-addr tape-length cells allot
create line-buffer line-length allot
s" input2.tape" r/w open-file throw Value fd-in

: init-tape ( c-addr u -- ) { tape-input-path path-char-count }
	2 tape-addr !
	try
	1 1 begin
		line-buffer line-length fd-in read-line throw
	  	while
			drop
			\ 0. line-buffer >number drop 2drop .s cr
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
