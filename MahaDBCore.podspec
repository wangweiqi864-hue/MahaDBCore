Pod::Spec.new do |s|
  s.name             = 'MahaDBCore'
  s.version          = '0.1.1'
  s.summary          = 'A lightweight SQLite wrapper and model layer used by the app.'

  s.description      = <<-DESC
MahaDBCore extracts the existing MHDBManager capability into a private pod.
It keeps the current SQLite wrapper behavior while exposing renamed public APIs.
  DESC

  s.homepage         = 'https://github.com/wangweiqi864-hue/MahaDBCore'
  s.license          = { :type => 'MIT' }
  s.author           = { 'wangweiqi864-hue' => 'wangweiqi864-hue@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/wangweiqi864-hue/MahaDBCore.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'MahaDBCore/Classes/**/*'
  s.dependency 'SQLite.swift', '~> 0.15.3'
  s.dependency 'HandyJSON', '~> 5.0.2'
  s.dependency 'MahaLogCore'
end
