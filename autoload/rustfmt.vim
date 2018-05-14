" Author: Stephen Sugden <stephen@stephensugden.com>
"
" Adapted from https://github.com/fatih/vim-go
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

if !exists("g:rustfmt_autosave")
	let g:rustfmt_autosave = 0
endif

if !exists("g:rustfmt_command")
	let g:rustfmt_command = "rustfmt"
endif

if !exists("g:rustfmt_options")
	let g:rustfmt_options = ""
endif

if !exists("g:rustfmt_fail_silently")
	let g:rustfmt_fail_silently = 0
endif

let s:got_fmt_error = 0

function! s:RustfmtCommandRange(filename, line1, line2)
	let l:arg = {"file": shellescape(a:filename), "range": [a:line1, a:line2]}
	return printf("%s %s --write-mode=overwrite --file-lines '[%s]' %s", g:rustfmt_command, g:rustfmt_options, json_encode(l:arg), shellescape(a:filename))
endfunction

function! s:RustfmtCommand(filename)
	return g:rustfmt_command . " --write-mode=overwrite " . g:rustfmt_options . " " . shellescape(a:filename)
endfunction

function! s:RunRustfmt(command, curw, tmpname)
	if exists("*systemlist")
		let out = systemlist(a:command)
	else
		let out = split(system(a:command), '\r\?\n')
	endif

	if v:shell_error == 0 || v:shell_error == 3
		" remove undo point caused via BufWritePre
		try | silent undojoin | catch | endtry

		" Replace current file with temp file, then reload buffer
		call rename(a:tmpname, expand('%'))
		silent edit!
		let &syntax = &syntax

		" only clear location list if it was previously filled to prevent
		" clobbering other additions
		if s:got_fmt_error
			let s:got_fmt_error = 0
			call setloclist(0, [])
			lwindow
		endif
	elseif g:rustfmt_fail_silently == 0
		" otherwise get the errors and put them in the location list
		let errors = []

		let prev_line = ""
		for line in out
			" error: expected one of `;` or `as`, found `extern`
			"  --> src/main.rs:2:1
			let tokens = matchlist(line, '^\s-->\s\(.\{-}\):\(\d\+\):\(\d\+\)$')
			if !empty(tokens)
				call add(errors, {"filename": @%,
						 \"lnum":	tokens[2],
						 \"col":	tokens[3],
						 \"text":	prev_line})
			endif
			let prev_line = line
		endfor

		if empty(errors)
			% | " Couldn't detect rustfmt error format, output errors
		endif

		if !empty(errors)
			call setloclist(0, errors, 'r')
			echohl Error | echomsg "rustfmt returned error" | echohl None
		endif

		let s:got_fmt_error = 1
		lwindow
		" We didn't use the temp file, so clean up
		call delete(a:tmpname)
	endif

	call winrestview(a:curw)
endfunction

function! rustfmt#FormatRange(line1, line2)
	let l:curw = winsaveview()
	let l:tmpname = expand("%:p:h") . "/." . expand("%:p:t") . ".rustfmt"
	let l:permissions = getfperm(@%)
	call writefile(getline(1, '$'), l:tmpname)
	call setfperm(l:tmpname, l:permissions)

	let command = s:RustfmtCommandRange(l:tmpname, a:line1, a:line2)

	call s:RunRustfmt(command, l:curw, l:tmpname)
endfunction

function! rustfmt#Format()
	let l:curw = winsaveview()
	let l:tmpname = expand("%:p:h") . "/." . expand("%:p:t") . ".rustfmt"
	let l:permissions = getfperm(@%)
	call writefile(getline(1, '$'), l:tmpname)
	call setfperm(l:tmpname, l:permissions)

	let command = s:RustfmtCommand(l:tmpname)

	call s:RunRustfmt(command, l:curw, l:tmpname)
endfunction
