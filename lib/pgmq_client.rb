# frozen_string_literal: true

require_relative "pgmq_client/version"
require_relative "pgmq_client/errors"

module PGMQ
  autoload :Configuration, "pgmq_client/configuration"
  autoload :Connection, "pgmq_client/connection"
  autoload :ConnectionPool, "pgmq_client/connection_pool"
  autoload :Client, "pgmq_client/client"
  autoload :Message, "pgmq_client/message"
  autoload :QueueInfo, "pgmq_client/queue_info"
  autoload :Metrics, "pgmq_client/metrics"
end
