require 'spec_helper'

describe "WithDisposableTransactionExtension#with_disposable_transaction" do
  let!(:blog) { Blog.create! :title => 'foo' }
  it "runs a transaction and rolls it back" do
    previous_open_transaction_count = Blog.connection.open_transactions
    Blog.with_disposable_transaction do
      blog.update_attributes! :title => 'bar'
      blog.reload.title.should == 'bar'
      Blog.connection.open_transactions.should == previous_open_transaction_count + 1
    end
    blog.reload.title.should == 'foo'
    Blog.connection.open_transactions.should == previous_open_transaction_count
  end
  it "preserves the return value" do
    result = Blog.with_disposable_transaction do
      1
    end
    result.should == 1
  end
  it "raises any StandardError occuring in the block" do
    expect do
      Blog.with_disposable_transaction do
        raise "Example Error"
      end
    end.to raise_error("Example Error")
  end
end

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

