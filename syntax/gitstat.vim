syn match gitstatChangeStat '| \+\d\+ [-+]\+$' contains=gitstatAdded,gitstatRemoved,gitstatNumber
syn match gitstatAdded '+\+' contained
syn match gitstatRemoved '-\+' contained
syn match gitstatNumber '\d\+' contained

syn match gitstatSummary '^ \d\+ files changed, \d\+ insertions(+), \d\+ deletions(-)$' contains=gitstatTotalFiles,gitstatTotalAdded,gitstatTotalRemoved
syn match gitstatTotalFiles '\d\+ files changed' contained contains=gitstatNumber
syn match gitstatTotalAdded '\d\+ insertions(+)' contained contains=gitstatNumber
syn match gitstatTotalRemoved '\d\+ deletions(-)' contained contains=gitstatNumber

hi link gitstatAdded Type
hi link gitstatRemoved Special
hi link gitstatNumber Number

hi link gitstatSummary Title
hi link gitstatTotalFiles Identifier
hi link gitstatTotalAdded Type
hi link gitstatTotalRemoved Special
