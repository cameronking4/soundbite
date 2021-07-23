# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

def shared_pods
  use_frameworks!

  # Pods for SoundBite
  
  pod 'EZAudio'
  pod 'AACameraView', '~> 1.1'
  pod 'KYShutterButton'
  
end

target 'MessagesExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  
  shared_pods
  
end

target 'SoundBite' do
  # Comment the next line if you don't want to use dynamic frameworks
  
  shared_pods
  
  pod 'IQKeyboardManagerSwift'

end
