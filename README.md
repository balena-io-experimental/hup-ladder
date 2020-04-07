# HUP-ladder

Tool for testing balenaOS updates both sequentially and randomly across OS versions in the staging environment of
balenaCloud.

Simply set `$UUID` and `$TOKEN` in the environment and let the good HUPs roll!

Additionally, to skip N revs, set `$SKIP` to `N`.

By default this tool proceeds sequentially, to instead pick a random sort order, set `$RANDOM_ORDER` to `true`.

## TODO

* Blacklist for known-bad versions
* Change from staging to other environments
