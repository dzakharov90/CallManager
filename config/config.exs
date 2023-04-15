import Config

config :ecallmanager, Ecallmanager.Routes, port: 4000
config :ecallmanager, Ecallmanager.ESLServer, port: 8022

config :event_socket_outbound, EventSocketOutbound.Call.Manager, call_mgt_adapter: Ecallmanager.Callmgm

import_config "#{Mix.env()}.exs"
