require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ReactNativeExif"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.4" }
  s.source       = { :git => "https://github.com/Pedrogabriel152/react-native-exif.git", :tag => "v#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,cpp}"

  s.dependency "React-Core"

  s.frameworks = "ImageIO"
  
  if s.respond_to?(:new_architecture_spec=)
    s.new_architecture_spec = true
  end
end
