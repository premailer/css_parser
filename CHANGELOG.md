## Ruby CSS Parser CHANGELOG

### Unreleased

 * Fix parsing background shorthands in ruby 3.2 [#140](https://github.com/premailer/css_parser/pull/140)

### Version v1.14.0

 * Fix parsing of multiline URL values for rule sets [#97](https://github.com/premailer/css_parser/pull/97)

### Version v1.13.0

 * Drop suppor for EOL ruby versions
 * fix regex deprecation

### Version v1.12.0

 * Improve exception message for missing value [#131](https://github.com/premailer/css_parser/pull/131)
 * `:rule_set_exceptions` option added [#132](https://github.com/premailer/css_parser/pull/132)

### Version 1.11.0

 * Do not combine border styles width/color/style are not all present

### Version 1.10.0

 * Allow CSS functions to be used in CssParser::RuleSet#expand_dimensions_shorthand! [#126](https://github.com/premailer/css_parser/pull/126)

### Version 1.9.0

 * Misc cleanup [#122](https://github.com/premailer/css_parser/pull/122)

### Version 1.8.0

 * Internal refactoring around ruleset [diff](https://github.com/premailer/css_parser/compare/v1.7.1...v1.8.0)

### Version 1.7.1

 * Force UTF-8 encoding; do not strip out UTF-8 chars. [#106](https://github.com/premailer/css_parser/pull/106)

### Version 1.7.0

 * No longer support ruby versions 1.9 2.0 2.1
 * Memory allocation improvements

### Version 1.6.0

 * Handles font-size/ line-height shorthand with spaces

### Version 1.5.0

 * Extended color keywords support (https://www.w3.org/TR/css3-color/).
 * `remove_rule_set!` method added.
 * `:capture_offsets` feature added.

### Version 1.4.10

 * Include uri in RemoteFileError message.
 * Prevent to convert single declarations to their respective shorthand.
 * Fix Ruby warnings.

### Version 1.4.9

 * Support for vrem, vh, vw, vmin, vmax and vm box model units.
 * Replace obsolete calls with actual ones.
 * Fix some Ruby warnings.

### Version 1.4.8

 * Allow to get CSS rules as Hash using `to_hash` method.
 * Updates to support Ruby 1.9 and JRuby.
 * utf-8 related update.

### Version 1.4.7

 * background-position shorthand fix.

### Version 1.4.6

 * Normalize whitespace in selectors and queries.
 * Strip spaces from keys.
 * More checks on ordering.

### Version 1.4.5

 * Maintenance release.

### Version 1.4.4

 * More robust redirection handling, refs #47.

### Version 1.4.3

 * Look for redirects, MAX_REDIRECTS set to 3, refs #36.
 * Fix border style expanding, refs #58.
 * load_string! described, refs #70.

### Version 1.4.2

 * Ship license with package, refs #69.

### Version 1.4.1

 * Fix background shorthands, refs #66.

### Version 1.4.0

 * Add support for background-size in the shorthand property @mitio

### Version 1.3.6

 * Fix bug not setting general rules after media query @jievans.
 * We doesn't support Ruby 1.8 anymore.
 * Run tests on Ruby 2.0 and Ruby 2.1.
 * Respect the :import option.

### Version 1.3.5

 * Use URI#request_uri instead of URI#path @duckinator.
 * Media_query_support @mzsanford
 * Don't require open-uri @aripollak
 * Symbols not sortable on 1.8.7 @morten
 * Improve create_dimensions_shorthand performance @aaronjensen
 * Fixes hash ordering in tests @morten

### Version 1.3.4

 * Enable code highlighting for tests @grosser
 * Fix error in media query parsing @smgt
 * Add test to missing cleaning of media type in parsing @smgt

### Version 1.3.3

 * Require version before requiring classes that depend on it @morten

### Version 1.3.2

 * Fix them crazy requires and only define version once @grosser
 * Apply ocd @grosser

### Version 1.3.1

 * More tests (and fixes) for background gradients @fortnightlabs
 * Support declarations with `;` in them @flavorpill
 * Stricter detection of !important @flavorpill

### Version 1.3.0

 * Updates of gem by @grosser
 * Multiple selectors should properly calculate specificity @alexdunae
 * Specificity: The selector with the highest specificity may be in a compound selector statement? @morten
 * Selectors should not be registered with surrounding whitespace. @morten
 * Fix RE_GRADIENT reference @alexdunae
 * Add load_string! method tests @alexdunae
 * Gradient regexp tests @alexdunae
 * Edited rule set @mccuskk

### Version 1.2.6

 * JRuby and Ruby 1.9.3-preview1 compat

### Version 1.2.5

 * Fix merging of multiple !important rules to match the spec

### Version 1.2.3

 * First pass of media query support

### Version 1.2.2

 * Fix merging of multiple !important rules to match the spec

### Version 1.2.1

 * Better border shorthand handling
 * List shorthand handling
 * Malformed URI handling improvements
 * Use Bundler

### Version 1.2.0

 * Specificity improvements
 * RGBA, HSL and HSLA support
 * Bug fixes

### Version 1.1.9

 * Add remove_declaration! to RuleSet

### Version 1.1.8

 * Fix syntax error

### Version 1.1.7

 * Automatically close missing braces at the end of a block

### Version 1.1.6

 * Fix media type handling in add_block! and load_uri!

### Version 1.1.5

 * Fix merging of !important declarations

### Version 1.1.4

 * Ruby 1.9.2 compat

### Version 1.1.3

 * allow limiting by media type in add_block!

### Version 1.1.2

 * improve parsing of malformed declarations
 * improve support for local files
 * added support for loading over SSL
 * added support for deflate

### Version 1.1.1

 * Ruby 1.9 compatibility
 * @import regexp updates
 * various bug fixes

### Version 1.1.0

 * Added support for local @import
 * Better remote @import handling

### Version 1.0.1

 * Fallback for declarations without sort order

### Version 1.0.0

 * Various test fixes and udpate for Ruby 1.9 (thanks to Tyler Cunnion)
 * Allow setting CSS declarations to nil

### Version 0.9

 * Initial version forked from Premailer project

### TODO: Future

 * re-implement caching on CssParser.merge
 * correctly parse http://www.webstandards.org/files/acid2/test.html
