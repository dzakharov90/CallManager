defmodule Ecallmanager.Configuration do
  use Plug.Router
  import XmlBuilder
  require Logger

  plug(:match)
  plug(:dispatch)

  @content_type "application/xml"

  post "/" do
    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(200, getconf(conn.body_params))
  end

  match _ do
    send_resp(conn, 404, "Requested page not found!")
  end

  defp getconf(params) do
    Logger.info("Config section")
    Logger.info("Config body params: #{inspect(params)}")
    with {:ok, key_value} <- Map.fetch(params, "key_value") do
      if key_value == "acl.conf" do
        Logger.info("Requested key acl.conf")
        [[proxyacls]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT sip_addr FROM clusterer) t", []).rows
        [[usersacls]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT ip FROM address) t", []).rows
        document(:document, %{type: "freeswitch/xml"}, [
          element(:section, %{name: "configuration"}, [
            element(:configuration, %{name: "acl.conf"},[
              element(:"network-lists",[
                element(:list, %{name: "ESL", default: "deny"},[
                  element(:node, %{type: "allow", cidr: "94.229.237.5/32"}),
                  element(:node, %{type: "allow", cidr: "127.0.0.1/32"}),
                  element(:node, %{type: "allow", cidr: "172.16.16.0/20"}),
                  element(:node, %{type: "allow", cidr: "::1/2"}),
                  element(:node, %{type: "allow", cidr: "::ffff:127.0.0.1"}),
                ]),
                element(:list, %{name: "authoritative", default: "deny"},[
                  proxyadresses(proxyacls),
                ]),
                element(:list, %{name: "trusted", default: "deny"},[
                  clientadresses(usersacls),
                ]),
              ]),
            ]),
          ]),
        ]) |> generate(standalone: false)
        else
          if key_value == "pocketsphinx.conf" do
            Logger.info("Requested key pocketsphinx.conf")
            document(:document, %{type: "freeswitch/xml"}, [
              element(:section, %{name: "configuration"}, [
                element(:configuration, %{name: "pocketsphinx.conf"},[
                  element(:settings, [
                    element(:param, %{name: "threshold", value: "400"}),
                    element(:param, %{name: "silence-hits", value: "25"}),
                    element(:param, %{name: "listen-hits", value: "1"}),
                    element(:param, %{name: "auto-reload", value: "true"}),
                  ]),
                ]),
              ]),
            ]) |> generate(standalone: false)
            else
              if key_value == "ivr.conf" do
                document(:document, %{type: "freeswitch/xml"},[
                  element(:section, %{name: "configuration"},[
                    element(:configuration, %{name: "ivr.conf"},[
                      element(:settings,[

                      ]),
                    ]),
                  ]),
                ]) |> generate(standalone: false)
              end
          end
      end
    end
  end

  def proxyadresses(proxyacls) do
    if proxyacls != nil do
      for proxyacl <- proxyacls do
        {:ok, sip_addr} = Map.fetch(proxyacl, "sip_addr")
        element(:node, %{type: "allow", cidr: "#{sip_addr}/32"}) |> generate
      end
    end
  end

  def clientadresses(usersacls) do
    if usersacls != nil do
      for usersacl <- usersacls do
        {:ok, ip} = Map.fetch(usersacl, "ip")
        element(:node, %{type: "allow", cidr: "#{ip}/32"}) |> generate
      end
    else
      element(:node, %{type: "allow", cidr: "127.0.0.1/32"}) |> generate
    end
  end

end
