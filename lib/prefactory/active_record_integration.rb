# encoding: UTF-8

# Copyright (c) 2014, VMware, Inc. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
            current_transaction.instance_variable_set(:@run_commit_callbacks, true)
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

      if ActiveRecord.version.to_s.start_with?('4.2')
        def rollback
          unless @savepoint_already_released
            connection.rollback_to_savepoint(savepoint_name)
            super
            rollback_records
          end
        end

        def commit
          connection.release_savepoint(savepoint_name)
          super
          if @fake_commit
            @savepoint_already_released = true
            commit_records
          else
            parent = connection.transaction_manager.current_transaction
            records.each { |r| parent.add_record(r) }
          end
        end

      elsif ActiveRecord.version.to_s.start_with?('4')

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
