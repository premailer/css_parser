# frozen_string_literal: true

require 'strscan'
require 'digest'
require 'base64'

module CssParser
  # Exception class used for any errors encountered while downloading remote files.
  class RemoteFileError < IOError; end

  # Exception class used when a fetched remote file fails Subresource Integrity
  # verification (see the `:integrity` option on `Parser#load_uri!`). A subclass of
  # `RemoteFileError` so existing `rescue RemoteFileError` callers are unaffected;
  # callers that want to distinguish an integrity failure from other fetch failures
  # (404, SSRF rejection, timeout, etc.) can rescue this class specifically.
  class IntegrityError < RemoteFileError; end

  # Exception class used if a request is made to load a CSS file more than once.
  class CircularReferenceError < StandardError; end

  # == Parser class
  #
  # All CSS is converted to UTF-8.
  #
  # When calling Parser#new there are some configuaration options:
  # [<tt>absolute_paths</tt>] Convert relative paths to absolute paths (<tt>href</tt>, <tt>src</tt> and <tt>url('')</tt>. Boolean, default is <tt>false</tt>.
  # [<tt>import</tt>] Follow <tt>@import</tt> rules. Boolean, default is <tt>true</tt>.
  # [<tt>io_exceptions</tt>] Throw an exception if a link can not be found. Boolean, default is <tt>true</tt>.
  # [<tt>allow_local_network</tt>] Permit http(s) fetches against loopback / private / link-local / cloud-metadata addresses. Boolean, default is <tt>false</tt>. When <tt>false</tt> (the default), outbound HTTP requests are routed through <tt>ssrf_filter</tt>, which resolves the host and rejects unsafe IP ranges. Set to <tt>true</tt> only when the destination is known to be safe (e.g. local fixture servers in tests). Independent of <tt>allow_file_uris</tt>.
  # [<tt>allow_file_uris</tt>] Permit <tt>file://</tt> URIs via <tt>load_uri!</tt>. Boolean, default is <tt>false</tt>. When <tt>false</tt> (the default), a caller that passes a <tt>file://</tt> URI to <tt>load_uri!</tt> — directly or via a CSS <tt>@import</tt> resolved against a <tt>file://</tt> base_uri — is refused, closing the local-file-disclosure vector when the URI is influenced by user input. <tt>load_file!</tt> is unaffected: it is the explicit local-file API and takes a caller-supplied path. Independent of <tt>allow_local_network</tt>.
  #
  # <tt>load_uri!</tt> also accepts a per-call <tt>:integrity</tt> option (see its documentation) for
  # verifying a remote stylesheet against a Subresource Integrity value before it is parsed.
  class Parser
    USER_AGENT = "Ruby CSS Parser/#{CssParser::VERSION} (https://github.com/premailer/css_parser)".freeze
    RULESET_TOKENIZER_RX = /\s+|\\{2,}|\\?[{}\s"]|[()]|.[^\s"{}()\\]*/.freeze
    STRIP_CSS_COMMENTS_RX = %r{/\*.*?\*/}m.freeze
    STRIP_HTML_COMMENTS_RX = /<!--|-->/m.freeze

    # Initial parsing
    RE_AT_IMPORT_RULE = /@import\s*(?:url\s*)?(?:\()?(?:\s*)["']?([^'"\s)]*)["']?\)?([\w\s,^\]()]*)\)?[;\n]?/.freeze

    MAX_REDIRECTS = 3

    # Schemes accepted by `read_remote_file`. `file://` is intentionally
    # NOT in this list — local files are handled directly by `load_uri!`
    # and `load_file!`. Keeping `file://` out of the remote read path
    # closes the cross-scheme redirect (HTTP 3xx → `file://`) vector that
    # was GHSA-9pmc-p236-855h.
    REMOTE_ALLOWED_SCHEMES = %w[http https].freeze

    # Subresource Integrity hash algorithms this library can verify, mapped to their
    # Digest class, ordered strongest first. A single structure (rather than a
    # separate priority list and digest-class lookup) so the two can't drift out of
    # sync. Mirrors the SRI spec's "agility" rule (https://www.w3.org/TR/SRI/#agility):
    # when a caller-supplied `integrity` value lists more than one algorithm, only
    # the strongest one present is checked.
    INTEGRITY_ALGORITHMS = {
      'sha512' => Digest::SHA512,
      'sha384' => Digest::SHA384,
      'sha256' => Digest::SHA256
    }.freeze

    # Array of CSS files that have been loaded.
    attr_reader :loaded_uris

    def initialize(options = {})
      @options = {
        absolute_paths: false,
        import: true,
        io_exceptions: true,
        rule_set_exceptions: true,
        capture_offsets: false,
        user_agent: USER_AGENT,
        allow_local_network: false,
        allow_file_uris: false
      }.merge(options)

      # array of RuleSets
      @rules = []

      @loaded_uris = []

      # unprocessed blocks of CSS
      @blocks = []
      reset!
    end

    # Get declarations by selector.
    #
    # +media_types+ are optional, and can be a symbol or an array of symbols.
    # The default value is <tt>:all</tt>.
    #
    # ==== Examples
    #  find_by_selector('#content')
    #  => 'font-size: 13px; line-height: 1.2;'
    #
    #  find_by_selector('#content', [:screen, :handheld])
    #  => 'font-size: 13px; line-height: 1.2;'
    #
    #  find_by_selector('#content', :print)
    #  => 'font-size: 11pt; line-height: 1.2;'
    #
    # Returns an array of declarations.
    def find_by_selector(selector, media_types = :all)
      out = []
      each_selector(media_types) do |sel, dec, _spec|
        out << dec if sel.strip == selector.strip
      end
      out
    end
    alias [] find_by_selector

    # Finds the rule sets that match the given selectors
    def find_rule_sets(selectors, media_types = :all)
      rule_sets = []

      selectors.each do |selector|
        selector = selector.gsub(/\s+/, ' ').strip
        each_rule_set(media_types) do |rule_set, _media_type|
          if !rule_sets.member?(rule_set) && rule_set.selectors.member?(selector)
            rule_sets << rule_set
          end
        end
      end

      rule_sets
    end

    # Add a raw block of CSS.
    #
    # In order to follow +@import+ rules you must supply either a
    # +:base_dir+ or +:base_uri+ option.
    #
    # Use the +:media_types+ option to set the media type(s) for this block.  Takes an array of symbols.
    #
    # Use the +:only_media_types+ option to selectively follow +@import+ rules.  Takes an array of symbols.
    #
    # ==== Example
    #   css = <<-EOT
    #     body { font-size: 10pt }
    #     p { margin: 0px; }
    #     @media screen, print {
    #       body { line-height: 1.2 }
    #     }
    #   EOT
    #
    #   parser = CssParser::Parser.new
    #   parser.add_block!(css)
    def add_block!(block, options = {})
      options = {base_uri: nil, base_dir: nil, charset: nil, media_types: :all, only_media_types: :all}.merge(options)
      options[:media_types] = [options[:media_types]].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }
      options[:only_media_types] = [options[:only_media_types]].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }

      block = cleanup_block(block, options)

      if options[:base_uri] and @options[:absolute_paths]
        block = CssParser.convert_uris(block, options[:base_uri])
      end

      # Load @imported CSS
      if @options[:import]
        block.scan(RE_AT_IMPORT_RULE).each do |import_rule|
          media_types = []
          if (media_string = import_rule[-1])
            media_string.split(',').each do |t|
              media_types << CssParser.sanitize_media_query(t) unless t.empty?
            end
          else
            media_types = [:all]
          end

          next unless options[:only_media_types].include?(:all) or media_types.empty? or media_types.intersect?(options[:only_media_types])

          import_path = import_rule[0].to_s.gsub(/['"]*/, '').strip

          import_options = {media_types: media_types}
          import_options[:capture_offsets] = true if options[:capture_offsets]

          if options[:base_uri]
            import_uri = Addressable::URI.parse(options[:base_uri].to_s) + Addressable::URI.parse(import_path)
            import_options[:base_uri] = options[:base_uri]
            load_uri!(import_uri, import_options)
          elsif options[:base_dir]
            import_options[:base_dir] = options[:base_dir]
            load_file!(import_path, import_options)
          end
        end
      end

      # Remove @import declarations
      block = ignore_pattern(block, RE_AT_IMPORT_RULE, options)

      parse_block_into_rule_sets!(block, options)
    end

    # Add a CSS rule by setting the +selectors+, +declarations+
    # and +media_types+. Optional pass +filename+ , +offset+ for source
    # reference too.
    #
    # +media_types+ can be a symbol or an array of symbols. default to :all
    # optional fields for source location for source location
    # +filename+ can be a string or uri pointing to the file or url location.
    # +offset+ should be Range object representing the start and end byte locations where the rule was found in the file.
    def add_rule!(*args, selectors: nil, block: nil, filename: nil, offset: nil, media_types: :all) # rubocop:disable Metrics/ParameterLists
      if args.any?
        media_types = nil
        if selectors || block || filename || offset || media_types
          raise ArgumentError, "don't mix positional and keyword arguments arguments"
        end

        warn '[DEPRECATION] `add_rule!` with positional arguments is deprecated. ' \
             'Please use keyword arguments instead.', uplevel: 1

        case args.length
        when 2
          selectors, block = args
        when 3
          selectors, block, media_types = args
        else
          raise ArgumentError
        end
      end

      begin
        rule_set = RuleSet.new(
          selectors: selectors, block: block,
          offset: offset, filename: filename
        )

        add_rule_set!(rule_set, media_types)
      rescue ArgumentError => e
        raise e if @options[:rule_set_exceptions]
      end
    end

    # Add a CSS rule by setting the +selectors+, +declarations+, +filename+, +offset+ and +media_types+.
    #
    # +filename+ can be a string or uri pointing to the file or url location.
    # +offset+ should be Range object representing the start and end byte locations where the rule was found in the file.
    # +media_types+ can be a symbol or an array of symbols.
    def add_rule_with_offsets!(selectors, declarations, filename, offset, media_types = :all)
      warn '[DEPRECATION] `add_rule_with_offsets!` is deprecated. Please use `add_rule!` instead.', uplevel: 1
      add_rule!(
        selectors: selectors, block: declarations, media_types: media_types,
        filename: filename, offset: offset
      )
    end

    # Add a CssParser RuleSet object.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def add_rule_set!(ruleset, media_types = :all)
      raise ArgumentError unless ruleset.is_a?(CssParser::RuleSet)

      media_types = [media_types] unless media_types.is_a?(Array)
      media_types = media_types.flat_map { |mt| CssParser.sanitize_media_query(mt) }

      @rules << {media_types: media_types, rules: ruleset}
    end

    # Remove a CssParser RuleSet object.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def remove_rule_set!(ruleset, media_types = :all)
      raise ArgumentError unless ruleset.is_a?(CssParser::RuleSet)

      media_types = [media_types].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }

      @rules.reject! do |rule|
        rule[:media_types] == media_types && rule[:rules].to_s == ruleset.to_s
      end
    end

    # Iterate through RuleSet objects.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def each_rule_set(media_types = :all) # :yields: rule_set, media_types
      media_types = [:all] if media_types.nil?
      media_types = [media_types].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }

      @rules.each do |block|
        if media_types.include?(:all) or block[:media_types].any? { |mt| media_types.include?(mt) }
          yield(block[:rules], block[:media_types])
        end
      end
    end

    # Output all CSS rules as a Hash
    def to_h(which_media = :all)
      out = {}
      styles_by_media_types = {}
      each_selector(which_media) do |selectors, declarations, _specificity, media_types|
        media_types.each do |media_type|
          styles_by_media_types[media_type] ||= []
          styles_by_media_types[media_type] << [selectors, declarations]
        end
      end

      styles_by_media_types.each_pair do |media_type, media_styles|
        ms = {}
        media_styles.each do |media_style|
          ms = css_node_to_h(ms, media_style[0], media_style[1])
        end
        out[media_type.to_s] = ms
      end
      out
    end

    # Iterate through CSS selectors.
    #
    # +media_types+ can be a symbol or an array of symbols.
    # See RuleSet#each_selector for +options+.
    def each_selector(all_media_types = :all, options = {}) # :yields: selectors, declarations, specificity, media_types
      return to_enum(__method__, all_media_types, options) unless block_given?

      each_rule_set(all_media_types) do |rule_set, media_types|
        rule_set.each_selector(options) do |selectors, declarations, specificity|
          yield selectors, declarations, specificity, media_types
        end
      end
    end

    # Output all CSS rules as a single stylesheet.
    def to_s(which_media = :all)
      out = []
      styles_by_media_types = {}

      each_selector(which_media) do |selectors, declarations, _specificity, media_types|
        media_types.each do |media_type|
          styles_by_media_types[media_type] ||= []
          styles_by_media_types[media_type] << [selectors, declarations]
        end
      end

      styles_by_media_types.each_pair do |media_type, media_styles|
        media_block = (media_type != :all)
        out << "@media #{media_type} {" if media_block

        media_styles.each do |media_style|
          if media_block
            out.push("  #{media_style[0]} {\n    #{media_style[1]}\n  }")
          else
            out.push("#{media_style[0]} {\n#{media_style[1]}\n}")
          end
        end

        out << '}' if media_block
      end

      out << ''
      out.join("\n")
    end

    # A hash of { :media_query => rule_sets }
    def rules_by_media_query
      rules_by_media = {}
      @rules.each do |block|
        block[:media_types].each do |mt|
          unless rules_by_media.key?(mt)
            rules_by_media[mt] = []
          end
          rules_by_media[mt] << block[:rules]
        end
      end

      rules_by_media
    end

    # Merge declarations with the same selector.
    def compact! # :nodoc:
      []
    end

    def parse_block_into_rule_sets!(block, options = {}) # :nodoc:
      current_media_queries = [:all]
      if options[:media_types]
        current_media_queries = options[:media_types].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }
      end

      in_declarations = 0
      block_depth = 0

      in_charset = false # @charset is ignored for now
      in_string = false
      in_at_media_rule = false
      in_media_block = false

      current_selectors = +''
      current_media_query = +''
      current_declarations = +''

      # once we are in a rule, we will use this to store where we started if we are capturing offsets
      rule_start = nil
      start_offset = nil
      end_offset = nil

      scanner = StringScanner.new(block)
      until scanner.eos?
        # save the regex offset so that we know where in the file we are
        start_offset = scanner.pos
        token = scanner.scan(RULESET_TOKENIZER_RX)
        end_offset = scanner.pos

        if token.start_with?('"') # found un-escaped double quote
          in_string = !in_string
        end

        if in_declarations > 0
          # too deep, malformed declaration block
          if in_declarations > 1
            in_declarations -= 1 if token.include?('}')
            next
          end

          if !in_string && token.include?('{')
            in_declarations += 1
            next
          end

          current_declarations << token

          if !in_string && token.include?('}')
            current_declarations.gsub!(/\}\s*$/, '')

            in_declarations -= 1
            current_declarations.strip!

            unless current_declarations.empty?
              add_rule_options = {
                selectors: current_selectors, block: current_declarations,
                media_types: current_media_queries
              }
              if options[:capture_offsets]
                add_rule_options[:filename] = options[:filename]
                add_rule_options[:offset] = rule_start..end_offset
              end
              add_rule!(**add_rule_options)
            end

            current_selectors = +''
            current_declarations = +''

            # restart our search for selectors and declarations
            rule_start = nil if options[:capture_offsets]
          end
        elsif /@media/i.match?(token)
          # found '@media', reset current media_types
          in_at_media_rule = true
          current_media_queries = []
        elsif in_at_media_rule
          if token.include?('{')
            block_depth += 1
            in_at_media_rule = false
            in_media_block = true
            current_media_queries << CssParser.sanitize_media_query(current_media_query)
            current_media_query = +''
          elsif token.include?(',')
            # new media query begins
            token.tr!(',', ' ')
            token.strip!
            current_media_query << token << ' '
            current_media_queries << CssParser.sanitize_media_query(current_media_query)
            current_media_query = +''
          else
            token.strip!
            # special-case the ( and ) tokens to remove inner-whitespace
            # (eg we'd prefer '(width: 500px)' to '( width: 500px )' )
            case token
            when '('
              current_media_query << token
            when ')'
              current_media_query.sub!(/ ?$/, token)
            else
              current_media_query << token << ' '
            end
          end
        elsif in_charset or /@charset/i.match?(token)
          # iterate until we are out of the charset declaration
          in_charset = !token.include?(';')
        elsif !in_string && token.include?('}')
          block_depth -= 1

          # reset the current media query scope
          if in_media_block
            current_media_queries = [:all]
            in_media_block = false
          end
        elsif !in_string && token.include?('{')
          current_selectors.strip!
          in_declarations += 1
        else
          # if we are in a selector, add the token to the current selectors
          current_selectors << token

          # mark this as the beginning of the selector unless we have already marked it
          rule_start = start_offset if options[:capture_offsets] && rule_start.nil? && /^[^\s]+$/.match?(token)
        end
      end

      # check for unclosed braces
      return unless in_declarations > 0

      add_rule_options = {
        selectors: current_selectors, block: current_declarations,
        media_types: current_media_queries
      }
      if options[:capture_offsets]
        add_rule_options[:filename] = options[:filename]
        add_rule_options[:offset] = rule_start..end_offset
      end
      add_rule!(**add_rule_options)
    end

    # Load a remote CSS file.
    #
    # You can also pass in file://test.css
    #
    # See add_block! for options. In addition to those, <tt>:integrity</tt> accepts a
    # Subresource Integrity value (https://www.w3.org/TR/SRI/) -- e.g. the value of an
    # HTML <tt><link integrity="..."></tt> attribute -- and, for http(s) URIs, verifies the
    # fetched response body against it before the CSS is parsed. When the digest does not
    # match, <tt>CssParser::IntegrityError</tt> (a subclass of <tt>RemoteFileError</tt>) is
    # raised if <tt>io_exceptions</tt> is enabled, otherwise nothing is loaded. Ignored for
    # <tt>file://</tt> URIs.
    #
    # Deprecated: originally accepted three params: `uri`, `base_uri` and `media_types`
    def load_uri!(uri, options = {}, deprecated = nil)
      uri = Addressable::URI.parse(uri) unless uri.respond_to? :scheme

      opts = {base_uri: nil, media_types: :all}

      if options.is_a? Hash
        opts.merge!(options)
      else
        warn '[DEPRECATION] `load_uri!` with positional arguments is deprecated. ' \
             'Please use keyword arguments instead.', uplevel: 1
        opts[:base_uri] = options if options.is_a? String
        opts[:media_types] = deprecated if deprecated
      end

      if uri.scheme == 'file' or uri.scheme.nil?
        uri.path = File.expand_path(uri.path)
        uri.scheme = 'file'
      end

      opts[:base_uri] = uri if opts[:base_uri].nil?

      # pass on the uri if we are capturing file offsets
      opts[:filename] = uri.to_s if opts[:capture_offsets]

      # file:// is handled here, not inside read_remote_file. The
      # remote-read path must never service file:// URIs, so a 3xx
      # `Location: file://...` redirect cannot be turned into a local
      # File.read.
      #
      # file:// via `load_uri!` is also gated by `allow_file_uris`:
      # an attacker who can influence a URI passed here (e.g. via a CSS
      # @import resolved against an attacker-controlled base_uri) could
      # otherwise turn it into arbitrary local file disclosure. Callers
      # that legitimately need to load local files should use
      # `load_file!` (the explicit local-file API).
      src = if uri.scheme == 'file'
              unless @options[:allow_file_uris]
                raise RemoteFileError, uri.to_s if @options[:io_exceptions]

                return
              end
              read_local_file(uri)
            else
              src_and_charset, = read_remote_file(uri, integrity: opts[:integrity]) # skip charset
              src_and_charset
            end

      add_block!(src, opts) if src
    end

    # Load a local CSS file.
    def load_file!(file_name, options = {}, deprecated = nil)
      opts = {base_dir: nil, media_types: :all}

      if options.is_a? Hash
        opts.merge!(options)
      else
        warn '[DEPRECATION] `load_file!` with positional arguments is deprecated. ' \
             'Please use keyword arguments instead.', uplevel: 1
        opts[:base_dir] = options if options.is_a? String
        opts[:media_types] = deprecated if deprecated
      end

      file_name = File.expand_path(file_name, opts[:base_dir])
      return unless File.readable?(file_name)
      return unless circular_reference_check(file_name)

      src = File.read(file_name)

      opts[:filename] = file_name if opts[:capture_offsets]
      opts[:base_dir] = File.dirname(file_name)

      add_block!(src, opts)
    end

    # Load a local CSS string.
    def load_string!(src, options = {}, deprecated = nil)
      opts = {base_dir: nil, media_types: :all}

      if options.is_a? Hash
        opts.merge!(options)
      else
        warn '[DEPRECATION] `load_file!` with positional arguments is deprecated. ' \
             'Please use keyword arguments instead.', uplevel: 1
        opts[:base_dir] = options if options.is_a? String
        opts[:media_types] = deprecated if deprecated
      end

      add_block!(src, opts)
    end

  protected

    # Check that a path hasn't been loaded already
    #
    # Raises a CircularReferenceError exception if io_exceptions are on,
    # otherwise returns true/false.
    # TODO: fix rubocop
    def circular_reference_check(path) # rubocop:disable Naming/PredicateMethod
      path = path.to_s
      if @loaded_uris.include?(path)
        raise CircularReferenceError, "can't load #{path} more than once" if @options[:io_exceptions]

        false
      else
        @loaded_uris << path
        true
      end
    end

    # Remove a pattern from a given string
    #
    # Returns a string.
    def ignore_pattern(css, regex, options)
      # if we are capturing file offsets, replace the characters with spaces to retail the original positions
      return css.gsub(regex) { |m| ' ' * m.length } if options[:capture_offsets]

      # otherwise just strip it out
      css.gsub(regex, '')
    end

    # Strip comments and clean up blank lines from a block of CSS.
    #
    # Returns a string.
    def cleanup_block(block, options = {}) # :nodoc:
      # Strip CSS comments
      utf8_block = block.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: ' ')
      utf8_block = ignore_pattern(utf8_block, STRIP_CSS_COMMENTS_RX, options)

      # Strip HTML comments - they shouldn't really be in here but
      # some people are just crazy...
      utf8_block = ignore_pattern(utf8_block, STRIP_HTML_COMMENTS_RX, options)

      # Strip lines containing just whitespace
      utf8_block.gsub!(/^\s+$/, '') unless options[:capture_offsets]

      utf8_block
    end

    # Read a local file:// URI. Called only from `load_uri!` — never
    # from the remote read path — so an HTTP redirect cannot reach this
    # branch (GHSA-9pmc-p236-855h).
    def read_local_file(uri) # :nodoc:
      # Internal invariant: this method is the implementation of the
      # `allow_file_uris: true` branch of `load_uri!`. If it is ever
      # reached without that flag set, a future change has bypassed the
      # LFI gate; refuse to read rather than silently leak.
      unless @options[:allow_file_uris]
        raise "BUG: #{self.class}##{__method__} reached with " \
              'allow_file_uris=false (LFI gate bypassed)'
      end

      return nil unless circular_reference_check(uri.to_s)

      path = uri.path
      path.gsub!(%r{^/}, '') if Gem.win_platform?
      File.read(path, mode: 'rb')
    rescue
      raise RemoteFileError, uri.to_s if @options[:io_exceptions]

      nil
    end

    # Download a remote http(s) file into a string.
    #
    # Returns the file's data and character set in an array.
    #
    # In the default (secure) configuration, requests are issued via
    # `SsrfFilter.get`, which:
    #   - rejects any scheme other than http/https (defeats redirect-to-
    #     `file://` / `gopher://` / `dict://` etc.);
    #   - resolves the hostname with `Resolv` and rejects requests whose
    #     resolved IP is loopback, RFC-1918, link-local, multicast, or any
    #     other range typically used for internal services (defeats SSRF
    #     via literal IPs and via CNAME / attacker-controlled A records);
    #   - re-validates scheme and IP on every redirect hop.
    #
    # When `allow_local_network: true` is set on the Parser, the SSRF
    # check is bypassed and plain `Net::HTTP` is used — but the scheme
    # is still validated on every redirect hop, so cross-scheme
    # redirect to `file://` (the original GHSA-9pmc-p236-855h sink)
    # remains closed even on this opt-in path.
    #
    # `integrity:`, when given, is verified against the raw response body
    # (before charset decoding, matching Subresource Integrity semantics)
    # -- see `integrity_matches?` and `load_uri!`'s documentation.
    #--
    # TODO: add option to fail silently or throw and exception on a 404
    #++
    def read_remote_file(uri, integrity: nil) # :nodoc:
      uri = Addressable::URI.parse(uri.to_s)

      unless circular_reference_check(uri.to_s)
        return nil, nil
      end

      unless REMOTE_ALLOWED_SCHEMES.include?(uri.scheme)
        raise RemoteFileError, uri.to_s if @options[:io_exceptions]

        return nil, nil
      end

      begin
        res = if @options[:allow_local_network]
                fetch_via_net_http(uri)
              else
                SsrfFilter.get(
                  uri.to_s,
                  scheme_whitelist: REMOTE_ALLOWED_SCHEMES,
                  max_redirects: MAX_REDIRECTS,
                  headers: {'User-Agent' => @options[:user_agent]}
                )
              end

        if res.code.to_i >= 400
          raise RemoteFileError, uri.to_s if @options[:io_exceptions]

          return '', nil
        end

        if integrity && !integrity_matches?(res.body, integrity)
          raise IntegrityError, uri.to_s if @options[:io_exceptions]

          return nil, nil
        end

        charset = res.respond_to?(:charset) ? res.encoding : 'utf-8'
        src = res.body
        src.encode!('UTF-8', charset) if charset

        [src, charset]
      rescue IntegrityError
        # Let the IntegrityError raised above propagate with its specific
        # class intact, rather than being downgraded to a generic
        # RemoteFileError by the catch-all below. Other RemoteFileErrors
        # raised within this method (e.g. from fetch_via_net_http on a
        # cross-scheme redirect) are intentionally still caught by the
        # catch-all: it discards their (potentially redirect-target-scoped)
        # message in favor of this method's own `uri`, which several
        # existing tests depend on.
        raise
      rescue
        raise RemoteFileError, uri.to_s if @options[:io_exceptions]

        [nil, nil]
      end
    end

    # Verifies +body+ (raw response bytes, not yet charset-decoded) against a
    # Subresource Integrity value -- a single `<algorithm>-<base64 digest>` token, or
    # several whitespace-separated tokens (https://www.w3.org/TR/SRI/#the-integrity-attribute).
    # Tokens using an algorithm this library doesn't recognize are ignored; per the spec's
    # "agility" rule, when multiple recognized algorithms are present only the strongest one
    # is checked. A value containing no recognized algorithm is treated as unverifiable and
    # matches by default, rather than failing every fetch whenever a caller passes a stronger
    # or newer algorithm than this library currently supports.
    def integrity_matches?(body, integrity) # :nodoc:
      candidates = integrity.to_s.split.filter_map do |token|
        algorithm, value = token.split('-', 2)
        [algorithm, value] if algorithm && value && INTEGRITY_ALGORITHMS.key?(algorithm)
      end
      return true if candidates.empty?

      algorithms_present = candidates.map(&:first)
      algorithm = INTEGRITY_ALGORITHMS.each_key.find { |a| algorithms_present.include?(a) }
      expected_values = candidates.select { |a, _v| a == algorithm }.map { |_a, v| v }
      digest_class = INTEGRITY_ALGORITHMS.fetch(algorithm)

      expected_values.include?(Base64.strict_encode64(digest_class.digest(body)))
    end

    # Net::HTTP path used only when `allow_local_network: true`. Validates
    # the URI scheme on every redirect hop so a `Location: file://...`
    # cannot be followed even on this opt-in code path.
    def fetch_via_net_http(uri, redirect_count = 0) # :nodoc:
      # Internal invariant: this method is the implementation of the
      # `allow_local_network: true` branch of `read_remote_file`. If it
      # is ever reached without that flag set, a future change has
      # bypassed the SSRF gate; refuse to fetch rather than silently
      # connect. The recursive call on a redirect inherits this guard
      # because the option does not change mid-request.
      unless @options[:allow_local_network]
        raise "BUG: #{self.class}##{__method__} reached with " \
              'allow_local_network=false (SSRF gate bypassed)'
      end

      raise RemoteFileError, uri.to_s unless REMOTE_ALLOWED_SCHEMES.include?(uri.scheme)
      raise RemoteFileError, uri.to_s if redirect_count > MAX_REDIRECTS

      http = Net::HTTP.new(uri.host, uri.port || uri.default_port)
      http.use_ssl = (uri.scheme == 'https')

      res = http.get(uri.request_uri, {'User-Agent' => @options[:user_agent]})

      if res.code.to_i >= 300 && res.code.to_i < 400 && res['Location']
        redirect_uri = Addressable::URI.parse(Addressable::URI.escape(res['Location']))
        return fetch_via_net_http(redirect_uri, redirect_count + 1)
      end

      res
    end

  private

    # Save a folded declaration block to the internal cache.
    def save_folded_declaration(block_hash, folded_declaration) # :nodoc:
      @folded_declaration_cache[block_hash] = folded_declaration
    end

    # Retrieve a folded declaration block from the internal cache.
    def get_folded_declaration(block_hash) # :nodoc:
      @folded_declaration_cache[block_hash] ||= nil
    end

    def reset! # :nodoc:
      @folded_declaration_cache = {}
      @css_source = ''
      @css_rules = []
      @css_warnings = []
    end

    # recurse through nested nodes and return them as Hashes nested in
    # passed hash
    def css_node_to_h(hash, key, val)
      hash[key.strip] = '' and return hash if val.nil?

      lines = val.split(';')
      nodes = {}
      lines.each do |line|
        parts = line.split(':', 2)
        if parts[1].include?(':')
          nodes[parts[0]] = css_node_to_h(hash, parts[0], parts[1])
        else
          nodes[parts[0].to_s.strip] = parts[1].to_s.strip
        end
      end
      hash[key.strip] = nodes
      hash
    end
  end
end
