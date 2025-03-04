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
        label:  string
        path:   string
        parent: DirTreeNode
        case kind: ItemKind
        of itemDir:
            contents: seq[DirTreeNode]
            html:     string
            style:    string
            config:   JsonNode
            hasIndex: DirTreeNode
        of itemFile:
            fileKind: FileKind


proc getConfig(node: DirTreeNode, key: string): JsonNode {.inline.} 
proc removeSuffixInsensitive(s, suffix: string): string 
proc convertMarkdownToNercPage(tree: DirTreeNode) 
proc buildDirTree(node: DirTreeNode, depth: uint)
proc printTree(tree: DirTreeNode) 
proc genSidebar( tree: DirTreeNode, currentItem: DirTreeNode): string
proc populateDirs(treeRoot: DirTreeNode)


const
    PageTitleTag:     string = "<!--page title-->"
    StyleOverrideTag: string = "<!--style override-->"
    LinksTag:         string = "<!--links-->"
    SiteTitleTag:     string = "<!--site title-->"
    SubtitleTag:      string = "<!--subtitle-->"
    SidebarTag:       string = "<!--sidebar-->"
    ContentTag:       string = "<!--content-->"
    FooterLeftTag:    string = "<!--footer left-->"
    FooterRightTag:   string = "<!--footer right-->"
    
    DefaultTemplate = staticRead("res/template.htm")
    DefaultStyle    = staticRead("res/styles.css")
    DefaultJson     = staticRead("res/config.json")

let DefaultConfig   = parseJson(DefaultJson)


var 
    pageTitle:       string
    htmlSidebar:     string
    htmlLinksLeft:   string
    htmlLinksRight:  string
    htmlFooterLeft:  string
    htmlFooterRight: string
    
    fsTree:          DirTreeNode = DirTreeNode(depth: 0, label: "Main", path: ".", kind: itemDir)
    

fsTree.html   = DefaultTemplate
fsTree.style  = DefaultStyle
fsTree.config = DefaultConfig


proc removeSuffixInsensitive(s, suffix: string): string =
    if s.toLowerAscii().endsWith(suffix.toLowerAscii()):
        return s[0 ..< s.len - suffix.len]
    return s


proc getConfig(node: DirTreeNode, key: string): JsonNode {.inline.} =
    if not node.config.isNil:
        if node.config.hasKey(key):
            return node.config[key]

    if node.parent != nil:
        return getConfig(node.parent, key)

    return DefaultConfig[key]


proc genLinks(node: DirTreeNode): string =
    var 
        links:        string   = ""
        separator:    string   = ""
        addSeparator: bool     = false

    if node.config.isNil: return node.parent.genLinks()
    let config:       JsonNode = node.getConfig("links")
    
    if config.kind != JObject: 
        #echo "[LINKS] Not generating links."
        return node.parent.genLinks()

    for label, link in config.pairs():
        separator = if addSeparator: "&nbsp;|&nbsp;" else: ""

        if label == "" and link.getStr() == "SPACER":
            links = links & "<div class=\"spacer\" ></div>"
            addSeparator = false
            continue
        
        links = links & separator & "<a href=\"" & link.getStr() & "\">" & label & "</a>"
        addSeparator = true
    
    #echo "[LINKS] " & links
    return links


proc genPath(node: DirTreeNode): string =
    if node.parent == nil: return "/"
    var path = genPath(node.parent) & node.name
    if node.kind == itemDir: path = path & '/'
    return path


proc convertMarkdownToNercPage(tree: DirTreeNode) =
    echo tree.path[2..^1]  & " : " & tree.name & "\n"
    if tree.kind == itemDir: return
    
    var outPath: string = tree.path[2..^1]
    outPath.removeSuffix(".md")
    if toLowerAscii(outPath).endsWith("readme"): 
        outpath = outPath.removeSuffixInsensitive("readme") & "index"
    outPath = outPath & ".htm"
    
    let mdFile  = readFile(tree.path[2..^1])
    
    var htmlTxt = DefaultTemplate
    if htmlTxt.contains(PageTitleTag):    htmlTxt = htmlTxt.replace( PageTitleTag,   tree.parent.getConfig("page title").getStr() & " - " & tree.name )
    if htmlTxt.contains(LinksTag):        htmlTxt = htmlTxt.replace( LinksTag,       tree.parent.genLinks()                         )
    if htmlTxt.contains(SiteTitleTag):    htmlTxt = htmlTxt.replace( SiteTitleTag,   tree.parent.getConfig("site title").getStr()   )
    if htmlTxt.contains(SubtitleTag):     htmlTxt = htmlTxt.replace( SubtitleTag,    tree.parent.getConfig("subtitle").getStr()     )
    if htmlTxt.contains(SidebarTag):      htmlTxt = htmlTxt.replace( SidebarTag,     fsTree.genSidebar(tree)                        )
    if htmlTxt.contains(ContentTag):      htmlTxt = htmlTxt.replace( ContentTag,     mdFile.markdown()                              )
    if htmlTxt.contains(FooterLeftTag):   htmlTxt = htmlTxt.replace( FooterLeftTag,  tree.parent.getConfig("footer left").getStr()  )
    if htmlTxt.contains(FooterRightTag):  htmlTxt = htmlTxt.replace( FooterRightTag, tree.parent.getConfig("footer right").getStr() )
    
    writefile(outPath, htmlTxt)


proc buildDirTree(node: DirTreeNode, depth: uint) =
    let path = node.path 
    
    for kind, name in walkDir(path, relative = true):
        if name[0] == '.': continue # Skip hidden files and directories (such as .git)
        if kind == pcFile:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemFile, name: name, path: path & '/' & name, parent: node)
            echo "[FILE] " & name
            if name.toLowerAscii().endsWith(".md"):
                new_node.fileKind = fileMarkdown
                new_node.label = name.split('.')[0].replace('_', ' ')
                echo "[LABEL] " & new_node.label
                if "readme" == new_node.label.toLowerAscii(): node.hasIndex = new_node
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
            new_node.parent = node
            #echo "\t", path & "/" & name
            node.contents.add(new_node)
            
        elif kind == pcDir:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemDir, name: name, label: name.split('.')[0].replace('_', ' '), path: path & '/' & name, parent: node)
            #echo path & "/" & name
            echo "[DIR] " & name
            echo "[LABEL] " & new_node.label
            new_node.parent = node
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
            name  = tree.name
            label = tree.label
            path  = tree.genPath()
            
        if tree.fileKind != fileMarkdown and tree.fileKind != fileHTML: return ""

        if tree.fileKind == fileMarkdown:
            path.removeSuffix(".md")
            path = path & ".htm"
            
            if "readme" == toLowerAscii(label): return ""
        
        if "index" == toLowerAscii(label): return ""
        if tree == currentItem: label = ">> " & label & " <<"

        echo path
        return repeat('\t', tree.depth) & "<li class=\"page\"><a href=\"" & path & "\">" & label & "</a></li>\n"
        
    elif tree.kind == itemDir:
        var 
            itemList: string
            name  = tree.name
            label = tree.label
            path  = tree.genPath()
        
        #if tree.depth == 0: name = "Main"
        if tree.hasIndex == currentItem: label = ">> " & label & " <<"
        
        for item in tree.contents:
            itemList = itemList & genSidebar(item, currentItem)
        
        echo "Generated Path: " & path
        if tree.hasIndex != nil: label = "<a href=\"" & path & "\">" & label & "</a>\n"
        itemList = 
            "<li class=\"dir\">" & label & "<ul>\n" & 
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

    if 0 < args.len:
        if isValidFileName(args[0]):
            echo args[0]

    buildDirTree(fsTree, 1)
    printTree(fsTree)
    populateDirs(fsTree)

main()
