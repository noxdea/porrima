# frozen_string_literal: true

require "json"
require "optparse"
require "tempfile"
require "fileutils"

module Porrima
  module CLI
    MAX_BYTES = 10 * 1024 * 1024
    module_function

    def main(argv, output: $stdout, error: $stderr)
      arguments = argv.dup
      command = %w[diff merge apply].include?(arguments.first) ? arguments.shift : "diff"
      send("run_#{command}", arguments, output)
    rescue OptionParser::ParseError, StandardError => exception
      error.puts "porrima: #{exception.message}"
      2
    end

    def run_diff(arguments, output)
      options = {context: 3, json: false, quiet: false, max_bytes: MAX_BYTES}
      parser = OptionParser.new do |command|
        command.banner = "Usage: porrima [diff] [options] OLD NEW"
        command.on("-u", "--unified N", Integer) { |value| options[:context] = value }
        command.on("--json") { options[:json] = true }
        command.on("-q", "--quiet") { options[:quiet] = true }
        command.on("--max-bytes N", Integer) { |value| options[:max_bytes] = value }
        command.on("--version") { output.puts VERSION; return 0 }
        command.on("--help") { output.puts command; return 0 }
      end
      parser.parse!(arguments)
      raise OptionParser::MissingArgument, "OLD NEW" unless arguments.length == 2
      budget = Budget.new(max_bytes: options[:max_bytes], on_exceeded: :raise)
      result = Porrima.diff(File.binread(arguments[0]), File.binread(arguments[1]), context: options[:context], budget: budget)
      unless options[:quiet]
        output.puts JSON.generate(result.to_h) if options[:json]
        output << result.to_unified(old_name: arguments[0], new_name: arguments[1]) unless options[:json] || result.empty?
      end
      result.empty? ? 0 : 1
    end
    private_class_method :run_diff

    def run_merge(arguments, output)
      options = {style: :diff3, json: false, quiet: false, max_bytes: MAX_BYTES}
      parser = OptionParser.new do |command|
        command.banner = "Usage: porrima merge [options] BASE OURS THEIRS"
        command.on("--style STYLE", %w[diff3 merge]) { |value| options[:style] = value.to_sym }
        command.on("--json") { options[:json] = true }
        command.on("-q", "--quiet") { options[:quiet] = true }
        command.on("--max-bytes N", Integer) { |value| options[:max_bytes] = value }
        command.on("--version") { output.puts VERSION; return 0 }
        command.on("--help") { output.puts command; return 0 }
      end
      parser.parse!(arguments)
      raise OptionParser::MissingArgument, "BASE OURS THEIRS" unless arguments.length == 3
      texts = arguments.map { |path| File.binread(path) }
      raise BudgetExceeded, "diff budget exceeded" if texts.sum(&:bytesize) > options[:max_bytes]
      result = Merge.three_way(base: texts[0], ours: texts[1], theirs: texts[2])
      unless options[:quiet]
        output.puts JSON.generate(merge_to_h(result)) if options[:json]
        output << Merge.to_text(result, style: options[:style], labels: [arguments[1], arguments[0], arguments[2]]) unless options[:json]
      end
      result.clean? ? 0 : 1
    end
    private_class_method :run_merge

    def run_apply(arguments, output)
      options = {reverse: false, check: false, quiet: false, max_bytes: MAX_BYTES}
      parser = OptionParser.new do |command|
        command.banner = "Usage: porrima apply [options] PATCH [FILE]"
        command.on("--reverse") { options[:reverse] = true }
        command.on("--check") { options[:check] = true }
        command.on("-q", "--quiet") { options[:quiet] = true }
        command.on("--max-bytes N", Integer) { |value| options[:max_bytes] = value }
        command.on("--version") { output.puts VERSION; return 0 }
        command.on("--help") { output.puts command; return 0 }
      end
      parser.parse!(arguments)
      raise OptionParser::MissingArgument, "PATCH [FILE]" unless (1..2).cover?(arguments.length)
      patch_text = File.binread(arguments[0])
      raise BudgetExceeded, "diff budget exceeded" if patch_text.bytesize > options[:max_bytes]
      files = Patch.parse(patch_text)
      raise PatchError, "FILE is required for a multi-file patch" if arguments[1] && files.length != 1
      updates = files.map do |file|
        path = arguments[1] || patch_path(file, options[:reverse])
        content = File.file?(path) ? File.binread(path) : ""
        raise BudgetExceeded, "diff budget exceeded" if patch_text.bytesize + content.bytesize > options[:max_bytes]
        updated = options[:reverse] ? file.revert(content) : file.apply(content)
        [path, updated, options[:reverse] ? file.old_name == "/dev/null" : file.new_name == "/dev/null"]
      end
      unless options[:check]
        updates.each { |path, content, delete| delete ? File.unlink(path) : atomic_write(path, content) }
      end
      updates.each { |path,| output.puts path } unless options[:quiet]
      0
    end
    private_class_method :run_apply

    def patch_path(file, reverse)
      name = if reverse
        file.new_name == "/dev/null" ? file.old_name : file.new_name
      else
        file.old_name == "/dev/null" ? file.new_name : file.old_name
      end
      name = name.delete_prefix("a/").delete_prefix("b/")
      raise PatchError, "unsafe patch path" if name.empty? || name.start_with?("/") || name.split("/").any? { |part| ["", ".", "..", ".git"].include?(part) }
      name
    end
    private_class_method :patch_path

    def atomic_write(path, content)
      directory = File.dirname(File.expand_path(path))
      FileUtils.mkdir_p(directory)
      mode = File.file?(path) ? File.stat(path).mode & 0o777 : 0o644
      Tempfile.create([".porrima-", ".tmp"], directory) do |file|
        file.binmode
        file.chmod(mode)
        file.write(content)
        file.flush
        file.fsync
        file.close
        File.rename(file.path, path)
      end
    end
    private_class_method :atomic_write

    def merge_to_h(result)
      {version: 1, clean: result.clean?, sections: result.sections.map do |section|
        section.is_a?(Merge::Conflict) ? section.to_h.merge(kind: :conflict) : {kind: :text, text: section}
      end}
    end
    private_class_method :merge_to_h
  end
end
