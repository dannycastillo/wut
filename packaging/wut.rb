class Wut < Formula
  desc "Search your own command-line notes and copy the result"
  homepage "https://github.com/dannycastillo/wut"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/dannycastillo/wut/releases/download/v0.1.0/wut_0.1.0_darwin_arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/dannycastillo/wut/releases/download/v0.1.0/wut_0.1.0_darwin_amd64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dannycastillo/wut/releases/download/v0.1.0/wut_0.1.0_linux_arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/dannycastillo/wut/releases/download/v0.1.0/wut_0.1.0_linux_amd64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    bin.install "wut"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wut --version")
  end
end
