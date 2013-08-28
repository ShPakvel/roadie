module Roadie
  # Class that improves the markup of a HTML DOM tree
  #
  # This class will improve the following aspects of the DOM:
  #   * A HTML5 doctype will be added if missing, other doctypes will be left as-is
  #   * Basic HTML elements will be added if missing
  #     * <html>
  #     * <head>
  #     * <body>
  #     * <meta> declaring charset and content-type (text/html)
  #
  # The original HTML must also be passed in in order to handle the doctypes
  # since a Nokogiri::HTML::Document will always have a doctype, no matter if
  # the original source had it or not. Reading the raw HTML is the only way to
  # determine if we want to add a HTML5 doctype or not.
  class MarkupImprover
    def initialize(dom, original_html)
      @dom = dom
      @html = original_html
    end

    # @return [nil] passed DOM will be mutated
    def improve
      ensure_doctype_present
      head = ensure_head_element_present
      ensure_declared_charset head
    end

    private
    attr_reader :dom

    def ensure_doctype_present
      return if @html.include?('<!DOCTYPE ')
      # Nokogiri adds a "default" doctype to the DOM, which we will remove
      dom.internal_subset.remove unless dom.internal_subset.nil?
      dom.create_internal_subset 'html', nil, nil
    end

    def ensure_head_element_present
      if (head = dom.at_xpath('html/head'))
        head
      else
        create_head_element dom.at_xpath('html')
      end
    end

    def create_head_element(parent)
      head = Nokogiri::XML::Node.new 'head', dom
      unless parent.children.empty?
        # Crashes when no children are present
        parent.children.before head
      else
        parent << head
      end
      head
    end

    def ensure_declared_charset(parent)
      if content_type_meta_element_missing?
        parent.add_child make_content_type_element
      end
    end

    def content_type_meta_element_missing?
      dom.xpath('html/head/meta').none? do |meta|
        meta['http-equiv'].downcase == 'content-type'
      end
    end

    def make_content_type_element
      meta = Nokogiri::XML::Node.new('meta', dom)
      meta['http-equiv'] = 'Content-Type'
      meta['content'] = 'text/html; charset=UTF-8'
      meta
    end
  end
end