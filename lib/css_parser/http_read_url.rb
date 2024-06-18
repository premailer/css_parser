# frozen_string_literal: true

module CssParser
  class HTTPReadURL
    MAX_REDIRECTS = 3

    # Exception class used if a request is made to load a CSS file more than once.
    class CircularReferenceError < StandardError; end

    # Exception class used for any errors encountered while downloading remote files.
    class RemoteFileError < IOError; end

    def initialize(agent:, io_exceptions:)
      @agent = agent
      @io_exceptions = io_exceptions

      @redirect_count = nil
      @loaded_uris = []
    end

    # Check that a path hasn't been loaded already
    #
    # Raises a CircularReferenceError exception if io_exceptions are on,
    # otherwise returns true/false.
    def circular_reference_check(path)
      path = path.to_s
      if @loaded_uris.include?(path)
        raise CircularReferenceError, "can't load #{path} more than once" if @io_exceptions

        false
      else
        @loaded_uris << path
        true
      end
    end

    # Download a file into a string.
    #
    # Returns the file's data and character set in an array.
    #--
    # TODO: add option to fail silently or throw and exception on a 404
    #++
    def read_remote_file(uri) # :nodoc:
      if @redirect_count.nil?
        @redirect_count = 0
      else
        @redirect_count += 1
      end

      # TODO: has to be done on the outside
      unless circular_reference_check(uri.to_s)
        @redirect_count = nil
        return nil, nil
      end

      if @redirect_count > MAX_REDIRECTS
        @redirect_count = nil
        return nil, nil
      end

      src = '', charset = nil

      begin
        uri = Addressable::URI.parse(uri.to_s)

        if uri.scheme == 'file'
          # local file
          path = uri.path
          path.gsub!(%r{^/}, '') if Gem.win_platform?
          src = File.read(path, mode: 'rb')
        else
          # remote file
          if uri.scheme == 'https'
            uri.port = 443 unless uri.port
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          else
            http = Net::HTTP.new(uri.host, uri.port)
          end

          res = http.get(uri.request_uri, {'User-Agent' => @agent, 'Accept-Encoding' => 'gzip'})
          src = res.body
          charset = res.respond_to?(:charset) ? res.encoding : 'utf-8'

          if res.code.to_i >= 400
            @redirect_count = nil
            raise RemoteFileError, uri.to_s if @io_exceptions

            return '', nil
          elsif res.code.to_i >= 300 and res.code.to_i < 400
            unless res['Location'].nil?
              return read_remote_file(Addressable::URI.parse(Addressable::URI.escape(res['Location'])))
            end
          end

          case res['content-encoding']
          when 'gzip'
            io = Zlib::GzipReader.new(StringIO.new(res.body))
            src = io.read
          when 'deflate'
            io = Zlib::Inflate.new
            src = io.inflate(res.body)
          end
        end

        if charset
          if String.method_defined?(:encode)
            src.encode!('UTF-8', charset)
          else
            ic = Iconv.new('UTF-8//IGNORE', charset)
            src = ic.iconv(src)
          end
        end
      rescue
        @redirect_count = nil
        raise RemoteFileError, uri.to_s if @io_exceptions

        return nil, nil
      end

      @redirect_count = nil
      [src, charset]
    end
  end
end
