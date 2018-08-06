# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)

require 'open_project/gitlab_integration/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-gitlab_integration"
  s.version     = OpenProject::GitlabIntegration::VERSION
  s.authors     = "Ensolab"
  s.email       = "arruah@gmail.com"
  s.homepage    = "https://github.com/arruah/openproject-gitlab_integration"
  s.summary     = 'OpenProject Gitlab Integration'
  s.description = ''
  s.license     = 'MIT' # e.g. "MIT" or "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)

  s.add_dependency 'rails', '~> 5.0.6'

  s.add_dependency "openproject-webhooks", "~> 7.4.7"
end
