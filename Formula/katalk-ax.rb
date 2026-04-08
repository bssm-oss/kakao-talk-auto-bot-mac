class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.8/katalk-ax-cli.tar.gz"
  sha256 "7f9319d6e1fcfbf1d37e6ed3ced20e274fce425658e31bc8a1a1979b873db1b6"
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
