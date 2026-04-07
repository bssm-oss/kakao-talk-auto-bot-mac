class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.4/katalk-ax-cli.tar.gz"
  sha256 "77ac9d26f9de5a0b8c2834deb3a7611409093793b553ef4855ec72afd029bdeb"
  version "0.1.4"

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
