# Ruby CSS Parser [![Build Status](https://github.com/premailer/css_parser/workflows/Run%20css_parser%20CI/badge.svg)](https://github.com/ojab/css_parser/actions?query=workflow%3A%22Run+css_parser+CI%22) [![Gem Version](https://badge.fury.io/rb/css_parser.svg)](https://badge.fury.io/rb/css_parser)

Load, parse and cascade CSS rule sets in Ruby. 

# Setup

```Bash
gem install css_parser
```

# Usage

You initiate a document `CssParser::Document.new` and you can start to load it with css. Main methods to add css are: load_uri! (load url and follows @imports based on the full url), load_file! (loads file and follows @imports based on path from file imported) and load_string! (load a block of css). All of these apis tries to absolute all urls


```Ruby
require 'css_parser'
include CssParser

document = CssParser::Document.new
document.load_uri!('http://example.com/styles/style.css')

document = CssParser::Document.new
document.load_uri!('file://home/user/styles/style.css')

# load a remote file, setting the base_uri and media_types
document.load_uri!('../style.css', {base_uri: 'http://example.com/styles/inc/', media_types: [:screen, :handheld]})

# load a local file, setting the base_dir and media_types
document.load_file!('print.css', '~/styles/', :print)

# load a string
document = CssParser::Document.new
document.load_string! 'a { color: hotpink; }'

# lookup a rule by a selector
document.find_by_selector('#content')
#=> 'font-size: 13px; line-height: 1.2;'

# lookup a rule by a selector and media type
document.find_by_selector('#content', [:screen, :handheld])

# iterate through selectors by media type
document.each_selector(:screen) do |selector, declarations, specificity|
  ...
end

# add a block of CSS
css = <<-EOT
  body { margin: 0 1em; }
EOT

document.add_block!(css)

# output all CSS rules in a single stylesheet
document.to_s
=> #content { font-size: 13px; line-height: 1.2; }
   body { margin: 0 1em; }

# capturing byte offsets within a file
document.load_uri!('../style.css', {base_uri: 'http://example.com/styles/inc/', capture_offsets: true)
content_rule = document.find_rule_sets(['#content']).first
content_rule.filename
#=> 'http://example.com/styles/styles.css'
content_rule.offset
#=> 10703..10752

# capturing byte offsets within a string
document.load_string!('a { color: hotpink; }', {filename: 'index.html', capture_offsets: true)
content_rule = document.find_rule_sets(['a']).first
content_rule.filename
#=> 'index.html'
content_rule.offset
#=> 0..21
```

# Testing

```Bash
bundle
bundle exec rake
```

Runs on Ruby 3.0/JRuby 9.4 or above.

# Credits

By Alex Dunae (dunae.ca, e-mail 'code' at the same domain), 2007-11.

License: MIT

Thanks to [all the wonderful contributors](http://github.com/premailer/css_parser/contributors) for their updates.

Made on Vancouver Island.
