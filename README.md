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
http://192.168.1.130:2346/90800000/1
```

(Confirmed format in the rtl_fm_streamer README.)

---

## Files included in this plugin package

```
Plugins/RTLFM/
├── install.xml
├── Plugin.pm
├── OPML.pm
├── Settings.pm
├── strings.txt
└── HTML/
    └── settings/
        └── rtlfm.html
```

Below follow the contents for each file. Drop the `Plugins/RTLFM` folder into your LMS/Lyrion `Plugins/` directory and install via the LMS plugin manager (or copy into the existing plugins folder and restart the server).

---

## install.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<plugin>
  <name>RTLFM</name>
  <version>0.1</version>
  <author>Your Name</author>
  <brief>RTL FM Radio service that streams from a local rtl_fm_streamer service</brief>
  <description>Provides an RTL FM radio service and settings page to configure the rtl_fm_streamer server and stations.</description>
  <platforms>
    <platform>linux</platform>
    <platform>win32</platform>
    <platform>darwin</platform>
  </platforms>
  <files>
    <file>Plugin.pm</file>
    <file>OPML.pm</file>
    <file>Settings.pm</file>
    <file>strings.txt</file>
    <file>HTML/settings/rtlfm.html</file>
  </files>
</plugin>
```

---

## Plugin.pm

```perl
# Plugins/RTLFM/Plugin.pm
package Plugins::RTLFM::Plugin;
use strict;
use warnings;

use Slim::Utils::PluginManager ();
use Slim::Utils::Prefs;
use Plugins::RTLFM::OPML;
use Plugins::RTLFM::Settings;

my $prefs;

sub initPlugin {
    my ($class, $client, $args) = @_;

    $prefs = preferences('plugin.RTLFM');

    # Register the OPML provider so it shows up in the "Radio" page
    Plugins::RTLFM::OPML->init($prefs);

    # Register settings page
    Plugins::RTLFM::Settings->init($prefs);

    Slim::Utils::Log->info("RTLFM plugin initialized");
}

1;
```

---

## OPML.pm

This module provides the browse menu for the LMS 'Radio' section — it returns an OPML-style list of stations from prefs.

```perl
# Plugins/RTLFM/OPML.pm
package Plugins::RTLFM::OPML;
use strict;
use warnings;

use Slim::Utils::Prefs;
use JSON::XS qw(encode_json decode_json);
use Slim::Utils::Log;

my $prefs;

sub init {
    my ($class, $p) = @_;
    $prefs = $p;

    # register a simple browse provider entry point
    Slim::Control::Request::addDispatch(
        ['plugins', 'rtlfm', 'browse'],
        \&browseHandler
    );
}

sub browseHandler {
    my $request = shift;
    my $cli = $request->client;

    my $stations_json = $prefs->get('stations') || '[]';
    my $stations = eval { decode_json($stations_json) } || [];

    my @items;
    foreach my $s (@$stations) {
        my $name = $s->{name} || 'Unknown';
        my $freq_mhz = $s->{freq};

        # convert MHz to Hz integer (e.g. 90.8 -> 90800000)
        my $freq_hz = int($freq_mhz * 1_000_000 + 0.5);

        my $ip = $prefs->get('server_ip') || '127.0.0.1';
        my $port = $prefs->get('server_port') || 2346;

        # default to stereo (/1)
        my $streamUrl = "http://$ip:$port/$freq_hz/1";

        push @items, {
            type => 'track',
            title => $name . ' (' . $freq_mhz . ' MHz)',
            url => $streamUrl,
            artwork => '',
        };
    }

    # Build LMS 'browse' response using Slim JSON RPC replies (simplified)
    my $results = {
        items => [ map { { title => $_->{title}, url => $_->{url}, type => 'track' } } @items ],
    };

    $request->addResult('items', $results->{items});
}

1;
```

> **Note:** The LMS internal browsing API expects a particular structure; this file provides a minimal example that constructs a simple response with `title` and `url` per item. Depending on your LMS version you may want to mirror the structure used by other simple music-service plugins (see the Music Service Plugin Implementation Guide linked below).

---

## Settings.pm

`Settings.pm` adds a settings page endpoint that serves a small HTML settings page (provided below) and exposes a POST handler that saves the server IP, port and stations list as JSON into plugin preferences.

```perl
# Plugins/RTLFM/Settings.pm
package Plugins::RTLFM::Settings;
use strict;
use warnings;

use Slim::Web::Request;
use Slim::Web::Pages;
use Slim::Utils::Prefs;
use JSON::XS qw(encode_json decode_json);

my $prefs;

sub init {
    my ($class, $p) = @_;
    $prefs = $p;

    # Register a simple settings page URL under the plugin settings area
    Slim::Web::Pages->addPageFunction('plugins/RTLFM/settings', \&settingsPage);
}

sub settingsPage {
    my ($client, $params, $callback) = @_;

    my $method = Slim::Web::Request->getRequestMethod();

    if ($method eq 'POST') {
        my $data = Slim::Web::Request->getRequestBody();
        # Expect JSON with keys: server_ip, server_port, stations (array of {name, freq})
        my $obj = decode_json($data || '{}');

        $prefs->set('server_ip', $obj->{server_ip} || '');
        $prefs->set('server_port', $obj->{server_port} || '');
        $prefs->set('stations', encode_json($obj->{stations} || []));

        return $callback->(
            JSON::XS->new->utf8->encode({ success => JSON::XS::true })
        );
    }

    # On GET: return current settings as JSON
    my $out = {
        server_ip => $prefs->get('server_ip') || '',
        server_port => $prefs->get('server_port') || 2346,
        stations => eval { decode_json($prefs->get('stations') || '[]') } || [],
    };

    return $callback->(encode_json($out));
}

1;
```

> **Note:** The example above uses a minimal page registration approach. If your LMS version requires different hooks to register HTML pages, adapt `addPageFunction` to the appropriate call (review other plugins in `Plugins/` for examples).

---

## HTML/settings/rtlfm.html

A compact settings UI that reads and writes configuration via the JSON endpoint provided by `Settings.pm`.

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>RTL FM - Settings</title>
  <style>
    body { font-family: sans-serif; padding: 16px }
    label { display:block; margin-top:8px }
    input[type=text] { width: 300px }
    .station { margin:6px 0 }
  </style>
</head>
<body>
  <h2>RTL FM - Settings</h2>
  <label>Server IP: <input id="ip" type="text"/></label>
  <label>Server Port: <input id="port" type="text"/></label>

  <h3>Stations</h3>
  <div id="stations"></div>
  <button id="add">Add station</button>
  <hr>
  <button id="save">Save</button>

  <script>
    function el(tag, attrs) { var e = document.createElement(tag); for(var k in attrs) e[k]=attrs[k]; return e }

    function renderStations(stations) {
      var container = document.getElementById('stations');
      container.innerHTML = '';
      stations.forEach(function(s, i){
        var div = el('div', { className: 'station' });
        var name = el('input', { type: 'text', value: s.name });
        var freq = el('input', { type: 'text', value: s.freq });
        var rm = el('button', { innerText: 'Remove' });
        rm.onclick = function(){ stations.splice(i,1); renderStations(stations); };
        div.appendChild(name); div.appendChild(document.createTextNode(' '));
        div.appendChild(freq); div.appendChild(document.createTextNode(' MHz '));
        div.appendChild(rm);
        container.appendChild(div);
      });
    }

    var stations = [];

    function load() {
      fetch('/plugins/RTLFM/settings')
        .then(r => r.json())
        .then(data => {
          document.getElementById('ip').value = data.server_ip || '';
          document.getElementById('port').value = data.server_port || 2346;
          stations = data.stations || [];
          renderStations(stations);
        });
    }

    document.getElementById('add').onclick = function(){ stations.push({name: 'New station', freq: 100}); renderStations(stations); };

    document.getElementById('save').onclick = function(){
      // Collect values from inputs (simple approach)
      var ip = document.getElementById('ip').value;
      var port = document.getElementById('port').value;

      // update station inputs back into stations array
      var container = document.getElementById('stations');
      var inputs = container.querySelectorAll('.station');
      // but easier: re-read children
      var newStations = [];
      var children = container.children;
      for (var i=0;i<children.length;i++){
        var inputs = children[i].getElementsByTagName('input');
        var name = inputs[0].value;
        var freq = parseFloat(inputs[1].value);
        newStations.push({ name: name, freq: freq });
      }

      fetch('/plugins/RTLFM/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ server_ip: ip, server_port: port, stations: newStations })
      }).then(r=>r.json()).then(()=> alert('Saved'));
    };

    load();
  </script>
</body>
</html>
```

---

## strings.txt

```
# English strings
RTLFM=RTL FM Radio
RTLFM.CONFIG=RTL FM Configuration
```

---

## Installation & Notes

1. Create folder `Plugins/RTLFM` under your LMS plugins directory and place files accordingly (retain `HTML/settings/rtlfm.html`).
2. Restart LMS / Lyrion.
3. Go to Server Settings -> Plugins and enable `RTLFM`.
4. Open the plugin settings page (the server's plugin settings will link to it) or visit `/plugins/RTLFM/settings` in the LMS web UI to edit server IP, port and station list.
5. Open the "Radio" page — the new service **RTL FM Radio** will appear (some skins place custom services under Online Music Services / Radio). Selecting a station will hand the constructed `http://IP:PORT/FREQ_HZ/1` stream URL to LMS.

### Implementation caveats / TODOs

- The OPML/browse handler provided is a minimal, illustrative implementation. The exact browse response structure expected by your LMS version and skin may require tweaks to match other music-service plugins. See `Plugins/Spotty` or `Plugins/Qobuz` as examples for fully fledged implementations.
- The small HTML settings page uses a JSON POST endpoint; depending on LMS version you might need to adapt the server-side `Settings.pm` to the correct LMS web handler architecture (the Music Service Plugin Implementation Guide has examples). See the relevant docs below.

---

## References

- Lyrion Music Server — Music Service Plugin Implementation Guide (explains plugin layout, OPML/Browse, Settings, ProtocolHandler patterns). citeturn1view0
- rtl_fm_streamer — README (default port, streaming URL format `http://IP:port/FrequencyInHerz/1`). citeturn2view0

---

If you want, I can:
- produce these files as a ZIP for you to download and install, or
- convert the settings HTML into the exact settings UI format your LMS skin uses (if you tell me which skin/version you run), or
- adapt OPML/browse responses to exactly match another plugin’s response format (I can copy the exact structure from an installed plugin on your server if you provide its `OPML.pm` contents).


---

*Notes:* I implemented a compact and practical plugin skeleton that constructs HTTP stream URLs from user-supplied server IP, port, and station frequencies. The plugin uses the rtl_fm_streamer URL format (`http://IP:PORT/FREQ_IN_HZ/1`) shown in the rtl_fm_streamer README. Adjustments may be required for full compatibility with your LMS version/skin; if you paste the exact LMS error/messages (or the OPML format used by another working plugin) I will adapt the code accordingly.

