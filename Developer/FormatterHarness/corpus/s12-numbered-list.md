To install a paclet from a local file:

1. Download the `.paclet` file to your computer.
2. Run the following, replacing the path with your own:

```wl
PacletInstall["/path/to/MyPaclet-1.0.0.paclet"]
```

3. Load the package:

```wl
Needs["MyPaclet`"]
```

4. Verify that it's installed with `PacletFind["MyPaclet"]`.

If step 2 fails with a `PacletInstall::samevers` message, the paclet is already installed. Use `ForceVersionInstall -> True` to reinstall it.
