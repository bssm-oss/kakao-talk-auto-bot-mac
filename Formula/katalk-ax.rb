class KatalkAx < Formula
  desc "KakaoTalk macOS Accessibility CLI automation tool"
  homepage "https://github.com/bssm-oss/kakao-talk-auto-bot-mac"
  url "https://github.com/bssm-oss/kakao-talk-auto-bot-mac/releases/download/v0.1.0/katalk-ax-cli.tar.gz"
  sha256 "d31ec0e554f34cbd9170c34033df03a92d1e042f34c0a59b95c6ceb9d17bd5a7"
  version "0.1.0"

  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install "katalk-ax"
    bin.install "katalk-ax-mcp"
  end

  test do
    output = shell_output("#{bin}/katalk-ax help")
    assert_match "katalk-ax - KakaoTalk macOS Accessibility CLI", output
  end
end
