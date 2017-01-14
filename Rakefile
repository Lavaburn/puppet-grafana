require 'puppetlabs_spec_helper/rake_tasks'

begin
  require 'puppet_blacksmith/rake_tasks'
rescue LoadError # rubocop:disable Lint/HandleExceptions
end

exclude_dirs = [
  "pkg/**/*",
  "vendor/**/*",
  "spec/**/*"
]

PuppetLint::RakeTask.new :lint do |config|
  config.ignore_paths = exclude_dirs
  config.disable_checks = ["80chars", "class_inherits_from_params_class"] 

  config.with_context = true
  config.relative = true
  #  config.log_format = '%{filename} - %{message}'
  #  config.log_format = "%{path}:%{linenumber}:%{check}:%{KIND}:%{message}"
end

# PuppetSyntax.exclude_paths = exclude_dirs

desc "Run syntax and lint tests."
task :quick_test => [
  :validate,
  :lint,
  :rubocop,
]

desc "Run syntax, lint and spec tests."
task :test => [
  :quick_test,
  :spec
]
