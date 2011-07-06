Description
===========

Fig is a utility for configuring environments and managing dependencies across a team of developers. Fig takes a list of packages and a shell command to run, creates an environment that includes those packages, then executes the shell command in that environment. The caller's environment is not affected. 

An "environment" in fig is just a set of environment variables. A "package" is a collection of files, plus some metadata describing what environment variables should be modified when the package is included. 

Developers can use package files to specify the list of dependencies to use for different tasks. This file will typically be versioned along with the rest of the source files, ensuring that all developers on a team are using the same environemnts. 

Packages exist in two places: a "local" repository in the user's home directory, and a "remote" repository on a shared server. Fig will automatically download packages from the remote repository and install them in the local repository as needed. 

Fig is similar to a lot of other package/dependency managment tools. In particular, it steals a lot of ideas from Apache Ivy and Debian APT. However, unlike Ivy, fig is meant to be lightweight (no XML, no JVM startup time), language agnostic (Java doesn't get preferential treatment), and work with executables as well as libraries. And unlike APT, fig is cross platform and project-oriented.

Installation
============

Fig can be installed via rubygems. The gems are hosted at [Gemcutter](http://gemcutter.org), so you'll need to set that up first:

    $ gem install gemcutter
    $ gem tumble

Fig also depends on a third-party library named
[libarchive](http://libarchive.rubyforge.org/). Libarchive is easily available
via most package management systems on Linux, FreeBSD, and OS X.  Libarchive
versions greater than 2.6.0 are preferred.  If you are on Windows (not Cygwin Ruby), the gem will
install the libarchive binaries for you.

    [Linux - Debian / Ubuntu]
    apt-get libarchive-dev

    [Linux - Red Hat / CentOS]
    yum install libarchive-devel

    [OS X - MacPorts]
    port install libarchive

Then you can install fig:

     $ gem install fig

Usage
=====

Fig recognizes the following options (not all are implemented yet):

### Flags ###

    -d, --debug              Print debug info
        --force              Download/install packages from remote repository, even if up-to-date
    -u, --update             Download/install packages from remote repository, if out-of-date
    -m, --update-if-missing  Download/install packages from remote repository, if not already installed
    -l, --login              Authenticate with remote server using username/password (default is anonymous)

If the `--login` option is supplied, fig will look for credentials.  If
environment variables `FIG_REMOTE_USER` and/or `FIG_REMOTE_PASSWORD` are
defined, fig will use them instead of prompting the user.  If ~/.netrc exists,
with an entry corresponding to the host parsed from `FIG_REMOTE_URL`, that
entry will take precedence over `FIG_REMOTE_USER` and `FIG_REMOTE_PASSWORD`.
If sufficient credentials are still not found, fig will prompt for whatever is
still missing, and use the accumulated credentials to authenticate against the
remote server.  Even if both environment variables are defined, fig will only
use them if `--login` is given.

### Environment Modifiers ###

The following otpions modify the environment generated by fig:

    -i, --include DESCRIPTOR  Include package in environment (recursive)
    -p, --append  VAR=VALUE   Append value to environment variable using platform-specific separator
    -s, --set     VAR=VALUE   Set environment variable

### Environment Commands ###

The following commands will be run in the environment created by fig:

    -g, --get VARIABLE    Get value of environment variable
    -- COMMAND [ARGS...]  Execute arbitrary shell command

### Other Commands ###

Fig also supports the following options, which don't require a fig environment. Any modifiers will be ignored:

    -?, -h, --help   Display this help text
    --publish        Upload package to the remote repository (also installs in local repository)
    --publish-local  Install package in local repository only
    --list           List packages in local repository   
    --list-remote    List packages in remote repository

When using the `--list-remote` command against an FTP server, fig uses a pool of FTP sessions to improve
performance. By default it opens 16 connections, but that number can be overridden by setting the
`FIG_FTP_THREADS` environment variable.

Examples
========

Fig lets you configure environments three different ways:

* From the command line
* From a "package.fig" file in the current directory
* From packages included indirectly via one of the previous two methods

### Command Line ###

So to get started, let's trying defining an environment variable via the command line and executing a command in the newenvironment. We'll set the "GREETING" variable to "Hello", then run a command that uses that variable:

    $ fig -s GREETING=Hello -- echo "\$GREETING, World"
    Hello, World

Note that you need to put a slash before the dollar sign, otherwise the shell will evaluate the environment variable before it ever gets to fig.

Also note that when running fig, the original environment isn't affected:

     $ echo $GREETING
     <nothing>

Fig also lets you append environment variables, using the system-specified path separator (e.g. colon on unix, semicolon on windows). This is useful for adding directories to the PATH, LD_LIBRARY_PATH, CLASSPATH, etc. For example, let's create a "bin" directory, add a shell script to it, then include it in the PATH:

    $ mkdir bin
    $ echo "echo \$GREETING, World" > bin/hello
    $ chmod +x bin/hello
    $ fig -s GREETING=Hello -p PATH=bin -- hello
    Hello, World

### Fig Files ###

You can also specify environment modifiers in files. Fig looks for a file called "package.fig" in the current directory, and automatically processes it. So we can implement the previous example by creating a "package.fig" file that looks like:
        
    config default
      set GREETING=Hello
      append PATH=@/bin
    end
    
The '@' symbol represents the directory that the "package.fig" file is in (this example would still work if we just used "bin", but later on when we publish our project to the shared repository we'll definitely need the '@'). Then we can just run:

    $ fig -- hello
    Hello, World

A single fig file can have multiple configurations:

    config default 
      set GREETING=Hello
      append PATH=@/bin
    end

    config french
      set GREETING=Bonjour
      append PATH=@/bin
    end

Configurations other than "default" can be specified using the "-c" option:

    $ fig -c french -- hello
    Bonjour, World
     
### Packages ###

Now let's say we want to share our little script with the rest of the team by bundling it into a package. The first thing we need to do is specify the location of the remote repository by defining the `FIG_REMOTE_URL` environment variable. If you just want to play around with fig, you can have it point to localhost:

    $ export FIG_REMOTE_URL=ssh://localhost\`pwd\`/remote

Before we publish our package, we'll need to tell fig which files we want to include. We do this by using the "resource" statement in our "package.fig" file:

    resource bin/hello

    config default...

Now we can share the package with the rest of the team by using the "--publish" option:

    $ fig --publish hello/1.0.0

The "hello/1.0.0" string represents the name of the package and the version number. Once the package has been published, we can include it in other environments by using the "-i" or "--include" option (I'm going to move the "package.fig" file out of the way first, so that fig doesn't automatically process it.):

    $ mv package.fig package.bak
    $ fig -u -i hello/1.0.0 -- hello
    ...downloading files...
    Hello, World
		
The "-u" (or "--update") option tells fig to check the remote repository for packages if they aren't already installed locally (fig will never make any network connections unless this option is specified). Once the packages are downloaded, we can run the same command without the "-u" option:

    $ fig -i hello/1.0.0 -- hello
    Hello, World

Also, when including a package, you can specify a particular configuration by appending it to the package name using a colon:

    $ fig -i hello/1.0.0:french -- hello
    Bonjour, World

### Retrieves ###

By default, the resources associated with a package live in the fig home directory, which defaults to "~/.fighome". This doesn't always play nicely with IDE's however, so fig gives you a way to copy resources from the repository to the current directory. To do this you add "retrieve" statements to your "package.fig" file.

For example, let's create a package that contains a library for the "foo" programming language. First we'll define a "package.fig" file:

    config default
      append FOOPATH=lib/hello.foo
    end

Then:

    $ mkdir lib
    $ echo "print 'hello'" > lib/hello.foo
    $ fig --publish hello-lib/3.2.1    

Now we'll move to a different directory (or delete the current "package.fig" file) and create a new "package.fig" file:

    retrieve FOOPATH->lib/[package]
    config default
      include hello-lib/3.2.1
    end

When we do an update, all resources in the FOOPATH will be copied into the lib directory, into a subdirectory that matches the package name:

     $ fig -u
     ...downloading...
     ...retrieving...
     $ cat lib/hello-lib/hello.foo
     print 'hello'

Community
=========

\#fig on irc.freenode.net

[Fig Mailing List](http://groups.google.com/group/fig-user)

Copyright
=========

Copyright (c) 2009 Matthew Foemmel. See LICENSE for details.
