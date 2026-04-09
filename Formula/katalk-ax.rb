class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.9/katalk-ax-cli.tar.gz"
  sha256 "c8be2a597fdf8261de8ae22f1f5495e65516bac97d3d2827340a65dda2f575c7"
  version "0.1.9"

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
