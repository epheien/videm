"delf omnicpp#resolvers#GetOmniScopeStack
"echo omnicpp#resolvers#GetOmniScopeStack('A::B C::D::').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('A::B::C().').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('A::B().C->').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('A->B().').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('A->B.').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('Z Y = ((A*)B)->C.').omniss
"echo omnicpp#resolvers#GetOmniScopeStack('(A*)B()->C.')
"echo omnicpp#resolvers#GetOmniScopeStack('(A*)B()->C[D][E].')
"echo omnicpp#resolvers#GetOmniScopeStack('((A*)B).')
"echo omnicpp#resolvers#GetOmniScopeStack('this->A.B->')
"
"finish

function! s:GetCurStatementStartPos() "{{{2
    let origCursor = getpos('.')
    let origPos = origCursor[1:2]

    let result = [0, 0]

    while searchpos('[;{}]\|\%^', 'bW') != [0, 0]
        "if omnicpp#utils#IsCursorInCommentOrString()
            "continue
        "else
            break
        "endif
    endwhile

    if getpos('.')[1:2] == [1, 1] " 到达文件头的话, 接受光标所在位置的匹配
        let result = searchpos('[^ \t]', 'Wc')
    else
        let result = searchpos('[^ \t]', 'W')
    endif

    call setpos('.', origCursor)

    return result
endfunc
function! g:TestSyntaxSpeed()
    let nTimes = 100
    call g:Timer.Start()
    for i in range(nTimes)
        call omnicpp#utils#GetCurStatementStartPos()
    endfor
    call g:Timer.EndEchoMes()
    call g:Timer.Start()
    for i in range(nTimes)
        call s:GetCurStatementStartPos()
    endfor
    call g:Timer.EndEchoMes()
endfunction


" 简化 omni 补全请求代码, 效率不是太高
" eg1. A::B("\"")->C(" a(\")z ", ')'). -> A::B()->C().
" eg2. ((A*)(B))->C. -> ((A*)B)->C.
" egx. A::B(C.D(), ((E*)F->G)).
function! g:SimplifyOmniCode(szOmniCode) "{{{2
    let s = a:szOmniCode
    
    " 1. 清理函数函数
    let s = s:StripFuncArgs(s)
    " 2. 清理多余的括号, 不会检查匹配的情况. eg. ((A*)((B))) -> ((A*)B)
    " TODO: 需要更准确
    let s = substitute(s, '\W\zs(\+\(\w\+\))\+\ze', '\1', 'g')

    return s
endfunc
"}}}
" 剔除所有函数参数, 仅保留一个括号
" TODO: 处理引号中的 ')' 干扰
function! s:StripFuncArgs(szOmniCode) "{{{2
    let s = a:szOmniCode

    " 1. 清理引号内的 \" , 因为正则貌似是不能直接匹配 ("\"")
    let s = substitute(s, '\\"', '', 'g')
    " 2. 清理双引号的内容, 否则双引号内的括号会干扰括号替换
    let s = substitute(s, '".\{-}"', '', 'g')
    " 3. 清理 '(' 和 ')', 避免干扰
    let s = substitute(s, "'('\\|')'", '', 'g')

    let szResult = ''
    let nStart = 0
    while nStart < len(s) && nStart != -1
        let nEnd = matchend(s, '\w\s*(', nStart)
        if nEnd != -1
            let szResult .= s[nStart : nEnd - 1]

            let nStart = nEnd
            let nCount = 1
            " 开始寻找匹配的 ) 的位置
            for i in range(nStart, len(s) - 1)

                let c = s[i]

                if c == '('
                    let nCount += 1
                elseif c == ')'
                    let nCount -= 1
                endif

                if nCount == 0
                    let nStart = i + 1
                    let szResult .= ')'
                    break
                endif
            endfor

        else
            let szResult .= s[nStart :]
            break
        endif
    endwhile

    return szResult
endfunc
"}}}

"echo g:SimplifyOmniCode('A::B("\"")->C(" a(\")z ", '')'').')
"echo g:SimplifyOmniCode('((A*)(B))->C.')

"echo g:StripFuncArgs('A::B(C.D(), ((E*)F->G)).')

"echo g:StripFuncArgs('A::B(C.D(), ((E*)F->G)).H("1, 2)", '')'', Z()->Y()->X)->')


function! g:TestGetCurBlockStartPos()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        call omnicpp#scopes#GetCurBlockStartPos()
    endfor
    call g:Timer.EndEchoMes()
endfunc

function! g:TestGetCurBlockEndPos()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        call omnicpp#scopes#GetCurBlockEndPos()
    endfor
    call g:Timer.EndEchoMes()
endfunc
function! g:TestGetCurBlockEndPos2()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        let startPos = searchpairpos('{', '', '}', 'Wn')
    endfor
    call g:Timer.EndEchoMes()
endfunc
function! g:TestGetCurBlockEndPos3()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        let startPos = g:Searchpairpos()
    endfor
    call g:Timer.EndEchoMes()
endfunc
function! g:TestGetCurBlockEndPos4()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        call searchpair('{', '', '}', 'Wn', 
                    \'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    endfor
    call g:Timer.EndEchoMes()
endfunc
function! g:TestGetCurBlockEndPos5()
    call g:Timer.Start()
    let nTimes = 100
    for i in range(nTimes)
        let origCursor = getpos('.')
        call searchpair('{', '', '}', 'Wb')
        normal! %
        let b:startPos = getpos('.')[1:2]
        call setpos('.', origCursor)
    endfor
    call g:Timer.EndEchoMes()
endfunc
function! g:Searchpairpos()
    let origCursor = getpos('.')
    let nCount = 1
    while nCount > 0
        call search('{\|}')
        if getline('.')[col('.')-1] == '{'
            let nCount += 1
        else
            let nCount -= 1
        endif
    endwhile
    let result = getpos('.')[1:2]
    call setpos('.', origCursor)
    return result
endfunction



function! s:NewTypeInfo() "{{{2
    return {'name': '', 'tsdm': {}, 'til': [], 'tdl': []}
endfunc
"}}}
function! s:StripString(s) "{{{2
    let s = substitute(a:s, '^\s\+', '', 'g')
    let s = substitute(s, '\s\+$', '', 'g')
    return s
endfunc
"}}}
" Param: s  为模版声明或定义字符串
" Return:   模版初始化列表
function! s:GetTemplateSpecList(s) "{{{2
    let s = a:s
    let til = []

    let idx = 0
    let nCount = 0
    let s1 = 0
    while idx < len(s)
        let c = s[idx]
        if c == '<'
            let nCount += 1
            if nCount == 1
                let s1 = idx + 1
            endif
        elseif c == '>'
            let nCount -= 1
            if nCount == 0
                call add(til, s:StripString(s[s1 : idx-1]))
                break
            endif
        elseif c == ','
            if nCount == 1
                call add(til, s:StripString(s[s1 : idx-1]))
                let s1 = idx + 1
            endif
        endif

        let idx += 1
    endwhile

    return til
endfunc
"}}}
function! g:GetVariableTypeInfo(szDecl, szVar) "{{{2
    let typeInfo = s:NewTypeInfo()
    " FIXME: python 的字典转为 vim 字典时, \t 全部丢失
    let szDecl = substitute(a:szDecl, '\\t', ' ', 'g')
    let s = szDecl[: match(szDecl, a:szVar)-1]
    " 删除赋值语句
    let s = substitute(s, '=.*$', '', 'g')
    " eg. int *a, *b, *| -> int |
    let s = substitute(s, '\%(>\|\w\)\zs\s\+\%(\*\+\|&\)\?\s*\w\+\s*,.*$', '', 
                \'g')
    if s =~# '>\s*$'
        " 有模版
        let typeInfo.name = matchstr(s, '\w\+\ze\s*<.\+$')

        " 提取模版初始化列表
        let tds = matchstr(s, '\w\+\s*\zs<.\+$')
        let typeInfo.tdl = s:GetTemplateSpecList(tds)
    else
        let typeInfo.name = matchstr(s, '\w\+\ze\s*[*&]\?\s*$')
    endif

    return typeInfo
endfunc
"}}}

"echo g:GetVariableTypeInfo(' B< A, C < char, short > > **c1, c2, c3;', 'c3')
"echo g:GetVariableTypeInfo(' B * c1, & c2 = c1, c3;', 'c3')
"echo g:GetVariableTypeInfo(' B & c1, & c2 = c1, c3;', 'c3')
"echo g:GetVariableTypeInfo(' B c1, & c2 = c1, c3;', 'c3')
"echo g:GetVariableTypeInfo(' A < B, C , D < E, F > , G<H,I,K<L,M,N> > > x', 'x')

"echo s:GetTemplateSpecList(' A < B, C , D < E , F > , G<H,I,K<L,M,N> > >')

" 剔除配对的字符里面(包括配对的字符)的内容
function! s:StripPair(szString, szStart, szEnd, ...) "{{{2
    let szString = a:szString
    let szStart = a:szStart
    let szEnd = a:szEnd
    let nDeep = 1
    if a:0 > 0
        let nDeep = a:1
    endif

    if nDeep <= 0
        return szString
    endif

    let result = ''

    let idx = 0
    let nLen = len(szString)
    let nCount = 0
    let nSubStart = 0
    while idx < nLen
        let c = szString[idx]
        if c == szStart
            let nCount += 1
            if nCount == nDeep && nSubStart != -1
                let result .= szString[nSubStart : idx - 1]
                let nSubStart = -1
            endif
        elseif c == szEnd
            let nCount -= 1
            if nCount == nDeep - 1
                let nSubStart = idx + 1
            endif
        endif
        let idx += 1
    endwhile

    if nSubStart != -1
        let result .= szString[nSubStart : -1]
    endif

    return result
endfunc
"}}}

"echo s:StripPair('B1<A1>,B2<A1,T<a,b,c<d,e<f>>>>,B3', '<', '>')
"echo s:StripPair('B1<A1>,B2<A1,T<a,b,c<d,e<f>>>>,B3', '<', '>', 2)
"echo s:StripPair('A(B(C(D))), E(), F(G)', '(', ')', 0)
"echo s:StripPair('A(B(C(D))), E(), F(G)', '(', ')', 1)
"echo s:StripPair('A(B(C(D))), E(), F(G)', '(', ')', 2)
"echo s:StripPair('A(B(C(D))), E(), F(G)', '(', ')', 3)
"echo s:StripPair('A(B(C(D))), E(), F(G)', '(', ')', 4)


function! s:GetTemplateDeclList(sQualifiers) "{{{2
    let text = a:sQualifiers
    if text == ''
        return []
    endif

    let text = substitute(text, '^.\+<', '', 'g')
    let text = substitute(text, '>.*$', '', 'g')
    let text = substitute(text, 'typename', '', 'g')
    let text = substitute(text, 'class', '', 'g')

    return map(split(text, ','), 's:StripString(v:val)')
endfunc
"}}}

function! s:GetInheritsInfoList(sInherits) "{{{2
    let sInherits = a:sInherits
    if sInherits == ''
        return []
    endif

    let lResult = []

    let idx = 0
    let nNestDepth = 0
    let nLen = len(sInherits)
    let nSubStart = 0
    while idx < nLen
        let c = sInherits[idx]
        if c == '<'
            let nNestDepth += 1
        elseif c == '>'
            let nNestDepth -= 1
        elseif c == ','
            if nNestDepth == 0
                let sText = sInherits[nSubStart : idx - 1]
                let dInfo = {}
                let dInfo.name = matchstr(sText, '^\s*\zs\w\+\ze\s*<\?')
                let dInfo.til = s:GetTemplateSpecList(sText)
                call add(lResult, dInfo)
                let nSubStart = idx + 1
            endif
        endif

        let idx += 1
    endwhile

    let sText = sInherits[nSubStart : idx - 1]
    let dInfo = {}
    let dInfo.name = matchstr(sText, '^\s*\zs\w\+\ze\s*<\?')
    let dInfo.til = s:GetTemplateSpecList(sText)
    call add(lResult, dInfo)
    let nSubStart = idx + 1

    return lResult
endfunc
"}}}

"echo s:GetInheritsInfoList('B1<A1>,B2<A1,T>,B3,B4<A2<a,b>, A3<c,d<e>>>')
"echo s:GetInheritsInfoList('B1,B2')
"echo s:GetInheritsInfoList('B1<A1>,B2<A1,T>')

"echo s:GetTemplateDeclList(' template < T1 , T2 , T3> const T3 & ')

" Return: PrmtInfo 字典
" {
" 'kind': <'typename'|'class'|Non Type>
" 'name': <parameter name>
" 'default': <default value>
" }
function! s:NewPrmtInfo() "{{{2
    return {'kind': '', 'name': '', 'default': ''}
endfunc
"}}}
function! s:ResolveTemplateParameter(sDecl) "{{{2
    let bak_ic = &ic
    set noic

    let sDecl = s:StripString(a:sDecl)
    let dPrmtInfo = s:NewPrmtInfo()
    if sDecl =~# '^typename\|^class'
        " 类型参数
        let dPrmtInfo.kind = matchstr(sDecl, '^\w\+')
        if sDecl =~# '='
            " 有默认值
            let dPrmtInfo.name = matchstr(sDecl, '\w\+\ze\s*=')
            let dPrmtInfo.default = matchstr(sDecl, '=\s*\zs\S\+\ze$')
        else
            " 无默认值
            let dPrmtInfo.name = matchstr(sDecl, '\w\+$')
        endif
    else
        " 非类型参数
        let dPrmtInfo.kind = matchstr(sDecl, '^\S\+\ze[*& ]\+\w\+')
        if sDecl =~# '='
            " 有默认值
            let dPrmtInfo.name = matchstr(sDecl, '\w\+\ze\s*=')
            let dPrmtInfo.default = matchstr(sDecl, '=\s*\zs\S\+\ze$')
        else
            " 无默认值
            let dPrmtInfo.name = matchstr(sDecl, '\w\+$')
        endif
    endif

    let &ic = bak_ic
    return dPrmtInfo
endfunc
"}}}
function! s:GetTemplatePrmtInfoList(sQualifiers) "{{{2
    let sQualifiers = a:sQualifiers
    if sQualifiers == ''
        return []
    endif

    let lResult = []

    let idx = 0
    let nNestDepth = 0
    let nLen = len(sQualifiers)
    let nSubStart = 0
    while idx < nLen
        let c = sQualifiers[idx]
        if c == '<'
            let nNestDepth += 1
            if nNestDepth == 1
                let nSubStart = idx + 1
            endif
        elseif c == '>'
            let nNestDepth -= 1
            if nNestDepth == 0
                let sText = sQualifiers[nSubStart : idx - 1]
                let dPrmtInfo = s:ResolveTemplateParameter(sText)
                call add(lResult, dPrmtInfo)
                break
            endif
        elseif c == ','
            if nNestDepth == 1
                let sText = sQualifiers[nSubStart : idx - 1]
                let dPrmtInfo = s:ResolveTemplateParameter(sText)
                call add(lResult, dPrmtInfo)
                let nSubStart = idx + 1
            endif
        endif

        let idx += 1
    endwhile

    return lResult
endfunc
"}}}
"echo s:GetTemplatePrmtInfoList('template<typename T, Z<A>&t = x>')
"echo s:GetTemplatePrmtInfoList('template<typename T = A, Z<A>&t, class T2 = R>')

"try
    "let li = []
    "let x = li[0]
"catch /E684/
    "echo 'E'
"endtry

" TODO
" eg.
"   'const MyClass&'
"   'const map < int, int >&'
"   'MyNs::MyClass'
"   '::MyClass**'
"   'MyClass a, *b = NULL, c[1] = {};
"   'hello(MyClass a, MyClass* b'
"function! s:GetVariableTypeInfo(sDecl)
    "let lTokens = omnicpp#tokenizer#Tokenize(a:Decl)

    "let dResult = {'name': '', 'til': []}
    "let sType = ''
    "let lTsl = []

    "return dResult
"endfunc


if 0 " =========================================================================
call omnicpp#complete#Init()
delfun omnicpp#resolvers#DoResolveTemplate

let dClassTag = g:GetTagsByPath('C')[0] 
let lInstList = ['AA']
let sMacthClass = 'C'
let dTypeInfo = {'name': 'T', 'til': []}
echo dTypeInfo
"breakadd func omnicpp#resolvers#DoResolveTemplate
echo omnicpp#resolvers#DoResolveTemplate(
            \dClassTag, lInstList, sMacthClass, dTypeInfo)
"breakdel func omnicpp#resolvers#DoResolveTemplate
echo dTypeInfo
echo '--------------------'
let dClassTag = g:GetTagsByPath('C')[0] 
let lInstList = ['AA']
let sMacthClass = 'B2'
" X<A, T>
let dTypeInfo = {'name': 'A2', 'til': ['A', 'T1', 'TT', 'T2']}
echo dTypeInfo
"breakadd func omnicpp#resolvers#DoResolveTemplate
echo omnicpp#resolvers#DoResolveTemplate(
            \dClassTag, lInstList, sMacthClass, dTypeInfo)
"breakdel func omnicpp#resolvers#DoResolveTemplate
echo dTypeInfo
echo '--------------------'
let dClassTag = g:GetTagsByPath('C')[0] 
let lInstList = ['AA']
let sMacthClass = 'B'
" X<A, T>
let dTypeInfo = {'name': 'T', 'til': []}
echo dTypeInfo
"breakadd func omnicpp#resolvers#DoResolveTemplate
echo omnicpp#resolvers#DoResolveTemplate(
            \dClassTag, lInstList, sMacthClass, dTypeInfo)
"breakdel func omnicpp#resolvers#DoResolveTemplate
echo dTypeInfo
echo '--------------------'
endif "=========================================================================


" 获取 nStartLine 到 nStopLine 之间(包括 nStopLine)的名空间信息
" 仅处理风格良好的写法, 例如一行一个指令.
" Return: NSInfo 字典
" {
" 'using': []       <- using 语句
" 'usingns': []     <- using namespace
" 'nsalias': {}     <- namespace alias
" }
function! g:GetNamespaceInfo(nStartLine, nStopLine) "{{{2
    let dNSInfo = {'using': [], 'usingns': [], 'nsalias': {}}
    let lOrigCursor = getpos('.')

    call setpos('.', [0, a:nStartLine, 1, 0])
    let lCurPos = [a:nStartLine, 1]
    let bFirstEnter = 1
    while 1
        if bFirstEnter
            let bFirstEnter = 0
            let sFlag = 'Wc'
        else
            let sFlag = 'W'
        endif
        let lCurPos = searchpos('\C^\s*using\s\+\|^\s*namespace\s\+', 
                    \sFlag, a:nStopLine)

        if lCurPos != [0, 0]
            let sLine = getline('.')
            if sLine =~# '^\s*using'
                if sLine =~# 'namespace'
                    " using namespace
                    let sUsingNS = matchstr(sLine, 
                                \'\Cusing\s\+namespace\s\+\zs[a-zA-Z0-9_:]\+')
                    call add(dNSInfo.usingns, sUsingNS)
                else
                    " using
                    let sUsing = matchstr(sLine, '\Cusing\s\+\zs[a-zA-Z0-9_:]\+')
                    call add(dNSInfo.using, sUsing)
                endif
            else
                " 名空间别名
                let sNSAliasKey = matchstr(sLine, '\w\+\ze\s*=')
                let sNSAliasValue = matchstr(sLine, '=\s*\zs[a-zA-Z0-9_:]\+')
                let dNSInfo.nsalias[sNSAliasKey] = sNSAliasValue
            endif
        else
            break
        endif
    endwhile

    call setpos('.', lOrigCursor)
    return dNSInfo
endfunc
"}}}



" vim:fdm=marker:fen:expandtab:smarttab:fdl=1:
