#!/usr/bin/env ruby
# Adds the QingWuTests unit test target to QingWu.xcodeproj.
#
# Idempotent: re-runs are no-ops once the target exists. Run once after pulling
# new test source files, or commit the resulting pbxproj diff.
#
# Usage:
#   gem install xcodeproj   # if not already installed
#   ruby scripts/add_tests_target.rb
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../QingWu.xcodeproj', __dir__)
PROJECT_ROOT = File.expand_path('..', __dir__)
TESTS_DIR    = 'QingWuTests'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == 'QingWuTests' }
  puts "Target QingWuTests already exists, skipping."
  exit 0
end

host_target = project.targets.find { |t| t.name == 'QingWu' }
abort "QingWu host target not found" unless host_target

# --- Create unit test target ---
test_target = project.new_target(:unit_test_bundle, 'QingWuTests', :osx, '11.5')

project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][test_target.uuid] = {
  'CreatedOnToolsVersion' => '16.0',
  'TestTargetID'          => host_target.uuid,
}

test_target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']    = 'com.qingwu.app.tests'
  s['PRODUCT_NAME']                 = '$(TARGET_NAME)'
  s['SWIFT_VERSION']                = '6.0'
  s['MACOSX_DEPLOYMENT_TARGET']     = '11.5'
  s['INFOPLIST_FILE']               = 'QingWuTests/Info.plist'
  s['BUNDLE_LOADER']                = '$(TEST_HOST)'
  s['TEST_HOST']                    = '$(BUILT_PRODUCTS_DIR)/QingWu.app/Contents/MacOS/QingWu'
  s['LD_RUNPATH_SEARCH_PATHS']      = ['$(inherited)', '@executable_path/../Frameworks', '@loader_path/../Frameworks']
  s['CODE_SIGN_STYLE']              = 'Automatic'
  s['DEVELOPMENT_TEAM']             = '5EH69Y5X38'
  s['ENABLE_TESTING_SEARCH_PATHS']  = 'YES'
end

# --- File references ---
main_group  = project.main_group
tests_group = main_group.new_group('QingWuTests', TESTS_DIR)

def add_file(group, project_root, rel_path)
  ref = group.new_reference(File.join(project_root, rel_path))
  ref.path = rel_path
  ref.source_tree = 'SOURCE_ROOT'
  ref
end

test_sources = Dir.glob(File.join(PROJECT_ROOT, TESTS_DIR, '*.swift')).map { |abs|
  File.join(TESTS_DIR, File.basename(abs))
}.sort

test_sources.each do |rel_path|
  ref = add_file(tests_group, PROJECT_ROOT, rel_path)
  test_target.source_build_phase.add_file_reference(ref)
end

# Info.plist is referenced via INFOPLIST_FILE; only add as a file reference, not in any build phase.
add_file(tests_group, PROJECT_ROOT, File.join(TESTS_DIR, 'Info.plist'))

# --- Host target dependency ---
test_target.add_dependency(host_target)

# --- Wire the unit test target into the QingWu scheme so `xcodebuild test`
# against the existing `QingWu` scheme picks it up without users having to
# also wire a separate scheme. ---
shared_data_dir = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes')
scheme_path = File.join(shared_data_dir, 'QingWu.xcscheme')

if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path)
  test_action = scheme.test_action
  already_wired = test_action.testables.any? { |t|
    t.buildable_references.any? { |br| br.target_name == 'QingWuTests' }
  }
  unless already_wired
    testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
    test_action.add_testable(testable)
    scheme.save_as(PROJECT_PATH, 'QingWu')
    puts "Wired QingWuTests into QingWu.xcscheme."
  end
else
  puts "WARNING: QingWu.xcscheme not found at #{scheme_path}. Skipping scheme wiring; create a Tests scheme manually."
end

project.save
puts "Done. QingWuTests target added with #{test_sources.size} source file(s)."
puts "Run: xcodebuild test -project QingWu.xcodeproj -scheme QingWu -destination 'platform=macOS'"
