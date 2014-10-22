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

require 'prefactory/active_record_integration'
require 'rspec_around_all'
require 'prefactory/prefactory_lookup'

module Prefactory

  def prefactory_lookup(key)
    PrefactoryLookup.where(:key => key).first
  end

  # instantiate, or access an already-instantiated-and-memoized, prefabricated object.
  def prefactory(key)
    lookup = prefactory_lookup(key)
    return nil unless lookup.present?
    @prefactory_memo ||= {}
    begin
      @prefactory_memo[key] ||= lookup[:result_class].constantize.find(lookup[:result_id])
    rescue
    end
    @prefactory_memo[key]
  end

  def in_before_all?
    @before_all_context
  end

  # prefabricate an object.  Can be passed any block that returns a class accessible by Klass.find(id),
  # or, if no block is passed, invokes create(key, options) to use e.g. a FactoryGirl factory of that key name.
  def prefactory_add(key, *args, &block)
    raise "prefactory_add can only be used in a before(:all) context.  Change to a before(:all) or set!, or use let/let! instead." unless in_before_all?
    result = nil
    clear_prefactory_memoizations
    if block
      result = yield
    else
      result = create(key, *args) if respond_to?(:create)
    end
    if result.present?
      PrefactoryLookup.where(:key => key).first_or_initialize.tap do |lookup|
        lookup.result_class = result.class.name
        lookup.result_id = result.id
        lookup.save!
      end
    else
      warn "WARNING: Failed to add #{key} to prefactory: block result not present"
    end
    clear_prefactory_memoizations
    result
  end

  def self.included(base)
    base.extend RSpecAroundAll
    PrefactoryLookup.create_table

    # Wrap outermost describe block in a transaction, so before(:all) data is rolled back at the end of this suite.
    base.before(:all) do
      clear_prefactory_memoizations
    end
    base.around(:all) do |group|
      ActiveRecord::Base.with_disposable_transaction { group.run_examples }
    end
    base.after(:all) do
      clear_prefactory_memoizations
    end

    # Wrap each example in a transaction, instead of using Rails' transactional
    # fixtures, which does not support itself being wrapped in an outermost transaction.
    base.around(:each) do |example|
      clear_prefactory_memoizations
      ActiveRecord::Base.with_disposable_transaction { example.run }
      clear_prefactory_memoizations
    end

    # Wrap each ExampleGroup in a transaction, so group-level before(:all) settings
    # are scoped only to the group.
    base.instance_eval do
      def describe_with_transaction(*args, &block)
        original_caller = caller
        modified_block = proc do
          instance_eval do
            before(:all) { clear_prefactory_memoizations }
            around(:all) do |group|
              ActiveRecord::Base.with_disposable_transaction { group.run_examples }
            end
            after(:all) { clear_prefactory_memoizations }
          end
          instance_eval(&block)
        end

        caller_metadata = { :caller => original_caller }
        if args.last.is_a?(Hash)
          args.last.merge!(caller_metadata)
        else
          args << caller_metadata
        end

        describe_without_transaction(*args, &modified_block)
      end

      def before_with_detect_before_all(*args, &block)
        before_all_context = (args.first == :all)
        modified_block = proc do
          @before_all_context = before_all_context
          instance_eval(&block)
          @before_all_context = nil
        end
        before_without_detect_before_all(*args, &modified_block)
      end

      class << self
        alias_method_chain :describe, :transaction
        alias_method :context, :describe
        alias_method_chain :before, :detect_before_all
      end

      def set!(key, *args, &set_block)
        before(:all) do
          modified_block = proc { instance_eval(&set_block) } if set_block
          prefactory_add(key, *args, &modified_block)
        end
      end

    end

    # allow shorthand access to a prefabricated object
    # e.g. with prefactory_add(:active_user), calling the method active_user will return the (memoized) object,
    # by invoking the 'prefactory' method.
    base.class_eval do
      def method_missing(key, *args, &block)
        if prefactory_lookup(key)
          prefactory(key)
        else
          super
        end
      end
    end

  end

  private

  def clear_prefactory_memoizations
    @prefactory_memo = {}
  end

end
