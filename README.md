# Ruby CSS Parser [![Build Status](https://github.com/premailer/css_parser/workflows/Run%20css_parser%20CI/badge.svg)](https://github.com/ojab/css_parser/actions?query=workflow%3A%22Run+css_parser+CI%22) [![Gem Version](https://badge.fury.io/rb/css_parser.svg)](https://badge.fury.io/rb/css_parser)

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
parser.load_uri!('../style.css', {base_uri: 'http://example.com/styles/inc/', media_types: [:screen, :handheld]})

# load a local file, setting the base_dir and media_types
parser.load_file!('print.css', '~/styles/', :print)

# load a string
parser = CssParser::Parser.new
parser.load_string! 'a { color: hotpink; }'

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

# capturing byte offsets within a file
parser.load_uri!('../style.css', {base_uri: 'http://example.com/styles/inc/', capture_offsets: true)
content_rule = parser.find_rule_sets(['#content']).first
content_rule.filename
#=> 'http://example.com/styles/styles.css'
content_rule.offset
#=> 10703..10752

# capturing byte offsets within a string
parser.load_string!('a { color: hotpink; }', {filename: 'index.html', capture_offsets: true)
content_rule = parser.find_rule_sets(['a']).first
content_rule.filename
#=> 'index.html'
content_rule.offset
#=> 0..21
```

# Subresource Integrity

`Parser#load_uri!` accepts an `integrity:` option that verifies a fetched remote stylesheet
against a [Subresource Integrity](https://www.w3.org/TR/SRI/) value before it's parsed -- the
same value an HTML `<link integrity="...">` attribute carries.

```Ruby
parser.load_uri!(
  'http://example.com/styles/style.css',
  integrity: 'sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC'
)
```

When the fetched body doesn't match, `CssParser::IntegrityError` (a subclass of
`CssParser::RemoteFileError`, so existing `rescue RemoteFileError` code is unaffected) is
raised if `io_exceptions` is enabled, or nothing is loaded otherwise.

`integrity:` also accepts several space-separated values, exactly like the HTML attribute
does. When more than one hash algorithm is present, only the strongest one is checked
(sha512 > sha384 > sha256) and every weaker value is ignored; multiple values for that same
strongest algorithm are treated as alternatives -- matching any one of them is enough (useful
during a stylesheet rotation, when a CDN may still serve the old version for a while):

```Ruby
parser.load_uri!(
  'http://example.com/styles/style.css',
  integrity: 'sha256-Br6tO8uuFyBAw2O0eUNdXVyuS/POLb5jpHxXaxIq6Q0= sha384-0gCPKBW0n+VzQzZu5gzP+YMxy9QTLyn1y/O/TMvLTpVajzRKAx6d7TiPB5W7DnDn'
)
# only the sha384 value is actually checked here; the sha256 one is present
# (e.g. for browsers/tools that only understand sha256) but ignored by this
# library since a stronger algorithm is also listed.
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
