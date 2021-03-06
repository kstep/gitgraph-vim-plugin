syn match gitgraphTree "^[ 0-9\|/_*.-]\+\( [0-9a-f]\{7,40}\)\?\( ([:.a-zA-Z0-9_/, -]\+)\)\? " contains=@gitgraphTreeItems
syn region gitgraphAuthorship start=" \[[a-zA-Z0-9_]\@=" end="\]$" matchgroup=Comment contains=@gitgraphAuthorMarks keepend

syn match gitgraphCommittish "\<[0-9a-f]\{7,40}\>" nextgroup=gitgraphRefsList contains=gitgraphHeadRefItem,@NoSpell contained

syn region gitgraphRefsList start="(" end=")" contains=@gitgraphRefItems,gitgraphRefSep contained
syn match gitgraphBranchItem "[.a-zA-Z0-9_/-]\+" nextgroup=gitgraphRefSep contains=gitgraphHeadRefItem contained
syn match gitgraphTagItem "t:[.a-zA-Z0-9_/-]\+" nextgroup=gitgraphRefSep contained
syn match gitgraphRemoteItem "r:[.a-zA-Z0-9_/-]\+" nextgroup=gitgraphRefSep contained
syn match gitgraphSvnItem "s:[.a-zA-Z0-9_/-]\+" nextgroup=gitgraphRefSep contained
syn keyword gitgraphStashItem stash nextgroup=gitgraphRefSep contained
syn match gitgraphRefSep ", " nextgroup=@gitgraphRefItems contained

syn cluster gitgraphTreeItems contains=gitgraphTree1,gitgraphTree2,gitgraphTree3,gitgraphTree4,gitgraphTree5,gitgraphTree6,gitgraphTree7,gitgraphTree8,gitgraphTree9,gitgraphTreeC,gitgraphCommittish,gitgraphRefsList
syn cluster gitgraphRefItems contains=gitgraphBranchItem,gitgraphTagItem,gitgraphStashItem,gitgraphRemoteItem,gitgraphSvnItem
syn cluster gitgraphAuthorMarks contains=gitgraphAuthor,gitgraphDate

syn match gitgraphAuthor "[^],[]\{-1,}" contained contains=@NoSpell nextgroup=gitgraphDate
syn match gitgraphDate "\([A-Z][a-z]\{2} \)\{2}[0-9]\{1,2} [0-9]\{1,2}\([0-9]\{2}:\)\{2} [0-9]\{4}" contains=@NoSpell contained
syn match gitgraphDate "\([0-9]\+ \(second\|minute\|hour\|days\|week\|month\|year\)s\?\(, \)\?\)\+ ago" contains=@NoSpell contained
syn match gitgraphDate "[A-Z][a-z]\{2}, [0-9]\{1,2} [A-Z][a-z]\{2} [0-9]\{4} [0-9]\{1,2}\(:[0-9]\{2}\)\{2} [+-][0-9]\{4}" contains=@NoSpell contained
syn match gitgraphDate "[0-9]\{4}\(-[0-9]\{2}\)\{2}" contains=@NoSpell contained
syn match gitgraphDate "[0-9]\{4}\(-[0-9]\{2}\)\{2} [0-9]\{1,2}\(:[0-9]\{2}\)\{2} [+-][0-9]\{4}" contains=@NoSpell contained
syn match gitgraphDate "[0-9]\{10,} [+-][0-9]\{4}" contains=@NoSpell contained

syn match gitgraphTree1 "1[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree2 "2[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree3 "3[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree4 "4[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree5 "5[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree6 "6[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree7 "7[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree8 "8[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTree9 "9[*\|/_.-]\+" contained contains=gitgraphTreeMarker
syn match gitgraphTreeC " \*" contained

if has('conceal')
    setl cole=2 cocu=nvic
    syn conceal on
endif
syn match gitgraphTreeMarker "[0-9]" contained
if has('conceal')
    syn conceal off
endif


syn match gitgraphKeywords "Merge branch '.\+'"

hi link gitgraphTree Special
hi link gitgraphCommittish Identifier

hi link gitgraphRefsList String
hi link gitgraphBranchItem Label
hi link gitgraphSvnItem PreProc
hi link gitgraphStashItem Todo
hi link gitgraphTagItem Tag
hi link gitgraphRemoteItem Include
hi link gitgraphRefSep Delimiter
hi link gitgraphKeywords Keyword

" placeholder
"syn keyword gitgraphHeadRefItem xxxxxxx
hi link gitgraphHeadRefItem PreCondit
hi gitgraphHeadRefItem gui=underline,bold cterm=underline,bold
"hi gitgraphHeadRefItem gui=bold,inverse

hi link gitgraphAuthorship Comment
hi link gitgraphAuthor Comment
hi link gitgraphDate SpecialComment

hi gitgraphTree1 ctermfg=1 guifg=blue
hi gitgraphTree2 ctermfg=2 guifg=green
hi gitgraphTree3 ctermfg=3 guifg=cyan
hi gitgraphTree4 ctermfg=4 guifg=red
hi gitgraphTree5 ctermfg=5 guifg=magenta
hi gitgraphTree6 ctermfg=6 guifg=brown
hi gitgraphTree7 ctermfg=7 guifg=white
hi gitgraphTree8 ctermfg=8 guifg=yellow
hi gitgraphTree9 ctermfg=9 guifg=purple
hi link gitgraphTreeC SpecialChar
hi link gitgraphTreeMarker Ignore

