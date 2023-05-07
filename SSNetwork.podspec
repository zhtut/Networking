
Pod::Spec.new do |s| 

  s.name         = "SSNetwork"
  s.version      = "1.0.1"
  s.summary      = " 网络工具库 "

  s.description  = <<-DESC
    网络工具库 
                   DESC

  s.homepage     = "https://github.com/zhtut/SSNetwork.git"

  s.license        = { :type => 'MIT', :file => 'LICENSE' }

  s.author             = { "zhtg" => "zhtg@icloud.com" }

  s.source       = { :git => "https://github.com/zhtut/SSNetwork.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = '10.12'

  s.source_files  = "Sources/**/*.swift"
  s.swift_version = "5.0"

  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'ENABLE_MODULE_VERIFIER' => 'YES' }

end
