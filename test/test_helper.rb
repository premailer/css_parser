# frozen_string_literal: true

require 'bundler/setup'
require 'maxitest/autorun'
require 'net/http'
require 'css_parser'
require 'webmock/minitest'

def fixture(*path)
  Pathname(File.expand_path('fixtures', __dir__))
    .join(*path)
end
