
Pod::Spec.new do |s| 

  s.name         = "NetCore"
  s.version      = "1.0.7"
  s.summary      = " ios的网络工具库，使用combine框架作为回调 "

  s.description  = <<-DESC
    ios的网络工具库，使用combine框架作为回调
                   DESC

  s.homepage     = "https://github.com/zhtut/NetCore.git"

  s.license        = { :type => 'MIT', :file => 'LICENSE' }

  s.author             = { "zhtg" => "zhtg@icloud.com" }

  s.source       = { :git => "https://github.com/zhtut/NetCore.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "14.0"
  s.osx.deployment_target = '12.0'

  s.source_files  = "Sources/**/*.swift"
  s.swift_version = "5.0"

  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'ENABLE_MODULE_VERIFIER' => 'YES' }

end
