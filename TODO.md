# TODOs

## Document: How to distribute an ExTermbox app

* Unfortunately an escript won't work because escripts don't support the `priv/`
  directory, which ExTermbox needs to load the termbox so.
* Could potentially use archives, but they're intended for Mix extensions.
* Distillery supports building self-contained executables. This seems like the
  best option right now.
