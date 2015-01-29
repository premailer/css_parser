## Ruby CSS Parser CHANGELOG

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
