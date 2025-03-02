import  
    json,
    macros, 
    markdown, 
    os, 
    strutils, 
    terminal


type
    ItemKind = enum
        itemFile, itemDir

    FileKind = enum
        fileMarkdown,
        fileJSON
        fileHTML
        fileTemplate
    
    DirTreeNode = ref object
        depth:  uint
        name:   string
        path:   string
        parent: DirTreeNode
        case kind: ItemKind
        of itemDir:
            contents: seq[DirTreeNode]
            html:     string
            style:    string
            config:   JsonNode
        of itemFile:
            fileKind: FileKind
            label: string


proc convertMarkdownToNercPage(tree: DirTreeNode) 
proc buildDirTree(node: DirTreeNode, depth: uint)
proc printTree(tree: DirTreeNode) 
proc genSidebar( tree: DirTreeNode, currentItem: DirTreeNode): string
proc populateDirs(treeRoot: DirTreeNode)


const
    PageTitleTag:     string = "<!--page title-->"
    StyleOverrideTag: string = "<!--style override-->"
    LinksLeftTag:     string = "<!--links left-->"
    LinksRightTag:    string = "<!--links right-->"
    SiteTitleTag:     string = "<!--site title-->"
    SubtitleTag:      string = "<!--subtitle-->"
    SidebarTag:       string = "<!--sidebar-->"
    ContentTag:       string = "<!--content-->"
    FooterLeftTag:    string = "<!--footer left-->"
    FooterRightTag:   string = "<!--footer right-->"
    
    htmlTemplate = staticRead("res/template.htm")
    defaultStyle = staticRead("res/styles.css")
    defaultJson  = staticRead("res/config.json")


var 
    pageTitle:       string
    htmlSidebar:     string
    htmlLinksLeft:   string
    htmlLinksRight:  string
    htmlFooterLeft:  string
    htmlFooterRight: string
    
    fsTree:          DirTreeNode = DirTreeNode(depth: 0, name: "Main", path: ".", kind: itemDir)
    

fsTree.html   = htmlTemplate
fsTree.style  = defaultStyle
fsTree.config = parseJson(defaultJson)


proc getConfig(parentDir: DirTreeNode, key: string): JsonNode {.inline.} =
    if not parentDir.config.isNil and parentDir.config.hasKey(key): 
        return parentDir.config[key]
    
    if parentDir.parent != nil:
        return getConfig(parentDir.parent, key)

    return %*""


proc removeSuffixInsensitive(s, suffix: string): string =
    if s.toLowerAscii().endsWith(suffix.toLowerAscii()):
        return s[0 ..< s.len - suffix.len]
    return s

    
proc convertMarkdownToNercPage(tree: DirTreeNode) =
    echo tree.path[2..^1]  & " : " & tree.name & "\n"
    if tree.kind == itemDir: return
    
    var outPath: string = tree.path[2..^1]
    outPath.removeSuffix(".md")
    if toLowerAscii(outPath).endsWith("readme"): 
        outpath = outPath.removeSuffixInsensitive("readme") & "index"
    outPath = outPath & ".htm"
    
    let mdFile  = readFile(tree.path[2..^1])
    
    var htmlTxt = htmlTemplate
    if htmlTxt.contains(PageTitleTag):    htmlTxt = htmlTxt.replace(PageTitleTag,   tree.parent.getConfig("page title").getStr() & " - " & tree.name)
    if htmlTxt.contains(SiteTitleTag):    htmlTxt = htmlTxt.replace(SiteTitleTag,   tree.parent.getConfig("site title").getStr())
    if htmlTxt.contains(SubtitleTag):     htmlTxt = htmlTxt.replace(SubtitleTag,    tree.parent.getConfig("subtitle").getStr())
    if htmlTxt.contains(SidebarTag):      htmlTxt = htmlTxt.replace(SidebarTag,     genSidebar(fsTree, tree))
    if htmlTxt.contains(ContentTag):      htmlTxt = htmlTxt.replace(ContentTag,     markdown(mdFile))
    if htmlTxt.contains(FooterLeftTag):   htmlTxt = htmlTxt.replace(FooterLeftTag,  tree.parent.getConfig("footer left").getStr())
    if htmlTxt.contains(FooterRightTag):  htmlTxt = htmlTxt.replace(FooterRightTag, tree.parent.getConfig("footer right").getStr())
    
    writefile(outPath, htmlTxt)


proc buildDirTree(node: DirTreeNode, depth: uint) =
    let path = node.path 
    
    for kind, name in walkDir(path, relative = true):
        if name[0] == '.': continue # Skip hidden files and directories (such as .git)
        if kind == pcFile:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemFile, name: name.split('.')[0].replace('_', ' '), path: path & '/' & name, parent: node)
            
            if name.toLowerAscii().endsWith(".md"):
                new_node.fileKind = fileMarkdown
                #convertMarkdownToNercPage(path)
            elif name.toLowerAscii() == "config.json":
                echo new_node.path[2..^1]
                var file: string = readFile(new_node.path[2..^1])
                echo file
                node.config = parseJson(file)
                continue
            elif name.toLowerAscii() == "template.htm":
                node.html = readFile(new_node.path)
                continue
            elif name.toLowerAscii() == "styles.css":
                
                continue
            elif name.toLowerAscii().endsWith(".html"):
                new_node.fileKind = fileHTML
            else: continue
            
            #echo "\t", path & "/" & name
            node.contents.add(new_node)
            
        elif kind == pcDir:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemDir, name: name, path: path & '/' & name, parent: node)
            #echo path & "/" & name
            buildDirTree(new_node, depth+1)
            node.contents.add(new_node)


proc printTree(tree: DirTreeNode) =
    if tree.kind == itemFile:
        
        case tree.fileKind
        of fileMarkdown: echo tree.depth, repeat('\t', tree.depth), tree.name, " : Markdown"
        of fileJSON:     echo tree.depth, repeat('\t', tree.depth), tree.name, " : JSON"
        of fileTemplate: echo tree.depth, repeat('\t', tree.depth), tree.name, " : Template"
        of fileHTML:     echo tree.depth, repeat('\t', tree.depth), tree.name, " : HTML"
    
    elif tree.kind == itemDir:
        echo repeat('\t', tree.depth), tree.path, " : ", tree.name, " : ", tree.contents.len()
        
        for item in tree.contents:
            printTree(item)
            continue


proc genSidebar(tree: DirTreeNode, currentItem: DirTreeNode): string =
    var sidebar: string
    
    if tree.kind == itemFile:
        var 
            name = tree.name
            path = tree.path
            
        if tree.fileKind != fileMarkdown and tree.fileKind != fileHTML: return ""

        if tree.fileKind == fileMarkdown:
            path.removeSuffix("md")
            path = path & "htm"
            
            if "readme" == toLowerAscii(name): return ""
        
        if "index" == toLowerAscii(name): return ""
        if tree == currentItem: name = ">> " & name & " <<"
        
        return repeat('\t', tree.depth) & "<li class=\"page\"><a href=\"" & path & "\">" & name & "</a></li>\n"
        
    elif tree.kind == itemDir:
        var 
            itemList: string
            name = tree.name
        
        if tree.depth == 0: name = "Main"
        
        for item in tree.contents:
            itemList = itemList & genSidebar(item, currentItem)

        itemList = 
            "<li class=\"dir\"><a href=\"" & tree.path & "\">" & name & "</a>\n" & "<ul>\n" & 
            itemList & 
            "</ul>\n</li>"

        if tree.depth == 0: itemList = "<ul>\n" & itemList & "\n</ul>"
        
        return itemList


proc populateDirs(treeRoot: DirTreeNode) = 
    for node in treeRoot.contents:
        if node.kind == itemFile:
            if node.fileKind != fileMarkdown: continue
            convertMarkdownToNercPage(node)
        elif node.kind == itemDir:
            populateDirs(node)


proc main() =
    let args       = commandLineParams()
    let currentDir = "."

    if 0 < args.len:
        if isValidFileName(args[0]):
            echo args[0]

    buildDirTree(fsTree, 1)
    printTree(fsTree)
    populateDirs(fsTree)

main()
