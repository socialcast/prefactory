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

require 'spec_helper'

describe "WithDisposableTransactionExtension#with_disposable_transaction" do
  let!(:blog) { Blog.create! :title => 'foo' }
  it "runs a transaction and rolls it back" do
    previous_open_transaction_count = Blog.connection.open_transactions
    Blog.with_disposable_transaction do
      blog.update_attributes! :title => 'bar'
      expect(blog.reload.title).to eq('bar')
      expect(Blog.connection.open_transactions).to eq(previous_open_transaction_count + 1)
    end
    expect(blog.reload.title).to eq('foo')
    expect(Blog.connection.open_transactions).to eq(previous_open_transaction_count)
  end
  it "preserves the return value" do
    result = Blog.with_disposable_transaction do
      1
    end
    expect(result).to eq(1)
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
  shared_examples_for "synthetic after_commit" do
    it "calls after_commit hooks at this open transaction level, but not above" do
      blog = Blog.create! :title => 'foo'
      expect(blog.called_after_commit).to eq(1)
      expect(blog.reload.title).to eq('foo')

      blog.update_attributes! :title => 'bar'
      expect(blog.called_after_commit).to eq(2)
      expect(blog.reload.title).to eq('bar')

      ActiveRecord::Base.connection.transaction(:requires_new => true) do
        blog.update_attributes! :title => 'quux'
        expect(blog.called_after_commit).to eq(2)
      end
      expect(blog.reload.title).to eq('quux')

      expect(blog.called_after_commit).to eq(3)
      ActiveRecord::Base.connection.transaction(:requires_new => true) do
        blog.update_attributes! :title => 'ragz'
        expect(blog.called_after_commit).to eq(3)
        raise ActiveRecord::Rollback
      end
      expect(blog.called_after_commit).to eq(3)
      expect(blog.reload.title).to eq('quux')
    end

    it "does not call after_commit hooks when an error is raised" do
      blog = Blog.create! :title => 'foo'
      expect(blog.called_after_commit).to eq(1)

      # raise the level at which a synthetic commit should take place
      Blog.with_disposable_transaction do
        blog.update_attributes! :title => 'ragz'
        expect(blog.called_after_commit).to eq(2)
      end

      # raise the level at which a synthetic commit should take place
      Blog.with_disposable_transaction do
        expect do
          ActiveRecord::Base.connection.transaction(:requires_new => true) do
            blog.update_attributes! :title => 'ragz'
            expect(blog.called_after_commit).to eq(2)
            raise "Something blows up"
          end
        end.to raise_error("Something blows up")
        expect(blog.called_after_commit).to eq(2)
        expect(blog.reload.title).to eq('foo')
      end

      expect(blog.called_after_commit).to eq(2)
      expect(blog.reload.title).to eq('foo')
    end

  end

  it "wraps describe blocks in a savepoint transaction" do
    expect(ActiveRecord::Base.connection.current_transaction).to be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
  end
  it "wrapped the suite before this describe block" do
    expect(ActiveRecord::Base.connection.open_transactions).to eq(2)
  end
  it "considers this level as commitable" do
    expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(2)
  end
  it "does not consider a nested transaction to be commitable" do
    ActiveRecord::Base.connection.transaction(:requires_new => true) do
      expect(ActiveRecord::Base.connection.open_transactions).to eq(3)
      expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(2)
    end
  end
  it_behaves_like "synthetic after_commit"

  [:describe, :context].each do |nesting_method|
    send(nesting_method, "with a nested #{nesting_method}") do
      it "is wrapped in in a new savepoint transaction" do
        expect(ActiveRecord::Base.connection.current_transaction).to be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
        expect(ActiveRecord::Base.connection.open_transactions).to eq(3)
      end
      it "considers this level as commitable" do
        expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(3)
      end
      it "does not consider a nested transaction to be commitable" do
        ActiveRecord::Base.connection.transaction(:requires_new => true) do
          expect(ActiveRecord::Base.connection.open_transactions).to eq(4)
          expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(3)
        end
      end
      it_behaves_like "synthetic after_commit"

      [:describe, :context].each do |nesting_method|
        send(nesting_method, "with a nested #{nesting_method}") do
          it "is wrapped in in a new savepoint transaction" do
            expect(ActiveRecord::Base.connection.current_transaction).to be_a ActiveRecord::ConnectionAdapters::SavepointTransaction
            expect(ActiveRecord::Base.connection.open_transactions).to eq(4)
          end
          it "considers this level as commitable" do
            expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(4)
          end
          it "does not consider a nested transaction to be commitable" do
            ActiveRecord::Base.connection.transaction(:requires_new => true) do
              expect(ActiveRecord::Base.connection.open_transactions).to eq(5)
              expect(ActiveRecord::Base.connection.commit_at_open_transaction_level).to eq(4)
            end
          end
          it_behaves_like "synthetic after_commit"
        end
      end
    end
  end
end

