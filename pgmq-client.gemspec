# frozen_string_literal: true

require_relative "lib/pgmq_client/version"

Gem::Specification.new do |spec|
  spec.name = "pgmq-client"
  spec.version = PGMQ::VERSION
  spec.authors = ["Artur Roszczyk"]
  spec.email = ["sevos@sevos.io"]

  spec.summary = "Ruby client for PGMQ (PostgreSQL Message Queue)"
  spec.description = "A Ruby client library for PGMQ that provides both sync and async support using Ruby's Fiber Scheduler"
  spec.homepage = "https://github.com/sevos/pgmq-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "pg", "~> 1.5"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.5"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "async", "~> 2.0"
end
