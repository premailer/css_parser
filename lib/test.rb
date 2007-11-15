require 'css_parser'
puts 'scan tests'
#puts '"test string"'.scan(/"/).length
qc = '"test \"string\"" "and another\'"'.scan(/[^\/]"/).length
puts qc
puts qc & 1

qca = '"test \"string\"" "and another unclosed'.scan(/[^\/]"/).length
puts qca
puts qca & 1
#puts qca & 1 ? true : false

#puts 'splitting'
#"test test { test}test }\n new { color: blue; }".scan(/((.[^{}"]*)\{|(.[^{}"]*)\}|(.[^{}"]*)\"|(.*)[\s]+)/mx).each do |token|
#  puts token.inspect
#  puts "t: #{token}"
#end

#exit 0

#require 'unprof'

css_block =<<-EOT
  color: green; rotation: 70deg; font: 12px sans-serif;
EOT

css_sel =<<-EOS
  #content p, a, strong
EOS

css_file =<<-EOF
/*body, #container {
  color: #fff;
  background: #1c2815 none;
}

#container {
  margin: 0 !important;
  width: 100%;
  background: #f0f0f0 url('/test.png');
  font-size: 12px;
}

#frame {
  margin: 0 auto;
  width: 740px;
}*/

.middle .text { width:531px; background-color:#fff; min-height:400px; padding: 5px 22px 5px 21px; }


td {
  font: 18px/1.5em Georgia, Times, serif;
}

/* from http://www.w3.org/TR/CSS21/syndata.html#rule-sets */
p[example="public class foo\
{\
    private int x;\
\
    foo(int x) {\
        this.x = x;\
    }\
\
}"] { color: blue; }
p[example="public \"class foo\"] { color: red }



EOF

css_addtl =<<-EOA
#head td {
  text-align: center;
  font-size: 11px;
}
EOA


cp = CssParser.new
cp.load_css!(css_file)

cp.rules.each_selector do |sel, decs, spec|
  puts "#{sel}\n { #{decs} } --> #{spec}"
end

#result = RubyProf.stop

#puts result.inspect

  # Print a flat profile to text
#  printer = RubyProf::TextPrinter.new(result)
#  printer.print(STDOUT, 0)
exit 0

r = CssRules.new
r.add_block!(css_file)
r.add_block!(css_addtl)

r.each_selector do |sel, decs, spec|
  puts "#{sel} { #{decs} } -- #{spec}"
end

exit 0


rs = CssRuleSet.new(css_sel, css_block)

rs.each_selector do |sel|
  puts "selector: #{sel}"
end


rs.each_declaration do |prop, val|
  puts "declaration: #{prop}, #{val}"
end


puts rs.block_to_s