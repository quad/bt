= Bugs

* Should commit results as merge commit of their needs


= Wishlist

* Should support dynamically defined stages
  * Stages per:
    * Spec
    * Feature
* Should support stage tags
  * Automatic tags
    * linux/windows/darwin
    * java/java5/java/6
    * rvm
    * ruby/ruby18/ruby187/ruby19
    * xvfb
* Should re-use build results when watching multiple repositories
* Should support custom build schedules
  * Optimistic with bisection on failing builds
  * Some machines satisfy old commits, some machine satisfy new commits
  * Historical tracking to schedule bad stages earlier?
* Should coordinate builds 


== bt-go

* Should build from a working directory
  * From a stash?

== bt-watch

* Should delegate to bt-agent, bt-go, bt-next-commit
* Should integrate with Jenkins for build reporting
  * Post-receive on the central repo?
* Should run a git serve of its mirror
* Should have an HTTP status console
  * Available? Busy?
  * Active log
  * Other agents?
* Should be able to watch multiple repos
  * Detect repos via bonjour



== bt-agent

* Should coordinate builds over WANs and the Internet
  * DNSSD only works on local networks, is buggy, and not Internet friendly.
