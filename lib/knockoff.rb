require 'active_record'
require 'knockoff/version'
require 'knockoff/base'
require 'knockoff/error'
require 'knockoff/replica_connection_holder'
require 'knockoff/active_record/base'
require 'knockoff/active_record/relation'

module Knockoff
  class << self
    attr_accessor :enabled
    attr_writer :spec_key

    def spec_key
      case @spec_key
      when String   then @spec_key
      when NilClass then @spec_key = "#{ActiveRecord::ConnectionHandling::RAILS_ENV.call}_replica"
      end
    end

    def on_replica(&block)
      Base.new(:replica).run(&block)
    end

    def on_primary(&block)
      Base.new(:primary).run(&block)
    end

    def replica_pool
      @replica_pool ||= begin
        pool = Concurrent::Hash.new

        config.replica_uris.each_with_index do |uri, index|
          pool["replica_#{index}"] = ReplicaConnectionHolder.new(uri)
        end
      end
    end

    def random_replica_connection
      replica_pool[replica_pool.keys.sample]
    end

    def config
      @config ||= Config.new
    end

    def base_transaction_depth
      @base_transaction_depth ||= begin
        testcase = ActiveSupport::TestCase
        if defined?(testcase) &&
            testcase.respond_to?(:use_transactional_fixtures) &&
            testcase.try(:use_transactional_fixtures)
          1
        else
          0
        end
      end
    end
  end
end
