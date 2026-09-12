# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "stringio"
require "tmpdir"
require "fileutils"

class CLITest < Minitest::Test
  def run_cli(*arguments)
    output, error = StringIO.new, StringIO.new
    code = Porrima::CLI.main(arguments, output: output, error: error)
    [code, output.string, error.string]
  end

  def setup
    require "porrima/cli"
    @directory = Dir.mktmpdir("porrima-cli-")
  end

  def teardown = FileUtils.remove_entry(@directory)

  def path(name, content = nil)
    location = File.join(@directory, name)
    File.binwrite(location, content) if content
    location
  end

  def test_diff_exit_codes_json_quiet_and_plain_output
    old = path("old", "one\n")
    same = path("same", "one\n")
    changed = path("changed", "two\n")
    assert_equal [0, "", ""], run_cli(old, same)
    code, output, error = run_cli("diff", "--json", old, changed)
    assert_equal 1, code
    assert_equal 1, JSON.parse(output).fetch("version")
    assert_empty error
    assert_equal [1, "", ""], run_cli("--quiet", old, changed)
    code, output, = run_cli(old, changed)
    assert_equal 1, code
    assert_includes output, "@@ -1,1 +1,1 @@"
    refute_includes output, "\e["
  end

  def test_missing_file_and_budget_errors_exit_two
    code, _, error = run_cli(path("missing"), path("also-missing"))
    assert_equal 2, code
    assert_match(/porrima:/, error)
    old = path("old", "one\n")
    new = path("new", "two\n")
    assert_equal 2, run_cli("--max-bytes", "1", old, new).first
  end

  def test_merge_exit_status_and_marker_styles
    base = path("base", "old\n")
    ours = path("ours", "ours\n")
    theirs = path("theirs", "theirs\n")
    code, output, error = run_cli("merge", "--style", "merge", base, ours, theirs)
    assert_equal 1, code
    assert_includes output, "<<<<<<< #{@directory}/ours"
    refute_includes output, "|||||||"
    refute_includes output, "\e["
    assert_empty error
    assert_equal 0, run_cli("merge", base, ours, base).first
  end

  def test_apply_check_write_and_reverse
    file = path("file", "old\n")
    patch = path("change.patch", Porrima.unified("old\n", "new\n", old_name: file, new_name: file, context: 0))
    assert_equal 0, run_cli("apply", "--check", patch, file).first
    assert_equal "old\n", File.binread(file)
    assert_equal 0, run_cli("apply", "--quiet", patch, file).first
    assert_equal "new\n", File.binread(file)
    assert_equal 0, run_cli("apply", "--reverse", "--quiet", patch, file).first
    assert_equal "old\n", File.binread(file)
  end

  def test_help_and_version
    assert_equal [0, "#{Porrima::VERSION}\n", ""], run_cli("--version")
    code, output, = run_cli("merge", "--help")
    assert_equal 0, code
    assert_includes output, "Usage: porrima merge"
  end
end
