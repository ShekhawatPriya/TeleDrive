# The simulator must already run the isolated tools/ios_photo_viewer_preview.dart build.
# Usage: ruby scripts/test_ios_photo_viewer.rb <booted-simulator-uuid>
require 'xcodeproj'
require 'tmpdir'
require 'fileutils'

simulator = ARGV.fetch(0)
root = File.expand_path('..', __dir__)
FileUtils.mkdir_p(File.join(root, 'build'))
output = Dir.mktmpdir('native-photo-tests-', File.join(root, 'build'))
path = File.join(output, 'NativeQA.xcodeproj')
project = Xcodeproj::Project.new(path)
target = project.new_target(:ui_test_bundle, 'NativeQA', :ios, '16.0')
source = project.main_group.new_file(File.join(root, 'test/native/PhotoViewerUITests.swift'))
target.source_build_phase.add_file_reference(source)
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.sree.teledrive.nativeqa'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(path, 'NativeQA', true)
exec('xcodebuild', '-project', path, '-scheme', 'NativeQA', '-destination',
     "platform=iOS Simulator,id=#{simulator}", '-parallel-testing-enabled', 'NO',
     '-resultBundlePath', File.join(output, 'results.xcresult'), 'test')
