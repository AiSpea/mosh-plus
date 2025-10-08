[![ci](https://github.com/mobile-shell/mosh/actions/workflows/ci.yml/badge.svg)](https://github.com/mobile-shell/mosh/actions/workflows/ci.yml)

Mosh: the mobile shell
======================

Mosh is a remote terminal application that supports intermittent
connectivity, allows roaming, and provides speculative local echo
and line editing of user keystrokes.

It aims to support the typical interactive uses of SSH, plus:

   * Mosh keeps the session alive if the client goes to sleep and
     wakes up later, or temporarily loses its Internet connection.

   * Mosh allows the client and server to "roam" and change IP
     addresses, while keeping the connection alive. Unlike SSH, Mosh
     can be used while switching between Wi-Fi networks or from Wi-Fi
     to cellular data to wired Ethernet.

   * The Mosh client runs a predictive model of the server's behavior
     in the background and tries to guess intelligently how each
     keystroke will affect the screen state. When it is confident in
     its predictions, it will show them to the user while waiting for
     confirmation from the server. Most typing and uses of the left-
     and right-arrow keys can be echoed immediately.

     As a result, Mosh is usable on high-latency links, e.g. on a
     cellular data connection or spotty Wi-Fi. In distinction from
     previous attempts at local echo modes in other protocols, Mosh
     works properly with full-screen applications such as emacs, vi,
     alpine, and irssi, and automatically recovers from occasional
     prediction errors within an RTT. On high-latency links, Mosh
     underlines its predictions while they are outstanding and removes
     the underline when they are confirmed by the server.

Mosh does not support X forwarding or the non-interactive uses of SSH,
including port forwarding.

Other features
--------------

   * Mosh adjusts its frame rate so as not to fill up network queues
     on slow links, so "Control-C" always works within an RTT to halt
     a runaway process.

   * Mosh warns the user when it has not heard from the server
     in a while.

   * Mosh supports lossy links that lose a significant fraction
     of their packets.

   * Mosh handles some Unicode edge cases better than SSH and existing
     terminal emulators by themselves, but requires a UTF-8
     environment to run.

   * Mosh leverages SSH to set up the connection and authenticate
     users. Mosh does not contain any privileged (root) code.

Getting Mosh
------------

  [The Mosh web site](https://mosh.org/#getting) has information about
  packages for many operating systems, as well as instructions for building
  from source.

Installing the mouse-enabled build from source
----------------------------------------------

  The mouse-forwarding functionality lives behind the normal Mosh build system
  and does not require any special configuration flags. To build from a fresh
  clone, install the standard build dependencies (see "Notes for developers"
  below) and then run:

  ```
  $ ./autogen.sh
  $ ./configure
  $ make
  $ sudo make install    # optional, installs into /usr/local by default
  ```

  These steps produce `mosh-client`, `mosh-server`, and the wrapper script with
  mouse support. You can also copy the `src/frontend/mosh-{client,server}`
  binaries out of the build tree if you prefer not to install system-wide.

Creating binary release artifacts
---------------------------------

  The repository now ships with an enhanced `scripts/package-release.sh`, which
  automates a reproducible out-of-tree install and collects the resulting
  binaries into a compressed tarball alongside a SHA-256 checksum. The script
  accepts optional `TARGET_OS`, `TARGET_ARCH`, and `PACKAGE_FORMATS`
  environment variables so you can create native bundles for Linux, macOS on
  Intel or Apple Silicon, or other supported hosts:

  ```
  $ TARGET_OS=linux TARGET_ARCH=arm64 PACKAGE_FORMATS=deb,rpm \
      scripts/package-release.sh
  $ ls build/release/artifacts
  mosh-plus-1.4.0-abcd123-linux-arm64.tar.gz
  mosh-plus-1.4.0-abcd123-linux-arm64.tar.gz.sha256
  mosh-plus_1.4.0-abcd123_arm64.deb
  mosh-plus-1.4.0-abcd123.aarch64.rpm
  ```

  The tarballs contain the `/usr/local` tree created by `make install`, so you
  can unpack them on a target system with root privileges to deploy the
  binaries:

  ```
  # tar -C /usr/local -xzf mosh-plus-1.4.0-abcd123-linux-arm64.tar.gz
  ```

  When `PACKAGE_FORMATS` includes `deb` or `rpm` the script uses
  [`fpm`](https://fpm.readthedocs.io/) to turn the staged install tree into
  packages consumable by `apt`/`dpkg` and `yum`/`dnf`. This makes it possible to
  ship native Linux packages alongside the compressed archives without
  maintaining separate packaging specs.

  For GitHub-hosted projects, publishing a release automatically triggers the
  `build-and-release` workflow under `.github/workflows/release.yml`. The job
  now builds on Ubuntu (amd64 and arm64) and macOS (Intel and Apple Silicon),
  installs the necessary build dependencies, invokes the packaging script with
  the appropriate environment, and uploads the tarballs, checksums, and native
  packages as release assets. You can also launch the workflow manually via the
  “Run workflow” button if you want fresh artifacts without cutting a tag.

Installing prebuilt packages
----------------------------

  Every release publishes ready-to-install bundles for the most common package
  managers. After downloading the asset that matches your platform, install it
  with the native tooling:

  * **Debian/Ubuntu (amd64 or arm64)**

    ```
    $ sudo apt install ./mosh-plus_1.4.0-abcd123_amd64.deb
    ```

  * **Fedora/RHEL/CentOS (x86_64 or aarch64)**

    ```
    $ sudo dnf install mosh-plus-1.4.0-abcd123.x86_64.rpm
    ```

    Replace `dnf` with `yum` on older distributions.

  * **macOS (Intel or Apple Silicon)**

    ```
    $ sudo tar -C /usr/local -xzf mosh-plus-1.4.0-abcd123-darwin-arm64.tar.gz
    ```

  Users who prefer to let Homebrew track the installation can tap the formula
  shipped with the repository:

  ```
  $ brew tap mosh-plus/tap https://github.com/mosh-plus/mosh-plus.git
  $ brew install mosh-plus
  ```

  The tap exposes the HEAD build by default so you can stay current between
  tagged releases. See `Formula/mosh-plus.rb` for the full formula definition.

  Note that `mosh-client` receives an AES session key as an environment
  variable.  If you are porting Mosh to a new operating system, please make
  sure that a running process's environment variables are not readable by other
  users.  We have confirmed that this is the case on GNU/Linux, OS X, and
  FreeBSD.

Usage
-----

  The `mosh-client` binary must exist on the user's machine, and the
  `mosh-server` binary on the remote host.

  The user runs:

    $ mosh [user@]host

  If the `mosh-client` or `mosh-server` binaries live outside the user's
  `$PATH`, `mosh` accepts the arguments `--client=PATH` and `--server=PATH` to
  select alternate locations. More options are documented in the mosh(1) manual
  page.

  Mouse input forwarding is disabled by default to preserve compatibility.
  When both the local client and remote server are running this fork, pass the
  `--enable-mouse` option to `mosh` to activate experimental forwarding of
  scroll, click, and movement events:

  ```
  $ mosh --enable-mouse [user@]host
  ```

  The wrapper will ensure that the flag propagates to both the client and
  server binaries. Applications such as `vim`, `htop`, and `less` can then
  receive translated xterm mouse sequences over the PTY.

  There are [more examples](https://mosh.org/#usage) and a
  [FAQ](https://mosh.org/#faq) on the Mosh web site.

How it works
------------

  The `mosh` program will SSH to `user@host` to establish the connection.
  SSH may prompt the user for a password or use public-key
  authentication to log in.

  From this point, `mosh` runs the `mosh-server` process (as the user)
  on the server machine. The server process listens on a high UDP port
  and sends its port number and an AES-128 secret key back to the
  client over SSH. The SSH connection is then shut down and the
  terminal session begins over UDP.

  If the client changes IP addresses, the server will begin sending
  to the client on the new IP address within a few seconds.

  To function, Mosh requires UDP datagrams to be passed between client
  and server. By default, `mosh` uses a port number between 60000 and
  61000, but the user can select a particular port with the -p option.
  Please note that the -p option has no effect on the port used by SSH.

Advice to distributors
----------------------

A note on compiler flags: Mosh is security-sensitive code. When making
automated builds for a binary package, we recommend passing the option
`--enable-compile-warnings=error` to `./configure`. On GNU/Linux with
`g++` or `clang++`, the package should compile cleanly with
`-Werror`. Please report a bug if it doesn't.

Where available, Mosh builds with a variety of binary hardening flags
such as `-fstack-protector-all`, `-D_FORTIFY_SOURCE=2`, etc.  These
provide proactive security against the possibility of a memory
corruption bug in Mosh or one of the libraries it uses.  For a full
list of flags, search for `HARDEN` in `configure.ac`.  The `configure`
script detects which flags are supported by your compiler, and enables
them automatically.  To disable this detection, pass
`--disable-hardening` to `./configure`.  Please report a bug if you
have trouble with the default settings; we would like as many users as
possible to be running a configuration as secure as possible.

Mosh ships with a default optimization setting of `-O2`. Some
distributors have asked about changing this to `-Os` (which causes a
compiler to prefer space optimizations to time optimizations). We have
benchmarked with the included `src/examples/benchmark` program to test
this. The results are that `-O2` is 40% faster than `-Os` with g++ 4.6
on GNU/Linux, and 16% faster than `-Os` with clang++ 3.1 on Mac OS
X. In both cases, `-Os` did produce a smaller binary (by up to 40%,
saving almost 200 kilobytes on disk). While Mosh is not especially CPU
intensive and mostly sits idle when the user is not typing, we think
the results suggest that `-O2` (the default) is preferable.

Our Debian and Fedora packaging presents Mosh as a single package.
Mosh has a Perl dependency that is only required for client use.  For
some platforms, it may make sense to have separate mosh-server and
mosh-client packages to allow mosh-server usage without Perl.

Notes for developers
--------------------

To start contributing to Mosh, install the following dependencies:

Debian, Windows Subsystem for Linux:

```
$ sudo apt install -y build-essential protobuf-compiler \
    libprotobuf-dev pkg-config libutempter-dev zlib1g-dev libncurses5-dev \
    libssl-dev bash-completion tmux less
```

MacOS:

```
$ brew install autoconf automake libtool pkg-config protobuf
```

Once you have forked the repository, run the following to build and test Mosh:

```
$ ./autogen.sh
$ ./configure
$ make
$ make check
```

Mosh supports producing code coverage reports by tests, but this feature is
disabled by default. To enable it, make sure `lcov` is installed on your
system. Then, configure and run tests:

```
$ ./configure --enable-code-coverage
$ make check-code-coverage
```

This will run all tests and produce a coverage report in HTML form that can be
opened with your favorite browser. Ideally, newly added code should strive for
90% (or better) incremental test coverage.

More info
---------

  * Mosh Web site:

    <https://mosh.org>

  * `mosh-devel@mit.edu` mailing list:

    <https://mailman.mit.edu/mailman/listinfo/mosh-devel>

  * `mosh-users@mit.edu` mailing list:

    <https://mailman.mit.edu/mailman/listinfo/mosh-users>

  * `#mosh` channel on [Libera Chat](https://libera.chat/)

    https://web.libera.chat/#mosh
