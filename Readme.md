# Ruby CSS Parser

Load, parse and cascade CSS rule sets in Ruby.

# Setup

```Bash
gem install css_parser
```

# Usage

```Ruby
require 'css_parser'
include CssParser

parser = CssParser::Parser.new
parser.load_uri!('http://example.com/styles/style.css')

parser = CssParser::Parser.new
parser.load_uri!('file://home/user/styles/style.css')

# load a remote file, setting the base_uri and media_types
parser.load_uri!('../style.css', {:base_uri => 'http://example.com/styles/inc/', :media_types => [:screen, :handheld])

# load a local file, setting the base_dir and media_types
parser.load_file!('print.css', '~/styles/', :print)

# lookup a rule by a selector
parser.find_by_selector('#content')
#=> 'font-size: 13px; line-height: 1.2;'

# lookup a rule by a selector and media type
parser.find_by_selector('#content', [:screen, :handheld])

# iterate through selectors by media type
parser.each_selector(:screen) do |selector, declarations, specificity|
  ...
end

# add a block of CSS
css = <<-EOT
  body { margin: 0 1em; }
EOT

parser.add_block!(css)

# output all CSS rules in a single stylesheet
parser.to_s
=> #content { font-size: 13px; line-height: 1.2; }
   body { margin: 0 1em; }
```

# Testing

```Bash
bundle
bundle exec rake
```

Runs on Ruby/JRuby 1.9.2 or above.

# Credits

By Alex Dunae (dunae.ca, e-mail 'code' at the same domain), 2007-11.

License: MIT

Thanks to [all the wonderful contributors](http://github.com/alexdunae/css_parser/contributors) for their updates.

Made on Vancouver Island.

[![Build Status](https://travis-ci.org/alexdunae/css_parser.png)](https://travis-ci.org/alexdunae/css_parser)

