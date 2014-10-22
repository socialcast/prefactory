class PrefactoryLookup < ActiveRecord::Base
  class_attribute :table_created
  def self.create_table
    conn = ActiveRecord::Base.connection
    conn.create_table :prefactory_lookups, :force => true do |t|
      t.column :key, :string
      t.column :result_class, :string
      t.column :result_id, :integer
      t.index [:key], :unique => true
    end
  end
end
