# encoding: UTF-8
require 'spec_helper'

module Roadie
  describe Inliner do
    before { @stylesheet = "" }
    def use_css(css) @stylesheet = Stylesheet.new("example", css) end

    def rendering(html, stylesheet = @stylesheet)
      dom = Nokogiri::HTML.parse html
      Inliner.new([stylesheet]).inline(dom)
      dom
    end

    describe "inlining styles" do
      it "inlines simple attributes" do
        use_css 'p { color: green }'
        expect(rendering('<p></p>')).to have_styling('color' => 'green')
      end

      it "inlines browser-prefixed attributes" do
        use_css 'p { -vendor-color: green }'
        expect(rendering('<p></p>')).to have_styling('-vendor-color' => 'green')
      end

      it "inlines CSS3 attributes" do
        use_css 'p { border-radius: 2px; }'
        expect(rendering('<p></p>')).to have_styling('border-radius' => '2px')
      end

      it "keeps the order of the styles that are inlined" do
        use_css 'h1 { padding: 2px; margin: 5px; }'
        expect(rendering('<h1></h1>')).to have_styling([['padding', '2px'], ['margin', '5px']])
      end

      it "combines multiple selectors into one" do
        use_css 'p { color: green; }
                .tip { float: right; }'
        expect(rendering('<p class="tip"></p>')).to have_styling([['color', 'green'], ['float', 'right']])
      end

      it "uses the attributes with the highest specificity when conflicts arises" do
        use_css ".safe { color: green; }
                p { color: red; }"
        expect(rendering('<p class="safe"></p>')).to have_styling([['color', 'red'], ['color', 'green']])
      end

      it "sorts styles by specificity order" do
        use_css 'p          { important: no; }
                 #important { important: very; }
                 .important { important: yes; }'

        expect(rendering('<p class="important"></p>')).to have_styling([
          %w[important no], %w[important yes]
        ])

        expect(rendering('<p class="important" id="important"></p>')).to have_styling([
          %w[important no], %w[important yes], %w[important very]
        ])
      end

      it "supports multiple selectors for the same rules" do
        use_css 'p, a { color: green; }'
        rendering('<p></p><a></a>').tap do |document|
          expect(document).to have_styling('color' => 'green').at_selector('p')
          expect(document).to have_styling('color' => 'green').at_selector('a')
        end
      end

      it "keeps !important properties" do
        use_css "a { text-decoration: underline !important; }
                 a.hard-to-spot { text-decoration: none; }"
        expect(rendering('<a class="hard-to-spot"></a>')).to have_styling([
          ['text-decoration', 'none'], ['text-decoration', 'underline !important']
        ])
      end

      it "combines with already present inline styles" do
        use_css "p { color: green }"
        expect(rendering('<p style="font-size: 1.1em"></p>')).to have_styling([['color', 'green'], ['font-size', '1.1em']])
      end

      it "does not override inline styles" do
        use_css "p { text-transform: uppercase; color: red }"
        # The two color properties are kept to make css fallbacks work correctly
        expect(rendering('<p style="color: green"></p>')).to have_styling([
          ['text-transform', 'uppercase'],
          ['color', 'red'],
          ['color', 'green'],
        ])
      end

      it "does not apply link and dynamic pseudo selectors" do
        use_css "
          p:active { color: red }
          p:focus { color: red }
          p:hover { color: red }
          p:link { color: red }
          p:target { color: red }
          p:visited { color: red }

          p.active { width: 100%; }
        "
        expect(rendering('<p class="active"></p>')).to have_styling('width' => '100%')
      end

      it "does not crash on any pseudo element selectors" do
        use_css "
          p.some-element { width: 100%; }
          p::some-element { color: red; }
        "
        expect(rendering('<p class="some-element"></p>')).to have_styling('width' => '100%')
      end

      it "warns on selectors that crash Nokogiri" do
        dom = Nokogiri::HTML.parse "<p></p>"

        stylesheet = Stylesheet.new "foo.css", "p[%^=foo] { color: red; }"
        inliner = Inliner.new([stylesheet])
        expect(inliner).to receive(:warn).with(
          %{Roadie cannot use "p[%^=foo]" (from "foo.css" stylesheet) when inlining stylesheets}
        )
        inliner.inline(dom)
      end

      it "works with nth-child" do
        use_css "
          p { color: red; }
          p:nth-child(2n) { color: green; }
        "
        result = rendering("<p></p> <p></p>")

        expect(result).to have_styling([['color', 'red']]).at_selector('p:first')
        expect(result).to have_styling([['color', 'red'], ['color', 'green']]).at_selector('p:last')
      end

      it "ignores selectors with @" do
        use_css '@keyframes progress-bar-stripes {
          from {
            background-position: 40px 0;
          }
          to {
            background-position: 0 0;
          }
        }'
        expect { rendering('<p></p>') }.not_to raise_error
      end
    end
  end
end
