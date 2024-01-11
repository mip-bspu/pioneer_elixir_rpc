defmodule PioneerRpc.PioneerRpcServer do
  require Logger
  use AMQP

#  defmodule State do
#    defstruct [fn: nil,channel: nil]
#  end

  defmacro __using__(opts) do

    target_module = __CALLER__.module
    name = Access.get(opts, :name, target_module)
    reconnect_interval = Access.get(opts, :reconnect_interval, 10000)
    connection_string = Access.get(opts, :connetion_string, "amqp://localhost")
    queues = Access.get(opts, :queues,[])

    quote do
      require Logger
      use GenServer
      use AMQP

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

      def start_link(state\\[]) do
        GenServer.start_link(__MODULE__, [], name: unquote(name))
      end

      def init(_opts) do
        Logger.info("#{unquote(name)}: starting RPC server.")
        Logger.debug("#{unquote(name)}: server connection '#{get_connection_string()}'")
        resp = rabbitmq_connect()
        if resp do
          Logger.debug("#{unquote(name)}: server connected to RabbitMQ")
          {:ok, resp}
        else
          Logger.warning("#{unquote(name)}: failed to connect to RabbitMQ during init. Scheduling reconnect.")
          :erlang.send_after(unquote(reconnect_interval), :erlang.self(),:try_to_connect)
          {:ok, :not_connected}
        end
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

      def handle_info(:try_to_connect, state), do: {:noreply, connect(state)}

      def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
        {:noreply, connect(:not_connected)}
      end

      defp consume(state, meta, payload) do
        Logger.debug("#{unquote(name)}: start work #{meta.routing_key}")
        response = case deserialize(payload) do
          {:ok, args} ->
            Logger.debug("#{unquote(name)}: apply function [#{meta.routing_key}]...")
            try do
              IO.inspect(String.to_atom(meta.routing_key))
              IO.inspect(args)
              apply(unquote(target_module), String.to_atom(meta.routing_key), args)
            rescue
              error in UndefinedFunctionError ->
                IO.inspect(error)
                Logger.debug("#{unquote(name)}: (#{meta.routing_key}) redirect function urpc...")
                try do
                  apply(unquote(target_module), :urpc, [args])
                rescue
                  error ->
                    Logger.error(Exception.format(:error, error))
                    Logger.error("#{unquote(name)}: Error apply function [#{meta.routing_key}]")
                    %{error: 500, message: error}
                end
              error ->
                Logger.error(Exception.format(:error, error))
                Logger.error("#{unquote(name)}: Error apply function [#{meta.routing_key}]")
                %{error: 500, message: error}
            end
          _ ->
            Logger.error("#{unquote(name)}: Error parse #{payload}")
            %{error: 400, message: "parse args error"}
        end

        Logger.debug("#{unquote(name)}: response #{meta.routing_key}")

        sresponse = case Poison.encode(response) do
          {:ok, data} -> data
          _ -> Poison.encode!(%{error: 500, message: "error encode respons to json"})
        end

        try do
          Logger.debug("#{unquote(name)}: start publish #{meta.routing_key}")
          AMQP.Basic.publish(
            state,"", meta.reply_to, sresponse ,
            correlation_id: meta.correlation_id, content_type: content_type()
          )
        rescue
          error ->
            Logger.error(Exception.format(:error, error))
            Logger.error("#{unquote(name)}: Error publish [#{meta.reply_to}]")
        after
           Logger.debug("#{unquote(name)}: end publish #{meta.routing_key}")
        end
      end

      defp connect(state) do
        Logger.warning("#{unquote(name)}: RabbitMQ connect...")
        if state == :not_connected do
          resp = rabbitmq_connect()
          if resp do
            Logger.warning("#{unquote(name)}: RabbitMQ connect succeeded.")
            resp
          else
            Logger.warning("#{unquote(name)}: RabbitMQ connect failed. Scheduling reconnect.")
            :erlang.send_after(unquote(reconnect_interval), :erlang.self(),:try_to_connect)
            :not_connected
          end
        else
          :io.format("~p", [state])
          Logger.debug("#{unquote(name)}: trying to connect while aready connected.")
          state
        end
      end

      defp rabbitmq_connect() do
        Logger.debug("#{unquote(name)}: Start connection...")
        case Connection.open(get_connection_string()) do
          {:ok, conn} ->
            Process.monitor(conn.pid)
            {:ok, chan} = Channel.open(conn)
            Basic.qos(chan, prefetch_count: 10)

            create_map(unquote(queues),chan,&(Queue.declare(&1, &2, exclusive: true, arguments: [{"x-message-ttl", :long, 1000}])))
            create_map(unquote(queues),chan,&(Basic.consume(&1, &2, nil, no_ack: true)))
            chan
          {:error, message} ->
            Logger.warning("#{unquote(name)}: Error open connection: #{message}")
            :timer.sleep(unquote(reconnect_interval))
            false
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
