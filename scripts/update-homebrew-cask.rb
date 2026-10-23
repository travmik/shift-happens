# frozen_string_literal: true

# Creates or updates the Homebrew cask for Shift Happens in the tap repo.
#
# Usage: ruby update-homebrew-cask.rb <cask-path> <version> <sha256> <repo-slug>
#
# - Missing file (or directory): created from the built-in template.
# - Existing cask: rewrites version, sha256 arm64:, and the url line.
#   Refuses (exit 1) to touch a file that is not our cask.

CASK_TOKEN = 'shift-happens'
APP_NAME = 'ShiftHappens.app'
ARTIFACT = 'ShiftHappens-v%<version>s-arm64.tar.gz'

CAVEAT = <<~CAVEAT_TEXT
  Grant Accessibility permission after installing:
  System Settings → Privacy & Security → Accessibility → ShiftHappens.app.

  First launch from Finder is blocked by Gatekeeper (the app is unsigned).
  To allow it: System Settings → Privacy & Security → "Open Anyway", or run
  `xattr -d com.apple.quarantine /Applications/ShiftHappens.app`.
  Both steps repeat after each update: the app is unsigned, so macOS ties
  the permission and the block to the exact build.
CAVEAT_TEXT

# Note: template lines start at column 0 so the generated cask body is
# indented correctly (the %<caveats>s placeholder line prevents <<~ from
# stripping anything).
TEMPLATE = <<~RUBY
cask "#{CASK_TOKEN}" do
  version "%<version>s"
  sha256 "%<sha256>s"

  url "https://github.com/%<slug>s/releases/download/v%<version>s/#{ARTIFACT}"
  name "Shift Happens"
  desc "Menu bar utility that fixes text typed in the wrong keyboard layout"
  homepage "https://github.com/%<slug>s"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "#{APP_NAME}"

  caveats <<~EOS
%<caveats>s  EOS
end
RUBY

def die(message)
  warn "error: #{message}"
  exit 1
end

if ARGV.length != 4
  die "usage: #{$PROGRAM_NAME} <cask-path> <version> <sha256> <repo-slug>"
end

cask_path, version, sha256, slug = ARGV
ctx = { version: version, sha256: sha256, slug: slug }

unless File.exist?(cask_path)
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(cask_path))
  indented_caveat = CAVEAT.lines.map { |line| "    #{line}" }.join.chomp
  File.write(cask_path, format(TEMPLATE, ctx.merge(caveats: "#{indented_caveat}\n")))
  warn "created #{cask_path} at version #{version}"
  exit 0
end

content = File.read(cask_path)
die "#{cask_path} is not the #{CASK_TOKEN} cask" unless content.include?("cask \"#{CASK_TOKEN}\"")

content.sub!(%r{version ".*"}, format('version "%s"', version))
content.sub!(%r{sha256 ".*"}, format('sha256 "%s"', sha256))
content.sub!(%r{url ".*"}, format('url "https://github.com/%s/releases/download/v%s/%s"',
                                  slug, version, format(ARTIFACT, version: version)))
File.write(cask_path, content)
warn "updated #{cask_path} to version #{version}"
