require 'spec_helper'

describe "Transactional wrapping" do
  it "wraps describe blocks in a savepoint transaction" do
    ActiveRecord::Base.connection.current_transaction.should be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
  end
  it "wrapped the suite before this describe block" do
    ActiveRecord::Base.connection.open_transactions.should == 2
  end
  it "considers this level as commitable" do
    ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 2
  end
  it "does not consider a nested transaction to be commitable" do
    ActiveRecord::Base.connection.transaction(:requires_new => true) do
      ActiveRecord::Base.connection.open_transactions.should == 3
      ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 2
    end
  end

  [:describe, :context].each do |nesting_method|
    send(nesting_method, "with a nested #{nesting_method}") do
      it "is wrapped in in a new savepoint transaction" do
        ActiveRecord::Base.connection.current_transaction.should be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
        ActiveRecord::Base.connection.open_transactions.should == 3
      end
      it "considers this level as commitable" do
        ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 3
      end
      it "does not consider a nested transaction to be commitable" do
        ActiveRecord::Base.connection.transaction(:requires_new => true) do
          ActiveRecord::Base.connection.open_transactions.should == 4
          ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 3
        end
      end

      [:describe, :context].each do |nesting_method|
        send(nesting_method, "with a nested #{nesting_method}") do
          it "is wrapped in in a new savepoint transaction" do
            ActiveRecord::Base.connection.current_transaction.should be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
            ActiveRecord::Base.connection.open_transactions.should == 4
          end
          it "considers this level as commitable" do
            ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 4
          end
          it "does not consider a nested transaction to be commitable" do
            ActiveRecord::Base.connection.transaction(:requires_new => true) do
              ActiveRecord::Base.connection.open_transactions.should == 5
              ActiveRecord::Base.connection.commit_at_open_transaction_level.should == 4
            end
          end
        end
      end
    end
  end
end

