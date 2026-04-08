class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.8/katalk-ax-cli.tar.gz"
  sha256 "096f729016ebd26faeb7c79c47b1f0df5f999e6ad53e5ca994b08e148de44d75"
  version "0.1.8"

  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install "kabot"
    bin.install "katalk-ax"
    bin.install "katalk-ax-mcp"
  end

  test do
    output = shell_output("#{bin}/katalk-ax help")
    assert_match "katalk-ax - KakaoTalk macOS 접근성 CLI", output
  end
end
