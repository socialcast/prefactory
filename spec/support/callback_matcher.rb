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

class CallbackMatcher
  CALLBACK_EVENTS = [:before, :after]
  CALLBACK_TYPES = [:create, :update, :destroy, :save, :commit]

  module ActiveRecordHooks

    def self.included(base)
      base.class_eval do
        class_attribute :callback_tester_attrs
        self.callback_tester_attrs = []

        CALLBACK_EVENTS.each do |ce|
          CALLBACK_TYPES.each do |ct|
            next if ce == :before && ct == :commit
            callback_name = :"#{ce}_#{ct}"
            callback_attr = :"called_#{callback_name}"

            callback_tester_attrs << callback_attr
            attr_accessor callback_attr

            send( callback_name ) {
              send(:"#{callback_attr}=", send(:"#{callback_attr}").to_i + 1)
            }
          end
        end
        alias_method_chain :initialize, :callback_init
      end
    end

    def initialize_with_callback_init(*args)
      reset_callback_flags!
      initialize_without_callback_init(*args)
    end

    def reset_callback_flags!
      self.class.callback_tester_attrs.each do |attr|
        send("#{attr}=", 0)
      end
    end

  end

end

require 'rspec/matchers'

RSpec::Matchers.define :trigger_callbacks_for do |types|

  check_for_match = ->(model_instance, types) {
    @called = []
    @not_called = []
    Array.wrap(types).each do |ct|
      CallbackMatcher::CALLBACK_EVENTS.each do |ce|
        callback_name = "#{ce}_#{ct}"
        result = model_instance.send("called_#{callback_name}".to_sym)
        @called << callback_name if result
        @not_called << callback_name unless result
      end
    end
  }

  match_for_should do |model_instance|
    check_for_match.call(model_instance, types)
    result = true
    result = false unless @called.present?
    result = false if @not_called.present?
    result
  end

  match_for_should_not do |model_instance|
    check_for_match.call(model_instance, types)
    result = true
    result = false unless @not_called.present?
    result = false if @called.present?
    result
  end

  failure_message_for_should do |actual|
    ["Called:\t#{@called.join("\n\t")}", "Not called:\t#{@called.join("\n\t")}"].join("\n")
  end

  failure_message_for_should_not do |actual|
    ["Called:\t#{@called.join("\n\t")}", "Not called:\t#{@called.join("\n\t")}"].join("\n")
  end

end

