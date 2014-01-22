require 'active_record/connection_adapters/abstract/database_statements'

module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements

      # Allow for setting a 'base' number of open transactions at which
      # a commit should fire commit callbacks, when nesting transactional
      # example groups.

      attr_writer :commit_at_open_transaction_level

      def commit_at_open_transaction_level
        @commit_at_open_transaction_level || 1
      end

      def transaction_with_transactional_specs(options = {}, &block)
        return_value = nil
        rolled_back = false

        transaction_without_transactional_specs(options.merge(:requires_new => true)) do
          begin
            return_value = yield
          rescue StandardError => e
            rolled_back = true
            raise e
          end
          if !rolled_back && open_transactions <= commit_at_open_transaction_level + 1
            current_transaction.instance_variable_set(:@fake_commit, true)
          end
        end
        return_value
      end
      alias_method_chain :transaction, :transactional_specs

    end
  end
end

require 'active_record/connection_adapters/abstract/transaction'
module ActiveRecord
  module ConnectionAdapters
    class SavepointTransaction

      # If the savepoint was already released, we have an exception in an after-commit callback.
      # That means *this* transaction cannot and should not be rolled back, unlike the parent
      # transactions, which will roll back as the exception bubbles upwards.
      def perform_rollback
        unless @savepoint_already_released
          connection.rollback_to_savepoint
          rollback_records
        end
      end

      def perform_commit
        connection.release_savepoint
        if @fake_commit
          @savepoint_already_released = true
          commit_records
        else
          records.each { |r| parent.add_record(r) }
        end
      end

    end
  end
end

require 'active_record/base'
module WithDisposableTransactionExtension

  # do a transaction with a silent rollback (unless another
  # exception is doing a loud rollback already) and trigger
  # commit logic for any transaction above this open-transaction level.
  def with_disposable_transaction(&block)
    return_value = nil
    ActiveRecord::Base.connection.transaction(:requires_new => true) do
      ActiveRecord::Base.connection.commit_at_open_transaction_level = ActiveRecord::Base.connection.open_transactions
      begin
        return_value = yield
      rescue StandardError => e
        raise e
      end
      raise ActiveRecord::Rollback
    end
    return_value
  end

end
ActiveRecord::Base.send(:extend, WithDisposableTransactionExtension)
