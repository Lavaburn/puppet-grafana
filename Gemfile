source "https://rubygems.org"

group :test do
	gem "puppet", ENV['PUPPET_VERSION'] || '~> 4.3.2'
	gem "puppetlabs_spec_helper"
	
	gem "metadata-json-lint"
	gem "toml"
	
	if RUBY_VERSION < '2.2.0'	
		gem "rubocop-rspec", '1.5.0'
	else 
		gem "rubocop-rspec" # rubocop:disable Bundler/DuplicatedGem
	end
	
	if RUBY_VERSION < '2.0.0'	
		gem "parallel_tests", '~> 2.9.0'
	else 
		gem "parallel_tests" # rubocop:disable Bundler/DuplicatedGem
	end
	
	# Version pinning for older Ruby versions
	gem "rubocop", '~> 0.41.0' if RUBY_VERSION < '2.0.0'
end

group :integration_test do
	gem 'beaker-rspec'
	gem "vagrant-wrapper"

	gem 'beaker-puppet_install_helper'
		
	# Version pinning for older Ruby versions
	gem 'beaker', '~> 2.52' if RUBY_VERSION < '2.2.5'
	gem "nokogiri", '~> 1.6.8' if RUBY_VERSION < '2.2.2'
end

group :development do
	gem "travis"
	gem "travis-lint"
	
	gem "puppet-blacksmith"
	
	gem "guard-rake" if RUBY_VERSION >= '2.2.5'
end
