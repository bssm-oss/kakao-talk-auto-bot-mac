class KatalkAx < Formula
  desc "KakaoTalk macOS Accessibility CLI automation tool"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  head "https://github.com/bssm-oss/kakao-talk-auto-bot-mac.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--product", "katalk-ax"
    system "swift", "build", "-c", "release", "--product", "katalk-ax-mcp"
    bin.install ".build/release/katalk-ax"
    bin.install ".build/release/katalk-ax-mcp"
  end

  test do
    output = shell_output("#{bin}/katalk-ax help")
    assert_match "katalk-ax - KakaoTalk macOS Accessibility CLI", output
  end
end
