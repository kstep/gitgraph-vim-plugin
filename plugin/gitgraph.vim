
" Common utility functions {{{
function! s:FillList(alist, size, fill)
    let lst = copy(a:alist)
    while len(lst) < a:size
        let lst = add(lst, a:fill)
    endwhile
    return lst
endfunction

function! s:ShellJoin(alist, glue)
    return type(a:alist) == type([]) ? join(map(copy(a:alist), 'shellescape(v:val, 1)'), a:glue) : shellescape(a:alist, 1)
endfunction

function! s:Line(l)
    return type(a:l) == type('') ? line(a:l) : a:l
endfunction

function! s:Col(c)
    return type(a:c) == type('') ? col(a:c) : a:c
endfunction

function! s:GetSynName(l, c)
    return synIDattr(synID(s:Line(a:l), s:Col(a:c), 1), 'name')
endfunction

" a:1 = depth, default to 0
function! s:GetSynRegionName(l, c, ...)
    return synIDattr(synstack(s:Line(a:l), s:Col(a:c))[a:0 > 0 ? a:1 : 0], 'name')
endfunction

function! s:SynSearch(pattern, synnames, back)
    let oldpos = getpos('.')
    while 1
        let found = searchpos(a:pattern, a:back ? 'bW' : 'W')
        if found == [0,0]
            call setpos('.', oldpos)
            echomsg 'No more matches found!'
            break
        endif
        let synname = synIDattr(synID(found[0], found[1], 1), 'name')
        if index(a:synnames, synname) > -1 | break | endif
    endwhile
endfunction

function! s:ExtractLayout(obj)
    return get(g:gitgraph_layout, a:obj, [30,'rb'])
endfunction

" bufname = buffer name to open
" sizes = if int its a width (height if below 0), if < 0 split vertically,
" if string its a layout element to use.
" a:1 = cmd = command to run to fill the new window,
" a:2 = gravity = one of commands la(leftabove)/rb(rightbelow)/tl(topleft)/br(botright)/t(tab).
let s:gitgraph_gravities = {
    \ 't': 'tab ', 'la': 'leftabove ',
    \ 'rb': 'rightbelow ', 'tl': 'topleft ',
    \ 'br': 'botright ' }
function! s:Scratch(bufname, size, ...)

    " parse args at first
    if type(a:size) == type('')
        let [size, gravity] = s:ExtractLayout(a:size)
    else
        let size = a:size
        let gravity = exists('a:2') ? a:2 : 'rb'
    endif

    let gravity = get(s:gitgraph_gravities, gravity, 'rb')

    " negative size opens vertical window
    if size < 0
        let gravity = 'vertical ' . gravity
        let size = -size
    end

    if size > 1 | let gravity = gravity . size | endif

    " now we must try to find buffer with the name
    let bufno = bufnr('^'.a:bufname.'$')

    " no buffer is created yet
    if bufno == -1
        exec gravity . 'new'
        setl noswf nonu nospell bt=nofile bh=hide
        exec 'file ' . escape(a:bufname, ' ')

    " yup, we have a buffer, switch to it
    else
        let winno = bufwinnr(bufno)

        " the buffer is not opened in any window, open it up
        if winno == -1
            exec gravity . 'split +buffer' . bufno

        " the buffer is opened in some window, so switch to it if necessary
        elseif winno != winnr()
            exec winno."wincmd w"
        endif
    endif

    " if we are provided with filling command, run it now
    if exists('a:1') && !empty(a:1)
        setl ma
        1,$delete
        exec a:1
    endif

    " the buffer is not modifiable
    setl noma nomod
    goto 1
    return bufnr('.')
endfunction
" }}}

" Common git helper functions {{{
let s:gitgraph_reponame_cache = {}
function! s:GitGetRepository()
    let curdir = getcwd()
    if has_key(s:gitgraph_reponame_cache, curdir)
        return s:gitgraph_reponame_cache[curdir]
    endif

    let reponame = s:GitSys('rev-parse --git-dir')[:-2]
    if reponame ==# '.git'
        let reponame = curdir
    else
        let reponame = fnamemodify(reponame, ':h')
    endif
    let s:gitgraph_reponame_cache[curdir] = reponame
    return reponame
endfunction

function! s:GitIsSvn()
    let repopath = s:GitGetRepository()
    return isdirectory(repopath.'/svn')
endfunction

function! s:GitIsMerging()
    let repopath = s:GitGetRepository()
    return filereadable(repopath.'/.git/MERGE_HEAD')
endfunction
function! s:GitIsBisecting()
    let repopath = s:GitGetRepository()
    return filereadable(repopath.'/.git/BISECT_LOG')
endfunction

function! s:GitIsRebasing()
    let repopath = s:GitGetRepository()
    for dir in ['rebase-merge', 'rebase-apply', 'rebase'] do
        if isdirectory(repopath.'/.git/'.dir) | return 1 | endif
    endfor
    return 0
endfunction

function! s:GitGetRemoteBranches(svnonly)
    let branches = split(s:GitSys('branch', '-r'), "\n")
    if a:svnonly
        let branches = filter(branches, 'v:val !~ "/"')
    endif
    return branches
endfunction

function! s:GitGetRepoFilename(filename)
    let reponame = s:GitGetRepository()
    let repolen = strlen(reponame)

    if strpart(a:filename, 0, repolen) !=# reponame
        return ''
    endif

    return strpart(a:filename, repolen+1)
endfunction

function! s:GetLineCommit(line)
    return matchstr(getline(a:line), '\<[a-f0-9]\{7,40}\>')
endfunction

function! s:GetRegCommit(regn)
    return split(getreg(a:regn), "\n")
endfunction

function! s:GitBranchCompleter(arg, cline, cpos)
    let lst = join(map(split(s:GitSys('branch'), "\n"), 'v:val[2:]'), "\n")
    return lst
endfunction

function! s:GitDiffBuffer(bufname, cmd, readonly)
    call s:Scratch(a:bufname, 'd', a:cmd)
    setl ft=diff inex=GitGraphGotoFile(v:fname) bh=wipe
    command! -buffer -count=3 GitDiff let b:gitgraph_diff_args[4]=<q-count>|call call('<SID>GitDiff', b:gitgraph_diff_args)
    map <buffer> <C-f> /^diff --git<CR>
    map <buffer> <C-b> ?^diff --git<CR>
    map <buffer> <Tab> /^@@ <CR>
    map <buffer> <S-Tab> ?^@@ <CR>
    map <buffer> ]] /^diff --git<CR>
    map <buffer> [[ ?^diff --git<CR>
    map <buffer> gf :call <SID>GitDiffGotoFile()<CR>
    map <buffer> gd :<C-U>exec v:count1.'GitDiff'<CR>

    if !a:readonly
        map <buffer> dd :call <SID>GitDiffDelete()<CR>
        setl bt=acwrite
        augroup GitDiffView
            au!
            au BufWriteCmd <buffer> setl ma | call s:GitApply('-', 1, 0) | silent undo | setl nomod noma
        augroup end
    endif
endfunction

function! s:GitDiffParseModes(modes, default)
    if empty(a:modes)
        let modes = default
    else
        let modes = ''
        if stridx(a:modes, 'p') >= 0 | let modes .= '-p ' | endif
        if stridx(a:modes, 's') >= 0 | let modes .= '--stat=0,10000 ' | endif
        if stridx(a:modes, 'd') >= 0 | let modes .= '--dirstat ' | endif
        if stridx(a:modes, 'r') >= 0 | let modes .= '--raw ' | endif
        if stridx(a:modes, 'n') >= 0 | let modes .= '--numstat ' | endif
        if stridx(a:modes, 'o') >= 0 | let modes .= '--shortstat ' | endif
    endif
    return modes
endfunction

" returns 1 if workdir is clean, 0 if it has changes.
" if a:1, then checks index in the same way: 1 => index clean, 0 => index has
" changes.
function! s:GitIsClean(...)
    let cached = a:0 && a:1 ? '--cached' : ''
    call s:GitSys('diff', cached, '--quiet', '--exit-code')
    return v:shell_error == 0
endfunction

function! s:GitEnsureClean()
    if s:GitIsClean() | return 1 | endif
    let choice = confirm("The command requires the working copy to be clean,\nbut it has changes. "
                     \ . "I can stash these changes for you.\nShall I proceed?", "&Yes\n&No\nYes, &pop after run")
    if choice == 2 || choice == 0 | return 0 | endif
    call s:GitStashSave('')
    return choice == 1 ? 1 : 2
endfunction

" }}}

" Exported functions {{{
function! GitGraphFolder(lnum)
    let regex = '\([0-9][|] \)* [*] '
    let bline = matchstr(getline(a:lnum-1), regex)
    let aline = matchstr(getline(a:lnum+1), regex)
    let line = matchstr(getline(a:lnum), regex)
    return bline ==# line && aline ==# line
endfunction

function! GitGraphGotoFile(fname)
    let repopath = s:GitGetRepository()
    let fname = a:fname
    if fname =~# '^[ab]/' | let fname = fname[2:] | endif
    if !empty(repopath) | let fname = repopath . '/' . fname | endif
    return fname
endfunction
" }}}

" GitGraph view implementation {{{
function! s:GitGraphMappings()
    command! -buffer -range GitYankRange call setreg(v:register, <SID>GetLineCommit(<line1>)."\n".<SID>GetLineCommit(<line2>), "l")
    command! -buffer -bang -range GitRebase call <SID>GitRebase(<SID>GetLineCommit(<line1>), <SID>GetLineCommit(<line2>), '', <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer -bang GitRebaseOnto :let rng = <SID>GetRegCommit(v:register) | call <SID>GitRebase(rng[0], rng[1], <SID>GetLineCommit('.'), <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer -bang GitRebaseCurrent call <SID>GitRebase('', <SID>GetLineCommit('.'), '', <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer -bang -nargs=* -range GitDiff call <SID>GitDiff(<SID>GetLineCommit(<line1>), <SID>GetLineCommit(<line2>), <q-bang>=='!', <f-args>)
    command! -buffer -range GitDiffSplit call <SID>GitDiffSplit(expand('#:p'), <SID>GetLineCommit(<line1>), <SID>GetLineCommit(<line2>))
    command! -buffer GitShow call <SID>GitShow(<SID>GetLineCommit('.'))
    command! -buffer -bang GitNextRef call <SID>GitGraphNextRef(<q-bang>=='!')

    command! -buffer -bang GitDelete call <SID>GitDelete(expand('<cword>'), <SID>GetSynName('.', '.'), <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer -bang GitRevert call <SID>GitRevert(<SID>GetLineCommit('.'), <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer GitBranch call <SID>GitBranch(<SID>GetLineCommit('.'), input("Enter new branch name: ")) | call <SID>GitGraphView()
    command! -buffer GitBranchRename call <SID>GitBranchRename(expand('<cword>'), input("Enter new branch name: ", expand('<cword>'))) | call <SID>GitGraphView()

    command! -buffer -bang GitTag call <SID>GitTag(<SID>GetLineCommit('.'), input("Enter new tag name: "), <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer -bang GitSignedTag call <SID>GitCommitView(<SID>GetLineCommit('.'), 0, 'c', 1, 1)
    command! -buffer -bang GitAnnTag call <SID>GitCommitView(<SID>GetLineCommit('.'), 0, 'c', 0, 1)

    command! -buffer -bang GitPush call <SID>GitPush(expand('<cword>'), <SID>GetSynName('.', '.'), <q-bang>=='!') | call <SID>GitGraphView()
    command! -buffer GitPull call <SID>GitPull(expand('<cword>'), <SID>GetSynName('.', '.')) | call <SID>GitGraphView()
    command! -buffer GitCheckout call <SID>GitCheckout(expand('<cword>'), <SID>GetSynName('.', '.')) | call <SID>GitGraphMarkHead()

    command! -buffer GitSVNRebase call <SID>GitSVNRebase(expand('<cword>'), <SID>GetSynName('.', '.')) | call <SID>GitGraphView()
    command! -buffer GitSVNDcommit call <SID>GitSVNDcommit(expand('<cword>'), <SID>GetSynName('.', '.')) | call <SID>GitGraphView()
    command! -buffer -bang GitSVNFetch call <SID>GitSVNFetch(<q-bang>=='!') | call <SID>GitGraphView()

    command! -buffer -bang -count GitCommit call <SID>GitCommitView(<SID>GetLineCommit('.'), <q-bang>=='!', 'c', <q-count>)
    command! -buffer -bang GitReset call <SID>GitReset(<SID>GetLineCommit('.'), <q-bang>=='!' ? 'h' : '') | call <SID>GitGraphView()

    command! -buffer -bang GitCherryPick call <SID>GitCherryPick(<SID>GetLineCommit('.'), <q-bang>=='!') | call <SID>GitGraphView()

    " (y)ank range into buffer and (r)ebase onto another branch
    map <buffer> Y :GitYankRange<cr>
    vmap <buffer> Y :GitYankRange<cr>
    map <buffer> R :GitRebaseOnto<cr>
    map <buffer> r :GitRebaseCurrent<cr>

    " (d)elete (w)ord: branch/tag/remote..., force with DW
    map <buffer> dw :GitDelete<cr>
    map <buffer> DW :GitDelete!<cr>
    " (d)elete commit, aka revert, (D)on't commit
    map <buffer> dd :GitRevert<cr>
    map <buffer> DD :GitRevert!<cr>
    " reset (hard) current HEAD
    map <buffer> xx :GitReset<cr>
    map <buffer> XX :GitReset!<cr>

    " (g)o (b)ranch, (p)ush, p(u)ll
    map <buffer> gp :GitPush<cr>
    map <buffer> gu :GitPull<cr>
    map <buffer> gb :GitCheckout<cr>

    " (a)dd (b)ranch, (t)ag, (a)nnotated/(s)igned tag, (c)ommit, a(m)end, (p)icked
    map <buffer> ab :GitBranch<cr>
    map <buffer> ar :GitBranchRename<cr>
    map <buffer> at :GitTag<cr>
    map <buffer> aa :GitAnnTag<cr>
    map <buffer> as :GitSignedTag<cr>
    map <buffer> ac :GitCommit<cr>
    map <buffer> am :GitCommit!<cr>
    map <buffer> ap :GitCherryPick<cr>
    map <buffer> aP :GitCherryPick!<cr>

    " (g)o (r)ebase (interactive), (d)iff, (f)ile (aka commit)
    vmap <buffer> gr :GitRebase<space>
    vmap <buffer> gR :GitRebase!<cr>
    map <buffer> gd :GitDiff<cr>
    map <buffer> gD :GitDiffSplit<cr>
    map <buffer> <CR> :GitShow<cr>

    " like gu/gp, but for git-svn
    map <buffer> gU :GitSVNRebase<cr>
    map <buffer> gP :GitSVNDcommit<cr>
    " fetch unfetched revisions from svn: (g)o (s)vn (parent only)
    map <buffer> gs :GitSVNFetch<cr>
    map <buffer> gS :GitSVNFetch!<cr>

    map <buffer> <Tab> :GitNextRef<cr>
    map <buffer> <S-Tab> :GitNextRef!<cr>
endfunction

function! s:GitGraphNew(branch, afile)
    let repopath = s:GitGetRepository()
    let reponame = fnamemodify(repopath, ':t')
    call s:Scratch('git-graph:'.reponame, 'g')
    let b:gitgraph_file = a:afile
    let b:gitgraph_branch = a:branch
    let b:gitgraph_repopath = repopath
    exec 'lcd ' . repopath
    au ColorScheme <buffer> setl ft=gitgraph | call s:GitGraphMarkHead()
    call s:GitGraphMappings()
endfunction

function! s:GitGraphMarkHead()
    let commit = s:GitSys('rev-parse --short HEAD')[:-2]
    let branch = s:GitSys('symbolic-ref -q HEAD')[11:-2]
    silent! syn clear gitgraphHeadRefItem
    exec 'syn keyword gitgraphHeadRefItem ' . commit . ' ' . branch . ' contained'
endfunction

function! s:GitGraphNextRef(back)
    call s:SynSearch('\<\([a-z]\+:\)\?[a-zA-Z0-9./_-]\+\>',
            \ ["gitgraphBranchItem", "gitgraphHeadRefItem",
            \ "gitgraphTagItem", "gitgraphRemoteItem",
            \ "gitgraphStashItem", "gitgraphSvnItem"], a:back)
endfunction

" a:1 - branch, a:2 - order, a:3 - file
function! s:GitGraphView(...)
    let branch = exists('a:1') && !empty(a:1) ? a:1 : ''
    let order = exists('a:2') && a:2 ? 'date' : 'topo'
    let afile = exists('a:3') && !empty(a:3) ? a:3 : ''

    if exists('b:gitgraph_repopath')
        if empty(afile) | let afile = b:gitgraph_file | endif
        if empty(branch) | let branch = b:gitgraph_branch | endif
        exec 'lcd ' . b:gitgraph_repopath
    else
        call s:GitGraphNew(branch, afile)
    endif

    let cmd = s:GitPipe('.', 'log', '--graph', '--decorate=full', '--date='.g:gitgraph_date_format, '--format=format:'.s:gitgraph_graph_format, '--abbrev-commit', '--color', '--'.order.'-order', branch, '--', afile)
    setl ma
    1,$delete
    exec cmd

    silent! %s/\*\( *\)/*\1/ge
    silent! %s/\[\(1;\)\=3\([0-9]\)m\([\|/_.-]\)\[m/\2\3/ge
    silent! %s/\[[0-9]*m//ge
    silent! %s/\([0-9]\)\([\|/_.-]\(\1[\|/_.-]\)\+\)/\=submatch(1).substitute(submatch(2),submatch(1),'','g')/ge

    silent! g/refs\/tags\//s/\(tag: \)\?refs\/tags\//t:/ge
    silent! g/refs\/remotes\//s/refs\/remotes\/\([^\/,)]\{-1,}\/\)\@=/r:/ge|s/refs\/remotes\//s:/ge
    silent! g/refs\/heads/s/refs\/heads\///ge
    silent! g/refs\/stash/s/refs\/stash/stash/ge

    goto 1

    setl bt=nofile bh=delete ft=gitgraph fde=GitGraphFolder(v:lnum) isk=:,a-z,A-Z,48-57,.,_,-,/ fdm=expr nowrap noma nomod noswf cul
    let &l:grepprg = s:gitgraph_git_path . ' grep -n $* -- ' . escape(b:gitgraph_repopath, ' ')
    call s:GitGraphMarkHead()
endfunction
" }}}

" GitStatus view implementation {{{
function! s:GitStatusNextFile(back)
    call s:SynSearch('[\[{][ =+*-][\]}]', ['gitModFile', 'gitNewFile', 'gitDelFile', 'gitUntFile'], a:back)
endfunction

function! s:GitStatusGetFile(lineno)
    let synname = s:GetSynName(a:lineno, 5)
    if synname =~ 'git.*File'
        return getline(a:lineno)[5:]
    endif
    return ''
endfunction

function! s:GitStatusGetFilesDict(l1, l2)
    let filelist = {}
    for lineno in range(a:l1, a:l2)
        let fname = s:GitStatusGetFile(lineno)
        if !empty(fname)
            let synname = s:GetSynName(lineno, 5)
            if !has_key(filelist, synname) | let filelist[synname] = [] | endif
            call add(filelist[synname], fname)
        endif
    endfor
    return filelist
endfunction

function! s:GitStatusGetFiles(l1, l2)
    let filelist = []
    for lineno in range(a:l1, a:l2)
        let fname = s:GitStatusGetFile(lineno)
        if !empty(fname)
            call add(filelist, fname)
        endif
    endfor
    return filelist
endfunction

function! s:GitStatusRevertFile(fname, region)
    if empty(a:fname) | return | endif
    if a:region ==# 'gitStaged'
        call s:GitResetFiles(a:fname)
    elseif a:region ==# 'gitUnstaged'
        call s:GitCheckoutFiles(a:fname, 1)
    elseif a:region ==# 'gitUntracked'
        call s:GitRemoveFiles(a:fname)
    elseif a:region ==# 'gitUnmerged'
        let side =  confirm("Which side should I checkout?", "&Theirs\n&Ours")
        if !side | return | endif
        call s:GitCheckoutFiles(a:fname, [0, 't', 'o'][side])
    else
        return
    endif
endfunction

function! s:GitStatusAddFile(fname, region)
    if empty(a:fname) | return | endif
    if a:region ==# 'gitUnstaged' || a:region ==# 'gitUntracked' || a:region ==# 'gitUnmerged'
        if type(a:fname) == type({})
            call s:GitAddFiles(get(a:fname, 'gitUntFile', []))
            call s:GitAddFiles(get(a:fname, 'gitModFile', []))

            call s:GitAddFiles(get(a:fname, 'gitMModFile', []))
            call s:GitAddFiles(get(a:fname, 'gitMNewFile', []))

            call s:GitPurgeFiles(get(a:fname, 'gitDelFile', []))
            call s:GitPurgeFiles(get(a:fname, 'gitMDelFile', []))
        else
            call s:GitAddFiles(a:fname)
        endif
    else
        return
    endif
endfunction

function! s:GitStatusMappings()
    command! -buffer -bang GitNextFile call <SID>GitStatusNextFile(<q-bang>==1)
    command! -buffer -range GitRevertFile call <SID>GitStatusRevertFile(<SID>GitStatusGetFiles(<line1>, <line2>), <SID>GetSynRegionName(<line1>, '.')) | call <SID>GitStatusView()
    command! -buffer -range GitAddFile call <SID>GitStatusAddFile(<SID>GitStatusGetFilesDict(<line1>, <line2>), <SID>GetSynRegionName(<line1>, '.')) | call <SID>GitStatusView()
    command! -buffer -range GitDiff call <SID>GitDiff('', '', <SID>GetSynRegionName('.', '.') ==# 'gitStaged', <SID>GitStatusGetFiles(<line1>, <line2>))

    map <buffer> <Tab> :GitNextFile<cr>
    map <buffer> <S-Tab> :GitNextFile!<cr>
    map <buffer> dd :GitRevertFile<cr>
    map <buffer> yy :GitAddFile<cr>
    map <buffer> gd :GitDiff<cr>
    map <buffer> gf <C-w>gf
endfunction

function! s:GitStatusView()
    let repopath = s:GitGetRepository()
    let cmd = 'lcd ' . repopath . ' | setl enc=latin1 | ' . s:GitPipe('.', 'status')

    call s:Scratch('git-status:'.fnamemodify(repopath, ':t'), 's', cmd)
    setl ma

    "silent! 1,/^#\( Changes\| Changed\| Untracked\| Unmerged\)/-1delete
    silent! g!/^#\( On branch \| Changes\| Changed\| Untracked\| Unmerged\|\t\|\s*$\)/delete
    silent! g/^#\( Changes\| Changed\| Untracked\| Unmerged\)/.+1delete

    silent! %s/^#\tnew file:\s\+/\t[+] /e
    silent! %s/^#\tmodified:\s\+/\t[*] /e
    silent! %s/^#\tdeleted:\s\+/\t[-] /e
    silent! %s/^#\trenamed:\s\+/\t[=] /e
    silent! %s/^#\tcopied:\s\+/\t[>] /e
    silent! %s/^#\tunknown:\s\+/\t[?] /e
    silent! %s/^#\tunmerged:\s\+/\t[%] /e
    silent! %s/^#\ttypechange:\s\+/\t[@] /e

    silent! %s/^#\tboth modified:\s\+/\t{*} /e
    silent! %s/^#\tboth added:\s\+/\t{+} /e
    silent! %s/^#\tboth deleted:\s\+/\t{-} /e

    silent! %s/^#\tadded by us:\s\+/\t[+} /e
    silent! %s/^#\tdeleted by us:\s\+/\t[-} /e
    silent! %s/^#\tadded by them:\s\+/\t{+] /e
    silent! %s/^#\tdeleted by them:\s\+/\t{-] /e

    silent! %s/^#\t/\t[ ] /e
    silent! %s/^#\s*$//e

    " I use double conversion latin1->utf-8 in order to unescape
    " octal-escaped utf-8 file names, which can contain git-status output.
    " I used to use the following perl snippet to do the same thing w/o
    " encoding resetting:
    "if has('perl') || has('perl/dyn')
    "    silent! g/^\t\[.\] \".*\"$/perldo s/\\([0-7]{1,3})|(")/if($2){""}else{$c=oct($1);if(($c&0xc0)==0x80){$a=($a<<6)|($c&63);$i--}else{for($m=0x80,$i=-1;($m&$c)!=0;$m>>=1){$i++};$a=$c&($m-1)};$i>0?"":chr($a)}/ge
    "end
    silent! g/^\t[\[{].[\]}] \"/s/\\\([0-7]\+\)/\=eval('"\<Char-0'.submatch(1).'>"')/ge
    setl enc=utf-8

    setl ts=4 noma nomod ft=gitstatus fdm=syntax nowrap cul
    goto 1

    call s:GitStatusMappings()
endfunction
" }}}

" GitCommit view implementation {{{
" a:1 = tag mode, a:2 = tagname, a:3 = key id
function! s:GitCommitView(msg, amend, src, signoff, ...)
    call s:Scratch('git-commit', 'c', '1') | setl ma

    let tagmode = 0
    let submessage = []

    if a:src == 'c'
        let message = substitute(s:GitSys('cat-file', 'commit', a:msg), '^.\{-}\n\n', '', '')
        let b:gitgraph_commit_hash = a:msg
        let tagmode = exists('a:1') ? a:1 : 0
        if tagmode
            let message = message . "\nTag: " . (exists('a:2') && !empty(a:2) ? a:2 : '')
            let b:gitgraph_commit_tag = 1
            let b:gitgraph_commit_key = exists('a:3') ? a:3 : ''
            call add(submessage, '## ⁰This is a '.(a:signoff ? 'signed ' : '').'tag commit.'
                        \ .(empty(b:gitgraph_commit_key) ? '' :
                            \ ' It will be signed with '.b:gitgraph_commit_key.' key.')
                        \ .' Please enter tag name on line with “Tag” above.')
        endif
    elseif a:src == 'f'
        let message = readfile(a:msg)
    elseif a:amend && empty(a:msg)
        let message = substitute(s:GitSys('cat-file', 'commit', 'HEAD'), '^.\{-}\n\n', '', '')
    else
        let editmsg = s:GitGetRepository() . '/.git/' . (s:GitIsMerging() ? 'MERGE_MSG' : 'COMMIT_EDITMSG')
        echomsg editmsg
        if empty(a:msg) && filereadable(editmsg)
            let message = readfile(editmsg)
            call filter(message, 'strpart(v:val, 0, 1) != "#"')
        else
            let message = a:msg
        endif
    endif

    silent 0put =message

    silent put ='## -------------------------------------------------------------------------------------'
    silent put ='## Enter commit message here. Write it (:w) to commit or close the buffer (:q) to cancel.'
    silent put ='## Lines starting with ## are removed from commit message.'

    if a:amend | call add(submessage, '## ¹This is an amend commit on top of current branch.') | endif
    if a:signoff && !tagmode | call add(submessage, '## ²This commit will be signed off with your signature.') | endif

    if !empty(submessage)
        silent put =submessage
    endif

    setl ft=gitcommit bt=acwrite bh=wipe nomod
    let b:gitgraph_commit_amend = a:amend
    let b:gitgraph_commit_signoff = a:signoff
    goto 1
    augroup GitCommitView
        au!
        if empty(tagmode)
            au BufWriteCmd <buffer> call s:GitCommitBuffer()
        else
            au BufWriteCmd <buffer> call s:GitTagBuffer()
        endif
    augroup end
endfunction

function! s:GetMessageBuffer(buf)
    let message = getbufline(a:buf, 1, '$')
    call filter(message, 'strpart(v:val, 0, 2) != "##"')
    return message
endfunction

function! s:GitCommitBuffer()
    if s:GitIsClean(1)
        if !s:GitIsClean() && 1 == confirm('No changes were staged. Shall I commit all changes?', "&Yes\n&No")
            call s:GitSys('add -u')
        elseif !b:gitgraph_commit_amend
            echomsg "No files to commit!"
            return
        endif
    endif
    silent g/^##/delete
    call s:GitCommit('-', b:gitgraph_commit_amend, b:gitgraph_commit_signoff, 'f')
    setl nomod
    bwipeout!
endfunction

function! s:GitTagBuffer()
    let tagline = search('^Tag: ', 'nw')
    if tagline < 1 | return | endif
    let tagname = matchstr(getline(tagline), '\h\w+', 5)
    if empty(tagname) | return | endif

    exec tagline.'delete'
    silent g/^##/delete
    set nomod
    call s:GitTag(b:gitgraph_commit_hash, tagname, 0, b:gitgraph_commit_signoff ? 's' : 'a', '-', 1, b:gitgraph_commit_key)
    bwipeout!
endfunction
" }}}

" GitStash view implementation {{{
function! s:GitStashView()
    let cmd = s:GitPipe('.', 'stash list')
    call s:Scratch('git-stash:'.fnamemodify(s:GitGetRepository(), ':t'), 't', cmd)
    setl ma
    silent! %s/^stash@{[0-9]\+}: //e
    silent! g/^\s*$/d
    setl noma nomod cul nowrap
    goto 1

    command! -buffer -bang GitStashApply call <SID>GitStashApply(line('.')-1, <q-bang>=='!') | call <SID>GitStashView()
    command! -buffer GitStashRemove call <SID>GitStashRemove(line('.')-1) | call <SID>GitStashView()
    command! -buffer -count=3 GitStashDiff call <SID>GitStashDiff(line('.')-1, <q-count>)

    map <buffer> dd :GitStashRemove<CR>
    map <buffer> yy :GitStashApply<CR>
    map <buffer> xx :GitStashApply!<CR>
    map <buffer> gd :GitStashDiff<CR>
endfunction
" }}}

" GitRemote view implementation {{{
function! s:GitRemoteView()
    call s:Scratch('git-remote:'.fnamemodify(s:GitGetRepository(), ':t'), 'r', s:GitPipe('.', 'remote', '--verbose'))
    setl ma
    silent %s/ (\S\+)$//e
    sort u
    setl noma nomod cul nowrap

    command! -buffer GitRemoteAdd call <SID>GitRemoteAdd(input('Enter remote name: '), input('Enter remote URL: '))
    command! -buffer GitRemoteRemove call <SID>GitRemoteRemove(matchstr(getline('.'), '^.*\t\@='))

    map <buffer> o :GitRemoteAdd<CR>
    map <buffer> dd :GitRemoteRemove<CR>
endfunction
" }}}

" GitBranches view implementation {{{
function! s:GitBranchesView()
    call s:Scratch('git-branches:'.fnamemodify(s:GitGetRepository(), ':t'), 'r', s:GitPipe('.', 'branch', '-v'))
endfunction
" }}}

" Initializator {{{
function! s:GitGraphInit()

    if !empty(v:servername)
        let $GIT_EDITOR = 'vim --servername "'.v:servername.'" --remote-tab-wait'
    endif

    " commits subject format to show in graph, defaults to simple commit subject
    if !exists('g:gitgraph_subject_format') || empty(g:gitgraph_subject_format)
        let g:gitgraph_subject_format = '%s'
    end

    " authorship mark, placed after commit subject in tree, defaults to author
    " name & timestamp
    if !exists('g:gitgraph_authorship_format') || empty(g:gitgraph_authorship_format)
        let g:gitgraph_authorship_format = '%aN, %ad'
    end

    " date format to show in authorship mark in graph, defaults to "short"
    " format, like "3 days ago"
    if !exists('g:gitgraph_date_format') || empty(g:gitgraph_date_format)
        let g:gitgraph_date_format = 'short'
    end

    " git path, if not set git sohuld be in your PATH
    if !exists('g:gitgraph_git_path') || empty(g:gitgraph_git_path)
        let g:gitgraph_git_path = 'git'
    endif

    " gitgraph layout configuration, defines how to place different views namely:
    " g = (g)raph view,
    " s = (s)tatus view,
    " t = s(t)ash view,
    " d = (d)iff view,
    " c = (c)ommit view,
    " v = (v)imdiff view,
    " r = (r)emotes view,
    " f = new (f)ile opened from any view (currently diff or status),
    " l = (l)ayout: open these objects in order when activating plugin.
    " format: [gstdcf]:<size>:<gravity>,...,l:[gstdcf]+
    " for size & gravity discription see s:Scratch().
    if !exists('g:gitgraph_layout') || empty(g:gitgraph_layout)
        let g:gitgraph_layout = { 'g':[20,'la'], 's':[-30,'tl'], 't':[5,'rb'], 'd':[0,'br'],
                    \ 'c':[10,'br'], 'v':[0,'rb'], 'f':[0,'rb'], 'r':[5,'rb'], 'l':['g','s','t','r'] }
    endif

    let s:gitgraph_git_path = g:gitgraph_git_path
    let s:gitgraph_graph_format = shellescape('%Creset%h%d ' . g:gitgraph_subject_format . ' [' . g:gitgraph_authorship_format . ']', 1)

    command! -nargs=* -complete=custom,<SID>GitBranchCompleter GitGraph call <SID>GitGraphView(<f-args>)
    command! GitStatus call <SID>GitStatusView()
    command! -bang -count -nargs=? GitCommit call <SID>GitCommitView(<q-args>, <q-bang>=='!', '', <q-count>)
    command! -bang -count=3 GitDiff call <SID>GitDiff('HEAD', 'HEAD', <q-bang>=='!', expand('%:p'), <q-count>)
    command! -count GitDiffSplit call <SID>GitDiffSplit(expand('%:p'), 'HEAD~'.<q-count>)
    command! GitRemote call <SID>GitRemoteView()
    command! GitStash call <SID>GitStashView()
    command! -count GitRebaseContinue call <SID>GitRebaseGoOn(<q-count>, <q-bang>=='!')
    command! GitRebaseGoOn let way=confirm('Which way?', "&Continue\n&Skip\n&Abort")|if way|call <SID>GitRebaseGoOn(way!=2,way==3)|endif

    command! -nargs=? GitStashSave call <SID>GitStashSave(<q-args>)
    command! GitAddFile call <SID>GitAddFiles(expand('%:p'))

    command! GitLayout call <SID>GitLayout()

    map ,gg :GitGraph "--all"<cr>
    map ,gs :GitStatus<cr>
    map ,gc :GitCommit<cr>
    map ,gC :GitCommit!<cr>
    map ,gd :<C-U>exec (v:count == 0 ? 3 : v:count)."GitDiff"<cr>
    map ,gD :<C-U>exec v:count1."GitDiffSplit"<CR>
    map ,gt :GitStash<cr>
    map ,gr :GitRemote<cr>
    map ,gn :GitRebaseGoOn<cr>

    map ,ga :GitAddFile<cr>
    map ,gA :GitStashSave<cr>
    map ,gf :exec 'GitGraph "--all" 0 '.expand('%:p')<cr>

    map ,go :GitLayout<cr>

    map ,gb :GitBranches<cr>
endfunction
" }}}

" Layout {{{
function! s:GitLayout()
    let layout = get(g:gitgraph_layout, 'l', ['g','s'])
    for obj in layout
        if obj == 'g'
            call s:GitGraphView()
        elseif obj == 's'
            call s:GitStatusView()
        elseif obj == 't'
            call s:GitStashView()
        elseif obj == 'r'
            call s:GitRemoteView()
        elseif obj == 'b'
            call s:GitBranchesView()
        endif
    endfor
endfunction
" }}}

" Git commands interface {{{
function! s:GitCmd(args)
    return s:gitgraph_git_path . ' ' . join(a:args, ' ')
endfunction

" just run simple git command
function! s:GitRun(...)
    exec 'silent !' . s:GitCmd(a:000)
endfunction
" returns git command setup to pipe current buffer contents through it
function! s:GitPipe(rng, ...)
    return 'silent '.a:rng.'!' . s:GitCmd(a:000)
endfunction
" runs git command and returns its output
function! s:GitSys(...)
    return system(s:GitCmd(a:000))
endfunction

" a:1 = force
function! s:GitBranch(commit, branch, ...)
    if !empty(a:branch)
        let force = a:0 && a:1 ? '-f' : ''
        call s:GitRun('branch', force, shellescape(a:branch, 1), a:commit)
    endif
endfunction

" a:1 = force
function! s:GitBranchRename(branch, newname, ...)
    if !empty(a:branch) && !empty(a:newname) && a:newname != a:branch
        let force = a:0 && a:1 ? '-M' : '-m'
        call s:GitRun('branch', force, shellescape(a:branch, 1), shellescape(a:newname, 1))
    endif
endfunction

" a:1 = force, a:2 = mode (none/'a'/'s'), a:3 = message, a:4 = from file, a:5 = key id
function! s:GitTag(commit, tag, ...)
    if !empty(a:tag)
        let mode = ''
        if exists('a:2')
            if a:2 ==# 'a'
                let mode = '-a'
            elseif a:2 ==# 's'
                let mode = exists('a:5') && !empty(a:5) ? '-u '.a:5 : '-s'
            endif
        endif
        if empty(mode)
            let msgparam = ''
            let message = ''
        else
            if !exists('a:3') || empty(a:3) | return | endif
            let msgparam = exists('a:4') && a:4 ? '-F' : '-m'
            let message = shellescape(a:3, 1)
        endif
        let force = exists('a:1') && a:1 ? '--force' : ''
        if msgparam == '-F' && msg == '-'
            exec s:GitPipe('%', 'tag', force, mode, msgparam, message, shellescape(a:tag, 1), a:commit)
        else
            call s:GitRun('tag', force, mode, msgparam, message, shellescape(a:tag, 1), a:commit)
        endif
    endif
endfunction

" a:1 - nocommit, a:2 - noff, a:3 - squash
function! s:GitMerge(tobranch, frombranch, ...)
    if !empty(a:tobranch) && !empty(a:frombranch)
        let nocommit = exists('a:1') && a:1 '--no-commit' : '--commit'
        let nofastfwd = exists('a:2') && a:2 '--no-ff' : '--ff'
        let squash = exists('a:3') && a:3 '--squash' : '--no-squash'
        call s:GitRun('checkout', shellescape(a:tobranch, 1))
        call s:GitRun('merge', nocommit, nofastfwd, squash, shellescape(a:frombranch, 1))
    endif
endfunction

" a:1 = interactive
function! s:GitRebase(branch, upstream, onto, ...)
    if !empty(a:upstream)
        let onto = empty(a:onto) ? a:upstream : a:onto
        let iact = exists('a:1') && a:1 ? '--interactive' : ''
        call s:GitRun('rebase', iact, '--onto', onto, a:upstream, a:branch)
    endif
endfunction

" a:1 = skip
function! s:GitRebaseGoOn(continue, ...)
    if a:continue
        let action = exists('a:1') && a:1 ? '--skip' : '--continue'
    else
        let action = '--abort'
    endif
    call s:GitRun('rebase', action)
endfunction

" a:1 = cached, a:2 = files, a:3 = context lines, a:4 = mode
" mode = list of modes: p/s/d/r/o/n for patch, stat, dirstat, raw,
" shortstat and numstat, defaults to p
function! s:GitDiff(fcomm, tcomm, ...)
    let cached = exists('a:1') && a:1 ? '--cached' : ''
    let paths = exists('a:2') && !empty(a:2) ? s:ShellJoin(a:2, ' ') : ''
    let ctxl = exists('a:3') ? '-U'.a:3 : ''
    let modes = exists('a:4') ? s:GitDiffParseModes(a:4, '-p') : '-p'
    let cmd = s:GitPipe('.', 'diff', modes, cached, ctxl, a:tcomm, a:fcomm != a:tcomm ? a:fcomm : '', '--', paths)
    call s:GitDiffBuffer('git-diff', cmd, 0)
    let b:gitgraph_diff_args = [ a:fcomm, a:tcomm ] + s:FillList(a:000, 3, 0)
endfunction

function! s:GitDiffGotoFile()
    " first try to go to file normally
    let cfile = GitGraphGotoFile(expand('<cfile>'))
    if filereadable(cfile)
        exec 'edit! '.cfile
        return
    endif

    " get header position
    let hdrpos = search('^+++ ', 'nbW')
    if hdrpos < 1 | return | endif
    let chdrpos = search('^@@ ', 'nbW')
    if chdrpos < 1 | return | endif

    " now get chunk position in original file
    let chunkpos = matchlist(getline(chdrpos), '+\([0-9]\+\),')[1]
    if empty(chunkpos) | return | endif

    " now get diff lines present in current file from header to current pos
    let offlines = filter(getbufline('%', chdrpos+2, line('.')), 'v:val =~ "^[ +]"')

    " and original file name from header
    let origfile = strpart(getline(hdrpos), 5)
    let repopath = s:GitGetRepository()

    " now we have: original file name, first line of chunk in it and
    " lines from chunk's start to our destination pos, so just
    " open the file and goto to position we seek!
    exec 'edit! '. repopath . origfile
    exec len(offlines)+chunkpos
endfunction

function! s:GitDiffDelete()
    let line = getline('.')
    let hunk = strpart(line, 0, 2)
    if hunk == '@@' " remove whole hunk
        try
            setl ma | .,/^@@/-1delete | setl noma
        catch /E493/
            setl ma | .,$delete | setl noma
        endtry
    elseif hunk == '++' || hunk == '--' " remove whole file
        setl ma | ?^---?,/^---/-1delete | setl noma
    elseif strpart(hunk, 0, 1) == '+' " remove added line
        setl ma | delete | setl noma
    elseif strpart(hunk, 0, 1) == '-' " remove removed line (make it context)
        setl ma | call setline('.', ' '.strpart(line, 1)) | setl noma
    endif
endfunction

" a:1 = modes, the same as in s:GitDiff()
function! s:GitShow(commit, ...)
    if !empty(a:commit)
        let modes = exists('a:1') ? s:GitDiffParseModes(a:1, '-p --stat=0,10000') : '-p --stat=0,10000'
        let cmd = s:GitPipe('.', 'show', modes, a:commit)
        call s:GitDiffBuffer('git-show', cmd, 1)
        setl ft=diff.gitlog.gitstat
    endif
endfunction

function! s:GitShowFile(commit, filename, size, gravity)
    let gitfname = a:commit.':'.a:filename
    let cmd = s:GitPipe('.', 'show', gitfname)
    call s:Scratch('git:'.gitfname, a:size, cmd, a:gravity)
    filetype detect
endfunction

" a:1 - force
function! s:GitPush(word, syng, ...)
    if a:syng == 'gitgraphRemoteItem'
        let parts = split(a:word[2:], '/')
        let force = exists('a:1') && a:1 ? '-f' : ''
        call s:GitRun('push', force, parts[0], join(parts[1:], '/'))
    endif
endfunction

function! s:GitCheckout(word, syng)
    if a:syng == 'gitgraphBranchItem' || a:syng == 'gitgraphSvnItem'
        call s:GitRun('checkout', a:word)
    endif
endfunction

function! s:GitPull(word, syng)
    if a:syng == 'gitgraphRemoteItem'
        let parts = split(a:word[2:], '/')
        call s:GitRun('pull', parts[0], join(parts[1:], '/'))
    endif
endfunction

" a:1 - force
function! s:GitDelete(word, syng, ...)
    let force = exists('a:1') && a:1
    if a:syng == 'gitgraphBranchItem' || a:syng == 'gitgraphSvnItem'
        let par = force ? '-D' : '-d'
        let cmd = 'branch ' . par . ' ' . a:word
    elseif a:syng == 'gitgraphTagItem'
        let cmd = 'tag -d ' . a:word[2:]
    elseif a:syng == 'gitgraphRemoteItem'
        let par = force ? '-f' : ''
        let parts = split(a:word[2:], "/")
        let cmd = 'push ' . par . ' ' . parts[0] . ' ' . join(parts[1:], '/') . ':'
    else
        return
    endif
    call s:GitRun(cmd)
endfunction

function! s:GitSVNRebase(word, syng)
    let clean = s:GitEnsureClean()
    if clean
        call s:GitCheckout(a:word, a:syng)
        call s:GitRun('svn rebase')
        if clean == 2 | call s:GitStashApply(0, 1) | endif
    endif
endfunction

function! s:GitSVNDcommit(word, syng)
    let clean = s:GitEnsureClean()
    if clean
        call s:GitCheckout(a:word, a:syng)
        call s:GitRun('svn dcommit')
        if clean == 2 | call s:GitStashApply(0, 1) | endif
    endif
endfunction

" a:1 = parent only
function! s:GitSVNFetch(...)
    let parent = exists('a:1') && a:1 ? '--parent' : ''
    call s:GitRun('svn fetch', parent)
endfunction

" a:1 = force
function! s:GitAddFiles(fname, ...)
    if empty(a:fname) | return | endif
    let files = s:ShellJoin(a:fname, ' ')
    let force = exists('a:1') && a:1 ? '--force' : ''
    call s:GitRun('add', force, '--', files)
endfunction

" a:1 = force, a:2 = index
function! s:GitPurgeFiles(fname, ...)
    if empty(a:fname) | return | endif
    let files = s:ShellJoin(a:fname, ' ')
    let force = exists('a:1') && a:1 ? '--force' : ''
    let index = exists('a:2') && a:2 ? '--cached' : ''
    call s:GitRun('rm -r', force, index, '--', files)
endfunction

function! s:GitResetFiles(fname)
    if empty(a:fname) | return | endif
    let files = s:ShellJoin(a:fname, ' ')
    call s:GitRun('reset', '--', files)
endfunction

" a:1 = mode: mixed/(s)oft/(h)ard/(m)erge
function! s:GitReset(commit, ...)
    let mode = exists('a:1') ? (a:1 == 's' ? '--soft' : (a:1 == 'h' ? '--hard' : (a:1 == 'm' ? '--merge' : '--mixed'))) : '--mixed'
    call s:GitRun('reset', mode, a:commit)
endfunction

function! s:GitRemoveFiles(fname)
    if empty(a:fname) | return | endif
    if type(a:fname) == type([])
        if confirm('Remove untracked file'.(len(a:fname) > 1 ? 's' : ' "'.a:fname[0].'"').'?', "&Yes\n&No") == 1
            call map(a:fname, 'delete(v:val)')
        endif
    else
        if confirm('Remove untracked file "'.a:fname.'"?', "&Yes\n&No") == 1
            call delete(a:fname)
        endif
    endif
endfunction

" a:1 = force
function! s:GitCheckoutFiles(fname, ...)
    if empty(a:fname) | return | endif
    let force = exists('a:1') && !empty(a:1) ? (a:1 == 't' ? '--theirs' : (a:1 == 'o' ? '--ours' : '--force')) : ''
    let files = s:ShellJoin(a:fname, ' ')
    call s:GitRun('checkout', force, '--', files)
endfunction

" a:1 = nocommit, a:2 = signoff
function! s:GitRevert(commit, ...)
    let nocommit = exists('a:1') && a:1 ? '--no-commit' : ''
    let signoff = exists('a:2') && a:2 ? '--signoff' : ''
    call s:GitRun('revert', nocommit, signoff, shellescape(a:commit, 1))
endfunction

" a:1 = nocommit, a:2 = signoff, a:3 = attribute
function! s:GitCherryPick(commit, ...)
    let nocommit = exists('a:1') && a:1 ? '--no-commit' : ''
    let signoff = exists('a:2') && a:2 ? '--signoff' : ''
    let attrib = exists('a:3') && a:3 ? '-x' : '-r'
    call s:GitRun('cherry-pick', nocommit, signoff, attrib, shellescape(a:commit, 1))
endfunction

" a:1 = amend, a:2 = signoff, a:3 = message source: string/(f)ile/(c)ommit
function! s:GitCommit(msg, ...)
    let amend = exists('a:1') && a:1 ? '--amend' : ''
    let signoff = exists('a:2') && a:2 ? '--signoff' : ''
    let msgparam = exists('a:3') ? (a:3 == 'c' ? '-C' : (a:3 == 'f' ? '-F' : '-m')) : '-m'

    if msgparam == '-F' && a:msg == '-'
        exec s:GitPipe('%', 'commit', amend, signoff, '-F', '-')
    else
        call s:GitRun('commit', amend, signoff, msgparam, shellescape(a:msg, 1))
    endif
endfunction

" the same as GitCommit
function! s:GitCommitFiles(fname, msg, include, ...)
    if empty(a:fname) | return | endif
    let include = a:include ? '-i' : '-o'
    let files = s:ShellJoin(a:fname, ' ')
    let amend = exists('a:1') && a:1 ? '--amend' : ''
    let signoff = exists('a:2') && a:2 ? '--signoff' : ''
    let msgparam = exists('a:3') ? (a:3 == 'c' ? '-C' : (a:3 == 'f' ? '-F' : '-m')) : '-m'

    if msgparam == '-F' && msg == '-'
        exec s:GitPipe('%', 'commit', amend, signoff, '-F', '-', include, '--', files)
    else
        call s:GitRun('commit', amend, signoff, msgparam, shellescape(a:msg, 1), include, '--', files)
    endif
endfunction

" a:1 = cached, a:2 = reverse, a:3 = recount
" TODO: check options
function! s:GitApply(patch, ...)
    let cached = exists('a:1') && a:1 ? '--cached' : ''
    let reverse = exists('a:2') && a:2 ? '--reverse' : ''
    let recount = exists('a:3') && a:3 ? '--recount' : ''
    if a:patch == '-'
        exec s:GitPipe('%', 'apply', cached, reverse, recount, '--', a:patch)
    else
        call s:GitRun('apply', cached, reverse, recount, '--', a:patch)
    endif
endfunction

" a:1 = remove stash after apply, a:2 = apply index
function! s:GitStashApply(stashno, ...)
    let cmd = exists('a:1') && a:1 ? 'pop' : 'apply'
    let index = exists('a:2') && a:2 ? '--index' : ''
    let stashname = type(a:stashno) == type([]) ? map(a:stashno, '"stash@{".v:val."}"') : 'stash@{'.a:stashno.'}'
    call s:GitRun('stash', cmd, index, s:ShellJoin(stashname, ' '))
endfunction

" if stashno < 0, then drop all
function! s:GitStashRemove(stashno)
    if a:stashno < 0
        call s:GitRun('stash clear')
    else
        let stashname = type(a:stashno) == type([]) ? map(a:stashno, '"stash@{".v:val."}"') : 'stash@{'.a:stashno.'}'
        call s:GitRun('stash drop', s:ShellJoin(stashname, ' '))
    endif
endfunction

" a:1 = keep index
function! s:GitStashSave(msg, ...)
    let keepindex = exists('a:1') && a:1 ? '--keep-index' : '--no-keep-index'
    call s:GitRun('stash save', keepindex, shellescape(a:msg, 1))
endfunction

function! s:GitStashBranch(stashno, branch)
    let stashname = 'stash@{'.a:stashno.'}'
    call s:GitRun('stash branch', shellescape(a:branch, 1), shellescape(stashname, 1))
endfunction

" a:1 = context lines 
function! s:GitStashDiff(stashno, ...)
    let stashname = 'stash@{'.a:stashno.'}'
    let ctxl = exists('a:1') ? '-U'.a:1 : ''
    let cmd = s:GitPipe('.', 'stash show -p', ctxl, shellescape(stashname, 1))
    call s:GitDiffBuffer('git-stash-diff', cmd, 0)
endfunction

" a:1 = rev1, a:2 = rev2
" if a:0 == 0, diff current vs. HEAD, a:0 == 1, diff current vs. a:1, a:0 ==
" 2, diff a:1 vs. a:2
function! s:GitDiffSplit(filename, ...)
    if a:0 == 0
        let rev1 = ''
        let rev2 = 'HEAD'
    elseif a:0 == 1
        let rev1 = ''
        let rev2 = a:1
    elseif a:0 == 2
        let rev1 = a:1
        let rev2 = a:2
    else
        return
    endif

    let repofname = s:GitGetRepoFilename(a:filename)
    if empty(repofname)
        echoerr 'File "'.a:filename.'" not in current repository!'
        return
    endif

    call s:GitShowFile(rev2, repofname, 'v', '')
    diffthis

    if empty(rev1)
        exec 'vertical leftabove new '.a:filename
    else
        call s:GitShowFile(rev1, repofname, -1, 'la')
    endif
    diffthis
endfunction

function! s:GitRemoteAdd(name, url)
    call s:GitRun('remote', 'add', a:name, a:url)
endfunction

function! s:GitRemoteRemove(name)
    call s:GitRun('remote', 'rm', a:name)
endfunction
" }}}

call s:GitGraphInit()

" vim: et ts=8 sts=4 sw=4
