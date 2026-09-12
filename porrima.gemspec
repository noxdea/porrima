# frozen_string_literal: true

require_relative "lib/porrima/version"

Gem::Specification.new do |spec|
  spec.name = "porrima"
  spec.version = Porrima::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Line, word, and three-way diff, patch, and merge in pure Ruby"
  spec.description = "Linear-space Myers diff with context hunks, gutter marks, paired rows, unified output, strict patch application, and three-way merge. No I/O, no dependencies."
  spec.homepage = "https://github.com/noxdea/porrima"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.files = Dir["lib/**/*.rb", "exe/*", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["porrima"]
  spec.require_paths = ["lib"]
end
