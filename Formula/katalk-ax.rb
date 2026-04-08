class KatalkAx < Formula
  desc "KakaoTalk macOS 접근성 CLI 자동화 도구"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.7/katalk-ax-cli.tar.gz"
  sha256 "1ad97f9c178f11b2b9b56614f2f5c59c454196500ccfcc1d4196839715288e94"
  version "0.1.7"

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
