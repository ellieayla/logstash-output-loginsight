Gem::Specification.new do |s|
  s.name          = 'logstash-output-loginsight'
  s.version       = '0.1.13'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Output events to a Log Insight server. This uses the Ingestion API protocol.'
  s.description   = 'This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install logstash-output-loginsight. This gem is not a stand-alone program.'
  s.homepage      = 'https://github.com/alanjcastonguay/logstash-output-loginsight'
  s.authors       = ['Alan Castonguay']
  s.email         = 'acastonguay@vmware.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency "manticore", "~> 0.6", ">= 0.6.0"

  s.add_development_dependency "logstash-devutils", "~> 0", ">= 1.3.1"
end
