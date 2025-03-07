import Config

# Use shoehorn to start the main application. See the shoehorn
# docs for separating out critical OTP applications such as those
# involved with firmware updates.

config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# Nerves Runtime can enumerate hardware devices and send notifications via
# SystemRegistry. This slows down startup and not many programs make use of
# this feature.

config :nerves_runtime, :kernel, use_system_registry: true
# config :nerves_runtime, :kernel, use_system_registry: false

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

config :nerves,
  erlinit: [
    hostname_pattern: "nerves-%s"
  ]

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

keys =
  [
    Path.join([System.user_home!(), ".ssh", "buckit.id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
  ]
  |> Enum.filter(&File.exists?/1)

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

# Configure the network using vintage_net
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  regulatory_domain: "00",
  # Uncomment following to disable config change persistance
  # persistence: VintageNet.Persistence.Null,
  internet_host_list: [{{192, 168, 24, 1}, 53}],
  additional_name_servers: [{{192, 168, 24, 1}}],
  config: [
    # {"usb0", %{type: VintageNetDirect}},
    {"eth0",
     %{
       type: VintageNetEthernet,
       ipv4: %{method: :dhcp}
     }},
    {"wlan0",
     %{
       type: VintageNetWiFi,
       dhcpd: %{
         start: {192, 168, 24, 10},
         end: {192, 168, 24, 250},
         options: %{
           dns: [{192, 168, 24, 1}],
           subnet: {255, 255, 255, 0},
           router: [{192, 168, 24, 1}],
           domain: "buckitup.app",
           search: ["buckitup.app"]
         }
       },
       dnsd: %{
         records: [
           {"buckitup.app", {192, 168, 24, 1}}
           # {"*", {192, 168, 24, 1}}
         ]
       },
       ipv4: %{
         address: {192, 168, 24, 1},
         method: :static,
         prefix_length: 24,
         name_servers: [{192, 168, 24, 1}]
       },
       vintage_net_wifi: %{
         networks: [
           %{
             key_mgmt: :wpa_psk,
             mode: :ap,
             psk: "buckitup",
             ssid: "buckitup.app",
             proto: "RSN",
             pairwise: "CCMP",
             group: "CCMP"
           }
         ]
       }
     }}
  ]

config :mdns_lite,
  # The `host` key specifies what hostnames mdns_lite advertises.  `:hostname`
  # advertises the device's hostname.local. For the official Nerves systems, this
  # is "nerves-<4 digit serial#>.local".  mdns_lite also advertises
  # "nerves.local" for convenience. If more than one Nerves device is on the
  # network, delete "nerves" from the list.

  host: [:hostname, "nerves"],
  ttl: 120,

  # Forbidding advertising services over wifi
  excluded_ifnames: ["wlan0", "lo"],

  # Advertise the following services over mDNS.
  services: [
    # %{
    #   protocol: "ssh",
    #   transport: "tcp",
    #   port: 22
    # },
    # %{
    #   protocol: "sftp-ssh",
    #   transport: "tcp",
    #   port: 22
    # },
    # %{
    #   protocol: "epmd",
    #   transport: "tcp",
    #   port: 4369
    # }
  ]

# Chat endpoint config
config :chat, ChatWeb.Endpoint,
  render_errors: [view: ChatWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Chat.PubSub,
  live_view: [signing_salt: "N+hZlbsm"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  # Possibly not needed, but doesn't hurt
  # http: [port: {:system, "PORT"}],
  http: [port: 80],
  url: [host: "buckitup.app"],
  # url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443],
  secret_key_base: "HEY05EB1dFVSu6KykKHuS4rQPQzSHv4F7mGVB/gnDLrIu75wE/ytBXy2TaL3A6RA",
  # secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  check_origin: [
    "https://buckitup.app",
    "http://192.168.0.127",
    "http://192.168.24.1"
  ],
  https: [
    port: 443,
    cipher_suite: :strong,
    cacertfile: "priv/cert/buckitup_app.ca-bundle",
    certfile: "priv/cert/buckitup_app.crt",
    keyfile: "priv/cert/priv.key"
  ],
  server: true,
  code_reloader: false

config :chat, :cub_db_file, "/root/db"
config :chat, :admin_cub_db_file, "/root/admin_db"

config :chat, :set_time, true

config :chat,
  data_pid: nil,
  files_base_dir: "/root/db/files",
  write_budget: 0,
  mode: :internal,
  flags: [],
  writable: :no

config :platform, :tmp_size, "1G"

config :logger,
  backends: [RamoopsLogger, RingLogger],
  compile_time_purge_matching: [
    [application: :ssl, level_lower_than: :error]
  ]

# config :phoenix, :json_library, Jason
# config :phoenix, :json_library, Poision

# Do not print debug messages in production

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
