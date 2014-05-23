# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'sequel-rake-tasks'
  gem.version       = '0.0.2'
  gem.authors       = ['Myles Megyesi', 'Steve Kim']
  gem.email         = ['myles.megyesi@gmail.com', 'skim.la@gmail.com']
  gem.description   = 'Rake tasks for Sequel'
  gem.summary       = 'Rake tasks for Sequel'

  gem.files         = Dir['lib/**/*.rb']
  gem.require_paths = ['lib']

  gem.add_runtime_dependency     'rake',   '~> 10.1.0'
  gem.add_runtime_dependency     'sequel', '~> 4.2'
  gem.add_development_dependency 'rake',   '~> 10.1.0'
end
