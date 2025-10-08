class MoshPlus < Formula
  desc "Mobile shell with experimental mouse forwarding"
  homepage "https://github.com/mosh-plus/mosh-plus"
  head "https://github.com/mosh-plus/mosh-plus.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "pkg-config" => :build
  depends_on "protobuf"
  depends_on "openssl@3"
  depends_on "readline"

  def install
    ENV.append "LDFLAGS", "-L#{Formula["openssl@3"].opt_lib}"
    ENV.append "CPPFLAGS", "-I#{Formula["openssl@3"].opt_include}"

    system "./autogen.sh"
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    assert_match "mosh", shell_output("#{bin}/mosh --help")
  end
end
