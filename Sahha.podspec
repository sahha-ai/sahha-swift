Pod::Spec.new do |s|
  s.name             = 'Sahha'
  s.version          = '0.0.7'
  s.summary          = 'Sahha Swift SDK for iOS'
  s.homepage         = 'https://sahha.ai'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Sahha' => 'developer@sahha.ai' }
  s.source           = { :git => 'https://github.com/sahha-ai/sahha-swift.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/Sahha/**/*'
end
