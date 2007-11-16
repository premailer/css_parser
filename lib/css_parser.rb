require 'uri'
require 'md5'
require 'zlib'
require 'iconv'
require 'lib/css_parser/rule_set'
require 'lib/css_parser/regexps'
require 'lib/css_parser/parser'

module CssParser

  attr :folded_declaration_cache

  # Merge multiple CSS RuleSets by cascading according to the CSS 2.1 cascading rules 
  # (http://www.w3.org/TR/REC-CSS2/cascade.html#cascading-order).
  #
  # Takes one or more RuleSet objects.
  #
  # If a RuleSet object has its specificity defined, that specificity is used in 
  # the cascade calculations.  If no specificity is set, the specificity is 
  # calculated using the RuleSet's selectors. (TODO: WHICH ONE?)  If no selectors
  # are present, the RuleSets are processed in order, with later ones taking 
  # precendence.
  #
  # Returns a RuleSet.
  #
  # ==== Example
  #  declaration_hashes = [{:specificity => 10, :declarations => 'color: red; font: 300 italic 11px/14px verdana, helvetica, sans-serif;'},
  #                        {:specificity => 1000, :declarations => 'font-weight: normal'}]
  #
  #  fold_declarations(declaration_hashes).inspect
  #
  #  => "font-weight: normal; font-size: 11px; line-height: 14px; font-family: verdana, helvetica, sans-serif; 
  #      color: red; font-style: italic;"
  #--
  # TODO: declaration_hashes should be able to contain a RuleSet
  #       this should be a Class method
  def CssParser.merge(*rule_sets)
    @folded_declaration_cache = {}

    unless rule_sets.all? {|rs| rs.kind_of?(CssParser::RuleSet)}
      raise ArgumentError, "all parameters must be CssParser::RuleSets."
    end

    return rule_sets[0] if rule_sets.length == 1

    # Internal storage of CSS properties that we will keep
    properties = {}

    rule_sets.each do |rule_set|
      #raise ArgumentError, "parameters must be CssParser::RuleSets." unless rule_set.kind_of?(CssParser::RuleSet)

      rule_set.expand_shorthand!
      specificity = rule_set.specificity || 0

      rule_set.each_declaration do |property, value, is_important|
        # Add the property to the list to be folded per http://www.w3.org/TR/CSS21/cascade.html#cascading-order
        if not properties.has_key?(property) or
               is_important or # step 2
               properties[property][:specificity] < specificity or # step 3
               properties[property][:specificity] == specificity # step 4    
          properties[property] = {:value => value, :specificity => specificity, :is_important => is_important}            
        end
      end
    end

    merged = RuleSet.new(nil, nil)

    # TODO: what about important
    properties.each do |property, details|
      merged[property.strip] = details[:value].strip
    end

    merged.create_shorthand!
    merged
  end

end