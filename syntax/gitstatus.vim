
" TODO syntax highlightng for git status view, commit view...

syn region gitStaged matchgroup=gitSectionHeader start='^# Changes to be committed:' end='^$' contains=@gitTrackedFiles,gitNewFile fold
syn region gitUnstaged matchgroup=gitSectionHeader start='^# Changes not staged for commit:' end='^$' contains=@gitTrackedFiles fold

syn region gitNewFile start='^\t\[+\]' end='$' contained
syn region gitModFile start='^\t\[\*\]' end='$' contained
syn region gitDelFile start='^\t\[-\]' end='$' contained
syn region gitRenFile start='^\t\[=\]' end='$' contained
syn region gitCpFile start='^\t\[>\]' end='$' contained
syn region gitUnkFile start='^\t\[?\]' end='$' contained
syn region gitUnmFile start='^\t\[%\]' end='$' contained
syn region gitChmFile start='^\t\[@\]' end='$' contained
syn cluster gitTrackedFiles contains=gitModFile,gitDelFile,gitRenFile,gitCpFile,gitUnkFile,gitChmFile,gitUnmFile

syn region gitUntracked matchgroup=gitSectionHeader start='^# Untracked files:' end='^$' contains=gitUntFile fold
syn region gitUntFile  start='^\t\[ \]' end='$' contained

syn region gitUnmerged matchgroup=gitSectionHeader start='^# Unmerged paths:' end='^$' contains=@gitUnmergedFiles fold
syn region gitMNewFile  start='^\t[\[{]+[\]}]' end='$' contained
syn region gitMDelFile  start='^\t[\[{]-[\]}]' end='$' contained
syn region gitMModFile  start='^\t{\*}' end='$' contained
syn cluster gitUnmergedFiles contains=gitMNewFile,gitMDelFile,gitMModFile

syn match gitCurrentBranch '^# On branch.*$'

hi link gitSectionHeader Title
hi link gitCurrentBranch StatusLine

hi link gitNewFile Type

hi link gitModFile Identifier
hi link gitDelFile Special
hi link gitRenFile Constant
hi link gitCpFile Constant
hi link gitUnkFile Question
hi link gitUnmFile Error
hi link gitChmFile Identifier

hi link gitUntFile PreProc

hi link gitMNewFile Type
hi link gitMModFile Identifier
hi link gitMDelFile Special

