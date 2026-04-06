cask "katalk-ax-menu-bar" do
  version :latest
  sha256 :no_check

  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/latest/download/katalk-ax.dmg"
  name "katalk-ax"
  desc "Native AppKit menu bar app for KakaoTalk Accessibility automation"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"

  depends_on arch: :arm64

  app "katalk-ax.app"
  binary "katalk-ax.app/Contents/MacOS/katalk-ax-menu-bar", target: "katalk-ax-menu-bar"

  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/katalk-ax.app"]
  end
end
