# logstash-output-loginsight

This is a plugin for [Logstash](https://github.com/elastic/logstash), sending events to [VMware vRealize Log Insight](https://www.vmware.com/support/pubs/log-insight-pubs.html)

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Installation from rubygems

[logstash-output-loginsight](http://rubygems.org/gems/logstash-output-loginsight) is hosted on rubygems.org. [Download and install the latest gem](https://www.elastic.co/guide/en/logstash/current/working-with-plugins.html) in your Logstash deployment:

```sh
bin/logstash-plugin install logstash-output-loginsight
```

Verify installed version:
```sh
bin/logstash-plugin list --verbose logstash-output-loginsight
logstash-output-loginsight (0.1.12)
```

## Usage

The plugin requires, at minimum, the hostname or IP address of a remote Log Insight server. Connections are established via HTTPS on port 9543, with certificate verification by default. If the Log Insight server carries a certificate issued by a trusted authority, a hostname is the only required option.

```
loginsight {
    host => "loginsightvip.example.com"
}
```

| option | default | notes |
| --- | --- | --- |
| `host`  |       | required remote sserver to connect to |
| `port`  | `9543`  | ingestion api port 9000 uses http |
| `proto` | `https` | `https` or `http` |
| `uuid`  | `id` or `0` | unique identifier for client |
| `verify` | `True` | verify certificate chain and hostname for SSL connections |
| `ca_file` |       | alternate certificate chain to trust |

## Self-signed Certificate

Verification of the remote certificate is done against the platform's certificate authority. If you're using a self-signed certificate, you can retrieve a copy of the certificate and then configure the client to trust it. The certificate's common name must still match the `host` option.

Connect to your Log Insight server and retrieve the certificate, writing it out to a PEM-formatted file. This method works for single-certificate chains, as in the self-signed case.
```sh
openssl s_client -showcerts -connect 10.11.12.13:9543 < /dev/null | openssl x509 -outform PEM > certificate.pem
```

For longer untrusted chains, use `openssl s_client -connect 10.11.12.13:9543 -verify 1` and copy the contents of all the sections inside `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`, inclusive, and save them in a new`certificate.pem` file.

Pass the PEM-formatted file in the `ca_file` parameter:

```sh
bin/logstash -e 'input { stdin { add_field => { "fieldname" => "10" } } } output { loginsight { host => ["10.11.12.13"] verify => [true] ca_file => ["/Path to PEM/certificate.pem"] } }' --log.level=debug
```

## AsciiDocs

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elastic/docs#asciidoc-guide

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Clone this repository.

- Install dependencies:
```sh
bundle install
```

#### Test

- Update your dependencies:
```sh
bundle install
```

- Run tests:
```sh
bundle exec rspec
```

### 2. Running the local, unpublished plugin in Logstash

#### 2.1 Run in a local Logstash clone

- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-output-loginsight", :path => "/your/local/logstash-output-loginsight"
```
- Install plugin
```sh
bin/logstash-plugin install --no-verify
```
- Start Logstash and with the `stdin` input plugin and test connectivity to Log Insight, with debug logging:
```sh
bin/logstash -e 'input { stdin { add_field => { "fieldname" => "10" } } } output { loginsight { host => ["10.11.12.13"] } }' --log.level=debug
```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory. Or you can build the gem and install it using:

- Build your plugin gem:
```sh
gem build logstash-output-loginsight.gemspec
```
- Install the plugin from the Logstash home:
```sh
bin/logstash-plugin install /your/local/plugin/logstash-output-loginsight.gem
```
- Start Logstash and with the `stdin` input plugin and test connectivity to Log Insight, with debug logging:
```sh
bin/logstash -e 'input { stdin { add_field => { "fieldname" => "10" } } } output { loginsight { host => ["10.11.12.13"] } }' --log.level=debug
```

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.
