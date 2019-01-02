git-lfs
=======

NARF
LSST stores large files using [git-lfs](https://git-lfs.github.com/). To use a
git repo like which uses git-lfs you must install git-lfs and configure it.
LSST runs their own git-lfs server and storage service. Git and git-lfs must
configured to use our server.

Add this to your git configuration. Typically `~/.gitconfig` or the
repository's `.git/config` file.

```git
[lfs]
url = "https://git-lfs.lsst.codes"
```

There is **no password required** for cloning or pulling from LSST's git-lfs
server or s3 service. But it is recommended that you use a [credential
helper](https://help.github.com/articles/caching-your-github-password-in-git/)
to avoid being prompted for a username and password repeatedly.

If you are a member of the github lsst organization then you may push using
git-lfs. To push you should login using your github username and password to
the git-lfs server (git-lfs.lsst.codes).

Setup
-----

### Mac OS X

```bash
brew install git-lfs
git-lfs init
git config --global credential.helper osxkeychain # A credential helper is highly recommended.
git config --global lfs.url 'https://git-lfs.lsst.codes'
git clone ...
```

This will install git-lfs, initialize it, configure the osxkeychain credential
helper and configure the LSST git-lfs server.

```bash
Username for 'https://git-lfs.lsst.codes': <Github Username OR Blank>
Password for 'https://<git>@git-lfs.lsst.codes': <Github password OR Blank>
```

If you are only interested in cloning or pulling, login and password may be
left blank.

If you are a member of the LSST Github organization then you can use your
Github username and password to push to the git-lfs server.

```bash
Username for 'https://s3.lsst.codes': <Empty>
Password for 'https://s3.lsst.codes': <Empty>
```

There is no username or password for the LSST's S3 service.

### Linux

[Download and install](https://github.com/github/git-lfs/releases/tag/v1.0.0)
the current git-lfs.

```bash
git-lfs init
git config --global credential.helper cache
```

A credential helper is highly recommended.

```bash
git config --global lfs.url 'https://git-lfs.lsst.codes'
```

At this point git-lfs is installed and initialized, and credential helper is
configured.

```bash
Username for 'https://git-lfs.lsst.codes': <Github Username OR Blank>
Password for 'https://<git>@git-lfs.lsst.codes': <Github password OR Blank>
```

If you are only interested in cloning or pulling, login and password may be
left blank.

If you are a member of the LSST Github organization then you can use your
Github username and password to push to the git-lfs server.

```bash
Username for 'https://s3.lsst.codes': <Empty>
Password for 'https://s3.lsst.codes': <Empty>
```

There is no username or password for the LSST's S3 service.

Credential Helpers
------------------

Github has excellent documentation on configuring [credential helpers](https://help.github.com/articles/caching-your-github-password-in-git/).

If you do not use a credential helper, git-lfs will repeatedly ask for your
username and password. This can be very frustrating. To avoid globally
installing a credential helper use git's cache credential helper. By default,
it will work for 15 minutes before expiring.

```git
git config credential.helper cache
```
