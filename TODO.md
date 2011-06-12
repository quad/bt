= Bugs

* Build results are children of the source commit. They should be children of
  their needs.

= Wishlist

* Integrate with Jenkins for build reporting
* Dynamic stage generation
* Building branches other than master (HEAD)
* Stage aliases?
  * Should there be a bt/HEAD/stage or a bt/stage?
* Agent HTTP monitoring / status console
* Automatic tags (sreeni)
* Watch multiple repositories
  * Detect repos via bonjour
* Commit sharing
  * When watching multiple repositories, if two repos share the same
    commit/sha, then re-use the build result.
* Build coordination via Kademlia
  * DNSSD only works on local networks, is buggy, and not Internet friendly.
