require "json"

package = JSON.parse(File.read(File.join(__dir__, "..", "package.json")))

Pod::Spec.new do |s|
  s.name = "MatchPointLocalAI"
  s.version = package["version"]
  s.summary = "On-device AI bridge for MatchPoint Tennis"
  s.description = "Conditional bridge to Apple Foundation Models."
  s.license = "MIT"
  s.author = "MatchPoint Tennis"
  s.homepage = "https://matchpointclubs.app"
  s.platforms = { :ios => "15.1" }
  s.swift_version = "5.9"
  s.source = { :path => "." }
  s.static_framework = true
  s.source_files = "**/*.swift"
  s.dependency "ExpoModulesCore"
end
