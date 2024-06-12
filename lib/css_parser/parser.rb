# frozen_string_literal: true

module CssParser
  # We have a Parser class which you create and instance of but we have some
  # functions which is nice to have outside of this instance
  #
  # Intended as private helpers for lib. Breaking changed with no warning
  module ParserFx
    # Receives properties from a style_rule node from crass.
    def self.create_declaration_from_properties(properties)
      declarations = RuleSet::Declarations.new

      properties.each do |child|
        case child
        in node: :property, value: '' # nothing, happen for { color:green; color: }
        in node: :property
          declarations.add_declaration!(
            child[:name],
            RuleSet::Declarations::Value.new(child[:value], important: child[:important])
          )
        in node: :whitespace # nothing
        in node: :semicolon # nothing
        in node: :error # nothing
        end
      end

      declarations
    end

    # it is expecting the selector tokens from node: :style_rule, not just
    # from Crass::Tokenizer.tokenize(input)
    def self.split_selectors(tokens)
      tokens
        .each_with_object([[]]) do |token, sum|
          case token
          in node: :comma
            sum << []
          else
            sum.last << token
          end
        end
    end
  end

  # == Parser class
  #
  # All CSS is converted to UTF-8.
  #
  # When calling Parser#new there are some configuaration options:
  # [<tt>absolute_paths</tt>] Convert relative paths to absolute paths (<tt>href</tt>, <tt>src</tt> and <tt>url('')</tt>. Boolean, default is <tt>false</tt>.
  # [<tt>import</tt>] Follow <tt>@import</tt> rules. Boolean, default is <tt>true</tt>.
  # [<tt>io_exceptions</tt>] Throw an exception if a link can not be found. Boolean, default is <tt>true</tt>.
  class Parser
    USER_AGENT = "Ruby CSS Parser/#{CssParser::VERSION} (https://github.com/premailer/css_parser)".freeze

    #--
    # Class variable? see http://www.oreillynet.com/ruby/blog/2007/01/nubygems_dont_use_class_variab_1.html
    #++
    @folded_declaration_cache = {}
    class << self; attr_reader :folded_declaration_cache; end

    def initialize(options = {})
      @options = {
        absolute_paths: false,
        import: true,
        io_exceptions: true,
        rule_set_exceptions: true,
        capture_offsets: false,
        user_agent: USER_AGENT
      }.merge(options)

      @options[:http_resource] ||= CssParser::HTTPReadURL
                                   .new(agent: @options[:user_agent],
                                     io_exceptions: @options[:io_exceptions])
      @options[:file_resource] ||= CssParser::FileResource
                                   .new(io_exceptions: @options[:io_exceptions])

      # array of RuleSets
      @rules = []

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
        selector = selector.strip
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

      # TODO: Would be nice to skip this step too
      if options[:base_uri] and @options[:absolute_paths]
        block = CssParser.convert_uris(block, options[:base_uri])
      end

      current_media_queries = [:all]
      if options[:media_types]
        current_media_queries = options[:media_types].flatten.collect { |mt| CssParser.sanitize_media_query(mt) }
      end

      Crass.parse(block).each do |node|
        case node
        in node: :style_rule
          declarations = ParserFx.create_declaration_from_properties(node[:children])
          selectors = ParserFx
                      .split_selectors(node[:selector][:tokens])
                      .map { Crass::Parser.stringify(_1).strip }

          add_rule_options = {
            selectors: selectors,
            block: declarations,
            media_types: current_media_queries
          }
          if options[:capture_offsets]
            add_rule_options.merge!(
              filename: options[:filename],
              offset: node[:selector][:tokens].first[:pos]..node[:children].last[:pos]
            )
          end

          add_rule!(**add_rule_options)
        in node: :at_rule, name: 'media'
          new_media_queries = split_media_query_by_or_condition(node[:prelude])
          add_block!(node[:block], options.merge(media_types: new_media_queries))

        in node: :at_rule, name: 'page'
          declarations = ParserFx.create_declaration_from_properties(Crass.parse_properties(node[:block]))
          add_rule_options = {
            selectors: "@page#{Crass::Parser.stringify(node[:prelude])}",
            block: declarations,
            media_types: current_media_queries
          }
          if options[:capture_offsets]
            add_rule_options.merge!(
              filename: options[:filename],
              offset: node[:tokens].first[:pos]..node[:tokens].last[:pos]
            )
          end
          add_rule!(**add_rule_options)

        in node: :at_rule, name: 'font-face'
          declarations = ParserFx.create_declaration_from_properties(Crass.parse_properties(node[:block]))
          add_rule_options = {
            selectors: "@font-face#{Crass::Parser.stringify(node[:prelude])}",
            block: declarations,
            media_types: current_media_queries
          }
          if options[:capture_offsets]
            add_rule_options.merge!(
              filename: options[:filename],
              offset: node[:tokens].first[:pos]..node[:tokens].last[:pos]
            )
          end
          add_rule!(**add_rule_options)

        in node: :at_rule, name: 'import'
          next unless @options[:import]

          import = nil
          import_options = options.slice(:capture_offsets, :base_uri, :base_dir)

          prelude = node[:prelude].each
          loop do
            case (token = prelude.next)
            in node: :whitespace # nothing
            in node: :string
              import = {type: :file, path: token[:value]}
              break
            in node: :function, name: 'url'
              import = {type: :url, path: token[:value].first[:value]}
              break
            end
          end

          media_query_section = []
          loop { media_query_section << prelude.next }

          import_options[:media_types] = split_media_query_by_or_condition(media_query_section)
          if import_options[:media_types].empty?
            import_options[:media_types] = [:all]
          end

          unless options[:only_media_types].include?(:all) or !(import_options[:media_types] & options[:only_media_types]).empty?
            next
          end

          if options[:base_uri]
            load_uri!(
              Addressable::URI.parse(options[:base_uri].to_s) + Addressable::URI.parse(import[:path]),
              import_options
            )
          elsif options[:base_dir]
            load_file!(import[:path], import_options)
          end
        in node: :whitespace # nothing
        in node: :error # nothing
        end
      end
    end

    # Add a CSS rule by setting the +selectors+, +declarations+
    # and +media_types+. Optional pass +filename+ , +offset+ for source
    # reference too.
    #
    # +media_types+ can be a symbol or an array of symbols. default to :all
    # optional fields for source location for source location
    # +filename+ can be a string or uri pointing to the file or url location.
    # +offset+ should be Range object representing the start and end byte locations where the rule was found in the file.
    def add_rule!(selectors: nil, block: nil, filename: nil, offset: nil, media_types: :all)
      rule_set = RuleSet.new(
        selectors: selectors, block: block,
        offset: offset, filename: filename
      )

      add_rule_set!(rule_set, media_types)
    rescue CssParser::Error => e
      raise e if @options[:rule_set_exceptions]
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

    # Load a remote CSS file.
    #
    # You can also pass in file://test.css
    #
    # See add_block! for options.
    #
    # Deprecated: originally accepted three params: `uri`, `base_uri` and `media_types`
    def load_uri!(uri, options = {})
      uri = Addressable::URI.parse(uri) unless uri.respond_to? :scheme

      opts = {base_uri: nil, media_types: :all}
      opts.merge!(options)

      if uri.scheme == 'file' or uri.scheme.nil?
        uri.path = File.expand_path(uri.path)
        uri.scheme = 'file'
      end

      opts[:base_uri] = uri if opts[:base_uri].nil?

      # pass on the uri if we are capturing file offsets
      opts[:filename] = uri.to_s if opts[:capture_offsets]

      src, = @options[:http_resource].read_remote_file(uri) # skip charset

      add_block!(src, opts) if src
    end

    # Load a local CSS file.
    def load_file!(file_name, options = {})
      opts = {base_dir: nil, media_types: :all}
      opts.merge!(options)

      file_path = @options[:file_resource]
                  .find_file(file_name, base_dir: opts[:base_dir])
      # we we cant read the file it's nil
      return if file_path.nil?

      src = File.read(file_path)

      opts[:filename] = file_path if opts[:capture_offsets]
      opts[:base_dir] = File.dirname(file_path)

      add_block!(src, opts)
    end

    # Load a local CSS string.
    def load_string!(src, options = {})
      opts = {base_dir: nil, media_types: :all}
      opts.merge!(options)

      add_block!(src, opts)
    end

  private

    def split_media_query_by_or_condition(media_query_selector)
      media_query_selector
        .each_with_object([[]]) do |token, sum|
          # comma is the same as or
          # https://developer.mozilla.org/en-US/docs/Web/CSS/@media#logical_operators
          case token
          in node: :comma
            sum << []
          in node: :ident, value: 'or' # rubocop:disable Lint/DuplicateBranch
            sum << []
          else
            sum.last << token
          end
        end # rubocop:disable Style/MultilineBlockChain
        .map { Crass::Parser.stringify(_1).strip }
        .reject(&:empty?)
        .map(&:to_sym)
    end

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
        if parts[1] =~ /:/
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
