# Copy to config.sh and fill in. config.sh is git-ignored: it holds your own Apple team, devices and paths.

# Apple signing (a free Personal Team works; its profiles last 7 days)
TEAM_ID=XXXXXXXXXX                  # security find-identity -v -p codesigning  → "Apple Development: ... (TEAM_ID)"
SIGN_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   # the 40-character hash on the same line
BUNDLE_PREFIX=com.example.nx        # unique to you: the launcher is $BUNDLE_PREFIX.games, each game $BUNDLE_PREFIX.<name>

# Devices (xcrun devicectl list devices). DEVICE=ipad tools/assemble.sh installs on IPAD_UDID.
IPHONE_UDID=00000000-0000000000000000
IPAD_UDID=

# Your own keys, dumped from your own Switch
KEYS=$HOME/keys/prod.keys
GAME_LANG=ko                        # language for the games (nxnative -l)
