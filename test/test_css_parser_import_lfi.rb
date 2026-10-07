# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'

# Tests for the @import local-file-disclosure remediation in
# `CssParser::Parser#load_file!` / the `base_dir` arm of `#add_block!`.
#
# This is the `base_dir` sibling of the SSRF / file:// hole fixed in
# GHSA-9pmc-p236-855h. That fix only closed the `file://`-via-`base_uri`
# arm of the @import handler (see test_css_parser_ssrf.rb); the `base_dir`
# arm routed the attacker-controlled @import path straight into
# `File.expand_path` + `File.read` with no containment.
#
# Pre-fix behaviour (with `:base_dir` set and no `:base_uri`, import on):
#   - `@import "/etc/passwd"` reads an absolute path outside base_dir.
#   - `@import "../../secret"` traverses out of base_dir.
#   The imported content is merged into the ruleset and surfaced to the
#   consumer (e.g. inlined by Premailer for local-file input).
#
# Post-fix expectations:
#   1. An @import whose resolved path escapes the import root -- by
#      absolute path or `..` traversal -- is refused: RemoteFileError
#      when io_exceptions are on (the default), a silent no-op otherwise.
#      No File.read of the out-of-root path happens.
#   2. Legitimate imports that stay inside the root still load, including
#      `..` segments that remain within the tree (subdir/x -> ../y).
#   3. `load_file!` called directly by the caller is unchanged: it is the
#      explicit, trusted local-file API and may load any readable path,
#      including one outside any base_dir. Only @import-sourced paths are
#      contained.
class CssParserImportLfiTests < Minitest::Test
  include CssParser

  def setup
    @cp = Parser.new # defaults: import:true, io_exceptions:true, allow_file_uris:false
  end

  # Build a disposable tree:
  #   <root>/main.css          (within root)
  #   <root>/sub/inner.css     (within root, nested)
  #   <outside>/secret.css     (sibling dir, OUTSIDE root)
  # Yields [root_dir, secret_path].
  def with_tree
    Dir.mktmpdir do |tmp|
      root = File.join(tmp, 'root')
      sub = File.join(root, 'sub')
      FileUtils.mkdir_p(sub)
      File.write(File.join(root, 'main.css'), 'div { color: lime; }')
      File.write(File.join(sub, 'inner.css'), 'a { text-decoration: none; }')
      secret = File.join(tmp, 'secret.css')
      File.write(secret, '.secret { content: "TOP_SECRET"; }')
      yield root, secret
    end
  end

  # ---- (1) Escaping imports refused ----

  def test_at_import_absolute_path_via_base_dir_is_refused
    with_tree do |root, secret|
      File.expects(:read).never # no out-of-root read may happen
      err = assert_raises(CssParser::RemoteFileError) do
        @cp.add_block!(%(@import "#{secret}";), base_dir: root)
      end
      assert_includes err.message, secret
      refute_includes @cp.to_s, 'TOP_SECRET'
    end
  end

  def test_at_import_traversal_escaping_root_is_refused
    with_tree do |root, _secret|
      File.expects(:read).never
      assert_raises(CssParser::RemoteFileError) do
        @cp.add_block!(%(@import "../secret.css";), base_dir: root)
      end
      refute_includes @cp.to_s, 'TOP_SECRET'
    end
  end

  def test_escaping_import_without_io_exceptions_is_silent_noop
    with_tree do |root, secret|
      cp = Parser.new(io_exceptions: false)
      cp.add_block!(%(@import "#{secret}";), base_dir: root) # must not raise
      refute_includes cp.to_s, 'TOP_SECRET'
      refute_includes cp.loaded_uris.join(' '), 'secret.css'
    end
  end

  # ---- (2) Legitimate in-root imports still load ----

  def test_import_within_base_dir_still_loads
    with_tree do |root, _secret|
      @cp.load_file!('main.css', base_dir: root)
      assert_equal 'color: lime;', @cp.find_by_selector('div').join(' ')
    end
  end

  def test_import_with_dotdot_that_stays_within_root_still_loads
    # sub/inner.css lives in <root>/sub; an @import "../main.css" from it
    # resolves to <root>/main.css -- a `..` that stays inside the root and
    # must keep working (mirrors the fixtures' subdir/import2 -> ../simple).
    with_tree do |root, _secret|
      File.write(File.join(root, 'sub', 'inner.css'),
        %(@import "../main.css";\na { text-decoration: none; }))
      @cp.load_file!('sub/inner.css', base_dir: root)
      assert_equal 'text-decoration: none;', @cp.find_by_selector('a').join(' ')
      assert_equal 'color: lime;', @cp.find_by_selector('div').join(' ') # from ../main.css
    end
  end

  # ---- (3) Direct load_file! (trusted caller API) is not contained ----

  def test_direct_load_file_outside_base_dir_still_works
    # Calling load_file! directly with a path outside base_dir is a
    # deliberate caller action, not an attacker-influenced @import, and
    # must keep working.
    with_tree do |root, secret|
      @cp.load_file!(secret, base_dir: root) # secret is outside root
      assert_equal 'content: "TOP_SECRET";', @cp.find_by_selector('.secret').join(' ')
    end
  end

  def test_direct_load_file_absolute_path_still_works
    with_tree do |_root, secret|
      @cp.load_file!(secret)
      assert_equal 'content: "TOP_SECRET";', @cp.find_by_selector('.secret').join(' ')
    end
  end
end
