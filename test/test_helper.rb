# frozen_string_literal: true

require 'bundler/setup'
require 'maxitest/autorun'
require 'mocha/minitest'
require 'ostruct'
require 'net/http'
require 'webrick'
require 'css_parser'

module AllocationCounting
  def allocations
    skip 'GC.stat(:total_allocated_objects) is MRI only' unless RUBY_ENGINE == 'ruby'

    yield
    GC.disable
    Array.new(2) do
      before = GC.stat(:total_allocated_objects)
      yield
      GC.stat(:total_allocated_objects) - before
    end.min
  ensure
    GC.enable
  end
end
