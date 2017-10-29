defmodule PioneerRpc.PioneerRpcClient do
  require Logger
  use AMQP

  defmacro __using__(opts) do
    target_module = __CALLER__.module
    name = Access.get(opts, :name, target_module)
    timeout = Access.get(opts, :timeout, 5000)
    reconnect_interval = Access.get(opts, :reconnect_interval, 10000)
    connection_string = Access.get(opts, :connetion_string, "amqp://localhost")
    cleanup_interval = Access.get(opts, :cleanup_interval, 60000)
    queues = Access.get(opts, :queues, [])

    quote do
      require Logger
      use GenServer
      use AMQP

      @queues unquote(queues)
      @timeout unquote(timeout)

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
        Logger.debug("#{unquote(name)}: client connection '#{get_connection_string()}'")
        resp = rabbitmq_connect()
        if resp do
          Logger.debug("#{unquote(name)}: client connected to RabbitMQ")
          {:ok, resp}
        else
          Logger.warn("#{unquote(name)}: failed to connect to RabbitMQ during init. Scheduling reconnect.")
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

      def handle_info({:basic_deliver, sdata, %{correlation_id: deliver_correlation_id}}, state) do
        %{channel: channel,
          continuations: continuations,
          correlation_id: correlation_id,
          reply_queue: reply_queue} = state
        cont = Map.get(continuations, deliver_correlation_id, false)
        if cont do
          {from, timeout} = cont
          if not continuation_timed_out(timeout) do
            response = deserialize(sdata)
            GenServer.reply(from, response)
            {:noreply, %{channel: channel,
                         reply_queue: reply_queue,
                         correlation_id: correlation_id,
                         continuations: Map.delete(continuations, deliver_correlation_id)}}
          else
            {:noreply, state}
          end
        else
          {:noreply, state}
        end
      end

      def handle_call({{:call, command}, timeout}, from, state) do
        {queue, headers} = command
        if state == :not_connected do
          {:reply, :not_connected}
        else
          {:ok, sheaders} = serialize(headers)
          %{channel: channel,
            continuations: continuations,
            correlation_id: correlation_id,
            reply_queue: reply_queue} = state

          encoded_correlation_id = Integer.to_string(correlation_id)

          case Basic.publish(
            channel,
            "",
            queue,
            sheaders,
            reply_to: reply_queue,
            correlation_id: encoded_correlation_id,
            content_type: content_type(),
            persistent: false,
            mandatory: true
          ) do
            :ok -> {:noreply, %{channel: channel,
                         reply_queue: reply_queue,
                         correlation_id: correlation_id + 1,
                         continuations: Map.put(continuations, encoded_correlation_id, {from, timeout})}}
            _ -> {:reply,{:error, :timeout}, %{channel: channel,
                         reply_queue: reply_queue,
                         correlation_id: correlation_id + 1,
                         continuations: Map.put(continuations, encoded_correlation_id, {from, timeout})}}
          end

        end
      end


      def handle_info(:cleanup_trigger, state) do
        :erlang.send_after(unquote(cleanup_interval), :erlang.self(), :cleanup_trigger)
        {:noreply, cleanup_timedout_continuations(state)}
      end

      def handle_info(:try_to_connect, state) do
        new_state = connect(state)
        {:noreply, new_state}
      end

      def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
        fail_all_continuations(state, :connection_lost)
        new_state = connect(:not_connected)
        {:noreply, new_state}
      end

      def rpc(command, timeout \\ @timeout) do
        try do
          GenServer.call(unquote(name), {{:call, command}, :erlang.monotonic_time(:milli_seconds) + timeout}, timeout)
        catch
          :exit, {:timeout, _} ->
              Logger.warn("#{unquote(name)}: timeout call.")
            {:error, :timeout}
        end
      end

      defp connect(state) do
        Logger.warn("#{unquote(name)}: RabbitMQ connect...")
        if state == :not_connected do
          resp = rabbitmq_connect()
          if resp do
            Logger.warn("#{unquote(name)}: RabbitMQ connect succeeded.")
            resp
          else
            Logger.warn("#{unquote(name)}: RabbitMQ connect failed. Scheduling reconnect.")
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
        case Connection.open(get_connection_string()) do
          {:ok, conn} ->
            Logger.debug("#{unquote(name)}: Start process monitor")
            Process.monitor(conn.pid)
            Logger.debug("#{unquote(name)}: Open channel")
            {:ok, chan} = Channel.open(conn)
            Basic.qos(chan, prefetch_count: 10)
            Logger.debug("#{unquote(name)}: Declare list queues")
            create_map(@queues,chan,&(Queue.declare(&1, &2, exclusive: true, arguments: [{"x-message-ttl", :long, 1000}])))
            Logger.debug("#{unquote(name)}: Declare reply queue")
            {:ok, reply_queue} = Queue.declare(chan,"", exclusive: true, auto_delete: true)
            %{queue: reply_queue} = reply_queue
            Logger.debug("#{unquote(name)}: Consume reply queue")
            {:ok, _consumer_tag} = Basic.consume(chan, reply_queue, self(), no_ack: true)
            :erlang.send_after(unquote(cleanup_interval), :erlang.self(), :cleanup_trigger)
            %{channel: chan,
              reply_queue: reply_queue,
              correlation_id: 0,
              continuations: %{}}
          {:error, _} ->
            Logger.warn("#{unquote(name)}: Error open connection")
            false
        end
      end

      defp fail_all_continuations(state, reply) do
        %{continuations: continuations} = state
        Map.to_list(continuations)
        |> Enum.each(fn({_, {from, timeout}}) ->
          if not continuation_timed_out(timeout) do
            GenServer.reply(from, reply)
          end
        end)
      end

      defp cleanup_timedout_continuations(state) do
        if state != :not_connected and state != nil do
          %{continuations: old_continuations} = state
          clist = Map.to_list(old_continuations)
          new_continuations = clist |> Enum.reject(fn({_, {_, timeout}}) -> continuation_timed_out timeout end)
          # Logger.debug("#{unquote(name)}: timed out continuations cleaned: before #{length(clist)}, after #{length(new_continuations)}")
          %{state | :continuations => Enum.into(new_continuations, %{})}
        end
      end

      defp continuation_timed_out (timeout) do
        :erlang.monotonic_time(:milli_seconds) >= timeout
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
