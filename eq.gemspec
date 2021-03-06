# -*- encoding: utf-8 -*-
require File.expand_path('../lib/eq/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jens Bissinger"]
  gem.email         = ["mail@jens-bissinger.de"]
  gem.description   = %q{Embedded Queueing. Background processing within a single process using multi-threading and a SQL database.}
  gem.summary       = %q{Based on Celluloid (multi-threading) and Sequel (SQLite3, MySQL, PostgreSQL, ...).}
  gem.homepage      = "https://github.com/dpree/eq"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "eq"
  gem.require_paths = ["lib"]
  gem.version       = EQ::VERSION

  gem.add_dependency "celluloid"

  # just to test the web view
  gem.add_development_dependency "sinatra"

  # just to test the scheduling  
  gem.add_development_dependency "clockwork"

  # just to test the queueing backends
  gem.add_development_dependency "sequel"       # sequel backend
  gem.add_development_dependency "sqlite3"      # sequel with sqlite
  gem.add_development_dependency "leveldb-ruby" # leveldb backend

  gem.add_development_dependency "guard"
  gem.add_development_dependency "guard-rspec"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "timecop"
end
