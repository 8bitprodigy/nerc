#[ TODO:
    - command line arguments
    - Clean up the code a little, I guess
]#
import  
    algorithm,
    json,
    macros, 
    markdown, 
    options,
    os, 
    posix,
    sequtils,
    strutils, 
    terminal,
    times


type
    ItemKind = enum
        itemFile, 
        itemDir

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
            config:   JsonNode
            hasIndex: DirTreeNode
            hasCSS:   DirTreeNode
            hasHTML:  DirTreeNode
        of itemFile:
            fileKind: FileKind
            date: times.Time


proc getConfig(node: DirTreeNode, key: string): JsonNode
proc genLinks(node: DirTreeNode): string 
proc genPath(node: DirTreeNode): string 
proc removeSuffixInsensitive(s, suffix: string): string 
proc convertMarkdownToNercPage(node: DirTreeNode) 
proc buildDirTree(node: DirTreeNode, depth: uint)
proc printTree(node: DirTreeNode) 
proc genSidebar( tree: DirTreeNode, currentItem: DirTreeNode): string
proc populateDirs(treeRoot: DirTreeNode)


const
    Spacer:           string = "<span class=\"spacer\" ></span>"
    
    PageTitleTag:     string = "<!--page title-->"
    StylesTag:        string = "<!--styles-->"
    LinksTag:         string = "<!--links-->"
    SiteTitleTag:     string = "<!--site title-->"
    SubtitleTag:      string = "<!--subtitle-->"
    SidebarTag:       string = "<!--sidebar-->"
    ContentTag:       string = "<!--content-->"
    FooterLeftTag:    string = "<!--footer left-->"
    FooterRightTag:   string = "<!--footer right-->"
    
    DefaultTemplate = staticRead("res/template.html")
    DefaultStyles    = staticRead("res/styles.css")
    DefaultJson     = staticRead("res/config.json")

var defaultconfig: JsonNode

try:
    defaultconfig = parseJson(DefaultJson)
except JsonParsingError:
    echo "[ERROR] Built-in config.json does not pass validation. Fix error and recompile."

let DefaultConfig = defaultconfig

var 
    pageTitle:       string
    htmlSidebar:     string
    htmlLinksLeft:   string
    htmlLinksRight:  string
    htmlFooterLeft:  string
    htmlFooterRight: string
    
    fsTree:          DirTreeNode = DirTreeNode(depth: 0, name: "", label: "Main", path: ".", kind: itemDir)
    

fsTree.html   = DefaultTemplate
fsTree.config = DefaultConfig


proc genNav(node: DirTreeNode): string =
    let
        size    = node.parent.contents.len
        nodeIdx = node.parent.contents.find(node)
        prev    = nodeIdx + 1
        next    = nodeIDX - 1
        hasPrev = prev < size
        hasNext = 0 <= next

    if not (hasPrev or hasNext): return ""

    result = "<span class=\"spacer\">"
    
    if hasPrev:
        let prevNode = node.parent.contents[prev]
        var path     = prevNode.genPath().removeSuffixInsensitive(".md") 
        if node.parent.hasIndex == prevNode: path = path.removeSuffixInsensitive(prevNode.name.removeSuffixInsensitive(".md")) & "index"
        if      prevNode.kind     == itemFile and 
                prevNode.fileKind == fileMarkdown:
            result = result & "<a href=\"" & path & ".htm\"><-&nbsp;Prev</a>"
            
    result = result & Spacer
    
    if hasNext:
        let nextNode = node.parent.contents[next]
        var path     = nextNode.genPath().removeSuffixInsensitive(".md") 
        if node.parent.hasIndex == nextNode: path = path.removeSuffixInsensitive(nextNode.name.removeSuffixInsensitive(".md")) & "index"
        if      nextNode.kind     == itemFile and
                nextNode.fileKind == fileMarkdown:
            result = result & "<a href=\"" & path & ".htm\">Next&nbsp;-></a>"
        
    result = result & "</span>"


proc getLatestNode(nodes: seq[DirTreeNode]): DirTreeNode =
    result = nil
    for node in nodes:
        if node.kind == itemFile:
            if result == nil:
                result = node
            elif node.date > result.date:
                result = node



proc getDirectorySorted(dir: string): seq[tuple[kind: PathComponent, path: string]] =
    # Create sequences to store directories and files
    var dirs: seq[tuple[kind: PathComponent, path: string]] = @[]
    var files: seq[tuple[kind: PathComponent, path: string]] = @[]

    # Walk through directory contents
    for ikind, ipath in walkDir(dir,relative=true):
        case ikind
        of pcDir:
            # Skip current and parent directories
            if not (ipath.endsWith("/.") or ipath.endsWith("/..")):
                dirs.add((ikind, ipath))
        of pcFile:
            files.add((ikind, ipath))
        else:
            continue

    result.concat(dirs, files)
 
    
proc removeSuffixInsensitive(s, suffix: string): string =
    if s.toLowerAscii().endsWith(suffix.toLowerAscii()):
        return s[0 ..< s.len - suffix.len]
    return s


proc getTemplate(node: DirTreeNode): string =
    if node.hasHTML != nil:
        if node.html != "":
            return node.html

    if node.parent != nil:
        return node.parent.getTemplate()

    return DefaultTemplate
            

proc getConfig(node: DirTreeNode, key: string): JsonNode = 
    if not node.config.isNil:
        if node.config.hasKey(key):
            return node.config[key]

    if node.parent != nil:
        return node.parent.getConfig(key)

    return DefaultConfig[key]


proc getStyles(node: DirTreeNode): string =
    if node.hasCSS != nil:
        let styles: string = if node.parent!=nil: node.parent.getStyles() else: ""
        return styles & "\n@import url(\"" & node.genPath() & "styles.css\");"
    if node.parent != nil:
        return node.parent.getStyles()
    return ""


proc genLinks(node: DirTreeNode): string =
    var 
        links:        string   = ""
        separator:    string   = ""
        addSeparator: bool     = false

    if node.config.isNil: return node.parent.genLinks()
    let config:       JsonNode = node.getConfig("links")
    
    if config.kind != JArray: 
        return node.parent.genLinks()

    for item in config:
        if item.kind != JObject: continue
        if not item.hasKey("label") and not item.hasKey("link"): continue
        if item["label"].kind != JString: continue
        if item["link"].kind  != JString: continue
        let
            label = item["label"].getStr()
            link  = item["link"].getStr()
        
        separator = if addSeparator: "&nbsp;|&nbsp;" else: ""

        if label == "" and link == "SPACER":
            links = links & Spacer
            addSeparator = false
            continue
        
        links = links & separator & "<a href=\"" & link & "\">" & label & "</a>"
        addSeparator = true
    
    return links


proc genPath(node: DirTreeNode): string =
    if node.parent == nil: return "/"
    var path = genPath(node.parent) & node.name
    if node.kind == itemDir: path = path & '/'
    return path


proc convertMarkdownToNercPage(node: DirTreeNode) =
    if node.kind == itemDir: return
    let config: string = node.parent.getConfig("index").getStr()
    
    var outPath: string = node.path[2..^1]
    outPath = outPath.removeSuffixInsensitive(".md")
    if node.parent.hasIndex == node:
        if config[0]=='$':
            outpath = outPath.removeSuffixInsensitive(config[1..^1]) & "index"
        elif config == "newest":
            outpath = outpath.removeSuffixInsensitive(node.name.removeSuffixInsensitive(".md")) & "index"
    outPath = outPath & ".htm"
    
    let 
        mdFile   = readFile(node.path[2..^1])
        navLinks = genNav(node)
    
    var 
        htmlTxt = node.parent.getTemplate()
        pageTitle: string = ""
        content: string   = ""

    if node.parent.getConfig("upper nav").getBool():
        content = content & navLinks & "\n<br />\n"

    if node.parent.getConfig("doc title").getBool() and 
            (node.parent.hasIndex != node):
        content = content & "<h1>" & node.label & "</h1>\n"

    content = content & mdFile.markdown()

    if node.parent.getConfig("lower nav").getBool():
        content = content & "\n<br />\n" & navLinks
    
    if node.parent.hasIndex != node: pageTitle = " - " & node.label
    if htmlTxt.contains(PageTitleTag):    htmlTxt = htmlTxt.replace( PageTitleTag,   node.parent.getConfig("page title").getStr() & pageTitle )
    if htmlTxt.contains(StylesTag):       htmlTxt = htmlTxt.replace( StylesTag,      node.parent.getStyles()                                  )
    if htmlTxt.contains(LinksTag):        htmlTxt = htmlTxt.replace( LinksTag,       node.parent.genLinks()                                   )
    if htmlTxt.contains(SiteTitleTag):    htmlTxt = htmlTxt.replace( SiteTitleTag,   node.parent.getConfig("site title").getStr()             )
    if htmlTxt.contains(SubtitleTag):     htmlTxt = htmlTxt.replace( SubtitleTag,    node.parent.getConfig("subtitle").getStr()               )
    if htmlTxt.contains(SidebarTag):      htmlTxt = htmlTxt.replace( SidebarTag,     fsTree.genSidebar(node)                                  )
    if htmlTxt.contains(ContentTag):      htmlTxt = htmlTxt.replace( ContentTag,     content                                                  )
    if htmlTxt.contains(FooterLeftTag):   htmlTxt = htmlTxt.replace( FooterLeftTag,  node.parent.getConfig("footer left").getStr()            )
    if htmlTxt.contains(FooterRightTag):  htmlTxt = htmlTxt.replace( FooterRightTag, node.parent.getConfig("footer right").getStr()           )
    
    writefile(outPath, htmlTxt)
    echo "[GENERATED]: ", outPath


proc buildDirTree(node: DirTreeNode, depth: uint) =
    let 
        path  = node.path 
        files = getDirectorySorted(path)
    
    for (kind, name) in files:
        if name.startsWith(".") or name.startsWith("_"): continue # Skip hidden files and directories (such as .git)
        if kind == pcFile:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemFile, name: name, path: path & '/' & name, parent: node)
            
            if name.toLowerAscii().endsWith(".md"):
                new_node.fileKind = fileMarkdown
                new_node.label = name.removeSuffixInsensitive(".md").replace('_', ' ')
                #convertMarkdownToNercPage(path)
            elif name.toLowerAscii() == "config.json":
                var file: string = readFile(new_node.path[2..^1])
                try: 
                    node.config = parseJson(file)
                except JsonParsingError:
                    echo "[ERROR] ", name, " at ", path, " did not pass validation and will be ignored." 
                continue
                
            elif name.toLowerAscii() == "template.html":
                node.hasHTML = new_node
                node.html    = readFile(new_node.path)
                continue
                
            elif name.toLowerAscii() == "styles.css":
                node.hasCSS = new_node
                continue
                
            elif name.toLowerAscii().endsWith(".html"):
                new_node.fileKind = fileHTML
            else: continue
            new_node.date = getCreationTime(new_node.path)
            new_node.parent = node
            node.contents.add(new_node)
            
        elif kind == pcDir:
            var new_node: DirTreeNode = DirTreeNode(depth: depth, kind: itemDir, name: name, label: name.split('.')[0].replace('_', ' '), path: path & '/' & name, parent: node)
            new_node.parent = node
            buildDirTree(new_node, depth+1)
            node.contents.add(new_node)

    
    let sortMode = node.getConfig("sort").getStr()
    if sortMode == "newest":
        var sortedSeq: seq[DirTreeNode] = @[node.contents[0]]
        let size =  node.contents.len
        while sortedSeq.len < size:
            let latestNode: DirTreeNode = node.contents.getLatestNode()
            sortedSeq.add(latestNode)
            node.contents.delete(node.contents.find(latestNode))
        node.contents = sortedSeq.reversed()

    let index = node.getConfig("index").getStr().toLowerAscii()
    if index == "newest":
        node.hasIndex = node.contents.getLatestNode()
    elif index[0] == '$':
        for e in node.contents:
            if e.name.removeSuffixInsensitive(".md").toLowerAscii() == index[1..^1]:
                node.hasIndex = e
                break
    if node.hasIndex != nil: node.hasIndex.label = "index"
        


proc printTree(node: DirTreeNode) =
    if node.kind == itemFile:
        var fileType: string
        case node.fileKind
        of fileMarkdown: fileType = "Markdown"
        of fileJSON:     fileType = "JSON"
        of fileTemplate: fileType = "Template"
        of fileHTML:     fileType = "HTML"
        echo "[FILE]", repeat('\t', node.depth), node.name, " : "
    
    elif node.kind == itemDir:
        echo "[DIR]", repeat('\t', node.depth), node.path, " : ", node.name, " : ", node.contents.len()
        
        for item in node.contents:
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

    echo "Scanning..."
    buildDirTree(fsTree, 1)
    if fsTree.hasCSS == nil: writefile("styles.css", DefaultStyles)
    printTree(fsTree)
    echo "\nGenerating pages..."
    populateDirs(fsTree)
    echo "\nDone!"

main()
