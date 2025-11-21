# RTL FM Radio — Lyrion Music Server plugin

**What this plugin does (summary)**

- Adds a new radio *service* called **"RTL FM Radio"** on Lyrion's Radio page.
- Provides a configuration/settings page where you can set:
  - Server IP Address
  - Server Port
  - A list of FM stations (name + frequency in MHz, e.g. `DR P1 — 90.8`)
- When selecting a station the plugin constructs an RTL FM Streamer HTTP URL and hands it to LMS for playback using the pattern:

```
http://<IP>:<PORT>/<FREQ_IN_HZ>/<MODE>
```

Where `FREQ_IN_HZ` is the frequency (MHz) multiplied by 1,000,000 (e.g. `90.8` MHz -> `90800000`) and `MODE` is `1` for stereo (or `0` for mono). Example from your request becomes:

```
http://<ip>:<port>/90800000/1
```

## References

- Lyrion Music Server — Music Service Plugin Implementation Guide (explains plugin layout, OPML/Browse, Settings, ProtocolHandler patterns). citeturn1view0
- rtl_fm_streamer — README (default port, streaming URL format `http://IP:port/FrequencyInHerz/1`). citeturn2view0

