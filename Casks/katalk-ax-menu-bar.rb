cask "katalk-ax-menu-bar" do
  version :latest
  sha256 :no_check

  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/latest/download/katalk-ax.dmg"
  name "katalk-ax"
  desc "Native AppKit menu bar app for KakaoTalk Accessibility automation"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"

  app "katalk-ax.app"
  binary "katalk-ax.app/Contents/MacOS/katalk-ax-menu-bar", target: "katalk-ax-menu-bar"
end
