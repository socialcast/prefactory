require 'logger'
require 'erb'
config = YAML.load(ERB.new(File.read(File.dirname(__FILE__) + '/database.yml')).result)
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite3'])

ActiveRecord::Schema.define(:version => 2) do
  create_table :blogs, :force => true do |t|
    t.column :title, :string
    t.column :counter, :integer
    t.timestamps
  end
  create_table :comments, :force => true do |t|
    t.column :blog_id, :integer
    t.column :counter, :integer
    t.column :text, :string
    t.timestamps
  end
  create_table :links, :force => true do |t|
    t.column :blog_id, :integer
    t.column :counter, :integer
    t.column :name, :string
    t.timestamps
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

