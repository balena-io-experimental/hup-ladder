# HUP-ladder

Tool for testing balenaOS updates both sequentially and randomly across OS versions in the staging/production
environments of balenaCloud.

Simply set `$UUID` and `$TOKEN` in the environment and let the good HUPs roll!

```shell
UUID={{uuid}} TOKEN={{token}} npm run start
```

By default this tool proceeds sequentially, to instead pick a random sort order, set `RANDOM_ORDER=true`.
To test against production, set `STAGING=false`.
To test alternate step size N, set `STEP=N`. Defaults to 1.

## TODO

* Blacklist for known-bad versions
