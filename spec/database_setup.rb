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

require 'logger'
require 'erb'
config = YAML.load(ERB.new(File.read(File.dirname(__FILE__) + '/database.yml')).result)
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite3'])
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)

ActiveRecord::Schema.define(:version => 2) do
  create_table :blogs, :force => true do |t|
    t.column :title, :string
    t.column :counter, :integer
    t.timestamps :null => false
  end
  create_table :comments, :force => true do |t|
    t.column :blog_id, :integer
    t.column :counter, :integer
    t.column :text, :string
    t.timestamps :null => false
  end
  create_table :links, :force => true do |t|
    t.column :blog_id, :integer
    t.column :counter, :integer
    t.column :name, :string
    t.timestamps :null => false
  end
end

class Blog < ActiveRecord::Base
  has_many :comments, :dependent => :destroy
  has_many :links, :dependent => :destroy
  include CallbackMatcher::ActiveRecordHooks
end

class Comment < ActiveRecord::Base
  belongs_to :blog
  include CallbackMatcher::ActiveRecordHooks
end

class Link < ActiveRecord::Base
  belongs_to :blog
  include CallbackMatcher::ActiveRecordHooks
end

FactoryGirl.define do
  factory :blog, :aliases => [:another_blog] do
    sequence(:title) { |n| "Title #{n}" }
  end

  factory :comment, :aliases => [:another_comment] do
    sequence(:text) { |n| "Comment #{n}" }
  end
end
