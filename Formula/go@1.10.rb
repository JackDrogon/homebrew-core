class GoAT110 < Formula
  desc "Go programming environment (1.10)"
  homepage "https://golang.org"
  url "https://dl.google.com/go/go1.10.8.src.tar.gz"
  mirror "https://fossies.org/linux/misc/go1.10.8.src.tar.gz"
  sha256 "6faf74046b5e24c2c0b46e78571cca4d65e1b89819da1089e53ea57539c63491"

  bottle do
    sha256 "caab06b2e576c27f57b70bcb9aee3e57ad47db8c54049e6fe497c0a41f93688b" => :mojave
    sha256 "a40ac4e44fb57800b9c55927a3a6be7174d14124ea9fd3966b9f1ad6efe8ea31" => :high_sierra
    sha256 "ac5994b638f96d001d45e26c40844384e11201b5830bef9aaa28d683103b6006" => :sierra
  end

  keg_only :versioned_formula

  resource "gotools" do
    url "https://go.googlesource.com/tools.git",
        :branch => "release-branch.go1.10"
  end

  # Don't update this unless this version cannot bootstrap the new version.
  resource "gobootstrap" do
    url "https://storage.googleapis.com/golang/go1.7.darwin-amd64.tar.gz"
    version "1.7"
    sha256 "51d905e0b43b3d0ed41aaf23e19001ab4bc3f96c3ca134b48f7892485fc52961"
  end

  # Prevents Go from building malformed binaries. Fixed upstream, should
  # be in a future release.
  # https://github.com/golang/go/issues/32673
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/b8d26872202f4efc9797a51265b868f7ebc0d03a/go%401.10/dwarf_segments.patch"
    sha256 "7bdf34196f5e8f7de705670e6199cf7dc22835f9a188af3e319aed60f7398ff6"
  end

  def install
    (buildpath/"gobootstrap").install resource("gobootstrap")
    ENV["GOROOT_BOOTSTRAP"] = buildpath/"gobootstrap"

    cd "go/src" do
      ENV["GOROOT_FINAL"] = libexec
      ENV["GOOS"]         = "darwin"
      system "./make.bash", "--no-clean"
    end

    (buildpath/"go/pkg/obj").rmtree
    rm_rf "gobootstrap" # Bootstrap not required beyond compile.
    libexec.install Dir["*"]
    bin.install_symlink Dir[libexec/"go/bin/go*"]

    system bin/"go", "install", "-race", "std"

    # Build and install godoc
    ENV.prepend_path "PATH", bin
    ENV["GOPATH"] = buildpath/"go"
    (buildpath/"go/src/golang.org/x/tools").install resource("gotools")
    cd "go/src/golang.org/x/tools/cmd/godoc/" do
      system "go", "build"
      (libexec/"bin").install "godoc"
    end
    bin.install_symlink libexec/"bin/godoc"
  end

  test do
    (testpath/"hello.go").write <<~EOS
      package main

      import "fmt"

      func main() {
          fmt.Println("Hello World")
      }
    EOS
    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system bin/"go", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")

    # godoc was installed
    assert_predicate libexec/"bin/godoc", :exist?
    assert_predicate libexec/"bin/godoc", :executable?

    ENV["GOOS"] = "freebsd"
    system bin/"go", "build", "hello.go"
  end
end
