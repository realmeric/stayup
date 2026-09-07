# StayUp

A macOS menu bar app that keeps this MacBook awake with the lid closed while an
agent is working, and lets it sleep the moment there is nothing left to wait
for. It raises `SleepDisabled`, the one flag that overrides a lid close, and
guarantees the flag comes back down.

    make test    # generate the project and run the tests
    make run     # build and launch
