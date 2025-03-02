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
            style:    string
            config:   JsonNode
        of itemFile:
            fileKind: FileKind


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
    


proc removeSuffixInsensitive(s, suffix: string): string =
    if s.toLowerAscii().endsWith(suffix.toLowerAscii()):
        return s[0 ..< s.len - suffix.len]
    return s

    
proc convertMarkdownToNercPage(tree: DirTreeNode) =
    echo tree.path[2..^1]  & " : " & tree.name & "\n\n\n"
    if tree.kind == itemDir: return
    
    var outPath: string = tree.path[2..^1]
    outPath.removeSuffix(".md")
    if toLowerAscii(outPath).endsWith("readme"): 
        outpath = outPath.removeSuffixInsensitive("readme") & "index"
    outPath = outPath & ".htm"
    
    let mdFile  = readFile(tree.path[2..^1])
    
    var htmlTxt = htmlTemplate.replace(ContentTag,markdown(mdFile))
    htmlTxt = htmlTxt.replace(SidebarTag,genSidebar(fsTree,tree))

    writefile(outPath, htmlTxt)


proc buildDirTree(node: DirTreeNode, depth: uint) =
    let path = node.path 
    
    for kind, name in walkDir(path, relative = true):
        if name[0] == '.': continue # Skip hidden files and directories (such as .git)
        if kind == pcFile:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemFile, name: name.split('.')[0].replace('_', ' '), path: path & '/' & name)
            
            if name.toLowerAscii().endsWith(".md"):
                new_node.fileKind = fileMarkdown
                #convertMarkdownToNercPage(path)
            elif name.toLowerAscii() == "config.json":
                new_node.fileKind = fileJSON
            elif name.toLowerAscii() == "template.htm":
                new_node.fileKind = fileTemplate
            elif name.toLowerAscii().endsWith(".htm") || name.toLowerAscii().endsWith(".html"):
                new_node.fileKind = fileHTML
            else: continue
            
            #echo "\t", path & "/" & name
            node.contents.add(new_node)
            
        elif kind == pcDir:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemDir, name: name, path: path & '/' & name)
            #echo path & "/" & name
            buildDirTree(new_node, depth+1)
            node.contents.add(new_node)


proc printTree(tree: DirTreeNode) =
    if tree.kind == itemFile:
        
        case tree.fileKind
        of fileMarkdown: echo tree.depth, repeat('\t', tree.depth), tree.name, " : Markdown"
        of fileJSON:     echo tree.depth, repeat('\t', tree.depth), tree.name, " : JSON"
        of fileTemplate: echo tree.depth, repeat('\t', tree.depth), tree.name, " : HTML"
    
    elif tree.kind == itemDir:
        echo repeat('\t', tree.depth), tree.path, " : ", tree.name, " : ", tree.contents.len()
        
        for item in tree.contents:
            printTree(item)
            continue


proc genSidebar(tree: DirTreeNode, currentItem: DirTreeNode): string =
    var sidebar: string
    
    if tree.kind == itemFile:
        if tree.fileKind != fileMarkdown: return ""
        
        var 
            name = tree.name
            path = tree.path
        
        path.removeSuffix("md")
        path = path & "htm"
        
        if "readme" == toLowerAscii(name): return ""
        if "index" == name: return ""
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
