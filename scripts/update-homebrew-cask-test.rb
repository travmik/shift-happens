# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

SCRIPT = File.join(__dir__, 'update-homebrew-cask.rb')
OLD_HASH = 'a' * 64
NEW_HASH = 'b' * 64

def run_script(*args)
  system('ruby', SCRIPT, *args, out: File::NULL, err: File::NULL)
end

class UpdateHomebrewCaskTest < Minitest::Test
  def test_creates_cask_when_missing
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'Casks', 'shift-happens.rb')
      assert run_script(path, '0.1.0', OLD_HASH, 'travmik/shift-happens'),
             'script should exit 0'

      cask = File.read(path)
      assert_includes cask, 'cask "shift-happens"'
      assert_includes cask, 'version "0.1.0"'
      assert_includes cask, %Q{sha256 arm64: "#{OLD_HASH}"}
      assert_includes cask,
                      'url "https://github.com/travmik/shift-happens/releases/download/v0.1.0/ShiftHappens-v0.1.0-arm64.tar.gz"'
      assert_includes cask, 'app "ShiftHappens.app"'
      assert_includes cask, 'Grant Accessibility permission after installing'
    end
  end

  def test_updates_existing_cask
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'shift-happens.rb')
      assert run_script(path, '0.0.1', OLD_HASH, 'travmik/shift-happens')
      before = File.read(path)

      assert run_script(path, '0.2.0', NEW_HASH, 'travmik/shift-happens')
      after = File.read(path)

      assert_includes after, 'version "0.2.0"'
      refute_includes after, 'version "0.0.1"'
      assert_includes after, %Q{sha256 arm64: "#{NEW_HASH}"}
      assert_includes after, 'ShiftHappens-v0.2.0-arm64.tar.gz'
      refute_includes after, 'ShiftHappens-v0.0.1-arm64.tar.gz'
      # untouched lines
      assert_equal before.lines.grep(/app /), after.lines.grep(/app /)
      assert_equal before.lines.grep(/caveats/), after.lines.grep(/caveats/)
      assert_equal before.lines.grep(/Grant Accessibility/),
                   after.lines.grep(/Grant Accessibility/)
    end
  end

  def test_fails_on_unrelated_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'shift-happens.rb')
      File.write(path, "cask \"someotherapp\" do\n  version \"1.0\"\nend\n")

      refute run_script(path, '0.2.0', NEW_HASH, 'travmik/shift-happens'),
             'script should exit 1 on a foreign cask'
      assert_includes File.read(path), 'cask "someotherapp"',
                      'foreign cask file must not be modified'
    end
  end
end
