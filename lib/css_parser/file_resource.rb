# frozen_string_literal: true

module CssParser
  class FileResource
    # Exception class used if a request is made to load a CSS file more than once.
    class CircularReferenceError < StandardError; end

    def initialize(io_exceptions:)
      @io_exceptions = io_exceptions

      @loaded_files = []
    end

    # Check that a path hasn't been loaded already
    #
    # Raises a CircularReferenceError exception if io_exceptions are on,
    # otherwise returns true/false.
    def circular_reference_check(path)
      path = path.to_s
      if @loaded_files.include?(path)
        raise CircularReferenceError, "can't load #{path} more than once" if @io_exceptions

        false
      else
        @loaded_files << path
        true
      end
    end

    def find_file(file_name, base_dir:)
      path = File.expand_path(file_name, base_dir)
      return unless File.readable?(path)
      return unless circular_reference_check(path)

      path
    end
  end
end
