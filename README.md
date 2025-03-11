# nerc

Web anti-framework in Nim.

## Rationale

Too many web frameworks are written in slow, heavy, bloated interpreted languages, so this is an *anti*-framework written in a fast, lightweight, and *nim*ble compiled language.



## Function

Converts markdown files into html files on a directory basis.




## Usage

Navigate to your directory you wish to be the root of your website and run:

```
nerc
```

Then upload the contents of that directory to the root of your website's hosting directory.

### Things to note

- `readme.md`(case insensitive) files will become `index.htm` files so you can use github hosting for your website, and people visiting the repo will get more or less the same experience.

- Files and directories starting with a `.` will be ignored for linkage.

- Directories that don't contain a `readme.md` will not be linkified in the sidebar, but any `.md` documents they contain will be.

- You can add your own html pages you made, but they will only be linkified if they end in `.html`.

## Options

Options can be overridden on a per-directory basis. Each directory can have its own `config.json`, `styles.css`, and `template.htm`, overriding one or more of a parent directory's  settings.

### config.json

You'll likely first wish to create your own `config.json` file to override the default settings built in to `nerc`.
This is a list of the various config options:

| **Key**        | **Value Type**                                                                               | **Description**                                                                                                                                                                                                |
| -------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "page title"   | string                                                                                       | Sets the page's title tag (in the browser window titlebar/tab).                                                                                                                                                |
| "links"        | array of JSON objects: `{"label": [string to hyperlink], "link":[string of URL to link to]}` | Sets the links that appear at the top of the page. Spacers can be inserted by inserting the following JSON object: `{"label": "", "link": "SPACER"}`                                                           |
| "site title"   | string                                                                                       | Sets the title at the top of each page, below the links row.                                                                                                                                                   |
| "subtitle"     | string                                                                                       | Sets the subtitle for the site that appears next to the title.                                                                                                                                                 |
| "footer right" | string                                                                                       | Sets the text string that is inserted into the footer at the bottom of the page on the right. You can insert HTML into this portion for formatting effects, or if you'd like to add a search bar or something. |

Only defined config options will be overridden, so any settings not defined in a directory's `config.json` file will be inherited either from their parent's directory, or from the default settings defined in `nerc`.

### styles.css

If one is not present in the root directory, a `styles.css` file will be generated and linked to by all pages in the directory and any child directories. If you wish to define your own style for your site, it is recommended to allow `nerc` to generate the `styles.css` file and modify that to set global style settings.

Styles are overridden by including each `styles.css` along the path to whatever page is being generated, so if a page is in `/places/America/Maryland/`, and `/`, `America`, and `Maryland` each has their own style, they'd be included as such:

```html
...
<style> 
    @import url("/styles.css");
    @import url("/places/America/styles.css");
    @import url("/places/America/Maryland/styles.css");
</style>
...
```

So as to allow individual styles to be overridden on a per-directory basis.
Here are a list of classes and IDs which can be styled:

| Class/ID   | Description                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------- |
| .spacer    | Styles spacers used to separate links and the left and right text in the footer.            |
| .nerc      | Styles shared by every element that generated content gets inserted to in the visible page. |
| #container | Element containing all the elements of the page.                                            |
| #links     | Element containing links at the top of the page.                                            |
| #header    | Element containing the Page Title and Subtitle.                                             |
| #body      | Element containing Sidebar and Content.                                                     |
| #sidebar   | Element containing an unordered list linking to different pages and directories.            |
| #content   | Element containing the contents of the document, rendered as HTML                           |
| #footer    | Element containing the footer contents.                                                     |

### template.htm

Like `config.json`, pages in a directory will use the last defined template up the chain of directories back to the root. Unlike `config.json` and `styles.css`,  however, `template.htm` overrides the whole page, so if you wish to override it, you'll have to define the whole page layout.
In order for content to be inserted into the page during generation, you'll need to declare the following tokens in your template:

| **Tag**               | **Description**                                                                                                                   |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `<!--page title-->`   | Inserts the string defined by `"page title"` in `config.json`.                                                                    |
| `<!--styles-->`       | Inserts the chain of `styles.css` files that apply to the current directory.                                                      |
| `<!--links-->`        | Inserts a series of `<a>` tags and spacers defined by `"links"` in `config.json`.                                                 |
| `<!--site title-->`   | Inserts the string defined by `"site title"` in `config.json`.                                                                    |
| `<!--subtitle-->`     | Inserts the string defined by `"subtitle"` in `config.json`.                                                                      |
| `<!--sidebar-->`      | Inserts an unordered list representing the directory structure of the website and all its generated/discovered pages/directories. |
| `<!--content-->`      | Inserts the contents of the markdown document, rendered as HMTL elements.                                                         |
| `<!--footer left-->`  | Inserts the string defined by "footer left" in `config.json`.                                                                     |
| `<!--footer right-->` | Inserts the string defined by "footer right" in `config.json`.                                                                    |



## Building

```shell
git clone https://github.com/8bitprodigy/nerc 
cd nerc
nimble build
```

## 

## Installation

```shell
install nerc /usr/local/bin
```

 Or:

```shell
install nerc ~/.local/bin
```

## 

## License:

This code is dedicated to the public domain, but is also made available under the terms of the 0-clause BSD license, as some jurisdictions do not recognize the public domain.

The terms of the 0-clause BSD license are thus:

```
Copyright (C) 2025 Christopher DeBoy <chrisxdeboy@gmail.com>



Permission to use, copy, modify, and/or distribute this software for  
any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL  
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES  
OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE  
FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY  
DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN  
AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT  
OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```
