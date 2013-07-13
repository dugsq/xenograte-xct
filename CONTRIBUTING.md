# CONTRIBUTING

The xenograte-xct project welcomes new contributors. This document will guide you through the process.


### FORK THE PROJECT

[Fork](https://help.github.com/articles/fork-a-repo) the project on the [GitHub repository](https://github.com/nodally/xenograte-xct) and check out
your copy.

```
$ git clone git@github.com:username/xenograte-xct.git
$ cd xenograte-xct
$ git remote add upstream git@github.com:Nodally/xenograte-xct.git
```

Most of the features/bug fixes should be applied to the development branch. The master branch is "stable" 
branch and therefore only bug fixes should be applied to the master branch which is basically **frozen**.

Bundled dependencies listed in the Gemfile are not part of the project so any changes to those projects 
should be sent the respective project owners as we can not accept those changes.

We invite you to follow the development and community updates on Xenograte so if you have any questions, 
concerns, ideas, or just need help: 
- Go to the [Xenograte Community][23] linkedin group.
- Follow [@nodally][21] on Twitter.
- Read and subscribe to the [Nodally Blog][22].

[21]: http://twitter.com/nodally
[22]: http://blog.nodally.com
[23]: http://www.linkedin.com/groups/Xenograte-Community-5068501

The Command-line Interface and instancing components are written in such a way that they will provide 
worker compatibilty with the Xenograte Cloud Edition.

Patches and bug fixes are welcome to these tools but keep in mind that in order for you to use your 
workers on that system we will need to maintain compatibility through these tools. 


### BRANCH

Having decided on the right branch. Create a feature branch and start hacking:

```
$ git checkout -b my-new-feature -t origin/master
```

### COMMIT

Make sure git knows your name and email address:

```
$ git config --global user.name "A. Person"
$ git config --global user.email "a.person@example.com"
```

Writing good commit logs is important. A commit log should describe what changed and why. Follow these 
guidelines when writing one:

1. The first line should contain a short (50 characters or less) 
   description of the change prefixed with the name of the changed
   subsystem (e.g. "file-watcher: add duplicate file window timing").
2. Keep the second line blank.
3. Wrap all other lines at 72 columns.

A good commit log looks like this:

```
subsystem: explaining the commit in one line

Body of commit message is a few lines of text, explaining things
in more detail, possibly giving some background about the issue
being fixed, etc etc.

The body of the commit message can be several paragraphs, and
please do proper word-wrap and keep columns shorter than about
72 characters or so. That way `git log` will show things
nicely even when it is indented.
```

The header line should be meaningful; it is what other people see when they
run `git shortlog` or `git log --oneline`.

Check the output of `git log --oneline files_that_you_changed` to find out
what subsystem (or subsystems) your changes touch.


### REBASE

Use `git rebase` (not `git merge`) to sync your work from time to time.

```
$ git fetch upstream
$ git rebase upstream/master
```


### TEST

Bug fixes and features should come with tests.  Add your tests in the
test/simple/ directory.  Look at other tests to see how they should be
structured (license boilerplate, common includes, etc.).


### PUSH

```
$ git push origin/master my-new-feature
```

Go to https://github.com/username/node and select your feature branch.  Click
the 'Pull Request' button.

Pull requests are usually reviewed within a few days.  If there are comments
to address, apply your changes in a separate commit and push that to your
feature branch.  Post a comment in the pull request afterwards; GitHub does
not send out notifications when you add commits.


### CONTRIBUTOR LICENSE AGREEMENT

By contributing to the xenograte-xct project you are agreeing to license your 
contribution by including the the following licensing notice adjacent to the 
copyright notice for the Original Work:

Licensed to xenograte-xct under the Academic Free License (AFL 3.0)
