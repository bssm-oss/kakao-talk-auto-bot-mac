class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.1/katalk-ax-cli.tar.gz"
  sha256 "e9921d41996994ba7249b498976ff636e2975fa80204f1247441a0a1185f6be6"
  version "0.1.1"

  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install "katalk-ax"
    bin.install "katalk-ax-mcp"
  end

  test do
    output = shell_output("#{bin}/katalk-ax help")
    assert_match "katalk-ax - KakaoTalk macOS 접근성 CLI", output
  end
end
