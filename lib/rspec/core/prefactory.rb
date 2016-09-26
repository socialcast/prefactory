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

require 'rspec_around_all'
require 'prefactory/prefactory_lookup'
require 'yaml'

module Prefactory
  class NotDefined
  end

  def self.included(base)
    base.include Transactionality
    base.include Lookups
  end

  module Lookups
    def self.included(base)
      PrefactoryLookup.create_table

      base.instance_eval do
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
          alias_method :before_without_detect_before_all, :before
          alias_method :before, :before_with_detect_before_all
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
          result = prefactory(key)
          result == Prefactory::NotDefined ? super : result
        end
      end
    end

    def prefactory_lookup(key)
      PrefactoryLookup.where(:key => key).first
    end

    # instantiate, or access an already-instantiated-and-memoized, prefabricated object.
    def prefactory(key)
      @prefactory_memo ||= {}
      @prefactory_memo[key] ||= begin
        lookup = prefactory_lookup(key)
        if lookup.present?
          if lookup[:result_class]
            lookup[:result_class].constantize.find(lookup[:result_id])
          else
            YAML.load(lookup[:result_value])
          end
        else
          Prefactory::NotDefined
        end
      rescue
      end
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
        if result.respond_to?(:id)
          PrefactoryLookup.where(:key => key).first_or_initialize.tap do |lookup|
            lookup.result_class = result.class.name
            lookup.result_id = result.id
            lookup.result_value = nil
            lookup.save!
          end
        else
          PrefactoryLookup.where(:key => key).first_or_initialize.tap do |lookup|
            lookup.result_class = nil
            lookup.result_id = nil
            lookup.result_value = YAML.dump(result)
            lookup.save!
          end
        end
      else
        warn "WARNING: Failed to add #{key} to prefactory: block result not present"
      end
      clear_prefactory_memoizations
      result
    end

    def clear_prefactory_memoizations
      @prefactory_memo = {}
    end
  end

  module Transactionality
    def self.included(base)
      require 'prefactory/active_record_integration'
      base.extend RSpecAroundAll
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

        class << self
          alias_method :describe_without_transaction, :describe
          alias_method :describe, :describe_with_transaction
          alias_method :context, :describe
        end
      end
    end
  end
end
