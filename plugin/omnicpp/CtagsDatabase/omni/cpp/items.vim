" Description: Omni completion script for cpp files
" Maintainer:  Vissale NEANG
" Last Change: 26 sept. 2007

" Build the item list of an instruction
" An item is an instruction between a -> or . or ->* or .*
" We can sort an item in different kinds:
" eg: ((MyClass1*)(pObject))->_memberOfClass1.get()     ->show()
"     |        cast        |  |    member   | | method |  | method |
" @return a list of item
" an item is a dictionnary where keys are:
"   tokens = list of token
"   kind = itemVariable|itemCast|itemCppCast|itemTemplate|itemFunction|itemUnknown|itemThis|itemScope
function! omni#cpp#items#Get(tokens, ...)
    let bGetWordUnderCursor = (a:0>0)? a:1 : 0

    let result = []
    let itemsDelimiters = ['->', '.', '->*', '.*']

    let tokens = reverse(omni#cpp#utils#BuildParenthesisGroups(a:tokens))

    " fsm states:
    "   0 = initial state
    "   TODO: add description of fsm states
    let state=(bGetWordUnderCursor)? 1 : 0
    let item = {'tokens' : [], 'kind' : 'itemUnknown'}
    let parenGroup=-1
    for token in tokens
        if state==0
            if index(itemsDelimiters, token.value)>=0
                let item = {'tokens' : [], 'kind' : 'itemUnknown'}
                let state = 1
            elseif token.value=='::'
                let state = 9
                let item.kind = 'itemScope'
                " Maybe end of tokens
            elseif token.kind =='cppOperatorPunctuator'
                " If it's a cppOperatorPunctuator and the current token is not
                " a itemsDelimiters or '::' we can exit
                let state=-1
                break
            endif
        elseif state==1
            call insert(item.tokens, token)
            if token.kind=='cppWord'
                " It's an attribute member or a variable
                let item.kind = 'itemVariable'
                let state = 2
                " Maybe end of tokens
            elseif token.value=='this'
                let item.kind = 'itemThis'
                let state = 2
                " Maybe end of tokens
            elseif token.value==')'
                let parenGroup = token.group
                let state = 3
            elseif token.value==']'
                let parenGroup = token.group
                let state = 4
            elseif token.kind == 'cppDigit'
                let state = -1
                break
            endif
        elseif state==2
            if index(itemsDelimiters, token.value)>=0
                call insert(result, item)
                let item = {'tokens' : [], 'kind' : 'itemUnknown'}
                let state = 1
            elseif token.value == '::'
                call insert(item.tokens, token)
                " We have to get namespace or classscope
                let state = 8
                " Maybe end of tokens
            else
                call insert(result, item)
                let state=-1
                break
            endif
        elseif state==3
            call insert(item.tokens, token)
            if token.value=='(' && token.group == parenGroup
                let state = 5
                " Maybe end of tokens
            endif
        elseif state==4
            call insert(item.tokens, token)
            if token.value=='[' && token.group == parenGroup
                let state = 1
            endif
        elseif state==5
            if token.kind=='cppWord'
                " It's a function or method
                let item.kind = 'itemFunction'
                call insert(item.tokens, token)
                let state = 2
                " Maybe end of tokens
            elseif token.value == '>'
                " Maybe a cpp cast or template
                let item.kind = 'itemTemplate'
                call insert(item.tokens, token)
                let parenGroup = token.group
                let state = 6
            else
                " Perhaps it's a C cast eg: ((void*)(pData)) or a variable eg:(*pData)
                let item.kind = omni#cpp#utils#GetCastType(item.tokens)
                let state=-1
                call insert(result, item)
                break
            endif
        elseif state==6
            call insert(item.tokens, token)
            if token.value == '<' && token.group == parenGroup
                " Maybe a cpp cast or template
                let state = 7
            endif
        elseif state==7
            call insert(item.tokens, token)
            if token.kind=='cppKeyword'
                " It's a cpp cast
                let item.kind = omni#cpp#utils#GetCastType(item.tokens)
                let state=-1
                call insert(result, item)
                break
            else
                " Template ?
                let state=-1
                call insert(result, item)
                break
            endif
        elseif state==8
            if token.kind=='cppWord'
                call insert(item.tokens, token)
                let state = 2
                " Maybe end of tokens
            else
                let state=-1
                call insert(result, item)
                break
            endif
        elseif state==9
            if token.kind == 'cppWord'
                call insert(item.tokens, token)
                let state = 10
                " Maybe end of tokens
            else
                let state=-1
                call insert(result, item)
                break
            endif
        elseif state==10
            if token.value == '::'
                call insert(item.tokens, token)
                let state = 9
                " Maybe end of tokens
            else
                let state=-1
                call insert(result, item)
                break
            endif
        endif
    endfor

    if index([2, 5, 8, 9, 10], state)>=0
        if state==5
            let item.kind = omni#cpp#utils#GetCastType(item.tokens)
        endif
        call insert(result, item)
    endif

    return result
endfunc

" Resolve type information of items
" @param namespaces: list of namespaces used in the file
" @param szCurrentClassScope: the current class scope, only used for the first
" item to detect if this item is a class member (attribute, method)
" @param items: list of item, can be an empty list @see GetItemsToComplete
" 解析类型信息. 如变量所属类型.
" @param namespaces: 名空间列表
" @param contextStack: 直接用上下文栈代替名空间和类作用域. eg. ['::', 'std']?
" @param items: 为 omni#cpp#items#Get() 处理当前光标所在位置的 tokens 的结果
function! omni#cpp#items#ResolveItemsTypeInfo(contextStack, items)
    " Note: kind = itemVariable|cCast|cppCast|template|function|itemUnknown|this
    " For the first item, if it's a variable we try to detect the type of the
    " variable with the function searchdecl. If it fails, thanks to the
    " current class scope, we try to detect if the variable is an attribute
    " member.
    " If the kind of the item is a function, we have to first check if the
    " function is a method of the class, if it fails we try to get a match in
    " the global namespace. After that we get the returned type of the
    " function.
    " It the kind is a C cast or C++ cast, there is no problem, it's the
    " easiest case. We just extract the type of the cast.
	" FIXME: 这里调用 searchdecl() 查找变量声明, 并不准确, 需要更准确的方法
	" 如果第一个条目是变量, 会在函数开始处查找变量声明的类型. 
	" 如果查找失败, 再尝试查找当前作用域所属的类的属性成员声明.
	" 如果条目的类型是函数, 我们必须检查此函数是否当前作用域所属类的方法.
	" 之后需要获取此函数的返回类型, 以继续解析.
	" 如果条目的类型是类型转换, 最容易处理, 直接得出结果

    let szCurrentContext = ''
    let typeInfo = {}
    " Note: We search the decl only for the first item
    let bSearchDecl = 1
    for item in a:items
        let curItem = item
        if index(['itemVariable', 'itemFunction'], curItem.kind)>=0
            " Note: a variable can be : MyNs::MyClass::_var or _var or (*pVar)
            " or _var[0][0]
            let szSymbol = s:GetSymbol(curItem.tokens)

            " If we have MyNamespace::myVar
            " We add MyNamespace in the context stack set szSymbol to myVar
            if match(szSymbol, '::\w\+$') >= 0
                let szCurrentContext = substitute(szSymbol, '::\w\+$', '', 'g')
                let szSymbol = matchstr(szSymbol, '\w\+$')
            endif
            let tmpContextStack = a:contextStack
            if szCurrentContext != ''
                let tmpContextStack = [szCurrentContext] + a:contextStack
            endif

            if curItem.kind == 'itemVariable'
                let typeInfo = s:GetTypeInfoOfVariable(tmpContextStack, szSymbol, bSearchDecl)
            else
                let typeInfo = s:GetTypeInfoOfReturnedType(tmpContextStack, szSymbol)
            endif

        elseif curItem.kind == 'itemThis'
            if len(a:contextStack)
                let typeInfo = omni#cpp#utils#CreateTypeInfo(substitute(a:contextStack[0], '^::', '', 'g'))
            endif
        elseif curItem.kind == 'itemCast'
            let typeInfo = omni#cpp#utils#CreateTypeInfo(s:ResolveCCast(curItem.tokens))
        elseif curItem.kind == 'itemCppCast'
            let typeInfo = omni#cpp#utils#CreateTypeInfo(s:ResolveCppCast(curItem.tokens))
        elseif curItem.kind == 'itemScope'
            let typeInfo = omni#cpp#utils#CreateTypeInfo(substitute(s:TokensToString(curItem.tokens), '\s', '', 'g'))
        endif

        if omni#cpp#utils#IsTypeInfoValid(typeInfo)
            let szCurrentContext = omni#cpp#utils#GetTypeInfoString(typeInfo)
        endif
        let bSearchDecl = 0
    endfor

    return typeInfo
endfunc

" Get symbol name
function! s:GetSymbol(tokens)
    let szSymbol = ''
    let state = 0
    for token in a:tokens
        if state == 0
            if token.value == '::'
                let szSymbol .= token.value
                let state = 1
            elseif token.kind == 'cppWord'
                let szSymbol .= token.value
                let state = 2
                " Maybe end of token
            endif
        elseif state == 1
            if token.kind == 'cppWord'
                let szSymbol .= token.value
                let state = 2
                " Maybe end of token
            else
                " Error
                break
            endif
        elseif state == 2
            if token.value == '::'
                let szSymbol .= token.value
                let state = 1
            else
                break
            endif
        endif
    endfor
    return szSymbol
endfunc

" Search a declaration.
" eg: std::map
" can be empty
" Note: The returned type info can be a typedef
" The typedef resolution is done later
" @return
"   - a dictionnary where keys are
"       - type: the type of value same as type()
"       - value: the value
function! s:GetTypeInfoOfVariable(contextStack, szVariable, bSearchDecl)
    let result = {}

    if a:bSearchDecl
        " Search type of declaration
        "let result = s:SearchTypeInfoOfDecl(a:szVariable)
        let result = s:SearchDecl(a:szVariable)
    endif

    if result=={}
        let szFilter = "index(['m', 'v'], v:val.kind[0])>=0"
        let tagItem = s:ResolveSymbol(a:contextStack, a:szVariable, szFilter)
        if tagItem=={}
            return result
        endif

		"从 pattern 解析变量的类型
        let szCmdWithoutVariable = substitute(omni#cpp#utils#ExtractCmdFromTagItem(tagItem), '\C\<'.a:szVariable.'\>.*', '', 'g')
        let tokens = omni#cpp#tokenizer#Tokenize(omni#cpp#utils#GetCodeFromLine(szCmdWithoutVariable))
        let result = omni#cpp#utils#CreateTypeInfo(omni#cpp#utils#ExtractTypeInfoFromTokens(tokens))
        " TODO: Namespace resolution for result

        if result != {} && result.value==''
            " result.value==''
            " eg: 
            " struct
            " {
            " }gVariable;
            if has_key(tagItem, 'typeref')
                " Maybe the variable is a global var of an
                " unnamed class, struct or union.
                " eg:
                " 1)
                " struct
                " {
                " }gVariable;
                " In this case we need the tags (the patched version)
                " Note: We can have a named type like this:
                " 2)
                " class A
                " {
                " }gVariable;
                if s:IsUnnamedType(tagItem)
                    " It's an unnamed type we are in the case 1)
                    let result = omni#cpp#utils#CreateTypeInfo(tagItem)
                else
                    " It's not an unnamed type we are in the case 2)

                    " eg: tagItem.typeref = 'struct:MY_STRUCT::MY_SUBSTRUCT'
                    let szTypeRef = substitute(tagItem.typeref, '^\w\+:', '', '')

                    " eg: szTypeRef = 'MY_STRUCT::MY_SUBSTRUCT'
                    let result = omni#cpp#utils#CreateTypeInfo(szTypeRef)
                endif
            endif
        endif
    endif
    return result
endfunc

" Get the type info string from the returned type of function
function! s:GetTypeInfoOfReturnedType(contextStack, szFunctionName)
    let result = {}

    let szFilter = "index(['f', 'p'], v:val.kind[0])>=0"
    let tagItem = s:ResolveSymbol(a:contextStack, a:szFunctionName, szFilter)

    if tagItem != {}
        let szCmdWithoutVariable = substitute(omni#cpp#utils#ExtractCmdFromTagItem(tagItem), '\C\<'.a:szFunctionName.'\>.*', '', 'g')
        let tokens = omni#cpp#tokenizer#Tokenize(omni#cpp#utils#GetCodeFromLine(szCmdWithoutVariable))
        let result = omni#cpp#utils#CreateTypeInfo(omni#cpp#utils#ExtractTypeInfoFromTokens(tokens))
        " TODO: Namespace resolution for result
        return result
    endif
    return result
endfunc

" Resolve a symbol, return a tagItem
" Gets the first symbol found in the context stack
function! s:ResolveSymbol(contextStack, szSymbol, szTagFilter)
	" TODO: 无须逐个搜索名空间的符号
	" FIXME: 方法错误, 对于成员补全来说, 根本是 名空间::符号 的组合
    let tagItem = {}
    for szCurrentContext in a:contextStack
        if szCurrentContext != '::'
            let szTagQuery = substitute(szCurrentContext, '^::', '', 'g').'::'.a:szSymbol
        else
            let szTagQuery = a:szSymbol
        endif

		if g:useTagsStorage
			"FIXME: 应该为在 scope 中搜索符号
			"搜索了 DFoo::testAnonStruct
			"还搜索了 TestNamespace::testAnonStruct
			"还搜索了 testAnonStruct
			let tagList = g:GetTagsByPath(szTagQuery)
		else
			let tagList = omni#common#utils#TagListNoThrow('^'.szTagQuery.'$')
		endif
        call filter(tagList, a:szTagFilter)
        if len(tagList)
			"FIXME: 这里出错
            let tagItem = tagList[0]
            break
        endif
    endfor
    return tagItem
endfunc

" Return if the tag item represent an unnamed type
function! s:IsUnnamedType(tagItem)
    let bResult = 0
    if has_key(a:tagItem, 'typeref')
        " Note: Thanks for __anon !
        let bResult = match(a:tagItem.typeref, '\C\<__anon') >= 0
    endif
    return bResult
endfunc

" Search the declaration of a variable and return the type info
function! s:SearchTypeInfoOfDecl(szVariable)
    let szReVariable = '\C\<'.a:szVariable.'\>'

    let originalPos = getpos('.')
    let origPos = originalPos[1:2]
    let curPos = origPos
    let stopPos = origPos
    
    while curPos !=[0,0]
        " We go to the start of the current scope
        let curPos = searchpairpos('{', '', '}', 'bW', g:omni#cpp#utils#expIgnoreComments)
        if curPos != [0,0]
            let matchPos = curPos
            " Now want to search our variable but we don't want to go in child
            " scope
            while matchPos != [0,0]
                let matchPos = searchpos('{\|'.szReVariable, 'W', stopPos[0])
                if matchPos != [0,0]
                    " We ignore matches under comment
                    if omni#cpp#utils#IsCursorInCommentOrString()
                        continue
                    endif

                    " Getting the current line
                    let szLine = getline('.')
                    if match(szLine, szReVariable)>=0
                        " We found our variable
                        " Check if the current instruction is a decl instruction
                        let tokens = omni#cpp#utils#TokenizeCurrentInstruction()
                        let szTypeInfo = s:ExtractTypeInfoFromDecl(tokens)
                        if szTypeInfo != ''
                            call setpos('.', originalPos)
                            return omni#cpp#utils#CreateTypeInfo(szTypeInfo)
                        endif
                    else
                        " We found a child scope, we don't want to go in, thus
                        " we search for the end } of this child scope
                        let bracketEnd = searchpairpos('{', '', '}', 'nW', g:omni#cpp#utils#expIgnoreComments)
                        if bracketEnd == [0,0]
                            break
                        endif

                        if bracketEnd[0] >= stopPos[0]
                            " The end of the scope is after our cursor we stop
                            " the search
                            break
                        else
                            " We move the cursor and continue to search our
                            " variable
                            call setpos('.', [0, bracketEnd[0], bracketEnd[1], 0])
                        endif
                    endif
                endif
            endwhile

            " Backing to the start of the scope
            call setpos('.', [0,curPos[0], curPos[1], 0])
            let stopPos = curPos
        endif
    endwhile

    let result = {}
    if s:LocalSearchDecl(a:szVariable)==0 && !omni#cpp#utils#IsCursorInCommentOrString()
        let tokens = omni#cpp#utils#TokenizeCurrentInstruction()
        let szTypeInfo = s:ExtractTypeInfoFromDecl(tokens)
        if szTypeInfo != ''
            let result = omni#cpp#utils#CreateTypeInfo(szTypeInfo)
        endif
    endif

    call setpos('.', originalPos)

    return result
endfunc

function! s:CmpPos(pos1, pos2) " 比较两个光标位置 {{{2
	let pos1 = a:pos1
	let pos2 = a:pos2
	if pos1[0] > pos2[0]
		return 1
	elseif pos1[0] < pos2[0]
		return -1
	else
		if pos1[1] > pos2[1]
			return 1
		elseif pos1[1] < pos2[1]
			return -1
		else
			return 0
		endif
	endif
endfunc

" Search a declaration
" @return
"   - tokens of the current instruction if success
"   - empty list if failure
function! s:SearchDecl(szVariable)
    let result = {}
    let originalPos = getpos('.')
    let searchResult = s:LocalSearchDecl(a:szVariable)
	let curPos = getpos('.')[1:2]
    while searchResult == 0 && s:CmpPos(curPos, originalPos[1:2]) < 0
        " searchdecl() may detect a decl if the variable is in a conditional
        " instruction (if, elseif, while etc...)
        " We have to check if the detected decl is really a decl instruction
		" FIXME: s:LocalSearchDecl() 得到的位置不准确. 需要更准确
		" TODO: 每搜索一次声明, 理解验证有效性
		" 1. 搜索声明, 解析 tokens, 若无效, 往下搜索不超过起始位置的同名符号
		" 2. 重复往下搜索同名符号, 不超过起始位置, 并检查有效性
		" 3. 到达起始位置, 搜索失败
		" 搜索 foo 声明行应该为 Foo foo;
		" TestCase:
		" mc.foo();
		" Foo foo;
		" foo;
        let tokens = omni#cpp#utils#TokenizeCurrentInstruction()

		" 上述情形, tokens 最后项的类型只能为
		" C++ 关键词或单词
		" * 或 & 后 > 操作符(eg. void *p; int &n; vector<int> x;)
		"if !empty(tokens) && !(tokens[-1].kind == 'cppKeyword' 
					"\|| tokens[-1].kind != 'cppWord' 
					"\|| (tokens[-1].kind == 'cppOperatorPunctuator' 
					"\	&& tokens[-1].value =~# '\V*\|&\|>' ))
		"简单的而快速的
		if !empty(tokens) && (tokens[-1].kind == 'cppOperatorPunctuator' 
					\&& tokens[-1].value =~# '\V.\|->')
			" 无效的声明
			" 继续搜索
			let curPos = searchpos('\C\<'. a:szVariable .'\>', 'W')
			" TODO: 如果当前位置是注释, 继续搜索
			continue
		endif

        for token in tokens
            " Simple test
            if index(['if', 'elseif', 'while', 'for', 'switch'], token.value)>=0
                " Invalid declaration instruction
				let curPos = searchpos('\C\<'. a:szVariable .'\>', 'W')
				continue
                "call setpos('.', originalPos)
                "return result
            endif
        endfor

        let szTypeInfo = s:ExtractTypeInfoFromDecl(tokens)
        if szTypeInfo != ''
            let result = omni#cpp#utils#CreateTypeInfo(szTypeInfo)
        endif
		let curPos = getpos('.')[1:2]
		break
	endwhile
    call setpos('.', originalPos)
    return result
endfunc

function! omni#cpp#items#SearchDecl(szVariable)
	return s:SearchDecl(a:szVariable)
endfunc

" Extract the type info string from an instruction.
" We use a small parser to extract the type
" We parse the code according to a C++ BNF from: http://www.nongnu.org/hcb/#basic.link
" @param tokens: token list of the current instruction
function! s:ExtractTypeInfoFromDecl(tokens)
    return omni#cpp#utils#ExtractTypeInfoFromTokens(a:tokens)
endfunc

" Convert tokens to string
function! s:TokensToString(tokens)
    let result = ''
    for token in a:tokens
        let result = result . token.value . ' '
    endfor
    return result[:-2]
endfunc

" Resolve a cast.
" Resolve a C++ cast
" @param list of token. tokens must be a list that represents
" a cast expression (C++ cast) the function does not control
" if it's a cast or not
" eg: static_cast<MyClass*>(something)
" @return type info string
function! s:ResolveCppCast(tokens)
    return omni#cpp#utils#ExtractTypeInfoFromTokens(s:ResolveCast(a:tokens, '<', '>'))
endfunc

" Resolve a cast.
" Resolve a C cast
" @param list of token. tokens must be a list that represents
" a cast expression (C cast) the function does not control
" if it's a cast or not
" eg: (MyClass*)something
" @return type info string
function! s:ResolveCCast(tokens)
    return omni#cpp#utils#ExtractTypeInfoFromTokens(s:ResolveCast(a:tokens, '(', ')'))
endfunc

" Resolve a cast.
" Resolve a C cast
" @param list of token. tokens must be a list that represents
" a cast expression (C cast) the function does not control
" if it's a cast or not
" eg: (MyClass*)something
" @return type tokens
function! s:ResolveCast(tokens, startChar, endChar)
    let tokens = omni#cpp#utils#BuildParenthesisGroups(a:tokens)

    " We remove useless parenthesis eg: (((MyClass)))
    let tokens = omni#cpp#utils#SimplifyParenthesis(tokens)

    let countItem=0
    let startIndex = -1
    let endIndex = -1 
    let i = 0
    for token in tokens
        if startIndex==-1
            if token.value==a:startChar
                let countItem += 1
                let startIndex = i
            endif
        else
            if token.value==a:startChar
                let countItem += 1
            elseif token.value==a:endChar
                let countItem -= 1
            endif

            if countItem==0
                let endIndex = i
                break
            endif
        endif
        let i+=1
    endfor

    return tokens[startIndex+1 : endIndex-1]
endfunc

" Replacement for build-in function 'searchdecl'
" It does not require that the upper-level bracket is in the first column.
" Otherwise it should be equal to 'searchdecl(name, 0, 1)'
" @param name: name of variable to find declaration for
function! s:LocalSearchDecl(name)

    if g:OmniCpp_LocalSearchDecl == 0
        let bUserIgnoreCase = &ignorecase

        " Forcing the noignorecase option
        " avoid bug when, for example, if we have a declaration like this : "A a;"
        set noignorecase

		" FIXME: 不准确!
        let result = searchdecl(a:name, 0, 1)

        " Restoring user's setting
        let &ignorecase = bUserIgnoreCase

        return result
    endif

    let lastpos = getpos('.')
    let winview = winsaveview()
    let lastfoldenable = &foldenable
    let &foldenable = 0

    " We add \C (noignorecase) to 
    " avoid bug when, for example, if we have a declaration like this : "A a;"
    let varname = "\\C\\<" . a:name . "\\>"

    " Go to first blank line before begin of highest scope
    normal 99[{
    let scopepos = getpos('.')
    while (line('.') > 1) && (len(split(getline('.'))) > 0)
        call cursor(line('.')-1, 0)
    endwhile

    let declpos = [ 0, 0, 0, 0 ]
    while search(varname, '', scopepos[1]) > 0
        " Check if we are a string or a comment
        if omni#cpp#utils#IsCursorInCommentOrString()
            continue
        endif

        " Remember match
        let declpos = getpos('.')
    endwhile
    if declpos[1] != 0
        " We found a match
        call winrestview(winview)
        call setpos('.', declpos)
        let &foldenable = lastfoldenable
        return 0
    endif

    while search(varname, '', lastpos[1]) > 0
        " Check if current scope is ending before variable
        let old_cur = getpos('.')
        normal ]}
        let new_cur = getpos('.')
        call setpos('.', old_cur)
        if (new_cur[1] < lastpos[1]) || ((new_cur[1] == lastpos[1]) && (new_cur[2] < lastpos[2]))
          continue
        endif

        " Check if we are a string or a comment
        if omni#cpp#utils#IsCursorInCommentOrString()
          continue
        endif

        " We found match
        call winrestview(winview)
        call setpos('.', old_cur)
        let &foldenable = lastfoldenable
        return 0
    endwhile

    " No match found.
    call winrestview(winview)
    let &foldenable = lastfoldenable
    return 1
endfunc
