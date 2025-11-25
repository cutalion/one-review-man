# frozen_string_literal: true

module Jekyll
  module RegexReplace
    def regex_replace(input, regex, replacement)
      input.to_s.gsub(Regexp.new(regex), replacement)
    end
  end
end

Liquid::Template.register_filter(Jekyll::RegexReplace)
