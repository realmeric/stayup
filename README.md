# StayUp

A macOS menu bar app that keeps this MacBook awake with the lid closed while an
agent is working, and lets it sleep the moment there is nothing left to wait
for. It raises `SleepDisabled`, the one flag that overrides a lid close, and
guarantees the flag comes back down.

    make test     # generate the project and run the tests
    make run      # build and launch from DerivedData
    make install  # build Release, check it, and put it in /Applications

`make install` is not optional if you want Launch at login: macOS registers a
login item only for an app under `/Applications`. The Release build is written
to `~/Library/Caches/StayUp/build` rather than into the repository, because
this one is inside an iCloud-synced folder and a synced bundle cannot be
signed.
