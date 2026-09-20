# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/test_*.rb"
end

task(:bench) { ruby "--yjit", "-Ilib", "bench/diff.rb" }
namespace :bench do
  task(:assert) { ruby "--yjit", "-Ilib", "bench/diff.rb", "--assert" }
end

task default: :test

desc "Regenerate deterministic demo media"
task :demo do
  Dir["demo/*.rb"].sort.each { |path| ruby "-Ilib", path }
end
