defmodule PioneerRpc.RPC.PioneerRpc do
  require Logger
  use AMQP

  defmodule State do
    defstruct [fn: nil,channel: nil]
  end

  defmacro __using__(opts) do

    target_module = __CALLER__.module
    name = Access.get(opts, :name, target_module)
    reconnect_interval = Access.get(opts, :reconnect_interval, 10000)
    connection_string = Access.get(opts, :connetion_string, "amqp://localhost")
    {:ok, queues} = Access.fetch(opts, :queues)

    quote do
      require Logger
      use GenServer
      use AMQP

      @queues unquote(queues)

      defp get_connection_string do
        unquote(case connection_string do
              {:system, name} ->
                System.get_env(name)
              {app, key} ->
                quote do
                  {:ok, connection_string} = :application.get_env(unquote(app), unquote(key))
                  connection_string
                end
              _ ->
                connection_string
            end)
      end

      def start_link do
        GenServer.start_link(__MODULE__, [], name: unquote(name))
      end

      def init(_opts) do
        Logger.info("#{unquote(name)}: starting RPC client.")
        Logger.debug("#{unquote(name)}: connection '#{get_connection_string()}'")
        resp = rabbitmq_connect()
        Logger.debug("#{unquote(name)}: connected to RabbitMQ")
        resp
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:noreply, state}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :normal, state}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:noreply, state}
      end

      def handle_info({:basic_deliver, payload, meta}, state) do
        Logger.debug("#{unquote(name)}: #{meta.routing_key} #{payload}")
        spawn fn -> consume(state, meta, payload) end
        {:noreply, state}
      end

      defp consume(state, meta, payload) do
        case deserialize(payload) do
          {:ok, args} ->
            response = try do
              apply(unquote(target_module), String.to_atom(meta.routing_key), [args])
            rescue
              error ->
                Logger.error("#{unquote(name)}: Error apply function [#{meta.routing_key}] : #{error.message}")
                %{error: 500, message: error.message}
            end
            {:ok, sresponse} = serialize(response)
          _ ->
            Logger.error("#{unquote(name)}: Error parse #{payload}")
            {:ok, sresponse} = serialize(%{error: 400, message: "parse args error"})
        end
        AMQP.Basic.publish(
          state,"", meta.reply_to, sresponse ,
          correlation_id: meta.correlation_id, content_type: content_type()
        )
      end

      def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
        {:ok, chan} = rabbitmq_connect()
        {:noreply, chan}
      end

      defp rabbitmq_connect() do
        case Connection.open(get_connection_string()) do
          {:ok, conn} ->
            Process.monitor(conn.pid)
            {:ok, chan} = Channel.open(conn)
            Basic.qos(chan, prefetch_count: 10)
            create_map(@queues,chan,&(Queue.declare(&1, &2, exclusive: true, arguments: [{"x-message-ttl", :long, 1000}])))
            create_map(@queues,chan,&(Basic.consume(&1, &2, nil, no_ack: true)))
            {:ok, chan}
          {:error, _} ->
            Logger.warn("#{unquote(name)}: Error open connection")
            :timer.sleep(unquote(reconnect_interval))
            rabbitmq_connect()
        end
      end

      defp create_map([],_,_), do: :ok

      defp create_map([queue|list],chan,func) do
        func.(chan,queue)
        create_map(list,chan,func)
      end

      defp content_type, do: "application/json"

      defp serialize(data), do: Poison.encode(data)

      defp deserialize(sdata), do: Poison.decode(sdata, keys: :atoms)

    end
  end
end
