# frozen_string_literal: true

spec = Gem::Specification.load(File.expand_path("../porrima.gemspec", __dir__))
abort "runtime dependency found" unless spec.runtime_dependencies.empty?

Dir[File.expand_path("../lib/**/*.rb", __dir__)].each do |file|
  source = File.read(file)
  cli = file.end_with?("/cli.rb")
  abort "application dependency in #{file}" if source.match?(/\b(?:Canopus|Thuban|Zaniah|Denebola)\b/)
  abort "display concern in #{file}" if source.include?("\e[")
  next if cli
  abort "I/O in core: #{file}" if source.match?(/\b(?:File|IO|Dir|Process|Kernel\.open|ENV)\b/)
  abort "CLI dependency in core: #{file}" if source.match?(/\bPorrima::CLI\b/)
end

puts "Isolated pure Ruby core: OK"
